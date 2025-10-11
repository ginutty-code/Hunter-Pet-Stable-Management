-- WoW API globals
local CreateFrame = _G.CreateFrame
local StableFrame = _G.StableFrame
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth
local UIDropDownMenu_GetSelectedValue = _G.UIDropDownMenu_GetSelectedValue
local UIDropDownMenu_SetSelectedValue = _G.UIDropDownMenu_SetSelectedValue
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton
local CopyTable = _G.CopyTable
local C_Timer = _G.C_Timer
local hooksecurefunc = _G.hooksecurefunc
local C_StableInfo = _G.C_StableInfo

local addonName = "PetDuplicateDetector"

local panel, scrollFrame, content
local rows = {}
local stablePets = {}
local sortByDisplayID = false
local sortBySlot = false
local ROW_HEIGHT = 90
local exoticFilter = false
local duplicatesOnlyFilter = false  -- NEW: Filter for duplicates only
local selectedSpecs = {}
local selectedFamilies = {}
local specList = {}
local familyList = {}

------------------------------------------------------------
-- Ensure row exists
------------------------------------------------------------
local function EnsureRow(i)
    if rows[i] then return rows[i] end

    local row = CreateFrame("Frame", nil, content)
    row:SetSize(500, ROW_HEIGHT)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0, 0, 0, 0.25)

    row.model = CreateFrame("PlayerModel", nil, row)
    row.model:SetSize(90, 90)
    row.model:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.model:SetRotation(math.pi*2)
    row.model:SetPortraitZoom(0.25)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(60, 60)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.model, "RIGHT", 6, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetWidth(300)

    row.makeActive = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.makeActive:SetSize(90, 22)
    row.makeActive:SetPoint("RIGHT", row, "RIGHT", -90, 5)
    row.makeActive:SetText("Make Active")
    row.makeActive:Hide()
    
    row.companion = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.companion:SetSize(80, 22)
    row.companion:SetPoint("RIGHT", row, "RIGHT", -10, 5)
    row.companion:SetText("Companion")
    row.companion:Hide()
    
    row.stable = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.stable:SetSize(60, 22)
    row.stable:SetPoint("RIGHT", row, "RIGHT", -90, -20)
    row.stable:SetText("Stable")
    row.stable:Hide()

    row.release = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.release:SetSize(60, 22)
    row.release:SetPoint("RIGHT", row, "RIGHT", -10, -20)
    row.release:SetText("Release")
    row.release:Hide()

    rows[i] = row
    return row
end

------------------------------------------------------------
-- Collect pet data from Blizzard UI and active slots
------------------------------------------------------------
local function CollectStablePets()
    stablePets = {}

    if not StableFrame then
        print("|cFFFF0000StableFrame not found in CollectStablePets!|r")
        return
    end

    -- Try to collect active pets using C_StableInfo
    if C_StableInfo and C_StableInfo.GetStablePetInfo then
        for slot = 1, 5 do
            local petInfo = C_StableInfo.GetStablePetInfo(slot)
            if petInfo and petInfo.name then
                -- Use the most robust fields for search
                local familyName = petInfo.familyName or (petInfo.family and petInfo.family.name) or petInfo.type or nil
                local specName = petInfo.specialization or petInfo.specName or (petInfo.spec and petInfo.spec.name) or petInfo.Specialization or (petInfo.Specialization and petInfo.Specialization.name) or nil
                local specID = petInfo.specID or petInfo.specId or nil
                table.insert(stablePets, {
                    slotID = slot,
                    name = petInfo.name,
                    icon = petInfo.icon,
                    displayID = petInfo.displayID or 0,
                    petNumber = petInfo.petNumber or 0,
                    petLevel = petInfo.level or 0,
                    familyName = familyName,
                    specName = specName,
                    specID = specID,
                    isExotic = (petInfo.isExotic or petInfo.Exotic) and true or false,
                    isActive = true,
                })
            end
        end
    end

    -- Collect from the StabledPetList (this gets all stabled pets including slot 6)
    local s = StableFrame.StabledPetList and StableFrame.StabledPetList.ScrollBox
    if s then
        local dp = s:GetDataProvider()
        if dp then
            dp:ForEach(function(node)
                local d = node:GetData()
                if d and d.icon then
                    d.isActive = false
                    -- Ensure familyName and specName are present for search
                    if not d.familyName then
                        if d.family and d.family.name then
                            d.familyName = d.family.name
                        elseif d.type then
                            d.familyName = d.type
                        end
                    end
                    if not d.specName then
                        if d.specialization then
                            d.specName = d.specialization
                        elseif d.spec and d.spec.name then
                            d.specName = d.spec.name
                        elseif d.Specialization then
                            if type(d.Specialization) == "table" and d.Specialization.name then
                                d.specName = d.Specialization.name
                            elseif type(d.Specialization) == "string" then
                                d.specName = d.Specialization
                            end
                        end
                    end
                    if not d.specID and (d.specId or d.specID) then
                        d.specID = d.specId or d.specID
                    end
                    -- Ensure isExotic is a boolean, using d.Exotic if present
                    if d.isExotic == nil and d.Exotic ~= nil then
                        d.isExotic = d.Exotic and true or false
                    elseif d.isExotic == nil then
                        d.isExotic = false
                    else
                        d.isExotic = d.isExotic and true or false
                    end
                    table.insert(stablePets, d)
                end
            end, false)
        end
    end

    -- Build unique spec and family lists
    specList = {}
    familyList = {}
    local specSet = {}
    local familySet = {}
    for _, pet in ipairs(stablePets) do
        local specName = pet.specName or pet.specialization
        local familyName = pet.familyName or pet.type
        if specName and not specSet[specName] then table.insert(specList, specName); specSet[specName] = true end
        if familyName and not familySet[familyName] then table.insert(familyList, familyName); familySet[familyName] = true end
    end
end

------------------------------------------------------------
-- Render panel rows
------------------------------------------------------------
local function RenderPanel()
    local searchText = panel.searchBox and panel.searchBox:GetText() or ""
    local searchLower = searchText:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if not panel or not content then
        print("|cFFFF0000RenderPanel: panel or content is nil!|r")
        return
    end

    local pets = CopyTable(stablePets)

    -- NEW: First pass - identify duplicates by grouping
    local duplicateKeys = {}
    if duplicatesOnlyFilter then
        local groups = {}
        for _, pet in ipairs(pets) do
            local key = tostring(pet.icon or 0) .. ":" .. tostring(pet.displayID or 0)
            groups[key] = groups[key] or {}
            table.insert(groups[key], pet)
        end
        -- Mark keys that have duplicates
        for key, group in pairs(groups) do
            if #group > 1 then
                duplicateKeys[key] = true
            end
        end
    end

    -- Apply filters: exotic, spec, family, duplicates, and search
    local filteredPets = {}
    local function should_skip(pet)
        if exoticFilter and not pet.isExotic then return true end
        if next(selectedSpecs) and not selectedSpecs[pet.specName] then return true end
        if next(selectedFamilies) and not selectedFamilies[pet.familyName] then return true end
        
        -- NEW: Check if we should filter to duplicates only
        if duplicatesOnlyFilter then
            local key = tostring(pet.icon or 0) .. ":" .. tostring(pet.displayID or 0)
            if not duplicateKeys[key] then return true end
        end
        
        if searchLower ~= "" then
            local match = false
            if pet.name and pet.name:lower():find(searchLower, 1, true) then match = true end
            if not match and pet.familyName and tostring(pet.familyName):lower():find(searchLower, 1, true) then match = true end
            if not match and pet.specName and tostring(pet.specName):lower():find(searchLower, 1, true) then match = true end
            if not match and pet.specialization and tostring(pet.specialization):lower():find(searchLower, 1, true) then match = true end
            if not match and pet.specID and tostring(pet.specID):find(searchLower, 1, true) then match = true end
            if not match and pet.displayID and tostring(pet.displayID):find(searchLower, 1, true) then match = true end
            if not match then return true end
        end
        return false
    end
    for _, pet in ipairs(pets) do
        if not should_skip(pet) then
            table.insert(filteredPets, pet)
        end
    end

    if sortByDisplayID then
        table.sort(filteredPets, function(a, b)
            return (a.displayID or 0) < (b.displayID or 0)
        end)
    elseif sortBySlot then
        table.sort(filteredPets, function(a, b)
            return (a.slotID or 0) < (b.slotID or 0)
        end)
    end

    -- Group pets by icon+displayID for duplicate detection
    local groups = {}
    local duplicateCount = 0
    for _, pet in ipairs(filteredPets) do
        local key = tostring(pet.icon or 0) .. ":" .. tostring(pet.displayID or 0)
        groups[key] = groups[key] or {}
        table.insert(groups[key], pet)
        if #groups[key] == 2 then
            duplicateCount = duplicateCount + 1
        end
    end
    
    -- Update summary text
    if panel and panel.summary then
        local dupGroups = 0
        for _, group in pairs(groups) do
            if #group > 1 then
                dupGroups = dupGroups + 1
            end
        end
        if dupGroups > 0 then
            panel.summary:SetText(string.format("⚠ Found %d duplicate groups ⚠", dupGroups))
        else
            panel.summary:SetText("✓ No duplicates found")
            panel.summary:SetTextColor(1, 1, 1)
        end
    end

    -- Determine number of columns based on content width
    local contentWidth = content:GetWidth() or 470
    local minRowWidth = 350
    local colCount = 1
    if contentWidth > minRowWidth * 2 + 20 then
        colCount = 2
    end
    local colWidth = math.floor((contentWidth - 8 * (colCount - 1)) / colCount)

    for i, pet in ipairs(filteredPets) do
        local row = EnsureRow(i)
        row:ClearAllPoints()
        local col = ((i - 1) % colCount)
        local rowIdx = math.floor((i - 1) / colCount)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 4 + col * (colWidth + 8), -(rowIdx) * ROW_HEIGHT)
        row:SetWidth(colWidth)
        if row.text then
            row.text:SetWidth(colWidth - 170)
        end

        -- Show 3D model if we have a displayID, otherwise show icon
        if pet.displayID and pet.displayID > 0 then
            row.model:SetDisplayInfo(pet.displayID)
            row.model:Show()
            row.icon:Hide()
        else
            row.icon:SetTexture(pet.icon)
            row.icon:Show()
            row.model:Hide()
        end

        -- Set up buttons if pet is in a slot
        if pet.slotID and pet.slotID > 0 then
            -- Make Active button - find first available active slot (1-5) or use slot 1
            row.makeActive:SetScript("OnClick", function()
                if C_StableInfo and C_StableInfo.SetPetSlot then
                    -- Find first available slot in 1-5
                    local targetSlot = nil
                    for slot = 1, 5 do
                        local occupied = false
                        for _, p in ipairs(stablePets) do
                            if p.slotID == slot then
                                occupied = true
                                break
                            end
                        end
                        if not occupied then
                            targetSlot = slot
                            break
                        end
                    end
                    -- If no free slot found, use slot 1 (replace current active)
                    if not targetSlot then
                        targetSlot = 1
                    end
                    C_StableInfo.SetPetSlot(pet.slotID, targetSlot)
                    C_Timer.After(0.2, UpdatePanel)
                else
                    print("|cFFFF0000C_StableInfo.SetPetSlot not available.|r")
                end
            end)
            -- Only show Make Active if pet is NOT already in slots 1-5
            if pet.slotID >= 1 and pet.slotID <= 5 then
                row.makeActive:Hide()
            else
                row.makeActive:Show()
            end
            -- Companion button - set as companion pet (slot 6)
            row.companion:SetScript("OnClick", function()
                if C_StableInfo and C_StableInfo.SetPetSlot then
                    C_StableInfo.SetPetSlot(pet.slotID, 6)
                    C_Timer.After(0.2, UpdatePanel)
                else
                    print("|cFFFF0000C_StableInfo.SetPetSlot not available.|r")
                end
            end)
            -- Don't show Companion button if already in slot 6
            if pet.slotID == 6 then
                row.companion:Hide()
            else
                row.companion:Show()
            end
            -- Stable button - move to first available stable slot (7-205)
            row.stable:SetScript("OnClick", function()
                if C_StableInfo and C_StableInfo.SetPetSlot then
                    -- Find first available stable slot (7-205)
                    local targetSlot = nil
                    for slot = 7, 205 do
                        local occupied = false
                        for _, p in ipairs(stablePets) do
                            if p.slotID == slot then
                                occupied = true
                                break
                            end
                        end
                        if not occupied then
                            targetSlot = slot
                            break
                        end
                    end
                    if targetSlot then
                        C_StableInfo.SetPetSlot(pet.slotID, targetSlot)
                        C_Timer.After(0.2, UpdatePanel)
                    else
                        print("|cFFFF0000No available stable slots found! (Max 205 slots)|r")
                    end
                else
                    print("|cFFFF0000C_StableInfo.SetPetSlot not available.|r")
                end
            end)
            -- Only show Stable button if pet is in active/companion slots (1-6)
            if pet.slotID >= 1 and pet.slotID <= 6 then
                row.stable:Show()
            else
                row.stable:Hide()
            end
            -- Release button - always show
            row.release:SetScript("OnClick", function()
                if StableFrame and StableFrame.OnPetSelected and StableFrame.ReleasePetButton then
                    StableFrame:OnPetSelected(pet)
                    C_Timer.After(0.05, function()
                        local onClick = StableFrame.ReleasePetButton:GetScript("OnClick")
                        if onClick then
                            onClick(StableFrame.ReleasePetButton)
                        end
                    end)
                end
            end)
            row.release:Show()
        else
            row.makeActive:Hide()
            row.companion:Hide()
            row.stable:Hide()
            row.release:Hide()
        end

        -- Set row text (add Family and Spec info)
        local exoticLabel = pet.isExotic and " |cffff8800[Exotic]|r" or ""
        local familyText = pet.familyName and ("Family: " .. tostring(pet.familyName)) or "Family: ?"
        local specText = pet.specName and ("Spec: " .. tostring(pet.specName)) or "Spec: ?"
        row.text:SetText(string.format(
            "Slot %d: %s%s\nDisplayID: %d\n%s\n%s",
            pet.slotID or 0,
            pet.name or "?",
            exoticLabel,
            pet.displayID or 0,
            familyText,
            specText
        ))

        -- Highlight duplicates in red
        local key = tostring(pet.icon or 0) .. ":" .. tostring(pet.displayID or 0)
        if #groups[key] > 1 then
            row.text:SetTextColor(1, 0.6, 0.6)
            row.bg:SetColorTexture(0.35, 0, 0, 0.35)
        else
            row.text:SetTextColor(1, 1, 1)
            row.bg:SetColorTexture(0, 0, 0, 0.25)
        end

        row:Show()
    end

    -- Hide unused rows
    for i = #filteredPets+1, #rows do
        rows[i]:Hide()
    end
    -- Set content height to fit all rows (row count = ceil(total/colCount))
    local rowTotal = math.ceil(#filteredPets / colCount)
    local newHeight = math.max(rowTotal * ROW_HEIGHT + 10, 100)
    content:SetHeight(newHeight)
end

------------------------------------------------------------
-- Build panel
------------------------------------------------------------
local function BuildPanel()
    -- Dynamically resize content and rows when the panel is resized (set after all objects are created)
    -- Handler is set after panel, scrollFrame, and content are created
    -- ...existing code...
    -- After creating panel, scrollFrame, and content:
    if panel and scrollFrame and content then
        panel:SetScript("OnSizeChanged", function(self, width, height)
            if not scrollFrame or not content then return end
            scrollFrame:SetWidth(width - 20)
            content:SetWidth(scrollFrame:GetWidth() - 10)
            -- Re-render panel to update columns
            RenderPanel()
        end)
    end
    if panel then 
        return -- Panel already exists
    end
    
    if not StableFrame then 
        print("|cFFFF0000StableFrame not found!|r")
        return
    end
    
    panel = CreateFrame("Frame", "PetDuplicateDetectorPanel", StableFrame)
    panel:SetSize(500, 640)
    panel:SetPoint("TOPLEFT", StableFrame, "TOPRIGHT", 0, 0)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    panel:SetResizable(true)
    if panel.SetResizeBounds then
        panel:SetResizeBounds(300, 200, 1200, 1000)
    end
    -- Add a resize handle in the bottom right corner
    if not panel.resizeButton then
        panel.resizeButton = CreateFrame("Button", nil, panel)
        panel.resizeButton:SetSize(16, 16)
        panel.resizeButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 2)
        panel.resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        panel.resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        panel.resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        panel.resizeButton:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                self:GetParent():StartSizing("BOTTOMRIGHT")
            end
        end)
        panel.resizeButton:SetScript("OnMouseUp", function(self, button)
            self:GetParent():StopMovingOrSizing()
        end)
    end
    
    -- Background
    panel.border = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.border:SetAllPoints()
    panel.border:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=30, edgeSize=16,
        insets={left=4,right=4,top=4,bottom=4}
    })
    panel.border:SetBackdropColor(0,0,0,0.25)

    -- Title (centered at top)
    panel.title = panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    panel.title:SetPoint("TOP", panel, "TOP", 0, -10)
    panel.title:SetText("Pet Duplicate Detector")
    
    -- Summary text (centered below title)
    panel.summary = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.summary:SetPoint("TOP", panel.title, "BOTTOM", 0, -8)
    panel.summary:SetText("")
    panel.summary:SetTextColor(1, 1, 1)

    -- Search box (centered below summary)
    panel.searchBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    panel.searchBox:SetSize(130, 22)
    panel.searchBox:SetPoint("TOP", panel.summary, "BOTTOM", 0, -15)
    panel.searchBox:SetAutoFocus(false)
    panel.searchBox:SetText("")
    panel.searchBox:SetScript("OnTextChanged", function()
        C_Timer.After(0.3, UpdatePanel)
    end)
    
    local searchLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("BOTTOM", panel.searchBox, "TOP", 0, 5)
    searchLabel:SetText("Search:")

    -- Exotic filter checkbox 
    panel.exoticCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    panel.exoticCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -85)
    panel.exoticCheck.text = panel.exoticCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.exoticCheck.text:SetPoint("LEFT", panel.exoticCheck, "RIGHT", 5, 0)
    panel.exoticCheck.text:SetText("Exotic Only")
    panel.exoticCheck:SetScript("OnClick", function(self)
        exoticFilter = self:GetChecked()
        C_Timer.After(0.1, UpdatePanel)
    end)
    panel.exoticCheck:SetChecked(exoticFilter)

    -- Duplicates Only checkbox 
    panel.duplicatesCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    panel.duplicatesCheck:SetPoint("TOPLEFT", panel.exoticCheck, "TOPRIGHT", 120, 0)
    panel.duplicatesCheck.text = panel.duplicatesCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.duplicatesCheck.text:SetPoint("LEFT", panel.duplicatesCheck, "RIGHT", 5, 0)
    panel.duplicatesCheck.text:SetText("Duplicates Only")
    panel.duplicatesCheck:SetScript("OnClick", function(self)
        duplicatesOnlyFilter = self:GetChecked()
        C_Timer.After(0.1, UpdatePanel)
    end)
    panel.duplicatesCheck:SetChecked(duplicatesOnlyFilter)

-- Spec dropdown
    panel.specDrop = CreateFrame("Frame", "PetDupSpecDrop", panel, "UIDropDownMenuTemplate")
    panel.specDrop:SetPoint("TOPLEFT", panel.exoticCheck, "BOTTOMLEFT", -15, -5)
    UIDropDownMenu_SetWidth(panel.specDrop, 100)
    -- Fix text alignment - align to left
    _G[panel.specDrop:GetName().."Text"]:SetJustifyH("LEFT")
    UIDropDownMenu_Initialize(panel.specDrop, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "  All Specs"
        info.value = "ALL"
        info.checked = (not next(selectedSpecs))
        info.func = function()
            selectedSpecs = {}
            UIDropDownMenu_SetText(panel.specDrop, "All Specs")
            C_Timer.After(0.1, UpdatePanel)
        end
        UIDropDownMenu_AddButton(info)
        for _, spec in ipairs(specList) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = "  " .. spec  -- Add spacing before text
            info.value = spec
            info.checked = selectedSpecs[spec] or false
            info.keepShownOnClick = true
            info.isNotRadio = true  -- Use checkboxes instead of radio buttons
            info.minWidth = 60  -- Control dropdown menu width
            info.func = function(_, _, _, checked)
                if checked then
                    selectedSpecs[spec] = true
                else
                    selectedSpecs[spec] = nil
                end
                if not next(selectedSpecs) then
                    UIDropDownMenu_SetText(panel.specDrop, "All Specs")
                else
                    local t = {}
                    for s in pairs(selectedSpecs) do table.insert(t, s) end
                    UIDropDownMenu_SetText(panel.specDrop, table.concat(t, ", "))
                end
                C_Timer.After(0.1, UpdatePanel)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    if not next(selectedSpecs) then
        UIDropDownMenu_SetText(panel.specDrop, "All Specs")
    else
        local t = {}
        for s in pairs(selectedSpecs) do table.insert(t, s) end
        UIDropDownMenu_SetText(panel.specDrop, table.concat(t, ", "))
    end

        -- Family dropdown
    panel.familyDrop = CreateFrame("Frame", "PetDupFamilyDrop", panel, "UIDropDownMenuTemplate")
    panel.familyDrop:SetPoint("TOPLEFT", panel.duplicatesCheck, "BOTTOMLEFT", -15, -5)
    UIDropDownMenu_SetWidth(panel.familyDrop, 100)
    _G[panel.familyDrop:GetName().."Text"]:SetJustifyH("LEFT")
    UIDropDownMenu_Initialize(panel.familyDrop, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "  All Families"
        info.value = "ALL"
        info.checked = (not next(selectedFamilies))
        info.func = function()
            selectedFamilies = {}
            UIDropDownMenu_SetText(panel.familyDrop, "All Families")
            C_Timer.After(0.1, UpdatePanel)
        end
        UIDropDownMenu_AddButton(info)
        for _, fam in ipairs(familyList) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = "  " .. fam
            info.value = fam
            info.checked = selectedFamilies[fam] or false
            info.keepShownOnClick = true
            info.isNotRadio = true
            info.minWidth = 60
            info.func = function(_, _, _, checked)
                if checked then
                    selectedFamilies[fam] = true
                else
                    selectedFamilies[fam] = nil
                end
                if not next(selectedFamilies) then
                    UIDropDownMenu_SetText(panel.familyDrop, "All Families")
                else
                    local t = {}
                    for f in pairs(selectedFamilies) do table.insert(t, f) end
                    UIDropDownMenu_SetText(panel.familyDrop, table.concat(t, ", "))
                end
                C_Timer.After(0.1, UpdatePanel)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    if not next(selectedFamilies) then
        UIDropDownMenu_SetText(panel.familyDrop, "All Families")
    else
        local t = {}
        for f in pairs(selectedFamilies) do table.insert(t, f) end
        UIDropDownMenu_SetText(panel.familyDrop, table.concat(t, ", "))
    end

    -- Sort by Slot button (right side, aligned with exotic checkbox)
    panel.sortSlotButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.sortSlotButton:SetSize(130, 22)
    panel.sortSlotButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -85)
    panel.sortSlotButton:SetText("Sort by Slot")
    panel.sortSlotButton:SetScript("OnClick", function()
        sortBySlot = not sortBySlot
        if sortBySlot then sortByDisplayID = false end
        UpdatePanel()
    end)

    -- Sort by DisplayID button (right side, below sort by slot)
    panel.sortDisplayIDButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.sortDisplayIDButton:SetSize(130, 22)
    panel.sortDisplayIDButton:SetPoint("TOPRIGHT", panel.sortSlotButton, "BOTTOMRIGHT", 0, -15)
    panel.sortDisplayIDButton:SetText("Sort by DisplayID")
    panel.sortDisplayIDButton:SetScript("OnClick", function()
        sortByDisplayID = not sortByDisplayID
        if sortByDisplayID then sortBySlot = false end
        UpdatePanel()
    end)

    -- Create the scroll frame (moved down to give more space for filters)
    scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -150)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 10)
    
    -- Create the content frame
    content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(scrollFrame:GetWidth() - 10, 500)
    scrollFrame:SetScrollChild(content)
end

------------------------------------------------------------
-- Update panel
------------------------------------------------------------
UpdatePanel = function()
    BuildPanel()
    CollectStablePets()
    RenderPanel()
    
    if panel then
        panel:Show()
        if panel.sortButton then
            panel.sortButton:SetText(sortByDisplayID and "Sorted by DisplayID" or "Sort by DisplayID")
        end
        if panel.sortSlotButton then
            panel.sortSlotButton:SetText(sortBySlot and "Sorted by Slot" or "Sort by Slot")
        end
        if not panel:IsVisible() then
            print("|cFFFF0000Panel failed to show!|r")
        end
    else
        print("|cFFFF0000Panel creation failed!|r")
    end
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PET_STABLE_SHOW")
f:RegisterEvent("PET_STABLE_UPDATE")
f:RegisterEvent("PET_STABLE_CLOSED")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- removed print
    elseif event == "PET_STABLE_SHOW" then
        C_Timer.After(0.3, function()
            UpdatePanel()
            -- Hook release button
            if StableFrame and StableFrame.ReleasePetButton and not StableFrame.ReleasePetButton.petdup_hooked then
                StableFrame.ReleasePetButton.petdup_hooked = true
                hooksecurefunc(StableFrame.ReleasePetButton, "Click", function()
                    C_Timer.After(0.1, UpdatePanel)
                end)
            end
        end)
    elseif event == "PET_STABLE_UPDATE" then
        if panel and panel:IsVisible() then
            C_Timer.After(0.1, UpdatePanel)
        end
    elseif event == "PET_STABLE_CLOSED" then
        if panel then panel:Hide() end
    end
end)
