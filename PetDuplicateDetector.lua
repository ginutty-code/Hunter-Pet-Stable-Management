local addonName = "PetDuplicateDetector"

local panel, scrollFrame, content
local rows = {}
local stablePets = {}
local sortByDisplayID = false
local ROW_HEIGHT = 70

------------------------------------------------------------
-- Ensure row exists
------------------------------------------------------------
local function EnsureRow(i)
    if rows[i] then return rows[i] end

    local row = CreateFrame("Frame", nil, content)
    row:SetSize(470, ROW_HEIGHT)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0, 0, 0, 0.25)

    row.model = CreateFrame("PlayerModel", nil, row)
    row.model:SetSize(100, 100)
    row.model:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.model:SetRotation(math.pi*2)
    row.model:SetPortraitZoom(0.5)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(60, 60)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.model, "RIGHT", 6, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")

    row.release = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.release:SetSize(60, 22)
    row.release:SetPoint("RIGHT", row, "RIGHT", -10, -15)
    row.release:SetText("Release")
    row.release:Hide()

    row.activate = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.activate:SetSize(60, 22)
    row.activate:SetPoint("RIGHT", row, "RIGHT", -80, -15)
    row.activate:SetText("Activate")
    row.activate:Hide()

    rows[i] = row
    return row
end

------------------------------------------------------------
-- Collect pet data from Blizzard UI
------------------------------------------------------------
local function CollectStablePets()
    stablePets = {}

    local s = StableFrame and StableFrame.StabledPetList and StableFrame.StabledPetList.ScrollBox
    if not s then return end
    local dp = s:GetDataProvider()
    if not dp then return end

    dp:ForEach(function(node)
        local d = node:GetData()
        if d and d.icon then
            table.insert(stablePets, d)
        end
    end, false)
end

------------------------------------------------------------
-- Render panel rows
------------------------------------------------------------
local function RenderPanel()
    local pets = CopyTable(stablePets)

    -- Apply search and family filters
    local searchText = panel.searchBox and panel.searchBox:GetText():lower() or ""
    local selectedFamily = UIDropDownMenu_GetSelectedValue(panel.familyFilter)

    local filteredPets = {}
    for _, pet in ipairs(pets) do
        local nameMatch = pet.name and pet.name:lower():find(searchText, 1, true)
        local familyMatch = not selectedFamily or pet.familyName == selectedFamily

        if nameMatch and familyMatch then
            table.insert(filteredPets, pet)
        end
    end

    if sortByDisplayID then
        table.sort(filteredPets, function(a, b)
            return (a.displayID or 0) < (b.displayID or 0)
        end)
    end

    local groups = {}
    for _, pet in ipairs(filteredPets) do
        local key = tostring(pet.icon or 0) .. ":" .. tostring(pet.displayID or 0)
        groups[key] = groups[key] or {}
        table.insert(groups[key], pet)
    end

    for i, pet in ipairs(filteredPets) do
        local row = EnsureRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -(i-1)*ROW_HEIGHT)

        if pet.displayID and pet.displayID > 0 then
            row.model:SetDisplayInfo(pet.displayID)
            row.model:Show()
            row.icon:Hide()
        else
            row.icon:SetTexture(pet.icon)
            row.icon:Show()
            row.model:Hide()
        end

        if pet.slotID and pet.slotID > 0 then
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

            row.activate:SetScript("OnClick", function()
                if StableFrame and StableFrame.StabledPetList and StableFrame.StabledPetList.SetActivePetBySlotIndex then
                    StableFrame.StabledPetList:SetActivePetBySlotIndex(pet.slotID)
                else
                    print("Activate function not available.")
                end
            end)
            row.activate:Show()
        else
            row.release:Hide()
            row.activate:Hide()
        end

        local iconID = tostring(pet.icon or 0)
        row.text:SetText(string.format(
            "Slot %d: %s (%s)\nIcon %s | DisplayID %d | PetNum %d",
            pet.slotID or 0, pet.name or "?", pet.familyName or "?",
            iconID, pet.displayID or 0, pet.petNumber or 0
        ))

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

    for i = #filteredPets+1, #rows do
        rows[i]:Hide()
    end

    content:SetHeight(#filteredPets * ROW_HEIGHT + 10)
end

------------------------------------------------------------
-- Build panel
------------------------------------------------------------
local function BuildPanel()
    if panel then return end
    panel = CreateFrame("Frame", "PetDuplicateDetectorPanel", StableFrame)
    panel:SetSize(500, StableFrame:GetHeight()-80)

    panel:SetPoint("TOPLEFT", StableFrame, "TOPRIGHT", 5, -140)
    panel:SetPoint("BOTTOMLEFT", StableFrame, "BOTTOMRIGHT", 5, 5)

    panel.border = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.border:SetAllPoints()
    panel.border:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=14,
        insets={left=3,right=3,top=3,bottom=3}
    })
    panel.border:SetBackdropColor(0,0,0,0.6)

    panel.title = panel:CreateFontString(nil,"OVERLAY","GameFontNormal")
    panel.title:SetPoint("TOPLEFT",12,-10)
    panel.title:SetText("Pet Duplicate Detector (DisplayID+Icon)")

    panel.sortButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.sortButton:SetSize(120, 22)
    panel.sortButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -10)
    panel.sortButton:SetText("Sort by DisplayID")
    panel.sortButton:SetScript("OnClick", function()
        sortByDisplayID = not sortByDisplayID
        UpdatePanel()
    end)

    panel.searchBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    panel.searchBox:SetSize(160, 22)
    panel.searchBox:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -6)
    panel.searchBox:SetAutoFocus(false)
    panel.searchBox:SetText("")
    panel.searchBox:SetScript("OnTextChanged", function()
        UpdatePanel()
    end)

    panel.familyFilter = CreateFrame("Frame", "PetFamilyDropdown", panel, "UIDropDownMenuTemplate")
    panel.familyFilter:SetPoint("LEFT", panel.searchBox, "RIGHT", 10, 2)

    UIDropDownMenu_Initialize(panel.familyFilter, function(self, level)
        local families = {}
        for _, pet in ipairs(stablePets) do
            if pet.familyName then
                families[pet.familyName] = true
            end
        end

        local sorted = {}
        for name in pairs(families) do table.insert(sorted, name) end
        table.sort(sorted)

        UIDropDownMenu_AddButton({
            text = "All Families",
            value = nil,
            func = function()
                UIDropDownMenu_SetSelectedValue(panel.familyFilter, nil)
                UpdatePanel()
            end
        })

        for _, name in ipairs(sorted) do
            UIDropDownMenu_AddButton({
                text = name,
                value = name,
                func = function()
                    UIDropDownMenu_SetSelectedValue(panel.familyFilter, name)
                    UpdatePanel()
                end
            })
        end
    end)

    UIDropDownMenu_SetWidth(panel.familyFilter, 140)
    UIDropDownMenu_SetSelectedValue(panel.familyFilter, nil)
end

    UIDropDownMenu_AddButton({
        text = "All Families",
        value = nil,
        func = function()
            UIDropDownMenu_SetSelectedValue(panel.familyFilter, nil)
            UpdatePanel()
        end
    })

    for _, name in ipairs(sorted) do
        UIDropDownMenu_AddButton({
            text = name,
            value = name,
            func = function()
                UIDropDownMenu_SetSelectedValue(panel.familyFilter, name)
                UpdatePanel()
            end
        })
    end
end)

UIDropDownMenu_SetWidth(panel.familyFilter, 140)
UIDropDownMenu_SetSelectedValue(panel.familyFilter, nil)

------------------------------------------------------------
-- Update panel
------------------------------------------------------------
function UpdatePanel()
    BuildPanel()
    CollectStablePets()
    RenderPanel()
    panel:Show()

    if panel.sortButton then
        panel.sortButton:SetText(sortByDisplayID and "Sorted by DisplayID" or "Sort by DisplayID")
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
        print("|cFF00FF00PetDuplicateDetector loaded.|r")

    elseif event == "PET_STABLE_SHOW" then
        C_Timer.After(0.2, function()
            UpdatePanel()

            if StableFrame and StableFrame.ReleasePetButton and not StableFrame.ReleasePetButton.petdup_hooked then
                StableFrame.ReleasePetButton.petdup_hooked = true

                hooksecurefunc(StableFrame.ReleasePetButton, "Click", function()
                    C_Timer.After(0.1, function()
                        if type(UpdatePanel) == "function" then
                            UpdatePanel()
                        end
                    end)
                end)
            end
        end)

    elseif event == "PET_STABLE_UPDATE" then
        UpdatePanel()

    elseif event == "PET_STABLE_CLOSED" then
        if panel then panel:Hide() end
    end
end)