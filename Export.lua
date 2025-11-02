-- Export.lua
-- Export functionality for PetStableManagement

local addonName = "PetStableManagement"

-- Initialize global namespace
_G.PSM = _G.PSM or {}
local PSM = _G.PSM

PSM.Export = {}

function PSM.Export:EscapeCSVField(field)
    if not field then return "" end

    local str = tostring(field)
    -- If field contains comma, quote, or newline, wrap in quotes and escape quotes
    if str:find('[,"\n]') then
        str = '"' .. str:gsub('"', '""') .. '"'
    end
    return str
end

function PSM.Export:GenerateCSV()
    local lines = {}

    -- CSV Header - add new columns for ability types
    local header = {
        "Slot",
        "Name",
        "Display ID",
        "Pet Number",
        "Level",
        "Family",
        "Specialization",
        "Spec ID",
        "Is Exotic",
        "Is Active",
        "Spec Abilities",
        "Family Abilities",
        "Pet Abilities",
        "Other Abilities"
    }
    table.insert(lines, table.concat(header, ","))

    -- Get current pets
    local petsToExport = PSM.state.stablePets

    -- Sort by slot if available
    local sortedPets = {}
    for _, pet in ipairs(petsToExport) do
        table.insert(sortedPets, pet)
    end
    table.sort(sortedPets, function(a, b)
        return (a.slotID or 999) < (b.slotID or 999)
    end)

    -- Data rows
    for _, pet in ipairs(sortedPets) do
        local specAbilities = ""
        local familyAbilities = ""
        local petAbilities = ""
        local otherAbilities = ""

        if pet.abilities and type(pet.abilities) == "table" then
            -- Check if we have grouped abilities
            if pet.abilities.spec or pet.abilities.family or pet.abilities.pet or pet.abilities.unknown then
                -- Grouped format
                if pet.abilities.spec then
                    specAbilities = table.concat(pet.abilities.spec, "; ")
                end
                if pet.abilities.family then
                    familyAbilities = table.concat(pet.abilities.family, "; ")
                end
                if pet.abilities.pet then
                    petAbilities = table.concat(pet.abilities.pet, "; ")
                end
                if pet.abilities.unknown then
                    otherAbilities = table.concat(pet.abilities.unknown, "; ")
                end
            else
                -- Put everything in "other"
                local abilityNames = {}
                for _, ability in ipairs(pet.abilities) do
                    local abilityName = type(ability) == "table" and ability.name or tostring(ability)
                    table.insert(abilityNames, abilityName)
                end
                otherAbilities = table.concat(abilityNames, "; ")
            end
        end

        local row = {
            self:EscapeCSVField(pet.slotID or ""),
            self:EscapeCSVField(pet.name or ""),
            self:EscapeCSVField(pet.displayID or ""),
            self:EscapeCSVField(pet.petNumber or ""),
            self:EscapeCSVField(pet.petLevel or ""),
            self:EscapeCSVField(pet.familyName or ""),
            self:EscapeCSVField(pet.specName or ""),
            self:EscapeCSVField(pet.specID or ""),
            self:EscapeCSVField(pet.isExotic and "Yes" or "No"),
            self:EscapeCSVField(pet.isActive and "Active" or "Stabled"),
            self:EscapeCSVField(specAbilities),
            self:EscapeCSVField(familyAbilities),
            self:EscapeCSVField(petAbilities),
            self:EscapeCSVField(otherAbilities)
        }
        table.insert(lines, table.concat(row, ","))
    end

    return table.concat(lines, "\n")
end

function PSM.Export:ShowExportDialog()
    -- Create or reuse export frame
    if PSM.state.exportFrame then
        PSM.state.exportFrame:Show()
        PSM.state.exportFrame:Raise()
        -- Regenerate CSV with current data
        local csvData = self:GenerateCSV()
        PSM.state.exportFrame.editBox:SetText(csvData)
        PSM.state.exportFrame.editBox:SetCursorPosition(0)

        -- Update pet count
        local lineCount = 0
        for _ in csvData:gmatch("[^\n]+") do
            lineCount = lineCount + 1
        end
        PSM.state.exportFrame.petCount:SetText(string.format("Exporting %d pets (%d total lines including header)", lineCount - 1, lineCount))
        return
    end

    local frame = CreateFrame("Frame", "PetStableExportFrame", UIParent, "BackdropTemplate")
    frame:SetSize(600, 500)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Background
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = {left=4, right=4, top=4, bottom=4}
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)

    -- Apply ElvUI skin to frame
    PSM.UI:ApplyElvUISkin(frame, "frame")

    -- Close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    PSM.UI:ApplyElvUISkin(closeButton, "closebutton")

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Export Pet Data (CSV)")
    title:SetTextColor(1, 0.82, 0)

    -- Instructions
    local instructions = frame:CreateFontString(nil, "OVERLAY")
    instructions:SetFont("Fonts\\FRIZQT__.TTF", 10)
    instructions:SetPoint("TOP", title, "BOTTOM", 0, -10)
    instructions:SetText("Copy the text below and paste it into a .csv file or spreadsheet")
    instructions:SetTextColor(0.8, 0.8, 0.8)

    -- ScrollFrame for CSV text
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -70)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 80)

    -- EditBox for CSV content
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(0)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(scrollFrame:GetWidth() - 20)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function()
        frame:Hide()
    end)

    scrollFrame:SetScrollChild(editBox)
    frame.editBox = editBox
    PSM.UI:ApplyElvUISkin(editBox, "editbox")

    -- Background for edit box
    local editBg = CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
    editBg:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -5, 5)
    editBg:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 5, -5)
    editBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left=4, right=4, top=4, bottom=4}
    })
    editBg:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    editBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    editBg:SetFrameLevel(scrollFrame:GetFrameLevel() - 1)

    -- Pet count info
    local petCount = frame:CreateFontString(nil, "OVERLAY")
    petCount:SetFont("Fonts\\FRIZQT__.TTF", 11)
    petCount:SetPoint("BOTTOM", 0, 50)
    petCount:SetTextColor(0.7, 0.9, 1)
    frame.petCount = petCount

    -- Select All button
    local selectAllBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selectAllBtn:SetSize(100, 25)
    selectAllBtn:SetPoint("BOTTOM", -55, 15)
    selectAllBtn:SetText("Select All")
    selectAllBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
    PSM.UI:ApplyElvUISkin(selectAllBtn, "button")

    -- Copy Instructions button
    local helpBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    helpBtn:SetSize(100, 25)
    helpBtn:SetPoint("BOTTOM", 55, 15)
    helpBtn:SetText("How to Copy")
    helpBtn:SetScript("OnClick", function()
        print("|cFFFFD700Pet Stable Management:|r To copy the CSV data:")
        print("|cFF00FF001.|r Click 'Select All' button")
        print("|cFF00FF002.|r Press Ctrl+C (Cmd+C on Mac) to copy")
        print("|cFF00FF003.|r Paste into Excel, Google Sheets, or a text editor")
        print("|cFF00FF004.|r Save as .csv file if needed")
    end)
    PSM.UI:ApplyElvUISkin(helpBtn, "button")

    -- Generate and display CSV
    local csvData = self:GenerateCSV()
    editBox:SetText(csvData)
    editBox:SetCursorPosition(0)

    -- Count lines (pets + header)
    local lineCount = 0
    for _ in csvData:gmatch("[^\n]+") do
        lineCount = lineCount + 1
    end
    petCount:SetText(string.format("Exporting %d pets (%d total lines including header)", lineCount - 1, lineCount))

    -- ESC key handling
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    frame:EnableKeyboard(true)

    -- Register for ESC key
    table.insert(UISpecialFrames, "PetStableExportFrame")

    PSM.state.exportFrame = frame
    frame:Show()
end
