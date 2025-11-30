-- UI/Filters.lua
-- Filter controls for PetStableManagement

local addonName = "PetStableManagement"

-- Initialize global namespace
_G.PSM = _G.PSM or {}
local PSM = _G.PSM

-- Helper function to apply ElvUI skin to dropdowns properly
local function ApplyElvUIDropdownSkin(dropdown)
    if not ElvUI or not ElvUI[1] or not ElvUI[1]:GetModule("Skins") then return end
    
    local S = ElvUI[1]:GetModule("Skins")
    
    -- Defer the skinning until the dropdown is fully created
    C_Timer.After(0.1, function()
        if dropdown.Button then
            -- Skin the button
            if S.HandleNextPrevButton then
                S:HandleNextPrevButton(dropdown.Button, "down")
            end
            
            -- Adjust button position to account for ElvUI styling
            dropdown.Button:ClearAllPoints()
            dropdown.Button:SetPoint("RIGHT", dropdown, "RIGHT", -10, 3)
        end
        
        -- Skin the backdrop
        if dropdown.Middle then
            dropdown.Middle:SetAlpha(0)
        end
        if dropdown.Left then
            dropdown.Left:SetAlpha(0)
        end
        if dropdown.Right then
            dropdown.Right:SetAlpha(0)
        end
        
        -- Create or update backdrop
        if not dropdown.backdrop then
            dropdown.backdrop = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
            dropdown.backdrop:SetFrameLevel(dropdown:GetFrameLevel() - 1)
            dropdown.backdrop:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 16, -4)
            dropdown.backdrop:SetPoint("BOTTOMRIGHT", dropdown.Button, "BOTTOMRIGHT", 2, -2)
            dropdown.backdrop:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 }
            })
            dropdown.backdrop:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
            dropdown.backdrop:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end
        
        -- Adjust text position
        if dropdown.Text then
            dropdown.Text:ClearAllPoints()
            dropdown.Text:SetPoint("LEFT", dropdown, "LEFT", 22, 2)
            dropdown.Text:SetPoint("RIGHT", dropdown.Button, "LEFT", -2, 2)
        end
    end)
end

function PSM.UI:BuildFilters(panel)
    -- Exotic filter
    panel.exoticCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    panel.exoticCheck:SetSize(25, 25)
    panel.exoticCheck:SetPoint("TOPLEFT", 5, -85)
    PSM.UI:ApplyElvUISkin(panel.exoticCheck, "checkbox")
    panel.exoticCheck.text = panel.exoticCheck:CreateFontString(nil, "OVERLAY")
    panel.exoticCheck.text:SetFont("Fonts\\FRIZQT__.TTF", 10)
    panel.exoticCheck.text:SetPoint("LEFT", panel.exoticCheck, "RIGHT", 5, 0)
    panel.exoticCheck.text:SetText("Exotic Only")

    local debouncedFilter = PSM.Utils:Debounce(function()
        PSM.UI:UpdatePanel()
    end, PSM.Config.UPDATE_DELAY)

    panel.exoticCheck:SetScript("OnClick", function(self)
        PSM.state.exoticFilter = self:GetChecked()
        debouncedFilter()
    end)
    panel.exoticCheck:SetChecked(PSM.state.exoticFilter)

    -- Duplicates filter
    panel.duplicatesCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    panel.duplicatesCheck:SetSize(25, 25)
    panel.duplicatesCheck:SetPoint("TOPLEFT", panel.exoticCheck, "TOPRIGHT", 120, 0)
    PSM.UI:ApplyElvUISkin(panel.duplicatesCheck, "checkbox")
    panel.duplicatesCheck.text = panel.duplicatesCheck:CreateFontString(nil, "OVERLAY")
    panel.duplicatesCheck.text:SetFont("Fonts\\FRIZQT__.TTF", 10)
    panel.duplicatesCheck.text:SetPoint("LEFT", panel.duplicatesCheck, "RIGHT", 5, 0)
    panel.duplicatesCheck.text:SetText("Duplicates Only")
    panel.duplicatesCheck:SetScript("OnClick", function(self)
        PSM.state.duplicatesOnlyFilter = self:GetChecked()
        debouncedFilter()
    end)
    panel.duplicatesCheck:SetChecked(PSM.state.duplicatesOnlyFilter)

    -- Spec dropdown
    panel.specDrop = CreateFrame("Frame", "PetDupSpecDrop", panel, "UIDropDownMenuTemplate")
    panel.specDrop:SetPoint("TOPLEFT", panel.exoticCheck, "BOTTOMLEFT", -15, 2)
    UIDropDownMenu_SetWidth(panel.specDrop, 100)
    
    -- Apply ElvUI skin with proper positioning
    ApplyElvUIDropdownSkin(panel.specDrop)

    UIDropDownMenu_Initialize(panel.specDrop, function()
        local info = UIDropDownMenu_CreateInfo()
        info.text = "  All Specs"
        info.value = "ALL"
        info.checked = (not next(PSM.state.selectedSpecs))
        info.func = function()
            PSM.Utils:ClearTable(PSM.state.selectedSpecs)
            UIDropDownMenu_SetText(panel.specDrop, "All Specs")
            PSM.C_Timer.After(0.1, function() PSM.UI:UpdatePanel() end)
        end
        UIDropDownMenu_AddButton(info)

        for _, spec in ipairs(PSM.state.specList) do
            info = UIDropDownMenu_CreateInfo()
            info.text = "  " .. spec
            info.value = spec
            info.checked = PSM.state.selectedSpecs[spec] or false
            info.keepShownOnClick = true
            info.isNotRadio = true
            info.func = function(_, _, _, checked)
                if checked then
                    PSM.state.selectedSpecs[spec] = true
                else
                    PSM.state.selectedSpecs[spec] = nil
                end

                if not next(PSM.state.selectedSpecs) then
                    UIDropDownMenu_SetText(panel.specDrop, "All Specs")
                else
                    local selected = {}
                    for s in pairs(PSM.state.selectedSpecs) do
                        table.insert(selected, s)
                    end
                    UIDropDownMenu_SetText(panel.specDrop, table.concat(selected, ", "))
                end
                PSM.C_Timer.After(0.1, function() PSM.UI:UpdatePanel() end)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(panel.specDrop, "All Specs")

    -- Family dropdown
    panel.familyDrop = CreateFrame("Frame", "PetDupFamilyDrop", panel, "UIDropDownMenuTemplate")
    panel.familyDrop:SetPoint("TOPLEFT", panel.duplicatesCheck, "BOTTOMLEFT", -15, 2)
    UIDropDownMenu_SetWidth(panel.familyDrop, 100)
    
    -- Apply ElvUI skin with proper positioning
    ApplyElvUIDropdownSkin(panel.familyDrop)

    UIDropDownMenu_Initialize(panel.familyDrop, function()
        local info = UIDropDownMenu_CreateInfo()
        info.text = "  All Families"
        info.value = "ALL"
        info.checked = (not next(PSM.state.selectedFamilies))
        info.func = function()
            PSM.Utils:ClearTable(PSM.state.selectedFamilies)
            UIDropDownMenu_SetText(panel.familyDrop, "All Families")
            PSM.C_Timer.After(0.1, function() PSM.UI:UpdatePanel() end)
        end
        UIDropDownMenu_AddButton(info)

        for _, family in ipairs(PSM.state.familyList) do
            info = UIDropDownMenu_CreateInfo()
            info.text = "  " .. family
            info.value = family
            info.checked = PSM.state.selectedFamilies[family] or false
            info.keepShownOnClick = true
            info.isNotRadio = true
            info.func = function(_, _, _, checked)
                if checked then
                    PSM.state.selectedFamilies[family] = true
                else
                    PSM.state.selectedFamilies[family] = nil
                end

                if not next(PSM.state.selectedFamilies) then
                    UIDropDownMenu_SetText(panel.familyDrop, "All Families")
                else
                    local selected = {}
                    for f in pairs(PSM.state.selectedFamilies) do
                        table.insert(selected, f)
                    end
                    UIDropDownMenu_SetText(panel.familyDrop, table.concat(selected, ", "))
                end
                PSM.C_Timer.After(0.1, function() PSM.UI:UpdatePanel() end)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(panel.familyDrop, "All Families")
end

function PSM.UI:UpdateFilterUI()
    if not PSM.state.panel then return end

    -- Update checkbox states
    if PSM.state.panel.exoticCheck then
        PSM.state.panel.exoticCheck:SetChecked(PSM.state.exoticFilter)
    end
    if PSM.state.panel.duplicatesCheck then
        PSM.state.panel.duplicatesCheck:SetChecked(PSM.state.duplicatesOnlyFilter)
    end

    -- Update dropdown texts
    if PSM.state.panel.specDrop then
        if not next(PSM.state.selectedSpecs) then
            UIDropDownMenu_SetText(PSM.state.panel.specDrop, "All Specs")
        else
            local selected = {}
            for s in pairs(PSM.state.selectedSpecs) do
                table.insert(selected, s)
            end
            UIDropDownMenu_SetText(PSM.state.panel.specDrop, table.concat(selected, ", "))
        end
    end

    if PSM.state.panel.familyDrop then
        if not next(PSM.state.selectedFamilies) then
            UIDropDownMenu_SetText(PSM.state.panel.familyDrop, "All Families")
        else
            local selected = {}
            for f in pairs(PSM.state.selectedFamilies) do
                table.insert(selected, f)
            end
            UIDropDownMenu_SetText(PSM.state.panel.familyDrop, table.concat(selected, ", "))
        end
    end
end

function PSM.UI:BuildSortButtons(panel)
    panel.sortSlotButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.sortSlotButton:SetSize(PSM.Config.BUTTON_WIDTH, PSM.Config.BUTTON_HEIGHT)
    panel.sortSlotButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -38, -80)
    panel.sortSlotButton:SetText("Sort by Slot")
    panel.sortSlotButton:SetNormalFontObject("GameFontNormalSmall")
    PSM.UI:ApplyElvUISkin(panel.sortSlotButton, "button")
    panel.sortSlotButton:SetScript("OnClick", function()
        PSM.state.sortBySlot = not PSM.state.sortBySlot
        if PSM.state.sortBySlot then
            PSM.state.sortByDisplayID = false
        end
        PSM.UI:UpdatePanel()
    end)

    panel.sortDisplayIDButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.sortDisplayIDButton:SetSize(PSM.Config.BUTTON_WIDTH, PSM.Config.BUTTON_HEIGHT)
    panel.sortDisplayIDButton:SetPoint("TOPRIGHT", panel.sortSlotButton, "BOTTOMRIGHT", 0, -5)
    panel.sortDisplayIDButton:SetText("Sort by Model")
    panel.sortDisplayIDButton:SetNormalFontObject("GameFontNormalSmall")
    PSM.UI:ApplyElvUISkin(panel.sortDisplayIDButton, "button")
    panel.sortDisplayIDButton:SetScript("OnClick", function()
        PSM.state.sortByDisplayID = not PSM.state.sortByDisplayID
        if PSM.state.sortByDisplayID then
            PSM.state.sortBySlot = false
        end
        PSM.UI:UpdatePanel()
    end)
end