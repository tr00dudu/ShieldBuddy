-- Check for SuperWoW
if not SUPERWOW_VERSION then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000ShieldBuddy requires SuperWoW|r")
    return
end

-- At the top of the file, after other SavedVariables
ShieldBuddyAbsorbLog = ShieldBuddyAbsorbLog or {}

-- Helper to check if a value exists in a table
local function AbsorbLogContains(tbl, value)
    for i = 1, table.getn(tbl) do
        if tbl[i] == value then
            return true
        end
    end
    return false
end

-- Helper to normalize string by replacing consecutive numbers with X
local function NormalizeString(str)
    return string.gsub(str, "%d+", "X")
end

-- Shield type to damage type mapping
local SHIELD_DAMAGE_TYPES = {
    ["Mana Shield"] = { "Physical" },
    ["Ice Barrier"] = { "Physical", "Frost", "Fire", "Arcane", "Shadow", "Nature", "Holy" },
    ["The Burrower's Shell"] = { "Physical", "Frost", "Fire", "Arcane", "Shadow", "Nature", "Holy" },
    ["Power Word: Shield"] = { "Physical", "Frost", "Fire", "Arcane", "Shadow", "Nature", "Holy" },
    ["Sacrifice"] = { "Physical", "Frost", "Fire", "Arcane", "Shadow", "Nature", "Holy" },
    ["Frost Resistance"] = { "Frost" },
    ["Fire Resistance"] = { "Fire" },
    ["Frost Ward"] = { "Frost" },
    ["Fire Ward"] = { "Fire" },
    ["Shadow Ward"] = { "Shadow" },
    ["Frost Protection"] = { "Frost" },
    ["Fire Protection"] = { "Fire" },
    ["Nature Protection"] = { "Nature" },
    ["Shadow Protection"] = { "Shadow" },
    ["Arcane Protection"] = { "Arcane" },
    ["Holy Protection"] = { "Holy" }
}

-- Active shield tracking
local activeShields = {
    shields = {},  -- Each shield will be {name, current_value, max_value, spell_id, update_max_value, broke_on_damage}
    order = {}    -- Array to maintain shield activation order
}

-- Function to check if a unit is in player's group
local function IsInPlayerGroup(unitGuid)
    -- If we're in a raid, check raid members
    if UnitInRaid("player") then
        for i = 1, 40 do
            if UnitExists("raid" .. i) then
                local _, raidMemberGuid = UnitExists("raid" .. i)
                if raidMemberGuid == unitGuid then
                    return true
                end
            end
        end
        return false
    end
    
    -- Check party members if not in raid
    if UnitInParty("player") then
        for i = 1, 4 do
            if UnitExists("party" .. i) then
                local _, partyMemberGuid = UnitExists("party" .. i)
                if partyMemberGuid == unitGuid then
                    return true
                end
            end
        end
    end
    
    -- Check if it's the player
    local _, playerGuid = UnitExists("player")
    return unitGuid == playerGuid
end

-- Create debug chat frame
local debugFrame = DEFAULT_CHAT_FRAME

-- Debug function
local function Debug(msg, force)
    if debugFrame and (ShieldBuddyOptions and ShieldBuddyOptions.DebugMessages == 1 or force) then
        debugFrame:AddMessage("|cFF00FF00ShieldBuddy:|r " .. msg)
    end
end

-- Create our main frame
local frame = CreateFrame("Frame", "ShieldBuddyFrame", UIParent)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)  -- Default center position until settings load
frame:SetWidth(225) -- Width of bar (200) + icon (16) + spacing (9)
frame:SetHeight(50)

-- Table to store our shield bars
local shieldBars = {}

-- Shield colors by damage type
local SHIELD_COLORS = {
    ["default"] = { r = 0.5, g = 0.8, b = 1.0 },  -- Light blue (default)
    ["Physical"] = { r = 0.82, g = 0.82, b = 0.82 }, -- Gray
    ["Frost"] = { r = 0.1, g = 0.4, b = 0.7 },      -- Darker Blue
    ["Fire"] = { r = 1.0, g = 0.3, b = 0.1 },       -- Red
    ["Arcane"] = { r = 0.8, g = 0.3, b = 1.0 },     -- Purple
    ["Shadow"] = { r = 0.5, g = 0.2, b = 0.7 },     -- Dark Purple
    ["Nature"] = { r = 0.3, g = 1.0, b = 0.3 },     -- Green
    ["Holy"] = { r = 1.0, g = 0.9, b = 0.3 }        -- Gold
}

-- Function to get shield color
local function GetShieldColor(shieldName)
    if ShieldBuddyOptions.UseShieldColors ~= 1 then
        return SHIELD_COLORS.default.r, SHIELD_COLORS.default.g, SHIELD_COLORS.default.b
    end
    
    local damageTypes = SHIELD_DAMAGE_TYPES[shieldName]
    if not damageTypes then return SHIELD_COLORS.default.r, SHIELD_COLORS.default.g, SHIELD_COLORS.default.b end
    
    -- For shields that absorb multiple damage types, use default light blue
    if table.getn(damageTypes) > 1 then
        return SHIELD_COLORS.default.r, SHIELD_COLORS.default.g, SHIELD_COLORS.default.b
    end
    
    local color = SHIELD_COLORS[damageTypes[1]]
    if color then
        return color.r, color.g, color.b
    end
    
    return SHIELD_COLORS.default.r, SHIELD_COLORS.default.g, SHIELD_COLORS.default.b
end

-- Function to update bar dimensions based on orientation
local function UpdateBarDimensions(barInfo)
    if not barInfo or not barInfo.barFrame then return end
    
    if ShieldBuddyOptions.Orientation == "vertical" then
        barInfo.barFrame:SetWidth(16)
        barInfo.barFrame:SetHeight(200)
        if barInfo.barFrame.bar then
            barInfo.barFrame.bar:SetOrientation("VERTICAL")
        end
        if barInfo.barFrame.iconContainer then
            barInfo.barFrame.iconContainer:SetWidth(16)
            barInfo.barFrame.iconContainer:SetHeight(100)
            barInfo.barFrame.iconContainer:ClearAllPoints()
            barInfo.barFrame.iconContainer:SetPoint("TOP", barInfo.barFrame, "BOTTOM", 0, -2)
        end
        if barInfo.barFrame.icon then
            barInfo.barFrame.icon:GetParent():ClearAllPoints()
            barInfo.barFrame.icon:GetParent():SetPoint("TOP", barInfo.barFrame, "BOTTOM", 0, -2)
        end
    else
        barInfo.barFrame:SetWidth(200)
        barInfo.barFrame:SetHeight(16)
        if barInfo.barFrame.bar then
            barInfo.barFrame.bar:SetOrientation("HORIZONTAL")
        end
        if barInfo.barFrame.iconContainer then
            barInfo.barFrame.iconContainer:SetWidth(100)
            barInfo.barFrame.iconContainer:SetHeight(16)
            barInfo.barFrame.iconContainer:ClearAllPoints()
            barInfo.barFrame.iconContainer:SetPoint("RIGHT", barInfo.barFrame, "LEFT", -2, 0)
        end
        if barInfo.barFrame.icon then
            barInfo.barFrame.icon:GetParent():ClearAllPoints()
            barInfo.barFrame.icon:GetParent():SetPoint("RIGHT", barInfo.barFrame, "LEFT", -2, 0)
        end
    end
end

-- Function to create or get a shield bar
local function GetShieldBar(index, isCumulative)
    if shieldBars[index] then
        UpdateBarDimensions(shieldBars[index])
        return shieldBars[index]
    end
    
    -- Create bar container frame with border
    local barFrame = CreateFrame("Frame", nil, frame)
    if ShieldBuddyOptions.Orientation == "vertical" then
        barFrame:SetWidth(16)
        barFrame:SetHeight(200)
    else
        barFrame:SetWidth(200)
        barFrame:SetHeight(16)
    end
    
    if isCumulative then
        -- Create icon container frame for cumulative bar
        local iconContainer = CreateFrame("Frame", nil, barFrame)
        if ShieldBuddyOptions.Orientation == "vertical" then
            iconContainer:SetWidth(16)  -- Same width as bar
            iconContainer:SetHeight(100)  -- Enough height for multiple icons
            iconContainer:SetPoint("TOP", barFrame, "BOTTOM", 0, -2)  -- Icons below bar
        else
            iconContainer:SetWidth(100)  -- Enough width for multiple icons
            iconContainer:SetHeight(16)
            iconContainer:SetPoint("RIGHT", barFrame, "LEFT", -2, 0)  -- Icons to left of bar
        end
        
        -- Store the icon container and icons table
        barFrame.iconContainer = iconContainer
        barFrame.icons = {}
    else
        -- Create single icon frame for normal bars
        local iconFrame = CreateFrame("Frame", nil, barFrame)
        iconFrame:SetWidth(16)
        iconFrame:SetHeight(16)
        if ShieldBuddyOptions.Orientation == "vertical" then
            iconFrame:SetPoint("TOP", barFrame, "BOTTOM", 0, -2)  -- Icon below bar
        else
            iconFrame:SetPoint("RIGHT", barFrame, "LEFT", -2, 0)  -- Icon to left of bar
        end
        
        -- Create icon texture
        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(iconFrame)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        barFrame.icon = icon
    end
    
    -- Create bar background and border
    barFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 9,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    barFrame:SetBackdropColor(0, 0, 0, 0.5)
    barFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    if isCumulative then
        -- Create container for shield segments
        local segmentContainer = CreateFrame("Frame", nil, barFrame)
        segmentContainer:SetPoint("TOPLEFT", barFrame, "TOPLEFT", 2, -2)
        segmentContainer:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", -2, 2)
        barFrame.segments = {}
        barFrame.segmentContainer = segmentContainer
    else
        -- Create normal status bar
        local bar = CreateFrame("StatusBar", nil, barFrame)
        bar:SetPoint("TOPLEFT", barFrame, "TOPLEFT", 2, -2)
        bar:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", -2, 2)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetStatusBarColor(SHIELD_COLORS.default.r, SHIELD_COLORS.default.g, SHIELD_COLORS.default.b)
        if ShieldBuddyOptions.Orientation == "vertical" then
            bar:SetOrientation("VERTICAL")
        end
        barFrame.bar = bar
    end
    
    -- Create value text
    local valueText
    if isCumulative then
        local textFrame = CreateFrame("Frame", nil, barFrame)
        textFrame:SetFrameStrata("HIGH")
        textFrame:SetAllPoints(barFrame)
        valueText = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    else
        valueText = barFrame.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    end
    valueText:SetPoint("CENTER", barFrame, "CENTER")
    valueText:SetJustifyH("CENTER")
    
    -- Store components
    shieldBars[index] = {
        barFrame = barFrame,
        valueText = valueText,
        isCumulative = isCumulative
    }
    
    return shieldBars[index]
end

-- Function to get shields that can absorb a specific damage type
local function GetShieldsForDamageType(dmgType)
    local shields = {}
    -- Convert incoming damage type to lowercase for comparison
    dmgType = string.lower(dmgType)
    
    -- First get all active shields in their cast order
    for _, shieldName in ipairs(activeShields.order) do
        local shield = activeShields.shields[shieldName]
        if shield and shield.current_value and shield.current_value > 0 then
            local damageTypes = SHIELD_DAMAGE_TYPES[shieldName]
            if damageTypes then
                for _, shieldDmgType in ipairs(damageTypes) do
                    -- Convert shield damage type to lowercase for comparison
                    if string.lower(shieldDmgType) == dmgType or dmgType == "any" then
                        -- Don't add Mana Shield yet
                        if shieldName ~= "Mana Shield" then
                            table.insert(shields, shieldName)
                        end
                        break
                    end
                end
            end
        end
    end
    
    -- Add Mana Shield last if it's active and valid for the damage type
    local manaShield = activeShields.shields["Mana Shield"]
    if manaShield and manaShield.current_value and manaShield.current_value > 0 then
        local manaShieldTypes = SHIELD_DAMAGE_TYPES["Mana Shield"]
        for _, shieldDmgType in ipairs(manaShieldTypes) do
            -- Convert shield damage type to lowercase for comparison
            if string.lower(shieldDmgType) == dmgType or dmgType == "any" then
                table.insert(shields, "Mana Shield")
                break
            end
        end
    end
    
    return shields
end

-- Function to format shield value text based on settings
local function GetShieldValueText(currentValue, maxValue)
    if ShieldBuddyOptions.ShowCurrentNumbers == 1 and ShieldBuddyOptions.ShowTotalNumbers == 1 then
        return currentValue .. " / " .. maxValue
    elseif ShieldBuddyOptions.ShowCurrentNumbers == 1 then
        return tostring(currentValue)
    elseif ShieldBuddyOptions.ShowTotalNumbers == 1 then
        return tostring(maxValue)
    else
        return ""
    end
end

-- Function to update shield display
function UpdateShieldDisplay()
    Debug("Updating shield display")
    local count = 0
    local lastBar = nil
    local totalValue = 0
    local totalMax = 0
    
    -- Hide all bars first
    for _, barInfo in pairs(shieldBars) do
        barInfo.barFrame:Hide()
    end
    
    -- Get shields in same order as they would absorb damage
    local shieldList = GetShieldsForDamageType("any")
    
    -- Don't show anything if no shields are active
    if table.getn(shieldList) == 0 then
        return
    end
    
    -- Create or update cumulative bar if enabled
    if ShieldBuddyOptions.ShowCumulative == 1 then
        local cumulativeBar = GetShieldBar(0, true)
        local segmentSize = ShieldBuddyOptions.Orientation == "vertical" and 196 or 196 -- Total height/width minus borders
        
        -- Clear existing segments and icons
        for _, segment in pairs(cumulativeBar.barFrame.segments) do
            segment:Hide()
        end
        for _, iconInfo in pairs(cumulativeBar.barFrame.icons) do
            if iconInfo and iconInfo.frame then
                iconInfo.frame:Hide()
            end
        end
        
        -- Calculate total values
        for _, shieldName in ipairs(shieldList) do
            totalValue = totalValue + (activeShields.shields[shieldName].current_value or 0)
            totalMax = totalMax + (activeShields.shields[shieldName].max_value or 0)
        end
        
        -- Only show cumulative bar if there are actual shields
        if totalMax > 0 then
            -- Calculate total size needed for icons
            local totalIconSize = (table.getn(shieldList) * 18) - 2  -- Last icon doesn't need spacing
            
            -- First calculate total max value
            local totalMaxValue = 0
            for i, shieldName in ipairs(shieldList) do
                totalMaxValue = totalMaxValue + (activeShields.shields[shieldName].max_value or 0)
            end
            
            -- Reverse the shield list so oldest (first to be damaged) is on the left/top
            local reversedList = {}
            for i = table.getn(shieldList), 1, -1 do
                table.insert(reversedList, shieldList[i])
            end

            -- For vertical orientation, we want oldest at top except Mana Shield
            if ShieldBuddyOptions.Orientation == "vertical" then
                -- First, remove Mana Shield if it exists
                local manaShieldIndex = nil
                for i, shieldName in ipairs(reversedList) do
                    if shieldName == "Mana Shield" then
                        manaShieldIndex = i
                        break
                    end
                end
                
                local manaShield = nil
                if manaShieldIndex then
                    manaShield = table.remove(reversedList, manaShieldIndex)
                end
                
                -- Now reverse the list again for vertical orientation
                local tempList = {}
                for i = table.getn(reversedList), 1, -1 do
                    table.insert(tempList, reversedList[i])
                end
                reversedList = tempList
                
                -- Add Mana Shield back at the end if it existed
                if manaShield then
                    table.insert(reversedList, manaShield)
                end
            end

            -- Create segments
            for i, shieldName in ipairs(reversedList) do
                local currentValue = activeShields.shields[shieldName].current_value
                local maxValue = activeShields.shields[shieldName].max_value
                
                if not cumulativeBar.barFrame.segments[i] then
                    local segment = CreateFrame("StatusBar", nil, cumulativeBar.barFrame.segmentContainer)
                    segment:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
                    local r, g, b = GetShieldColor(shieldName)
                    segment:SetStatusBarColor(r, g, b)
                    if ShieldBuddyOptions.Orientation == "vertical" then
                        segment:SetOrientation("VERTICAL")
                        segment:SetWidth(12)  -- Set fixed width for vertical segments
                    else
                        segment:SetOrientation("HORIZONTAL")
                        segment:SetHeight(12)  -- Set fixed height for horizontal segments
                    end
                    cumulativeBar.barFrame.segments[i] = segment
                else
                    -- Update existing segment color and orientation
                    local segment = cumulativeBar.barFrame.segments[i]
                    local r, g, b = GetShieldColor(shieldName)
                    segment:SetStatusBarColor(r, g, b)
                    if ShieldBuddyOptions.Orientation == "vertical" then
                        segment:SetOrientation("VERTICAL")
                        segment:SetWidth(12)  -- Set fixed width for vertical segments
                    else
                        segment:SetOrientation("HORIZONTAL")
                        segment:SetHeight(12)  -- Set fixed height for horizontal segments
                    end
                end
                
                local segment = cumulativeBar.barFrame.segments[i]
                segment:ClearAllPoints()
                
                if ShieldBuddyOptions.Orientation == "vertical" then
                    -- First segment attaches to top edge
                    if i == 1 then
                        segment:SetPoint("TOPLEFT", cumulativeBar.barFrame.segmentContainer, "TOPLEFT", 0, 0)
                        segment:SetPoint("TOPRIGHT", cumulativeBar.barFrame.segmentContainer, "TOPRIGHT", 0, 0)
                    else
                        -- All other segments attach to the bottom of the previous segment
                        segment:SetPoint("TOPLEFT", cumulativeBar.barFrame.segments[i-1], "BOTTOMLEFT", 0, 0)
                        segment:SetPoint("TOPRIGHT", cumulativeBar.barFrame.segments[i-1], "BOTTOMRIGHT", 0, 0)
                    end
                    
                    -- Calculate height based on max value proportion
                    local height = (maxValue / totalMaxValue) * segmentSize
                    height = math.floor(height + 0.5)
                    segment:SetHeight(height)
                else
                    -- First segment attaches to left edge
                    if i == 1 then
                        segment:SetPoint("TOPLEFT", cumulativeBar.barFrame.segmentContainer, "TOPLEFT", 0, 0)
                        segment:SetPoint("BOTTOMLEFT", cumulativeBar.barFrame.segmentContainer, "BOTTOMLEFT", 0, 0)
                    else
                        -- All other segments attach to the right of the previous segment
                        segment:SetPoint("TOPLEFT", cumulativeBar.barFrame.segments[i-1], "TOPRIGHT", 0, 0)
                        segment:SetPoint("BOTTOMLEFT", cumulativeBar.barFrame.segments[i-1], "BOTTOMRIGHT", 0, 0)
                    end
                    
                    -- Calculate width based on max value proportion
                    local width = (maxValue / totalMaxValue) * segmentSize
                    width = math.floor(width + 0.5)
                    segment:SetWidth(width)
                end
                
                segment:SetMinMaxValues(0, maxValue)
                segment:SetValue(currentValue)
                segment:Show()
            end
            
            -- Create and position icons
            for i, shieldName in ipairs(reversedList) do
                if not cumulativeBar.barFrame.icons[i] then
                    local iconFrame = CreateFrame("Frame", nil, cumulativeBar.barFrame.iconContainer)
                    iconFrame:SetWidth(16)
                    iconFrame:SetHeight(16)
                    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
                    icon:SetAllPoints(iconFrame)
                    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                    cumulativeBar.barFrame.icons[i] = {frame = iconFrame, texture = icon}
                end
                
                local iconInfo = cumulativeBar.barFrame.icons[i]
                iconInfo.frame:ClearAllPoints()
                
                if ShieldBuddyOptions.Orientation == "vertical" then
                    if i == 1 then
                        -- Position topmost icon
                        iconInfo.frame:SetPoint("TOP", cumulativeBar.barFrame.iconContainer, "TOP", 0, 0)
                    else
                        -- Position other icons below
                        iconInfo.frame:SetPoint("TOP", cumulativeBar.barFrame.icons[i-1].frame, "BOTTOM", 0, -2)
                    end
                else
                    if i == 1 then
                        -- Position leftmost icon at calculated offset
                        iconInfo.frame:SetPoint("RIGHT", cumulativeBar.barFrame, "LEFT", -2 - totalIconSize + 16, 0)
                    else
                        -- Position other icons to the right
                        iconInfo.frame:SetPoint("LEFT", cumulativeBar.barFrame.icons[i-1].frame, "RIGHT", 2, 0)
                    end
                end
                
                iconInfo.texture:SetTexture(ShieldBuddyShields.GetShieldIcon(shieldName))
                iconInfo.frame:Show()
            end
            
            -- Update value text
            if ShieldBuddyOptions.Orientation == "vertical" then
                cumulativeBar.valueText:Hide()
            else
                cumulativeBar.valueText:SetText(GetShieldValueText(totalValue, totalMax))
                cumulativeBar.valueText:Show()
            end
            
            -- Position the cumulative bar
            cumulativeBar.barFrame:ClearAllPoints()
            if ShieldBuddyOptions.Orientation == "vertical" then
                cumulativeBar.barFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -18)
            else
                cumulativeBar.barFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -5)
            end
            cumulativeBar.barFrame:Show()
            lastBar = cumulativeBar.barFrame
            count = 1
        end
    end
    
    -- Update individual shield bars if enabled
    if ShieldBuddyOptions.ShowIndividual == 1 then
        for _, shieldName in ipairs(shieldList) do
            count = count + 1
            local barInfo = GetShieldBar(count, false)
            
            -- Position the bar frame
            barInfo.barFrame:ClearAllPoints()
            if ShieldBuddyOptions.Orientation == "vertical" then
                if lastBar then
                    barInfo.barFrame:SetPoint("TOPLEFT", lastBar, "TOPRIGHT", 2, 0)
                else
                    barInfo.barFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -18)
                end
            else
                if lastBar then
                    barInfo.barFrame:SetPoint("TOPLEFT", lastBar, "BOTTOMLEFT", 0, -2)
                else
                    barInfo.barFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -5)
                end
            end
            
            -- Update icon
            barInfo.barFrame.icon:SetTexture(ShieldBuddyShields.GetShieldIcon(shieldName))
            
            -- Update bar value
            local currentValue = activeShields.shields[shieldName].current_value
            local maxValue = activeShields.shields[shieldName].max_value or 0
            barInfo.barFrame.bar:SetMinMaxValues(0, maxValue)
            barInfo.barFrame.bar:SetValue(currentValue)
            
            -- Set bar color
            local r, g, b = GetShieldColor(shieldName)
            barInfo.barFrame.bar:SetStatusBarColor(r, g, b)
            
            -- Update value text
            if ShieldBuddyOptions.Orientation == "vertical" then
                barInfo.valueText:Hide()
            else
                barInfo.valueText:SetText(GetShieldValueText(currentValue, maxValue))
                barInfo.valueText:Show()
            end
            
            -- Show the bar
            barInfo.barFrame:Show()
            
            lastBar = barInfo.barFrame
        end
    end
    
    -- Update frame dimensions based on orientation and number of visible bars
    if ShieldBuddyOptions.Orientation == "vertical" then
        local totalWidth = count * 18  -- 16px per bar + 2px spacing
        frame:SetWidth(math.max(50, totalWidth))
        frame:SetHeight(250)  -- Fixed height for vertical orientation (200px bar + icons + spacing)
    else
        frame:SetWidth(225)  -- Fixed width for horizontal orientation
        frame:SetHeight(math.max(50, count * 18))  -- 16px per bar + 2px spacing
    end
end

-- Function to handle orientation changes
function HandleOrientationChange()
    -- Update dimensions for all existing bars
    for _, barInfo in pairs(shieldBars) do
        UpdateBarDimensions(barInfo)
    end
    -- Force a full update of the display
    UpdateShieldDisplay()
end

-- Function to handle cast events
local function HandleCastEvent(caster, target, event, spellId)
    spellId = tonumber(spellId)
    --Debug("Cast event: " .. spellId)
    
    -- Check if it's a shield spell we care about
    local spellInfo = ShieldBuddyShields.GetShieldInfo(spellId, caster)
    if spellInfo then
        local _, playerGuid = UnitExists("player")
        
        -- Handle self-cast spells
        if spellInfo.self and caster == playerGuid then
            Debug("Self-cast shield detected: " .. spellId .. " (" .. spellInfo.name .. ") with value " .. spellInfo.value)
            
            -- Create or update shield data
            activeShields.shields[spellInfo.name] = {
                name = spellInfo.name,
                current_value = spellInfo.value,
                max_value = spellInfo.value,
                spell_id = spellId
            }
            
            -- Remove if already in order list
            for i = 1, table.getn(activeShields.order) do
                if activeShields.order[i] == spellInfo.name then
                    table.remove(activeShields.order, i)
                    break
                end
            end
            -- Add to end of order list (oldest first)
            table.insert(activeShields.order, spellInfo.name)
            Debug("Shield order updated: " .. table.concat(activeShields.order, ", "))
            UpdateShieldDisplay()
            
        -- Handle externally cast spells
        elseif spellInfo.external and target == playerGuid then
            Debug("External shield received: " .. spellId .. " (" .. spellInfo.name .. ") with value " .. spellInfo.value)
            
            -- Create or update shield data
            activeShields.shields[spellInfo.name] = {
                name = spellInfo.name,
                current_value = spellInfo.value,
                max_value = spellInfo.value,
                spell_id = spellId
            }
            
            -- Remove if already in order list
            for i = 1, table.getn(activeShields.order) do
                if activeShields.order[i] == spellInfo.name then
                    table.remove(activeShields.order, i)
                    break
                end
            end
            -- Add to end of order list (oldest first)
            table.insert(activeShields.order, spellInfo.name)
            Debug("Shield order updated: " .. table.concat(activeShields.order, ", "))
            UpdateShieldDisplay()
        end
    end
end

-- Function to parse absorbed damage from combat text
local function ParseAbsorbAmount(msg)
    -- Check for environmental damage format
    local _, _, damage, absorbed = string.find(msg, "lose (%d+) health for .+%. %((%d+) absorbed%)")
    if damage and absorbed then
        return tonumber(damage) or 0, tonumber(absorbed) or 0
    end
    
    -- First try to parse self damage format
    local _, _, damage, absorbed = string.find(msg, "[Yy]ou suffer (%d+) points? of .+ damage%. %((%d+) absorbed%)")
    if damage and absorbed then
        return tonumber(damage) or 0, tonumber(absorbed) or 0
    end
    
    -- Try to parse elemental damage
    local _, _, damage, dmgType, absorbed = string.find(msg, "(%d+) (%w+) damage from.*%((%d+) absorbed%)")
    if damage and absorbed then
        return tonumber(damage) or 0, tonumber(absorbed) or 0
    end
    
    -- Then try alternate elemental format
    local _, _, damage, dmgType, absorbed = string.find(msg, "(%d+) (%w+) damage.*%((%d+) absorbed%)")
    if damage and absorbed then
        return tonumber(damage) or 0, tonumber(absorbed) or 0
    end
    
    -- Finally try physical damage
    local _, _, damage, absorbed = string.find(msg, "for (%d+).*%((%d+) absorbed%)")
    if damage and absorbed then
        return tonumber(damage) or 0, tonumber(absorbed) or 0
    end
    
    return 0, 0
end

-- Function to parse damage type from combat text
local function ParseDamageType(msg)
    -- Check for environmental damage format first
    local _, _, damageSource = string.find(msg, "lose %d+ health for (.+)%.")
    if damageSource then
        -- Convert "swimming in lava" to Fire damage type
        if damageSource == "swimming in lava" then
            Debug("Parsed environmental damage type: Fire (lava)")
            return "Fire"
        end
        Debug("Parsed environmental damage source: " .. damageSource)
        return damageSource
    end
    
    -- First try to parse self damage format
    local _, _, dmgType = string.find(msg, "[Yy]ou suffer %d+ points? of ([%w%s]+) damage%.")
    if dmgType then
        Debug("Parsed damage type from self damage: " .. dmgType)
        return dmgType
    end
    
    -- Try to parse elemental damage
    _, _, dmgType = string.find(msg, "%d+ (%w+) damage from")
    if dmgType then
        Debug("Parsed damage type from 'from': " .. dmgType)
        return dmgType
    end
    
    -- Then try alternate format
    _, _, dmgType = string.find(msg, "%d+ (%w+) damage")
    if dmgType then
        Debug("Parsed damage type: " .. dmgType)
        return dmgType
    end
    
    -- If no specific damage type found, assume Physical
    return "Physical"
end

-- Function to check if damage is done to the player
local function IsDamageToPlayer(msg)
    if not msg then return false end
    
    -- Check for "you" as the target in various formats
    if string.find(msg, "hits you for") or
       string.find(msg, "crits you for") or
       string.find(msg, "You suffer") or
       string.find(msg, "You lose") then
        return true
    end
    
    -- Check for self-damage patterns (player damaging themselves)
    if string.find(msg, "Your .+ hits you for") or
       string.find(msg, "Your .+ crits you for") then
        return true
    end
    
    -- Check for environmental damage to player
    if string.find(msg, "lose %d+ health for") then
        return true
    end
    
    return false
end

-- Function to handle damage absorption
local function HandleDamageAbsorption(msg)
    if not string.find(msg, "absorbed") then return end
    
    -- Only process if damage is done to the player
    if not IsDamageToPlayer(msg) then
        Debug("Skipping damage absorption - not done to player: " .. msg)
        return
    end
    
    Debug("Processing damage absorption for player: " .. msg)
    
    local damage, absorbed = ParseAbsorbAmount(msg)
    if absorbed <= 0 then return end
    
    local dmgType = ParseDamageType(msg)
    Debug("Damage type: " .. dmgType .. ", Damage: " .. damage .. ", Absorbed: " .. absorbed)
    
    -- Get all shields that can absorb this damage type
    local shields = GetShieldsForDamageType(dmgType)
    Debug("Found " .. table.getn(shields) .. " shields that can absorb " .. dmgType .. " damage")
    local remainingDamage = absorbed
    
    -- Try to absorb damage with each shield in priority order
    for _, shieldName in ipairs(shields) do
        if remainingDamage <= 0 then break end
        
        local shield = activeShields.shields[shieldName]
        Debug(shield.name .. " current value: " .. (shield.current_value or "nil") .. ", max value: " .. (shield.max_value or "nil"))
        
        if shield and shield.current_value and shield.current_value > 0 then
            local absorbedAmount = math.min(shield.current_value, remainingDamage)
        
            -- Only check for max value updates if this is the only shield that can absorb this damage type
            if table.getn(shields) == 1 and absorbed > shield.current_value then
                -- If the shield absorbed more damage than it currently has, adjust the max value and current value
                Debug(string.format("Shield %s absorbed %d damage, which is more than current value %d - adjusting max value and current value", shieldName, absorbed, shield.current_value))
                shield.max_value = shield.max_value + (absorbed - shield.current_value)
                shield.current_value = 1
                shield.update_max_value = true
            else
                local newValue = shield.current_value - absorbedAmount
                if table.getn(shields) == 1 and newValue > 0 and damage > 0 then
                    -- If the shield absorbed less than max damage and broke on damage (player received >0 damage), mark it as broke on damage
                    Debug(string.format("Shield %s absorbed %d damage, it is still supposed to have %d value, but %d damage passed through the shield. Marking shield as broken.", shieldName, absorbed, newValue, damage))
                    shield.broke_on_damage = true
                else
                    Debug(string.format("%s absorbed %d damage, new value: %d", shieldName, absorbedAmount, newValue))
                end
                shield.current_value = newValue
            end
            
            remainingDamage = remainingDamage - absorbedAmount
        end
    end
    
    UpdateShieldDisplay()
end

-- Function to handle events
local function OnEvent()
    local event = event
    local arg1 = arg1
    
    if event == "VARIABLES_LOADED" then
        -- Initialize settings
        if not ShieldBuddyOptions then
            ShieldBuddyOptions = {
                ShowCumulative = 1,
                ShowIndividual = 0,
                Orientation = "horizontal",
                UseShieldColors = 0,
                ShowCurrentNumbers = 1,
                ShowTotalNumbers = 1,
                DebugMessages = 0
            }
        end
        -- Add UseShieldColors if it doesn't exist
        if ShieldBuddyOptions.UseShieldColors == nil then
            ShieldBuddyOptions.UseShieldColors = 0
        end
        
        -- Initialize shield tracking system
        if ShieldBuddyShields and ShieldBuddyShields.Initialize then
            ShieldBuddyShields.Initialize()
            Debug("Registering events...")
            -- Register events only after initialization
            frame:RegisterEvent("UNIT_CASTEVENT")                     -- Cast detection (from SuperAPI)
            frame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")      -- Fade detection
            frame:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS")      -- Physical hits
            frame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE")     -- Spell damage
            frame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")        -- DoT damage
            frame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS")         -- PvP physical damage
            frame:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE")        -- PvP spell damage
            frame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE") -- PvP DoTs
            frame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")     -- Creature DoTs/poisons
            frame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")                   -- Self physical damage
            frame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")                  -- Self-damage with absorb
            frame:RegisterEvent("PLAYER_DEAD")
            Debug("Events registered successfully")
            
            HandleOrientationChange()
            Debug("Addon loaded and ready")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000ShieldBuddy: Error loading shield tracking system|r")
        end
    elseif event == "UNIT_CASTEVENT" then
        local caster, target, _, spellID = arg1, arg2, arg3, arg4
        local _, playerGuid = UnitExists("player")
        
        -- Process if either:
        -- 1. We're the caster (self cast)
        -- 2. We're the target and the caster is in our group (external shield)
        if (caster == playerGuid) or (target == playerGuid and ShieldBuddy.IsInPlayerGroup(caster)) then
            -- Debug("Processing cast event - Caster: " .. (caster or "nil") .. ", Target: " .. (target or "nil") .. ", Spell: " .. (spellID or "nil"))
            HandleCastEvent(caster, target, event, spellID)
        end
    
    -- Shield break detection
    elseif event == "CHAT_MSG_SPELL_AURA_GONE_SELF" then
        local _, _, buffName = string.find(arg1, "(.-)%s+fades from you")
        local shield = activeShields.shields[buffName]
        if shield then
            Debug(buffName .. " faded")
            
            -- If this shield had a higher max value than we thought, update it in our tracking
            if shield and
               shield.spell_id and
               shield.max_value and
               ShieldBuddyShields.ShouldTrackShieldValue(buffName)
            then
                if shield.update_max_value == true then
                    Debug(string.format("Shield %s faded with max value: %d (spell ID: %d)", buffName, shield.max_value, shield.spell_id))
                    local _, playerGuid = UnitExists("player")
                    ShieldBuddyShields.UpdateTrackedShieldValue(buffName, shield.spell_id, playerGuid, shield.max_value)
                elseif shield.broke_on_damage == true then
                    Debug(string.format("Shield %s broke on damage with remaining value: %d (spell ID: %d)", buffName, shield.current_value, shield.spell_id))
                    local _, playerGuid = UnitExists("player")
                    ShieldBuddyShields.UpdateTrackedShieldValue(buffName, shield.spell_id, playerGuid, shield.max_value - shield.current_value)
                end
                
            end

            activeShields.shields[buffName] = nil
            -- Remove from order list
            for i = table.getn(activeShields.order), 1, -1 do
                if activeShields.order[i] == buffName then
                    table.remove(activeShields.order, i)
                    break
                end
            end
            UpdateShieldDisplay()
        end
    elseif event == "PLAYER_DEAD" then
        Debug("Reset triggered by death")
        activeShields.shields = {}
        activeShields.order = {}
        UpdateShieldDisplay()
    else
        -- Early return if no shields are active
        if table.getn(activeShields.order) == 0 then
            Debug("No shields are active, skipping combat log parsing")
            return
        end
        
        -- Handle damage absorption events
        if string.find(arg1 or "", "absorbed") then
            Debug("--------------------------------")
            Debug("Combat text: " .. (arg1 or "nil"))
            HandleDamageAbsorption(arg1)
            Debug("--------------------------------")
        end
    end

    -- Debug: save absorb messages
    -- if arg1 and string.find(arg1, "[Aa]bsorb") then
    --    local normalizedMsg = NormalizeString(arg1)
    --    if not AbsorbLogContains(ShieldBuddyAbsorbLog, normalizedMsg) then
    --        table.insert(ShieldBuddyAbsorbLog, normalizedMsg)
    --        if table.getn(ShieldBuddyAbsorbLog) > 2000 then
    --            table.remove(ShieldBuddyAbsorbLog, 1)
    --        end
    --    end
    --end
end

-- Export functions for use by other files
ShieldBuddy = {
    Debug = Debug,
    IsInPlayerGroup = IsInPlayerGroup
}

-- Register events
frame:RegisterEvent("VARIABLES_LOADED")
frame:SetScript("OnEvent", OnEvent)

-- Show the frame
frame:Show() 