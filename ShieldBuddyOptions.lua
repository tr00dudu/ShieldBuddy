-- Create debug chat frame
local debugFrame = DEFAULT_CHAT_FRAME

-- Debug function (global for XML access)
function Debug(msg)
    if debugFrame and ShieldBuddyOptions and ShieldBuddyOptions.DebugMessages == 1 then
        debugFrame:AddMessage("|cFF00FF00ShieldBuddy:|r " .. msg)
    end
end

-- Initialize global options table immediately
ShieldBuddyOptions = ShieldBuddyOptions or {}

-- Default settings
local defaultOptions = {
    DebugMessages = 0,
    ButtonShown = true,
    ButtonPosition = 336,
    ButtonRadius = 78,
    FrameX = 0,    -- Default center X
    FrameY = -200,  -- Position in bottom third of screen
    ShowCumulative = 1,
    ShowIndividual = 0,
    Orientation = "horizontal",  -- Default orientation
    UseShieldColors = 0,        -- Default shield colors off
    ShowCurrentNumbers = 1,     -- Show current shield values
    ShowTotalNumbers = 1        -- Show total/max shield values
}

-- Backup settings for cancel operation
local backupSettings = {}

-- Function to copy settings table
local function CopySettings(source)
    local copy = {}
    for k, v in pairs(source) do
        copy[k] = v
    end
    return copy
end

-- Function to initialize saved variables
local function InitializeSettings()
    -- Create new settings table if it doesn't exist
    if not ShieldBuddyOptions then
        ShieldBuddyOptions = CopySettings(defaultOptions)
    else
        -- Update any missing values with defaults
        for k, v in pairs(defaultOptions) do
            if ShieldBuddyOptions[k] == nil then
                ShieldBuddyOptions[k] = v
            end
        end
        
        -- Ensure numeric values for checkboxes
        if type(ShieldBuddyOptions.ShowCumulative) == "boolean" then
            ShieldBuddyOptions.ShowCumulative = ShieldBuddyOptions.ShowCumulative and 1 or 0
        end
        if type(ShieldBuddyOptions.ShowIndividual) == "boolean" then
            ShieldBuddyOptions.ShowIndividual = ShieldBuddyOptions.ShowIndividual and 1 or 0
        end
        if type(ShieldBuddyOptions.UseShieldColors) == "boolean" then
            ShieldBuddyOptions.UseShieldColors = ShieldBuddyOptions.UseShieldColors and 1 or 0
        end
        if type(ShieldBuddyOptions.ShowCurrentNumbers) == "boolean" then
            ShieldBuddyOptions.ShowCurrentNumbers = ShieldBuddyOptions.ShowCurrentNumbers and 1 or 0
        end
        if type(ShieldBuddyOptions.ShowTotalNumbers) == "boolean" then
            ShieldBuddyOptions.ShowTotalNumbers = ShieldBuddyOptions.ShowTotalNumbers and 1 or 0
        end
    end
    Debug("Settings initialized: Cumulative=" .. (ShieldBuddyOptions.ShowCumulative or "nil") .. 
          ", Individual=" .. (ShieldBuddyOptions.ShowIndividual or "nil") .. 
          ", Orientation=" .. (ShieldBuddyOptions.Orientation or "nil") ..
          ", ShowCurrentNumbers=" .. (ShieldBuddyOptions.ShowCurrentNumbers or "nil") ..
          ", ShowTotalNumbers=" .. (ShieldBuddyOptions.ShowTotalNumbers or "nil"))
end

-- Function to get screen dimensions
local function GetScreenDimensions()
    local width = UIParent:GetWidth()
    local height = UIParent:GetHeight()
    -- Return half dimensions since position is relative to center
    return floor(width/2), floor(height/2)
end

-- Function to update slider ranges
local function UpdateSliderRanges()
    local maxX, maxY = GetScreenDimensions()
    
    local xSlider = getglobal("ShieldBuddyOptionsFrameSliderX")
    if xSlider then
        xSlider:SetMinMaxValues(-maxX, maxX)
        getglobal(xSlider:GetName().."Low"):SetText(-maxX)
        getglobal(xSlider:GetName().."High"):SetText(maxX)
    end
    
    local ySlider = getglobal("ShieldBuddyOptionsFrameSliderY")
    if ySlider then
        ySlider:SetMinMaxValues(-maxY, maxY)
        getglobal(ySlider:GetName().."Low"):SetText(-maxY)
        getglobal(ySlider:GetName().."High"):SetText(maxY)
    end
end

-- Function to toggle options window
function ShieldBuddyOptions_Toggle()
    if (ShieldBuddyOptionsFrame:IsVisible()) then
        ShieldBuddyOptionsFrame:Hide()
    else
        -- Create backup of current settings when opening
        backupSettings = CopySettings(ShieldBuddyOptions)
        ShieldBuddyOptionsFrame:Show()
        -- Update slider ranges based on screen size
        UpdateSliderRanges()
        -- Update slider positions with current values
        local xSlider = getglobal("ShieldBuddyOptionsFrameSliderX")
        local ySlider = getglobal("ShieldBuddyOptionsFrameSliderY")
        if xSlider then xSlider:SetValue(ShieldBuddyOptions.FrameX) end
        if ySlider then ySlider:SetValue(ShieldBuddyOptions.FrameY) end
    end
end

-- Function to confirm settings
function ShieldBuddyOptions_Confirm()
    -- Settings are already saved, just close the window
    ShieldBuddyOptionsFrame:Hide()
end

-- Function to cancel settings
function ShieldBuddyOptions_Cancel()
    -- Restore from backup
    for k, v in pairs(backupSettings) do
        ShieldBuddyOptions[k] = v
    end
    -- Update UI
    ShieldBuddy_UpdatePosition()
    if ShieldBuddyOptions.ButtonShown then
        ShieldBuddyButtonFrame:Show()
    else
        ShieldBuddyButtonFrame:Hide()
    end
    ShieldBuddyButton_UpdatePosition()
    
    -- Update orientation checkboxes
    local horizontalCheck = getglobal("ShieldBuddyOptionsFrameHorizontalCheck")
    local verticalCheck = getglobal("ShieldBuddyOptionsFrameVerticalCheck")
    if horizontalCheck then
        horizontalCheck:SetChecked(ShieldBuddyOptions.Orientation ~= "vertical")
    end
    if verticalCheck then
        verticalCheck:SetChecked(ShieldBuddyOptions.Orientation == "vertical")
    end
    
    -- Update other checkboxes
    local cumulativeCheck = getglobal("ShieldBuddyOptionsFrameCumulativeCheck")
    local individualCheck = getglobal("ShieldBuddyOptionsFrameIndividualCheck")
    if cumulativeCheck then
        cumulativeCheck:SetChecked(ShieldBuddyOptions.ShowCumulative == 1)
    end
    if individualCheck then
        individualCheck:SetChecked(ShieldBuddyOptions.ShowIndividual == 1)
    end
    
    -- Update debug messages checkbox
    local debugMessagesCheck = getglobal("ShieldBuddyOptionsFrameDebugMessagesCheck")
    if debugMessagesCheck then
        debugMessagesCheck:SetChecked(ShieldBuddyOptions.DebugMessages == 1)
    end
    
    ShieldBuddyOptionsFrame:Hide()
end

-- Function to toggle button visibility
function ShieldBuddyButton_Toggle()
    if (ShieldBuddyButtonFrame:IsVisible()) then
        ShieldBuddyButtonFrame:Hide()
        ShieldBuddyOptions.ButtonShown = false
    else
        ShieldBuddyButtonFrame:Show()
        ShieldBuddyOptions.ButtonShown = true
    end
end

-- Function to initialize options
function ShieldBuddyOptions_Init()
    -- Initialize button state
    if ShieldBuddyOptions.ButtonShown then
        ShieldBuddyButtonFrame:Show()
    else
        ShieldBuddyButtonFrame:Hide()
    end
    ShieldBuddyButton_UpdatePosition()
end

-- Function to handle button dragging
function ShieldBuddyButton_BeingDragged()
    local xpos, ypos = GetCursorPosition()
    local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()

    xpos = xmin - xpos / UIParent:GetScale() + 70
    ypos = ypos / UIParent:GetScale() - ymin - 70

    ShieldBuddyButton_SetPosition(math.deg(math.atan2(ypos, xpos)))
end

function ShieldBuddyButton_SetPosition(v)
    if (v < 0) then
        v = v + 360
    end

    ShieldBuddyOptions.ButtonPosition = v
    ShieldBuddyButton_UpdatePosition()
end

function ShieldBuddyButton_UpdatePosition()
    ShieldBuddyButtonFrame:SetPoint(
        "TOPLEFT",
        "Minimap",
        "TOPLEFT",
        54 - (ShieldBuddyOptions.ButtonRadius * cos(ShieldBuddyOptions.ButtonPosition)),
        (ShieldBuddyOptions.ButtonRadius * sin(ShieldBuddyOptions.ButtonPosition)) - 55
    )
end

function ShieldBuddyButton_OnEnter()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("ShieldBuddy")
    GameTooltipTextLeft1:SetTextColor(1, 1, 1)
    GameTooltip:AddLine("Left-Click: Open Settings\nRight-Click & Drag: Move Button")
    GameTooltip:Show()
end

-- Function to update frame position
function ShieldBuddy_UpdatePosition()
    if ShieldBuddyFrame then
        ShieldBuddyFrame:ClearAllPoints()
        ShieldBuddyFrame:SetPoint("CENTER", UIParent, "CENTER", ShieldBuddyOptions.FrameX, ShieldBuddyOptions.FrameY)
    end
end

-- Initialize when addon loads
local function OnEvent()
    if event == "VARIABLES_LOADED" then
        InitializeSettings()
        ShieldBuddyOptions_Init()
        ShieldBuddy_UpdatePosition()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:SetScript("OnEvent", OnEvent) 