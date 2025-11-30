-- Minimap.lua
-- Minimap button functionality for PetStableManagement

local addonName = "PetStableManagement"

-- Initialize global namespace
_G.PSM = _G.PSM or {}
local PSM = _G.PSM

PSM.Minimap = {}

function PSM.Minimap:CreateButton()
    if PSM.state.minimapButton then return end

    local button = CreateFrame("Button", "PetStableManagementMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Background
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    -- Icon
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\Icons\\Ability_Mount_Raptor")
    icon:SetPoint("CENTER", 0, 1)
    button.icon = icon

    -- Click handler
    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            PSM.Minimap:TogglePanel()
        elseif btn == "RightButton" then
            PSM.Minimap:ShowContextMenu(self)
        end
    end)

    -- Drag handler
    button:SetScript("OnDragStart", function(self)
        if not PetStableManagementDB.settings.minimapButton.lock then
            self:LockHighlight()
            self.isMoving = true
            self:SetScript("OnUpdate", PSM.Minimap.OnUpdate)
        end
    end)

    button:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self.isMoving = false
        self:SetScript("OnUpdate", nil)
        PSM.Minimap:SavePosition()
    end)

    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Pet Stable Management", 1, 1, 1)
        GameTooltip:AddLine("Left-click to toggle panel", 0.7, 0.7, 1)
        GameTooltip:AddLine("Right-click for menu", 0.7, 0.7, 1)
        GameTooltip:AddLine("Drag to move", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    PSM.state.minimapButton = button
    PSM.Minimap:UpdatePosition()

    if PetStableManagementDB.settings.minimapButton.hide then
        button:Hide()
    else
        button:Show()
    end
end

function PSM.Minimap:OnUpdate()
    local button = PSM.state.minimapButton
    if not button or not button.isMoving then return end

    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()

    px, py = px / scale, py / scale

    local angle = math.atan2(py - my, px - mx)
    local degrees = math.deg(angle)

    PetStableManagementDB.settings.minimapButton.minimapPos = degrees
    PSM.Minimap:UpdatePosition()
end

function PSM.Minimap:UpdatePosition()
    local button = PSM.state.minimapButton
    if not button then return end

    local angle = math.rad(PetStableManagementDB.settings.minimapButton.minimapPos or 220)
    local x = math.cos(angle) * 100
    local y = math.sin(angle) * 100

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function PSM.Minimap:SavePosition()
    -- Position is already saved in OnUpdate
end

function PSM.Minimap:ShowContextMenu(button)
    local menu = CreateFrame("Frame", "PetStableManagementMinimapMenu", UIParent, "UIDropDownMenuTemplate")

    local menuList = {
        {
            text = "Pet Stable Management",
            isTitle = true,
            notCheckable = true
        },
        {
            text = "Load Pet Model Browser",
            notCheckable = true,
            func = function()
                PSM.ModelsPanel:Toggle()
            end
        },
        {
            text = "Hide Minimap Button",
            notCheckable = true,
            func = function()
                PSM.Minimap:Hide()
                print("|cFFFFAA00Pet Stable Management: Minimap button hidden. Use /psm show to show it again.|r")
            end
        },
        {
            text = "Cancel",
            notCheckable = true,
            func = function() end
        }
    }

    PSM.UIDropDownMenu_Initialize(menu, function()
        for _, item in ipairs(menuList) do
            local info = PSM.UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.isTitle = item.isTitle
            info.notCheckable = item.notCheckable
            info.func = item.func
            PSM.UIDropDownMenu_AddButton(info)
        end
    end)

    PSM.ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0, "MENU")
end

function PSM.Minimap:TogglePanel()
    PSM.state.isStableOpen = StableFrame and StableFrame:IsVisible() or false

    -- Build panel if it doesn't exist
    if not PSM.state.panel then
        PSM.UI:BuildPanel()
        if not PSM.state.panel then
            print("|cFFFF0000Failed to create panel.|r")
            return
        end
    end

    -- If panel is visible, hide it
    if PSM.state.panel and PSM.state.panel:IsVisible() then
        PSM.state.panel:Hide()
        if not PSM.state.isStableOpen then
            PSM.Data:ClearMemory()
        end
        return
    end

    -- Show panel - always try to load data
    if PSM.state.isStableOpen then
        -- Stable is open, collect fresh data
        PSM.Data:CollectStablePets()
        PSM.UI:RenderPanel()
        PSM.UI:UpdatePanelTitle()
        PSM.UI:UpdateSortButtonTexts()
    else
        -- Stable is closed, try to load from snapshot
        local hasData = #PSM.state.stablePets > 0
        
        if not hasData then
            -- Try to load from saved data
            hasData = PSM.Data:LoadPersistentDataForDisplay()
        end
        
        if hasData then
            PSM.UI:RenderPanel()
            PSM.UI:UpdatePanelTitle()
            PSM.UI:UpdateSortButtonTexts()
        else
            print(PSM.Config.MESSAGES.NO_SNAPSHOT)
            return
        end
    end

    if PSM.state.panel then
        PSM.state.panel:Show()
        PSM.state.panel:Raise()
    else
        print("|cFFFF0000Failed to create panel.|r")
    end
end

function PSM.Minimap:Show()
    if PSM.state.minimapButton then
        PSM.state.minimapButton:Show()
        PetStableManagementDB.settings.minimapButton.hide = false
    end
end

function PSM.Minimap:Hide()
    if PSM.state.minimapButton then
        PSM.state.minimapButton:Hide()
        PetStableManagementDB.settings.minimapButton.hide = true
    end
end