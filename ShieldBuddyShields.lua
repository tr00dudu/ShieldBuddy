-- Create the ShieldBuddyShields table at the start
ShieldBuddyShields = {}

-- Default shield value tracking data structure
local DEFAULT_SHIELD_DB = {
    -- Personal shields cast on self
    personal = {
        shields = {}  -- Will be populated dynamically
    },
    -- Shields cast by others (party/raid members only)
    external = {
        casters = {},  -- Will store up to 40 other casters
        maxCasters = 40
    }
}

-- Table to define which shields should have their values tracked
local TRACK_SHIELD_VALUES = {
    ["Power Word: Shield"] = true,
    ["Ice Barrier"] = true,
    ["Mana Shield"] = true,
    ["Frost Ward"] = true,
    ["Fire Ward"] = true,
    ["Shadow Ward"] = true,
    ["Sacrifice"] = true
}

-- Spell IDs and their max absorb values
local SHIELD_SPELLS = {
    -- Power Word: Shield (external cast)
    [17] = { name = "Power Word: Shield", value = 48, icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", external = true },    -- Rank 1
    [592] = { name = "Power Word: Shield", value = 94, icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", external = true },   -- Rank 2
    [600] = { name = "Power Word: Shield", value = 166, icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", external = true },  -- Rank 3
    [3747] = { name = "Power Word: Shield", value = 244, icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", external = true }, -- Rank 4
    [6065] = { name = "Power Word: Shield", value = 312, icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", external = true }, -- Rank 5
    [6066] = { name = "Power Word: Shield", value = 381, icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", external = true }, -- Rank 6
    [10898] = { name = "Power Word: Shield", value = 499, icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", external = true }, -- Rank 7
    [10899] = { name = "Power Word: Shield", value = 622, icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", external = true }, -- Rank 8
    [10900] = { name = "Power Word: Shield", value = 782, icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", external = true }, -- Rank 9
    [10901] = { name = "Power Word: Shield", value = 942, icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", external = true }, -- Rank 10

    -- Ice Barrier (self cast)
    [11426] = { name = "Ice Barrier", value = 442, icon = "Interface\\Icons\\Spell_Ice_Lament", self = true }, -- lvl 40
    [13031] = { name = "Ice Barrier", value = 549, icon = "Interface\\Icons\\Spell_Ice_Lament", self = true }, -- lvl 46
    [13032] = { name = "Ice Barrier", value = 678, icon = "Interface\\Icons\\Spell_Ice_Lament", self = true }, -- lvl 52
    [13033] = { name = "Ice Barrier", value = 818, icon = "Interface\\Icons\\Spell_Ice_Lament", self = true }, -- lvl 58

    -- Mana Shield (self cast)
    [1463] = { name = "Mana Shield", value = 120, icon = "Interface\\Icons\\Spell_Shadow_DetectLesserInvisibility", self = true },  -- lvl 20
    [8494] = { name = "Mana Shield", value = 210, icon = "Interface\\Icons\\Spell_Shadow_DetectLesserInvisibility", self = true },  -- lvl 28
    [8495] = { name = "Mana Shield", value = 300, icon = "Interface\\Icons\\Spell_Shadow_DetectLesserInvisibility", self = true },  -- lvl 36
    [10191] = { name = "Mana Shield", value = 390, icon = "Interface\\Icons\\Spell_Shadow_DetectLesserInvisibility", self = true }, -- lvl 44
    [10192] = { name = "Mana Shield", value = 480, icon = "Interface\\Icons\\Spell_Shadow_DetectLesserInvisibility", self = true }, -- lvl 52
    [10193] = { name = "Mana Shield", value = 570, icon = "Interface\\Icons\\Spell_Shadow_DetectLesserInvisibility", self = true }, -- lvl 60

    -- Frost Ward (self cast)
    [6143] = { name = "Frost Ward", value = 165, icon = "Interface\\Icons\\Spell_Frost_FrostWard", self = true },   -- lvl 24
    [8461] = { name = "Frost Ward", value = 290, icon = "Interface\\Icons\\Spell_Frost_FrostWard", self = true },   -- lvl 34
    [8462] = { name = "Frost Ward", value = 470, icon = "Interface\\Icons\\Spell_Frost_FrostWard", self = true },   -- lvl 44
    [10177] = { name = "Frost Ward", value = 675, icon = "Interface\\Icons\\Spell_Frost_FrostWard", self = true },  -- lvl 54
    [28609] = { name = "Frost Ward", value = 920, icon = "Interface\\Icons\\Spell_Frost_FrostWard", self = true },  -- lvl 60

    -- Fire Ward (self cast)
    [543] = { name = "Fire Ward", value = 165, icon = "Interface\\Icons\\Spell_Fire_FireArmor", self = true },    -- lvl 24
    [8457] = { name = "Fire Ward", value = 290, icon = "Interface\\Icons\\Spell_Fire_FireArmor", self = true },   -- lvl 34
    [8458] = { name = "Fire Ward", value = 470, icon = "Interface\\Icons\\Spell_Fire_FireArmor", self = true },   -- lvl 44
    [10223] = { name = "Fire Ward", value = 675, icon = "Interface\\Icons\\Spell_Fire_FireArmor", self = true },  -- lvl 54
    [10225] = { name = "Fire Ward", value = 920, icon = "Interface\\Icons\\Spell_Fire_FireArmor", self = true },  -- lvl 60

    -- Shadow Ward (self cast)
    [6229] = { name = "Shadow Ward", value = 290, icon = "Interface\\Icons\\Spell_Shadow_AntiShadow", self = true },  -- lvl 32
    [11739] = { name = "Shadow Ward", value = 470, icon = "Interface\\Icons\\Spell_Shadow_AntiShadow", self = true }, -- lvl 42
    [11740] = { name = "Shadow Ward", value = 675, icon = "Interface\\Icons\\Spell_Shadow_AntiShadow", self = true }, -- lvl 52
    [28610] = { name = "Shadow Ward", value = 920, icon = "Interface\\Icons\\Spell_Shadow_AntiShadow", self = true }, -- lvl 60

    -- Sacrifice (external - from pet to player)
    [7812] = { name = "Sacrifice", value = 319, icon = "Interface\\Icons\\Spell_Shadow_SacrificialShield", external = true },   -- lvl 16
    [19438] = { name = "Sacrifice", value = 529, icon = "Interface\\Icons\\Spell_Shadow_SacrificialShield", external = true },  -- lvl 24
    [19440] = { name = "Sacrifice", value = 794, icon = "Interface\\Icons\\Spell_Shadow_SacrificialShield", external = true },  -- lvl 32
    [19441] = { name = "Sacrifice", value = 1124, icon = "Interface\\Icons\\Spell_Shadow_SacrificialShield", external = true }, -- lvl 40
    [19442] = { name = "Sacrifice", value = 1503, icon = "Interface\\Icons\\Spell_Shadow_SacrificialShield", external = true }, -- lvl 48
    [19443] = { name = "Sacrifice", value = 1931, icon = "Interface\\Icons\\Spell_Shadow_SacrificialShield", external = true }, -- lvl 60

    -- Protection Potions (self use)
    [7239] = { name = "Frost Protection", value = 1800, icon = "Interface\\Icons\\Spell_Frost_WizardMark", self = true },
    [17544] = { name = "Frost Protection", value = 2600, icon = "Interface\\Icons\\Spell_Frost_WizardMark", self = true }, -- Greater
    [7233] = { name = "Fire Protection", value = 1300, icon = "Interface\\Icons\\Spell_Fire_FireArmor", self = true },
    [17543] = { name = "Fire Protection", value = 2600, icon = "Interface\\Icons\\Spell_Fire_FireArmor", self = true },  -- Greater
    [7254] = { name = "Nature Protection", value = 1800, icon = "Interface\\Icons\\Spell_Nature_SkinofEarth", self = true },
    [17546] = { name = "Nature Protection", value = 2600, icon = "Interface\\Icons\\Spell_Nature_SkinofEarth", self = true }, -- Greater
    [7242] = { name = "Shadow Protection", value = 900, icon = "Interface\\Icons\\Spell_Shadow_AntiShadow", self = true },
    [17548] = { name = "Shadow Protection", value = 2600, icon = "Interface\\Icons\\Spell_Shadow_AntiShadow", self = true }, -- Greater
    [17549] = { name = "Arcane Protection", value = 2600, icon = "Interface\\Icons\\Spell_Nature_WispSplode", self = true }, -- Greater
    [7245] = { name = "Holy Protection", value = 400, icon = "Interface\\Icons\\Spell_Holy_SealOfProtection", self = true },
    [17545] = { name = "Holy Protection", value = 2600, icon = "Interface\\Icons\\Spell_Holy_SealOfProtection", self = true },   -- Greater

    -- Misc (self use)
    [4077] = { name = "Frost Resistance", value = 600, icon = "Interface\\Icons\\Spell_Frost_WizardMark", self = true },  -- Ice Deflector
    [4057] = { name = "Fire Resistance", value = 500, icon = "Interface\\Icons\\Spell_Fire_FireArmor", self = true },   -- Fire Deflector
    [29506] = { name = "The Burrower's Shell", value = 900, icon = "Interface\\Icons\\INV_Misc_Shell_03", self = true },
    
    -- Naxxramas Items (self use)
    [29432] = { name = "Fire Protection", value = 2000, icon = "Interface\\Icons\\Spell_fire_masterofelements", self = true }  -- Frozen Rune
}

-- Table to store shield icons for non-spell shields (like potions)
local SHIELD_ICONS = {
    ["Power Word: Shield"] = "Interface\\Icons\\Spell_Holy_PowerWordShield",
    ["Ice Barrier"] = "Interface\\Icons\\Spell_Ice_Lament",
    ["Mana Shield"] = "Interface\\Icons\\Spell_Shadow_DetectLesserInvisibility",
    ["Frost Ward"] = "Interface\\Icons\\Spell_Frost_FrostWard",
    ["Fire Ward"] = "Interface\\Icons\\Spell_Fire_FireArmor",
    ["Shadow Ward"] = "Interface\\Icons\\Spell_Shadow_AntiShadow",
    ["Sacrifice"] = "Interface\\Icons\\Spell_Shadow_SacrificialShield",
    ["Frost Protection"] = "Interface\\Icons\\Spell_Frost_WizardMark",
    ["Fire Protection"] = "Interface\\Icons\\Spell_Fire_FireArmor",
    ["Nature Protection"] = "Interface\\Icons\\Spell_Nature_SkinofEarth",
    ["Shadow Protection"] = "Interface\\Icons\\Spell_Shadow_AntiShadow",
    ["Arcane Protection"] = "Interface\\Icons\\Spell_Nature_WispSplode",
    ["Holy Protection"] = "Interface\\Icons\\Spell_Holy_SealOfProtection",
    ["Frost Resistance"] = "Interface\\Icons\\Spell_Frost_WizardMark",
    ["Fire Resistance"] = "Interface\\Icons\\Spell_Fire_FireArmor",
    ["The Burrower's Shell"] = "Interface\\Icons\\INV_Misc_Shell_03",
    ["Frozen Rune"] = "Interface\\Icons\\Spell_fire_masterofelements"
}


-- Function to get the most recent shield value for a spell
local function GetTrackedShieldValue(spellName, spellId, caster)
    if not TRACK_SHIELD_VALUES[spellName] then
        ShieldBuddy.Debug("GetTrackedShieldValue - Shield not tracked: " .. spellName)
        return nil
    end

    local _, playerGuid = UnitExists("player")
    ShieldBuddy.Debug("GetTrackedShieldValue - Checking " .. spellName .. " (ID: " .. spellId .. ")")
    
    if caster == playerGuid then
        -- Personal shield
        ShieldBuddy.Debug("GetTrackedShieldValue - Checking personal shield")
        if ShieldBuddyShieldDB.personal.shields[spellName] and
           ShieldBuddyShieldDB.personal.shields[spellName][spellId] then
            local values = ShieldBuddyShieldDB.personal.shields[spellName][spellId].values
            if table.getn(values) > 0 then
                ShieldBuddy.Debug("GetTrackedShieldValue - Found personal value: " .. values[1])
                return values[1]  -- Return most recent value
            end
        end
        ShieldBuddy.Debug("GetTrackedShieldValue - No personal value found")
    elseif ShieldBuddy.IsInPlayerGroup(caster) then  -- Only check if caster is in group
        -- External shield
        ShieldBuddy.Debug("GetTrackedShieldValue - Checking external shield")
        if ShieldBuddyShieldDB.external.casters[caster] and
           ShieldBuddyShieldDB.external.casters[caster].shields[spellName] and
           ShieldBuddyShieldDB.external.casters[caster].shields[spellName][spellId] then
            local values = ShieldBuddyShieldDB.external.casters[caster].shields[spellName][spellId].values
            if table.getn(values) > 0 then
                ShieldBuddy.Debug("GetTrackedShieldValue - Found external value: " .. values[1])
                return values[1]  -- Return most recent value
            end
        end
        ShieldBuddy.Debug("GetTrackedShieldValue - No external value found")
    end
    ShieldBuddy.Debug("GetTrackedShieldValue - No value found")
    return nil
end

-- Function to cleanup old caster data
local function CleanupCasterData()
    local casterCount = 0
    local casters = {}
    
    -- Build a sorted list of casters by last seen time
    for caster, data in pairs(ShieldBuddyShieldDB.external.casters) do
        table.insert(casters, {
            caster = caster,
            lastSeen = data.lastSeen
        })
        casterCount = casterCount + 1
    end
    
    -- If we're over the limit, remove oldest casters
    if casterCount > ShieldBuddyShieldDB.external.maxCasters then
        -- Sort by lastSeen (oldest first)
        table.sort(casters, function(a, b) return a.lastSeen < b.lastSeen end)
        
        -- Remove oldest casters until we're at the limit
        for i = 1, casterCount - ShieldBuddyShieldDB.external.maxCasters do
            ShieldBuddyShieldDB.external.casters[casters[i].caster] = nil
        end
    end
end

-- Function to update tracked shield value
local function UpdateTrackedShieldValue(spellName, spellId, caster, newValue)
    if not TRACK_SHIELD_VALUES[spellName] then
        ShieldBuddy.Debug("Not tracking values for " .. spellName)
        return
    end

    local _, playerGuid = UnitExists("player")
    ShieldBuddy.Debug("Updating shield value - Name: " .. spellName .. ", ID: " .. spellId .. ", Value: " .. newValue .. ", Caster: " .. (caster or "nil"))
    
    if caster == playerGuid then
        -- Personal shield
        ShieldBuddy.Debug("Processing as personal shield")
        if not ShieldBuddyShieldDB.personal.shields[spellName] then
            ShieldBuddyShieldDB.personal.shields[spellName] = {}
            ShieldBuddy.Debug("Created new shield entry for " .. spellName)
        end
        if not ShieldBuddyShieldDB.personal.shields[spellName][spellId] then
            ShieldBuddyShieldDB.personal.shields[spellName][spellId] = { values = {} }
            ShieldBuddy.Debug("Created new spell ID entry for " .. spellId)
        end
        
        local values = ShieldBuddyShieldDB.personal.shields[spellName][spellId].values
        table.insert(values, 1, newValue)  -- Add new value at start
        if table.getn(values) > 1 then  -- For now we only keep 1 value
            table.remove(values, 2)
        end
        ShieldBuddy.Debug("Updated personal shield value to " .. newValue)
        
    elseif ShieldBuddy.IsInPlayerGroup(caster) then  -- Only track if caster is in group
        -- External shield
        ShieldBuddy.Debug("Processing as external shield")
        if not ShieldBuddyShieldDB.external.casters[caster] then
            -- Add new caster
            ShieldBuddyShieldDB.external.casters[caster] = {
                shields = {},
                lastSeen = GetTime()
            }
            ShieldBuddy.Debug("Added new caster entry")
        else
            -- Update last seen time
            ShieldBuddyShieldDB.external.casters[caster].lastSeen = GetTime()
        end
        
        local casterData = ShieldBuddyShieldDB.external.casters[caster]
        if not casterData.shields[spellName] then
            casterData.shields[spellName] = {}
            ShieldBuddy.Debug("Created new shield entry for caster")
        end
        if not casterData.shields[spellName][spellId] then
            casterData.shields[spellName][spellId] = { values = {} }
            ShieldBuddy.Debug("Created new spell ID entry for caster")
        end
        
        local values = casterData.shields[spellName][spellId].values
        table.insert(values, 1, newValue)  -- Add new value at start
        if table.getn(values) > 1 then  -- For now we only keep 1 value
            table.remove(values, 2)
        end
        ShieldBuddy.Debug("Updated external shield value to " .. newValue)
    else
        ShieldBuddy.Debug("Caster not in group, skipping update")
    end
end

-- Function to check if a shield's value should be tracked
local function ShouldTrackShieldValue(spellName)
    return TRACK_SHIELD_VALUES[spellName] or false
end

-- Function to get shield info and value
local function GetShieldInfo(spellId, caster)
    local spellInfo = SHIELD_SPELLS[spellId]
    if not spellInfo then 
        -- ShieldBuddy.Debug("GetShieldInfo - No info for spell ID: " .. spellId)
        return nil 
    end
    
    -- Get tracked value if applicable
    local shieldValue = spellInfo.value
    ShieldBuddy.Debug("GetShieldInfo - Base value for " .. spellInfo.name .. ": " .. shieldValue)
    
    if ShouldTrackShieldValue(spellInfo.name) then
        local trackedValue = GetTrackedShieldValue(spellInfo.name, spellId, caster)
        if trackedValue then
            shieldValue = trackedValue
            ShieldBuddy.Debug("GetShieldInfo - Using tracked value: " .. shieldValue)
        else
            ShieldBuddy.Debug("GetShieldInfo - No tracked value found, using base value")
        end
    end
    
    return {
        name = spellInfo.name,
        value = shieldValue,
        icon = spellInfo.icon,
        self = spellInfo.self,
        external = spellInfo.external
    }
end

-- Function to get shield icon
local function GetShieldIcon(shieldName)
    return SHIELD_ICONS[shieldName]
end

-- Function to initialize the shield tracking system
local function Initialize()
    -- Initialize ShieldBuddyShieldDB if it doesn't exist
    if not ShieldBuddyShieldDB then
        ShieldBuddyShieldDB = DEFAULT_SHIELD_DB
    end
    
    -- Ensure all required fields exist
    if not ShieldBuddyShieldDB.personal then
        ShieldBuddyShieldDB.personal = DEFAULT_SHIELD_DB.personal
    end
    if not ShieldBuddyShieldDB.external then
        ShieldBuddyShieldDB.external = DEFAULT_SHIELD_DB.external
    end
    if not ShieldBuddyShieldDB.external.maxCasters then
        ShieldBuddyShieldDB.external.maxCasters = DEFAULT_SHIELD_DB.external.maxCasters
    end
    
    -- Cleanup old caster data on initialization
    CleanupCasterData()
end

-- Function to find spell ID by shield name
local function FindSpellIdByName(shieldName)
    for id, info in pairs(SHIELD_SPELLS) do
        if info.name == shieldName then
            return id
        end
    end
    return nil
end

-- Export functions and tables for use in main addon
ShieldBuddyShields.GetTrackedShieldValue = GetTrackedShieldValue
ShieldBuddyShields.UpdateTrackedShieldValue = UpdateTrackedShieldValue
ShieldBuddyShields.ShouldTrackShieldValue = ShouldTrackShieldValue
ShieldBuddyShields.GetShieldInfo = GetShieldInfo
ShieldBuddyShields.GetShieldIcon = GetShieldIcon
ShieldBuddyShields.Initialize = Initialize
ShieldBuddyShields.FindSpellIdByName = FindSpellIdByName