-- WoW API globals
local CreateFrame = _G.CreateFrame
local StableFrame = _G.StableFrame
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth
local UIDropDownMenu_GetSelectedValue = _G.UIDropDownMenu_GetSelectedValue
local UIDropDownMenu_SetSelectedValue = _G.UIDropDownMenu_SetSelectedValue
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton
local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo
local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText
local CopyTable = _G.CopyTable
local C_Timer = _G.C_Timer
local hooksecurefunc = _G.hooksecurefunc
local C_StableInfo = _G.C_StableInfo
local C_Spell = _G.C_Spell
local GetSpellInfo = _G.GetSpellInfo

local addonName = "PetStableManagement"

-- Helper function to get spell name (compatible with both old and new API)
local function GetSpellNameCompat(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    elseif GetSpellInfo then
        return GetSpellInfo(spellID)
    end
    return nil
end

local panel, scrollFrame, content
local rows = {}
local stablePets = {}
local sortByDisplayID = false
local sortBySlot = false
local ROW_HEIGHT = 120  -- Increased to fit 7 lines of abilities
local exoticFilter = false
local duplicatesOnlyFilter = false
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
    row.bg:SetColorTexture(0, 0, 0, 1)

    row.model = CreateFrame("PlayerModel", nil, row)
    row.model:SetSize(90, 90)
    row.model:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.model:SetRotation(math.pi*2)
    row.model:SetPortraitZoom(0.25)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(60, 60)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)

    -- Main pet info text (left side)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row.model, "TOPRIGHT", 6, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetWidth(180)

    -- Abilities section (right side of pet info)
    row.abilitiesHeader = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.abilitiesHeader:SetPoint("TOPLEFT", row.text, "TOPRIGHT", 10, 0)
    row.abilitiesHeader:SetText("|cFFFFD700Abilities:|r")
    row.abilitiesHeader:SetJustifyH("LEFT")
    row.abilitiesHeader:SetWidth(150)

    row.abilitiesList = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.abilitiesList:SetPoint("TOPLEFT", row.abilitiesHeader, "BOTTOMLEFT", 0, -2)
    row.abilitiesList:SetWidth(150)
    row.abilitiesList:SetJustifyH("LEFT")
    row.abilitiesList:SetJustifyV("TOP")

    -- Buttons (far right)
    row.makeActive = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.makeActive:SetSize(80, 22)
    row.makeActive:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -5)
    row.makeActive:SetText("Make Active")
    row.makeActive:Hide()
    
    row.companion = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.companion:SetSize(80, 22)
    row.companion:SetPoint("TOPRIGHT", row.makeActive, "BOTTOMRIGHT", 0, -3)
    row.companion:SetText("Companion")
    row.companion:Hide()
    
    row.stable = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.stable:SetSize(80, 22)
    row.stable:SetPoint("TOPRIGHT", row.companion, "BOTTOMRIGHT", 0, -3)
    row.stable:SetText("Stable")
    row.stable:Hide()

    row.release = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.release:SetSize(80, 22)
    row.release:SetPoint("TOPRIGHT", row.stable, "BOTTOMRIGHT", 0, -3)
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
                
                -- Extract abilities - they are stored as spell IDs
                local abilities = {}
                local abilitySet = {}  -- Track duplicates
                local abilityFields = {"petAbilities", "specAbilities", "abilities", "specialAbilities", "Abilities", "SpecialAbilities"}
                for _, fieldName in ipairs(abilityFields) do
                    if petInfo[fieldName] and type(petInfo[fieldName]) == "table" then
                        for _, ability in ipairs(petInfo[fieldName]) do
                            if type(ability) == "number" then
                                -- It's a spell ID, convert to spell name
                                local spellName = GetSpellNameCompat(ability)
                                if spellName and not abilitySet[spellName] then
                                    table.insert(abilities, spellName)
                                    abilitySet[spellName] = true
                                end
                            elseif type(ability) == "string" then
                                if not abilitySet[ability] then
                                    table.insert(abilities, ability)
                                    abilitySet[ability] = true
                                end
                            elseif type(ability) == "table" then
                                local name = ability.name or ability.Name
                                if name and not abilitySet[name] then
                                    table.insert(abilities, name)
                                    abilitySet[name] = true
                                end
                            end
                        end
                    end
                end
                
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
                    abilities = abilities,
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
                    
                    -- Extract abilities for stabled pets - they are stored as spell IDs
                    local abilities = {}
                    local abilitySet = {}  -- Track duplicates
                    local abilityFields = {"petAbilities", "specAbilities", "abilities", "specialAbilities", "Abilities", "SpecialAbilities"}
                    for _, fieldName in ipairs(abilityFields) do
                        if d[fieldName] and type(d[fieldName]) == "table" then
                            for _, ability in ipairs(d[fieldName]) do
                                if type(ability) == "number" then
                                    -- It's a spell ID, convert to spell name
                                    local spellName = GetSpellNameCompat(ability)
                                    if spellName and not abilitySet[spellName] then
                                        table.insert(abilities, spellName)
                                        abilitySet[spellName] = true
                                    end
                                elseif type(ability) == "string" then
                                    if not abilitySet[ability] then
                                        table.insert(abilities, ability)
                                        abilitySet[ability] = true
                                    end
                                elseif type(ability) == "table" then
                                    local name = ability.name or ability.Name
                                    if name and not abilitySet[name] then
                                        table.insert(abilities, name)
                                        abilitySet[name] = true
                                    end
                                end
                            end
                        end
                    end
                    d.abilities = abilities
                    
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
    if not panel or not content then
        print("|cFFFF0000RenderPanel: panel or content is nil!|r")
        return
    end

    -- Normalize search text
    local searchText = panel.searchBox and panel.searchBox:GetText() or ""
    local searchLower = searchText:lower():gsub("^%s+", ""):gsub("%s+$", "")

    -- Build duplicate groups
    local groups = {}
    for _, pet in ipairs(stablePets) do
        local key = tostring(pet.icon or 0) .. ":" .. tostring(pet.displayID or 0)
        groups[key] = groups[key] or {}
        table.insert(groups[key], pet)
    end

    -- Build duplicateKeys if filter is active
    local duplicateKeys = {}
    if duplicatesOnlyFilter then
        for key, group in pairs(groups) do
            if #group > 1 then
                duplicateKeys[key] = true
            end
        end
    end

    -- Filter pets
    local filteredPets = {}
    for _, pet in ipairs(stablePets) do
        local skip = false

        if exoticFilter and not pet.isExotic then skip = true end
        if not skip and next(selectedSpecs) and not selectedSpecs[pet.specName] then skip = true end
        if not skip and next(selectedFamilies) and not selectedFamilies[pet.familyName] then skip = true end
        if not skip and duplicatesOnlyFilter then
            local key = tostring(pet.icon or 0) .. ":" .. tostring(pet.displayID or 0)
            if not duplicateKeys[key] then skip = true end
        end
        if not skip and searchLower ~= "" then
            local match = false
            local fields = {
                pet.name, pet.familyName, pet.specName,
                pet.specialization, tostring(pet.specID or ""), tostring(pet.displayID or "")
            }
            for _, field in ipairs(fields) do
                if field and tostring(field):lower():find(searchLower, 1, true) then
                    match = true
                    break
                end
            end
            -- Search in abilities
            if not match and pet.abilities and type(pet.abilities) == "table" then
                for _, ability in ipairs(pet.abilities) do
                    local abilityStr = type(ability) == "table" and ability.name or tostring(ability)
                    if abilityStr and abilityStr:lower():find(searchLower, 1, true) then
                        match = true
                        break
                    end
                end
            end
            if not match then skip = true end
        end

        if not skip then
            table.insert(filteredPets, pet)
        end
    end

    -- Sort pets
    if sortByDisplayID then
        table.sort(filteredPets, function(a, b)
            return (a.displayID or 0) < (b.displayID or 0)
        end)
    elseif sortBySlot then
        table.sort(filteredPets, function(a, b)
            return (a.slotID or 0) < (b.slotID or 0)
        end)
    end

    -- Update stats
    local totalFiltered = #filteredPets
    local duplicatePets, duplicateGroups = 0, 0
    for _, group in pairs(groups) do
        if #group > 1 then
            duplicateGroups = duplicateGroups + 1
            duplicatePets = duplicatePets + #group
        end
    end
    if panel.statsText then
        panel.statsText:SetText(string.format("Showing: %d pets  |  Duplicates: %d pets (%d groups)",
            totalFiltered, duplicatePets, duplicateGroups))
    end

    -- Layout
    local contentWidth = content:GetWidth() or 470
    local desiredColWidth = 400
    local colCount = math.max(1, math.floor((contentWidth + 8) / (desiredColWidth + 8)))
    local colWidth = math.floor((contentWidth - 8 * (colCount - 1)) / colCount)
    colWidth = math.max(colWidth, 220)
    local rowTotal = math.ceil(totalFiltered / colCount)

    for i, pet in ipairs(filteredPets) do
        local row = EnsureRow(i)
        row:ClearAllPoints()
        local rowIdx = ((i - 1) % rowTotal)
        local col = math.floor((i - 1) / rowTotal)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 4 + col * (colWidth + 8), -(rowIdx) * ROW_HEIGHT)
        row:SetWidth(colWidth)
        if row.text then row.text:SetWidth(math.min(180, colWidth - 350)) end
        if row.abilitiesHeader then row.abilitiesHeader:SetWidth(math.min(150, colWidth - 280)) end
        if row.abilitiesList then row.abilitiesList:SetWidth(math.min(150, colWidth - 280)) end

        -- Model or icon
        if pet.displayID and pet.displayID > 0 then
            row.model:SetDisplayInfo(pet.displayID)
            row.model:Show()
            row.icon:Hide()
        else
            row.icon:SetTexture(pet.icon)
            row.icon:Show()
            row.model:Hide()
        end

        -- Ability formatting - single column list
        local abilities = type(pet.abilities) == "table" and pet.abilities or {}
        local abilitiesText = ""
        for _, ability in ipairs(abilities) do
            local abilityName = type(ability) == "table" and ability.name or tostring(ability)
            abilitiesText = abilitiesText .. "• " .. abilityName .. "\n"
        end
        
        if row.abilitiesList then 
            row.abilitiesList:SetText(abilitiesText)
        end
        
        -- Show/hide abilities header based on whether there are abilities
        if row.abilitiesHeader then
            if #abilities > 0 then
                row.abilitiesHeader:Show()
                row.abilitiesList:Show()
            else
                row.abilitiesHeader:Hide()
                row.abilitiesList:Hide()
            end
        end

        -- Text block
        local exoticLabel = pet.isExotic and " |cffff8800[Exotic]|r" or ""
        local familyText = pet.familyName and ("Family: " .. pet.familyName) or "Family: ?"
        local specText = pet.specName and ("Spec: " .. pet.specName) or "Spec: ?"
        row.text:SetText(string.format(
            "Slot %d: %s%s\nDisplayID: %d\n%s\n%s",
            pet.slotID or 0,
            pet.name or "?",
            exoticLabel,
            pet.displayID or 0,
            familyText,
            specText
        ))

        -- Highlight duplicates
        local key = tostring(pet.icon or 0) .. ":" .. tostring(pet.displayID or 0)
        if #groups[key] > 1 then
            row.text:SetTextColor(1, 0.6, 0.6)
            row.bg:SetColorTexture(0.35, 0, 0, 0.35)
        else
            row.text:SetTextColor(1, 1, 1)
            row.bg:SetColorTexture(0, 0, 0, 0.25)
        end

        -- Button setup
        if pet.slotID and pet.slotID > 0 then
            -- Make Active button
            row.makeActive:SetScript("OnClick", function()
                if C_StableInfo and C_StableInfo.SetPetSlot then
                    local slot1Pet = nil
                    for _, p in ipairs(stablePets) do
                        if p.slotID == 1 then
                            slot1Pet = p
                            break
                        end
                    end
                    
                    if slot1Pet then
                        local displacementSlot = nil
                        for slot = 2, 5 do
                            local occupied = false
                            for _, p in ipairs(stablePets) do
                                if p.slotID == slot then
                                    occupied = true
                                    break
                                end
                            end
                            if not occupied then
                                displacementSlot = slot
                                break
                            end
                        end
                        if not displacementSlot then
                            for slot = 7, 205 do
                                local occupied = false
                                for _, p in ipairs(stablePets) do
                                    if p.slotID == slot then
                                        occupied = true
                                        break
                                    end
                                end
                                if not occupied then
                                    displacementSlot = slot
                                    break
                                end
                            end
                        end
                        
                        if displacementSlot then
                            C_StableInfo.SetPetSlot(1, displacementSlot)
                            C_Timer.After(0.1, function()
                                C_StableInfo.SetPetSlot(pet.slotID, 1)
                                C_Timer.After(0.2, UpdatePanel)
                            end)
                        else
                            print("|cFFFF0000No available slots to displace pet from slot 1!|r")
                        end
                    else
                        C_StableInfo.SetPetSlot(pet.slotID, 1)
                        C_Timer.After(0.2, UpdatePanel)
                    end
                else
                    print("|cFFFF0000C_StableInfo.SetPetSlot not available.|r")
                end
            end)
            if pet.slotID >= 1 and pet.slotID <= 5 then
                row.makeActive:Hide()
            else
                row.makeActive:Show()
            end
            
            -- Companion button
            row.companion:SetScript("OnClick", function()
                if C_StableInfo and C_StableInfo.SetPetSlot then
                    C_StableInfo.SetPetSlot(pet.slotID, 6)
                    C_Timer.After(0.2, UpdatePanel)
                else
                    print("|cFFFF0000C_StableInfo.SetPetSlot not available.|r")
                end
            end)
            if pet.slotID == 6 then
                row.companion:Hide()
            else
                row.companion:Show()
            end
            
            -- Stable button
            row.stable:SetScript("OnClick", function()
                if C_StableInfo and C_StableInfo.SetPetSlot then
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
            if pet.slotID >= 1 and pet.slotID <= 6 then
                row.stable:Show()
            else
                row.stable:Hide()
            end
            
            -- Release button
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

        row:Show()
    end

    -- Hide unused rows
    for i = #filteredPets + 1, #rows do
        rows[i]:Hide()
        -- Also hide all child elements
        if rows[i].model then rows[i].model:Hide() end
        if rows[i].icon then rows[i].icon:Hide() end
        if rows[i].text then rows[i].text:SetText("") end
        if rows[i].abilitiesHeader then rows[i].abilitiesHeader:Hide() end
        if rows[i].abilitiesList then 
            rows[i].abilitiesList:Hide()
            rows[i].abilitiesList:SetText("")
        end
        if rows[i].makeActive then rows[i].makeActive:Hide() end
        if rows[i].companion then rows[i].companion:Hide() end
        if rows[i].stable then rows[i].stable:Hide() end
        if rows[i].release then rows[i].release:Hide() end
    end
    
    -- Resize content
    content:SetHeight(math.max(rowTotal * ROW_HEIGHT + 10, 100))
end

------------------------------------------------------------
-- Build panel
------------------------------------------------------------
local function BuildPanel()
    if panel then 
        return
    end
    
    if not StableFrame then 
        print("|cFFFF0000StableFrame not found!|r")
        return
    end
    
    panel = CreateFrame("Frame", "PetStableManagementPanel", UIParent)
    panel:SetSize(500, 640)
    panel:SetPoint("TOPLEFT", StableFrame, "TOPRIGHT", 0, 0)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetFrameLevel(1000)
    panel:SetToplevel(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    panel:SetResizable(true)
    if panel.SetResizeBounds then
        panel:SetResizeBounds(300, 200, 4800, 1000)
    end
    
    -- Add resize handle
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

    -- Background
    panel.border = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.border:SetAllPoints()
    panel.border:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=30, edgeSize=5,
        insets={left=4,right=4,top=4,bottom=4}
    })
    panel.border:SetBackdropColor(0,0,0,0.7)
    panel.border:SetFrameLevel(panel:GetFrameLevel() - 1)

    -- Close button
    panel.closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    panel.closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -5)
    panel.closeButton:SetSize(20, 20)
    panel.closeButton:SetFrameLevel(panel:GetFrameLevel() + 10)
    panel.closeButton:SetScript("OnClick", function()
        panel:Hide()
    end)

    -- Title
    panel.title = panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    panel.title:SetPoint("TOP", panel, "TOP", 0, -10)
    panel.title:SetText("Pet Stable Management")
    panel.title:SetTextColor(1, 0.82, 0)
    panel.title:SetDrawLayer("OVERLAY", 7)

    -- Search box
    panel.searchBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    panel.searchBox:SetSize(130, 22)
    panel.searchBox:SetPoint("TOP", panel.title, "BOTTOM", 0, -15)
    panel.searchBox:SetAutoFocus(false)
    panel.searchBox:SetText("")
    panel.searchBox:SetScript("OnTextChanged", function()
        C_Timer.After(0.3, UpdatePanel)
    end)
    
    local searchLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("BOTTOM", panel.searchBox, "TOP", 0, 1)
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
            info.text = "  " .. spec
            info.value = spec
            info.checked = selectedSpecs[spec] or false
            info.keepShownOnClick = true
            info.isNotRadio = true
            info.minWidth = 60
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

        for _, family in ipairs(familyList) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = "  " .. family
            info.value = family
            info.checked = selectedFamilies[family] or false
            info.keepShownOnClick = true
            info.isNotRadio = true
            info.minWidth = 60
            info.func = function(_, _, _, checked)
                if checked then
                    selectedFamilies[family] = true
                else
                    selectedFamilies[family] = nil
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

    -- Sort by Slot button
    panel.sortSlotButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.sortSlotButton:SetSize(130, 22)
    panel.sortSlotButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -35, -85)
    panel.sortSlotButton:SetText("Sort by Slot")
    panel.sortSlotButton:SetScript("OnClick", function()
        sortBySlot = not sortBySlot
        if sortBySlot then sortByDisplayID = false end
        UpdatePanel()
    end)

    -- Sort by DisplayID button
    panel.sortDisplayIDButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.sortDisplayIDButton:SetSize(130, 22)
    panel.sortDisplayIDButton:SetPoint("TOPRIGHT", panel.sortSlotButton, "BOTTOMRIGHT", 0, -15)
    panel.sortDisplayIDButton:SetText("Sort by DisplayID")
    panel.sortDisplayIDButton:SetScript("OnClick", function()
        sortByDisplayID = not sortByDisplayID
        if sortByDisplayID then sortBySlot = false end
        UpdatePanel()
    end)

    -- Create scroll frame
    scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -150)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 35)
    
    -- Create content frame
    content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(scrollFrame:GetWidth() - 10, 500)
    scrollFrame:SetScrollChild(content)
    
    -- Statistics text
    panel.statsText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.statsText:SetPoint("BOTTOM", panel, "BOTTOM", 0, 10)
    panel.statsText:SetText("Showing: 0 pets  |  Duplicates: 0 pets (0 groups)")
    panel.statsText:SetTextColor(1, 0.82, 0)
    panel.statsText:SetDrawLayer("OVERLAY", 7)
    
    -- Handle panel resize
    panel:SetScript("OnSizeChanged", function(self, width, height)
        if not scrollFrame or not content then return end

        scrollFrame:SetWidth(width - 20)
        scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -150)
        scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 35)

        content:SetWidth(scrollFrame:GetWidth() - 10)
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT")
        content:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT")

        C_Timer.After(0.05, RenderPanel)
    end)
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
        if panel.sortDisplayIDButton then
            panel.sortDisplayIDButton:SetText(sortByDisplayID and "Sorted by DisplayID" or "Sort by DisplayID")
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
        -- Addon loaded
    elseif event == "PET_STABLE_SHOW" then
        C_Timer.After(0.3, function()
            UpdatePanel()
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
