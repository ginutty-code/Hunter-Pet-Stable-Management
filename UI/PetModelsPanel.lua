-- UI/PetModelsPanel.lua
-- Performance-optimized Pet Models Browser Panel

local addonName = "PetStableManagement"

_G.PSM = _G.PSM or {}
local PSM = _G.PSM

PSM.ModelsPanel = PSM.ModelsPanel or {}

-- Configuration
local MODELS_CONFIG = {
    PANEL_WIDTH = 1100,
    PANEL_HEIGHT = 775, 
    ROW_HEIGHT = 120,
    MODEL_SIZE = 100,
    PETS_PER_PAGE = 10, 
    PETS_PER_COLUMN = 5,
}

-- Build the models panel
function PSM.ModelsPanel:BuildPanel()
    if PSM.state.modelsPanel then return end

    local panel = CreateFrame("Frame", "PetStableManagementModelsPanel", UIParent)
    panel:SetSize(MODELS_CONFIG.PANEL_WIDTH, MODELS_CONFIG.PANEL_HEIGHT)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel(100)
    panel:SetToplevel(true)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Apply ElvUI skinning if available
    PSM.UI:ApplyElvUISkin(panel, "frame")

    -- Background and border
    panel.border = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.border:SetAllPoints()
    panel.border:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 30, edgeSize = 5,
        insets = {left=4, right=4, top=4, bottom=4}
    })
    panel.border:SetBackdropColor(0, 0, 0, 0.8)
    panel.border:SetFrameLevel(panel:GetFrameLevel() - 1)

    -- Close button
    panel.closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    panel.closeButton:SetPoint("TOPRIGHT", -5, -5)
    panel.closeButton:SetSize(20, 20)
    panel.closeButton:SetFrameLevel(panel:GetFrameLevel() + 10)
    panel.closeButton:SetScript("OnClick", function() panel:Hide() end)
    PSM.UI:ApplyElvUISkin(panel.closeButton, "closebutton")

    -- Title
    panel.title = panel:CreateFontString(nil, "OVERLAY")
    panel.title:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    panel.title:SetPoint("TOP", 0, -10)
    panel.title:SetText("Pet Model Browser")
    panel.title:SetTextColor(1, 0.82, 0)

    -- Favorites toggle
    panel.showFavorites = false
    panel.favoritesToggle = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    panel.favoritesToggle:SetPoint("TOPLEFT", 10, -60)
    panel.favoritesToggle:SetSize(20, 20)
    panel.favoritesToggle.text = panel.favoritesToggle:CreateFontString(nil, "OVERLAY")
    panel.favoritesToggle.text:SetFont("Fonts\\FRIZQT__.TTF", 10)
    panel.favoritesToggle.text:SetPoint("LEFT", panel.favoritesToggle, "RIGHT", 5, 0)
    panel.favoritesToggle.text:SetText("Show Only Favorites")
    panel.favoritesToggle:SetScript("OnClick", function(self)
        panel.showFavorites = self:GetChecked()
        PSM.ModelsPanel:LoadModelsForSelectedFamilies()
    end)
    PSM.UI:ApplyElvUISkin(panel.favoritesToggle, "checkbox")

    -- Search box
    panel.searchBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    panel.searchBox:SetSize(150, 22)
    panel.searchBox:SetPoint("TOP", 0, -35)
    panel.searchBox:SetAutoFocus(false)
    panel.searchBox:SetText("")
    PSM.UI:ApplyElvUISkin(panel.searchBox, "editbox")

    local debounceTimer = nil
    panel.searchBox:SetScript("OnTextChanged", function()
        -- Cancel existing timer
        if debounceTimer then
            debounceTimer:Cancel()
        end

        -- Create new debounced timer
        debounceTimer = PSM.C_Timer.NewTimer(0.3, function()
            PSM.ModelsPanel:LoadModelsForSelectedFamilies()
        end)
    end)

    -- Info text
    panel.infoText = panel:CreateFontString(nil, "OVERLAY")
    panel.infoText:SetFont("Fonts\\FRIZQT__.TTF", 10)
    panel.infoText:SetPoint("TOP", panel.searchBox, "BOTTOM", 0, -5)
    panel.infoText:SetText("Loading...")

    -- Family selection frame (always visible)
    panel.familyFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.familyFrame:SetPoint("TOPLEFT", 10, -85)
    panel.familyFrame:SetSize(150, MODELS_CONFIG.PANEL_HEIGHT - 85 - 50)
    panel.familyFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left=4, right=4, top=4, bottom=4}
    })
    panel.familyFrame:SetBackdropColor(0, 0, 0, 0.1)

    -- Select All/None buttons
    local selectAllBtn = CreateFrame("Button", nil, panel.familyFrame, "UIPanelButtonTemplate")
    selectAllBtn:SetPoint("TOPLEFT", 5, -5)
    selectAllBtn:SetSize(55, 20)
    selectAllBtn:SetText("All")
    selectAllBtn:SetScript("OnClick", function()
        panel.firstLoad = false -- Prevent auto-selection
        if PSM.PetModels and PSM.PetModels.GetAvailableFamilies then
            for _, familyName in ipairs(PSM.PetModels:GetAvailableFamilies()) do
                PSM.state.selectedModelsFamilies[familyName] = true
            end
        end
        PSM.ModelsPanel:PopulateFamilyCheckboxes()
        PSM.ModelsPanel:LoadModelsForSelectedFamilies()
    end)
    PSM.UI:ApplyElvUISkin(selectAllBtn, "button")

    local selectNoneBtn = CreateFrame("Button", nil, panel.familyFrame, "UIPanelButtonTemplate")
    selectNoneBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 5, 0)
    selectNoneBtn:SetSize(55, 20)
    selectNoneBtn:SetText("None")
    selectNoneBtn:SetScript("OnClick", function()
        panel.firstLoad = false -- Prevent auto-selection
        PSM.state.selectedModelsFamilies = {}
        PSM.ModelsPanel:PopulateFamilyCheckboxes()
        PSM.ModelsPanel:LoadModelsForSelectedFamilies()
    end)
    PSM.UI:ApplyElvUISkin(selectNoneBtn, "button")

    -- Scroll frame for family checkboxes
    local familyScrollFrame = CreateFrame("ScrollFrame", nil, panel.familyFrame, "UIPanelScrollFrameTemplate")
    familyScrollFrame:SetPoint("TOPLEFT", 5, -30)
    familyScrollFrame:SetPoint("BOTTOMRIGHT", -10, 5)

    local familyContent = CreateFrame("Frame", nil, familyScrollFrame)
    familyContent:SetSize(familyScrollFrame:GetWidth() - 10, 100)
    familyScrollFrame:SetScrollChild(familyContent)

    panel.familyScrollFrame = familyScrollFrame
    panel.familyContent = familyContent
    panel.familyCheckboxes = {}
    panel.firstLoad = true

    -- Create 2-column layout for pets
    local petsFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    petsFrame:SetPoint("TOPLEFT", panel.familyFrame, "TOPRIGHT", 10, 0)
    petsFrame:SetPoint("BOTTOMRIGHT", -10, 50) -- Leave space for navigation buttons
    petsFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left=4, right=4, top=4, bottom=4}
    })
    petsFrame:SetBackdropColor(0, 0, 0, 0.3)

    -- Add mouse wheel navigation
    petsFrame:EnableMouseWheel(true)
    petsFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxPages = math.ceil(#panel.allModels / MODELS_CONFIG.PETS_PER_PAGE)
        if delta < 0 then
            -- Scroll down = Next page
            if panel.currentPage < maxPages then
                panel.currentPage = panel.currentPage + 1
                PSM.ModelsPanel:UpdateVisibleRows()
            end
        else
            -- Scroll up = Previous page
            if panel.currentPage > 1 then
                panel.currentPage = panel.currentPage - 1
                PSM.ModelsPanel:UpdateVisibleRows()
            end
        end
    end)

    panel.petsFrame = petsFrame
    panel.modelRows = {}
    panel.currentPage = 1
    panel.allModels = {}

    -- Create 2 columns of pet slots (5 per column = 10 total) - fit available space
    local columnWidth = (petsFrame:GetWidth() - 30) / 2 
    for col = 1, 2 do
        for row = 1, MODELS_CONFIG.PETS_PER_COLUMN do
            local index = (col - 1) * MODELS_CONFIG.PETS_PER_COLUMN + row
            local petRow = self:CreateModelRow(petsFrame)
            petRow:SetPoint("TOPLEFT", 10 + (col - 1) * (columnWidth + 10), -(row - 1) * MODELS_CONFIG.ROW_HEIGHT - 10)
            petRow:SetWidth(columnWidth)
            panel.modelRows[index] = petRow
        end
    end

    -- Navigation buttons
    local prevButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    prevButton:SetPoint("BOTTOMLEFT", panel.petsFrame, "BOTTOMLEFT", 0, -35)
    prevButton:SetSize(80, 25)
    prevButton:SetText("Previous")
    prevButton:SetScript("OnClick", function()
        if panel.currentPage > 1 then
            panel.currentPage = panel.currentPage - 1
            self:UpdateVisibleRows()
        end
    end)
    PSM.UI:ApplyElvUISkin(prevButton, "button")

    local pageText = panel:CreateFontString(nil, "OVERLAY")
    pageText:SetFont("Fonts\\FRIZQT__.TTF", 12)
    pageText:SetPoint("BOTTOM", panel.petsFrame, "BOTTOM", 0, -25)
    pageText:SetText("Page 1 of 1")

    local nextButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    nextButton:SetPoint("BOTTOMRIGHT", panel.petsFrame, "BOTTOMRIGHT", 0, -35)
    nextButton:SetSize(80, 25)
    nextButton:SetText("Next")
    nextButton:SetScript("OnClick", function()
        local maxPages = math.ceil(#panel.allModels / MODELS_CONFIG.PETS_PER_PAGE)
        if panel.currentPage < maxPages then
            panel.currentPage = panel.currentPage + 1
            self:UpdateVisibleRows()
        end
    end)
    PSM.UI:ApplyElvUISkin(nextButton, "button")

    panel.prevButton = prevButton
    panel.nextButton = nextButton
    panel.pageText = pageText

    -- Initialize state
    PSM.state.modelsPanel = panel
    PSM.state.selectedModelsFamilies = PSM.state.selectedModelsFamilies or {}
    PSM.state.favoriteModels = PSM.state.favoriteModels or {}

    -- Load initial data after a short delay to ensure data is loaded
    PSM.C_Timer.After(0.1, function()
        self:LoadModelsForSelectedFamilies()
    end)

    -- Register for ESC
    table.insert(UISpecialFrames, "PetStableManagementModelsPanel")

    -- Add reload on show
    panel:SetScript("OnShow", function(self)
        PSM.C_Timer.After(0.01, function()
            PSM.ModelsPanel:LoadModelsForSelectedFamilies()
        end)
    end)

    -- Add cleanup on hide
    panel:SetScript("OnHide", function(self)
        -- Aggressive memory cleanup when hiding
        PSM._modelsRenderCache = nil
        PSM._modelsDebounceTimer = nil

        -- Clear PetModels cache to free memory
        PSM.PetModels:ClearCache()

        -- Clear all panel data
        panel.allModels = nil
        panel.currentPage = 1

        -- Clear and hide all UI elements
        for i = 1, MODELS_CONFIG.PETS_PER_PAGE do
            local row = panel.modelRows[i]
            if row then
                row:Hide()
                -- Clear text elements
                if row.npcText then
                    row.npcText:SetText("")
                    row.npcText:Hide()
                end
                if row.npcTexts then
                    for _, text in ipairs(row.npcTexts) do
                        text:SetText("")
                        text:Hide()
                    end
                end
                -- Clear other elements
                if row.nameText then
                    row.nameText:SetText("")
                end
                if row.infoText then
                    row.infoText:SetText("")
                end
                if row.model then
                    row.model:SetDisplayInfo(0)  
                    row.model:Hide()
                    row.model.isRotating = false
                    if PSM.RotationFrame and PSM.RotationFrame.activeModels then
                        PSM.RotationFrame.activeModels[row.model] = nil
                    end
                end
                if row.favoriteButton then
                    row.favoriteButton:Hide()
                end
            end
        end

        -- Force garbage collection
        collectgarbage("collect")
    end)

    panel:Hide()
end

-- Create a model row
function PSM.ModelsPanel:CreateModelRow(parent)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(400, MODELS_CONFIG.ROW_HEIGHT)
    row:SetHeight(MODELS_CONFIG.ROW_HEIGHT) 
    -- Background
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)

    -- Separator line at the bottom
    row.separator = row:CreateTexture(nil, "BORDER")
    row.separator:SetHeight(1)
    row.separator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.separator:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.separator:SetColorTexture(0.3, 0.3, 0.3, 0.5)

    -- Model display
    row.model = CreateFrame("PlayerModel", nil, row)
    row.model:SetSize(MODELS_CONFIG.MODEL_SIZE, MODELS_CONFIG.MODEL_SIZE)
    row.model:SetPoint("LEFT", 20, 0) 
    row.model:SetRotation(math.pi * 2)
    row.model:SetPortraitZoom(0.25)
    row.model.rotation = math.pi * 2
    row.model.zoom = 0.25
    row.model.isRotating = false

    -- Reset button
    row.modelReset = CreateFrame("Button", nil, row)
    row.modelReset:SetSize(16, 16)
    row.modelReset:SetPoint("TOPRIGHT", row.model, "TOPRIGHT", -2, -2)
    row.modelReset:SetFrameLevel(row.model:GetFrameLevel() + 2)
    row.modelReset:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
    row.modelReset:SetHighlightTexture("Interface\\Buttons\\UI-RefreshButton")
    row.modelReset:SetAlpha(0.7)
    row.modelReset:Hide()

    row.modelReset:SetScript("OnClick", function()
        row.model.rotation = math.pi * 2
        row.model.zoom = 0.25
        row.model:SetRotation(row.model.rotation)
        row.model:SetPortraitZoom(row.model.zoom)
        row.model.isRotating = false
        if PSM.RotationFrame and PSM.RotationFrame.activeModels then
            PSM.RotationFrame.activeModels[row.model] = nil
        end
    end)

    row.modelReset:SetScript("OnEnter", function(self)
        self:SetAlpha(1.0)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Reset View")
        GameTooltip:Show()
    end)

    row.modelReset:SetScript("OnLeave", function(self)
        self:SetAlpha(0.7)
        GameTooltip:Hide()
    end)

    -- Mouse interaction
    row.model:EnableMouse(true)
    row.model:EnableMouseWheel(true)

    row.model:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.isRotating = true
            self.lastX = GetCursorPosition()
            if PSM.RotationFrame and PSM.RotationFrame.activeModels then
                PSM.RotationFrame.activeModels[self] = true
            end
        end
    end)

    row.model:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.isRotating = false
            if PSM.RotationFrame and PSM.RotationFrame.activeModels then
                PSM.RotationFrame.activeModels[self] = nil
            end
        end
    end)

    row.model:SetScript("OnMouseWheel", function(self, delta)
        self.zoom = math.max(0.1, math.min(1.0, self.zoom + delta * 0.05))
        self:SetPortraitZoom(self.zoom)
    end)

    row.model:SetScript("OnEnter", function()
        row.modelReset:Show()
        GameTooltip:SetOwner(row.model, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click and drag to rotate\nScroll to zoom")
        GameTooltip:Show()
    end)

    row.model:SetScript("OnLeave", function()
        if not row.modelReset:IsMouseOver() then
            row.modelReset:Hide()
        end
        GameTooltip:Hide()
    end)

    -- Name text
    row.nameText = row:CreateFontString(nil, "OVERLAY")
    row.nameText:SetFont("Fonts\\FRIZQT__.TTF", 10)
    row.nameText:SetPoint("LEFT", row.model, "RIGHT", 10, 0)
    row.nameText:SetJustifyH("LEFT")

    -- Info text
    row.infoText = row:CreateFontString(nil, "OVERLAY")
    row.infoText:SetFont("Fonts\\FRIZQT__.TTF", 8)
    row.infoText:SetPoint("LEFT", row.nameText, "RIGHT", 10, 0)
    row.infoText:SetJustifyH("LEFT")
    row.infoText:SetTextColor(0.7, 0.7, 0.7)

    -- NPC texts (up to 4)
    row.npcTexts = {}
    for i = 1, 4 do
        local npcText = row:CreateFontString(nil, "OVERLAY")
        npcText:SetFont("Fonts\\FRIZQT__.TTF", 9)
        npcText:SetTextColor(0.8, 0.8, 0.8)
        npcText:SetJustifyH("LEFT")
        npcText:SetPoint("LEFT", row.model, "RIGHT", 15, 10 - i * 12)
        npcText:Hide()
        table.insert(row.npcTexts, npcText)
    end

    -- Favorite button
    row.favoriteButton = CreateFrame("Button", nil, row)
    row.favoriteButton:SetSize(16, 16)
    row.favoriteButton:SetPoint("TOPLEFT", row.model, "TOPLEFT", 0, -2)
    row.favoriteButton:SetFrameLevel(row.model:GetFrameLevel() + 2)
    row.favoriteButton:SetNormalTexture("Interface\\Common\\ReputationStar")
    row.favoriteButton:GetNormalTexture():SetTexCoord(0, 0.5, 0, 0.5)
    row.favoriteButton:SetHighlightTexture("Interface\\Common\\ReputationStar")
    row.favoriteButton:GetHighlightTexture():SetTexCoord(0, 0.5, 0, 0.5)

    row.favoriteButton:SetScript("OnClick", function()
        if row.displayId then
            local wasFavorited = PSM.state.favoriteModels[row.displayId]
            PSM.state.favoriteModels[row.displayId] = not wasFavorited

            -- Update button appearance
            if PSM.state.favoriteModels[row.displayId] then
                row.favoriteButton:GetNormalTexture():SetTexCoord(0, 0.5, 0, 0.5)
                row.favoriteButton:GetHighlightTexture():SetTexCoord(0, 0.5, 0, 0.5)
            else
                row.favoriteButton:GetNormalTexture():SetTexCoord(0.5, 1, 0, 0.5)
                row.favoriteButton:GetHighlightTexture():SetTexCoord(0.5, 1, 0, 0.5)
            end

            -- Refresh models panel if showing favorites
            local panel = PSM.state.modelsPanel
            if panel and panel.showFavorites then
                PSM.ModelsPanel:LoadModelsForSelectedFamilies()
            end
        end
    end)

    row:SetScript("OnEnter", function(self)
        if row.displayId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Display ID: " .. row.displayId)
            if row.familyName then
                GameTooltip:AddLine("Family: " .. row.familyName)
            end
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    return row
end

-- Populate family checkboxes
function PSM.ModelsPanel:PopulateFamilyCheckboxes()
    local panel = PSM.state.modelsPanel
    if not panel or not PSM.PetModels then
        return
    end

    local families = PSM.PetModels:GetAvailableFamilies()
    
    if #families == 0 then 
        panel.infoText:SetText("No pet families found in data")
        return 
    end

    -- If first load and no families selected, select all by default
    if panel.firstLoad and not next(PSM.state.selectedModelsFamilies) then
        panel.firstLoad = false
        for _, familyName in ipairs(families) do
            PSM.state.selectedModelsFamilies[familyName] = true
        end
    end

    -- Clear existing checkboxes
    for _, cb in ipairs(panel.familyCheckboxes) do
        cb:Hide()
    end
    panel.familyCheckboxes = {}

    local yOffset = 0
    for _, familyName in ipairs(families) do
        local checkbox = CreateFrame("CheckButton", nil, panel.familyContent, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", 0, -yOffset)
        checkbox:SetSize(20, 20)
        checkbox.text = checkbox:CreateFontString(nil, "OVERLAY")
        checkbox.text:SetFont("Fonts\\FRIZQT__.TTF", 10)
        checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
        checkbox.text:SetText(familyName)
        checkbox:SetChecked(PSM.state.selectedModelsFamilies[familyName] or false)
        checkbox:SetScript("OnClick", function(self)
            PSM.state.selectedModelsFamilies[familyName] = self:GetChecked()
            PSM.ModelsPanel:LoadModelsForSelectedFamilies()
        end)
        PSM.UI:ApplyElvUISkin(checkbox, "checkbox")
        table.insert(panel.familyCheckboxes, checkbox)
        yOffset = yOffset + 25
    end

    panel.familyContent:SetHeight(yOffset)
end

-- Update a model/NPC row with data
function PSM.ModelsPanel:UpdateItemRow(row, item, index)
    if not item then
        row:Hide()
        return
    end

    local panel = PSM.state.modelsPanel
    local displayId = nil
    local name = "Unknown"
    local info = ""

    if item.itemType == "display_with_npcs" then
        -- Display ID with embedded NPCs
        displayId = item.displayId

        if displayId then
            row.model:SetDisplayInfo(displayId)
            row.model:SetCamDistanceScale(1.2)
            row.model:Show()
            row.modelReset:Hide()
        else
            row.model:SetDisplayInfo(0)
            row.model:Show()
            row.modelReset:Hide()
        end

        -- Count owned instances of this display ID
        local stablePetDisplayIds = {}
        for _, pet in ipairs(PSM.state.stablePets) do
            if pet.displayID then
                stablePetDisplayIds[tonumber(pet.displayID)] = (stablePetDisplayIds[tonumber(pet.displayID)] or 0) + 1
            end
        end

        local ownedCount = stablePetDisplayIds[displayId] or 0
        local totalNpcs = #item.npcs

        name = string.format("Display ID: %d", displayId)
        if ownedCount > 0 then
            name = name .. string.format(" (%d owned)", ownedCount)
        end

        if ownedCount > 0 then
            row.bg:SetColorTexture(0, 0.2, 0, 0.5)
            row.nameText:SetTextColor(0, 1, 0)
        else
            row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5) 
            row.nameText:SetTextColor(1, 1, 1)
        end

        -- Update favorite button
        row.favoriteButton:Show()
        if PSM.state.favoriteModels[displayId] then
            row.favoriteButton:GetNormalTexture():SetTexCoord(0, 0.5, 0, 0.5)
            row.favoriteButton:GetHighlightTexture():SetTexCoord(0, 0.5, 0, 0.5)
        else
            row.favoriteButton:GetNormalTexture():SetTexCoord(0.5, 1, 0, 0.5)
            row.favoriteButton:GetHighlightTexture():SetTexCoord(0.5, 1, 0, 0.5)
        end

        -- Position main text at the top of the row
        row.nameText:ClearAllPoints()
        row.nameText:SetPoint("LEFT", row.model, "RIGHT", 15, 15) 

        -- Show NPCs: all if 4 or fewer, first 3 + "and x more" if more than 4
        local showAll = totalNpcs <= 4
        for i = 1, 4 do
            local npcText = row.npcTexts[i]
            if showAll and i <= totalNpcs then
                local npc = item.npcs[i]
                local npcId = npc.npcId or "?"
                npcText:SetText(string.format("%s (ID: %s)", npc.name, npcId))
                npcText:Show()
            elseif not showAll and i <= 3 then
                local npc = item.npcs[i]
                local npcId = npc.npcId or "?"
                npcText:SetText(string.format("%s (ID: %s)", npc.name, npcId))
                npcText:Show()
            elseif not showAll and i == 4 then
                npcText:SetText(string.format("and %d more...", totalNpcs - 3))
                npcText:Show()
            else
                npcText:Hide()
            end
        end

        -- Hide old single NPC text if it exists
        if row.npcText then
            row.npcText:Hide()
        end

        -- Clear info text
        row.infoText:SetText("")
    end

    row.displayId = displayId
    row.nameText:SetText(name)
    row.infoText:SetText(info)

    -- Update tooltip
    row:SetScript("OnEnter", function(self)
        if displayId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(name)
            GameTooltip:AddLine("Family: " .. (item.familyName or "Unknown"))
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("NPCs:")
            for _, npc in ipairs(item.npcs) do
                local npcId = npc.npcId or "?"
                GameTooltip:AddLine(string.format("  %s (ID: %s)", npc.name, npcId), 0.8, 0.8, 0.8)
            end
            GameTooltip:Show()
        end
    end)

    row:Show()
end

-- Performance optimization: Create render cache for models panel
function PSM.ModelsPanel:CreateRenderCache()
    PSM._modelsRenderCache = nil
    PSM._modelsDebounceTimer = nil
    PSM._lastModelsLayoutWidth = nil
    PSM._lastModelsLayoutHeight = nil
end

-- Generate cache key for models panel
function PSM.ModelsPanel:GenerateCacheKey()
    local panel = PSM.state.modelsPanel
    if not panel then return "" end

    local searchText = panel.searchBox:GetText() or ""
    local searchLower = searchText ~= "" and searchText:lower() or ""

    local selectionKey = ""
    for familyName, selected in pairs(PSM.state.selectedModelsFamilies) do
        if selected then
            selectionKey = selectionKey .. familyName .. ","
        end
    end

    local favoritesKey = ""
    for displayId in pairs(PSM.state.favoriteModels) do
        favoritesKey = favoritesKey .. tostring(displayId) .. ","
    end

    return string.format("%s_%s_%s_%s_%s",
        panel.showFavorites and "favorites" or "browse",
        searchLower,
        selectionKey,
        favoritesKey,
        #PSM.state.stablePets
    )
end

-- Optimized LoadModelsForSelectedFamilies with debouncing
function PSM.ModelsPanel:LoadModelsForSelectedFamilies()
    local panel = PSM.state.modelsPanel
    if not panel or not PSM.PetModels then return end

    -- Cancel existing debounce timer
    if PSM._modelsDebounceTimer then
        PSM._modelsDebounceTimer:Cancel()
    end

    -- Clear cache to prevent memory accumulation
    PSM._modelsRenderCache = nil

    -- Debounce to avoid excessive calls during rapid changes
    PSM._modelsDebounceTimer = PSM.C_Timer.NewTimer(0.05, function()
        self:_LoadModelsImmediate()
    end)
end

-- Immediate models loading with caching
function PSM.ModelsPanel:_LoadModelsImmediate()
    local panel = PSM.state.modelsPanel
    if not panel then
        return
    end

    -- Populate family checkboxes first to ensure selection is set
    self:PopulateFamilyCheckboxes()

    local cacheKey = self:GenerateCacheKey()

    -- Check cache validity
    if PSM._modelsRenderCache and PSM._modelsRenderCache.key == cacheKey then
        local age = GetTime() - PSM._modelsRenderCache.timestamp
        if age < 0.2 then -- Cache for 200ms
            self:_ApplyCachedModelsData(PSM._modelsRenderCache.data)
            return
        end
    end

    -- Expensive calculation
    local modelsData = self:_CalculateModelsData()

    -- Store in cache
    self:_ApplyCachedModelsData(modelsData)
end

-- Calculate all models data in hierarchical manner
function PSM.ModelsPanel:_CalculateModelsData()
    local panel = PSM.state.modelsPanel
    local allItems = {}

    -- Ensure stable pets data is loaded (for ownership checking)
    if PSM.state.isStableOpen then
        if #PSM.state.stablePets == 0 then
            PSM.Data:CollectStablePets()
        end
    else
        if #PSM.state.stablePets == 0 then
            PSM.Data:LoadPersistentDataForDisplay()
        end
    end

    -- Load selected families
    local selectedFamilies = {}
    for familyName, selected in pairs(PSM.state.selectedModelsFamilies) do
        if selected then
            table.insert(selectedFamilies, familyName)
        end
    end

    if #selectedFamilies == 0 then
        return {
            allItems = {},
            ownedCount = 0,
            totalCount = 0
        }
    end

    -- Load data for selected families
    for _, familyName in ipairs(selectedFamilies) do
        local familyData = PSM.PetModels:GetFamilyModels(familyName)
    end

    -- Build flat structure: Family > Display IDs > NPCs 
    for _, familyName in ipairs(selectedFamilies) do
        local familyData = PSM.PetModels[familyName]
        if familyData and familyData.displayIds then
            for _, displayData in ipairs(familyData.displayIds) do
                -- Skip excluded display IDs
                if not PSM.Config.EXCLUDED_DISPLAY_IDS[displayData.displayId] then
                    -- Filter by favorites for display items
                    local shouldIncludeDisplay = not panel.showFavorites or PSM.state.favoriteModels[displayData.displayId]

                    if shouldIncludeDisplay then
                        -- Create display ID entry with embedded NPCs
                        local displayEntry = {
                            displayId = displayData.displayId,
                            npcs = displayData.npcs,
                            familyName = familyName,
                            itemType = "display_with_npcs"
                        }
                        table.insert(allItems, displayEntry)
                    end
                end
            end
        end
    end

    if #allItems == 0 then
        return {
            allItems = {},
            ownedCount = 0,
            totalCount = 0
        }
    end

    -- Optimized search filtering
    local searchText = panel.searchBox:GetText() or ""
    local searchLower = searchText ~= "" and searchText:lower() or ""

    if searchLower ~= "" then
        local filteredItems = {}
        for _, item in ipairs(allItems) do
            local include = false

            if item.itemType == "display_with_npcs" then
                -- Check display ID
                if tostring(item.displayId):lower():find(searchLower, 1, true) then
                    include = true
                end

                -- Check family name
                if not include and item.familyName and item.familyName:lower():find(searchLower, 1, true) then
                    include = true
                end

                -- Check NPCs under this display ID
                if not include and item.npcs then
                    for _, npc in ipairs(item.npcs) do
                        if npc.name and npc.name:lower():find(searchLower, 1, true) then
                            include = true
                            break
                        end
                        if tostring(npc.npcId):lower():find(searchLower, 1, true) then
                            include = true
                            break
                        end
                        if npc.zones then
                            if type(npc.zones) == "table" then
                                for _, zone in ipairs(npc.zones) do
                                    if zone:lower():find(searchLower, 1, true) then
                                        include = true
                                        break
                                    end
                                end
                            else
                                -- npc.zones is a string
                                if npc.zones:lower():find(searchLower, 1, true) then
                                    include = true
                                end
                            end
                            if include then break end
                        end
                    end
                end
            end

            if include then
                table.insert(filteredItems, item)
            end
        end
        allItems = filteredItems
    end

    -- Count owned unique display IDs among shown items
    local ownedCount = 0
    local stablePetDisplayIds = {}

    -- Build lookup of owned display IDs with counts
    for _, pet in ipairs(PSM.state.stablePets) do
        if pet.displayID then
            stablePetDisplayIds[tonumber(pet.displayID)] = (stablePetDisplayIds[tonumber(pet.displayID)] or 0) + 1
        end
    end

    -- Count unique owned display IDs from the items that will be shown
    local shownDisplayIds = {}
    for _, item in ipairs(allItems) do
        shownDisplayIds[item.displayId] = true
    end

    for displayId in pairs(shownDisplayIds) do
        if (stablePetDisplayIds[displayId] or 0) > 0 then
            ownedCount = ownedCount + 1
        end
    end

    -- Calculate layout for pagination (no scrolling needed)
    local petsFrameWidth = panel.petsFrame:GetWidth()
    if not petsFrameWidth or petsFrameWidth <= 0 then petsFrameWidth = 400 end
    -- For pagination, we don't need complex layout calculations

    -- Calculate actual total height (all items are display_with_npcs now)
    local totalHeight = #allItems * MODELS_CONFIG.ROW_HEIGHT

    return {
        allItems = allItems,
        ownedCount = ownedCount,
        totalCount = #allItems 
    }
end

-- Apply cached models data to UI
function PSM.ModelsPanel:_ApplyCachedModelsData(modelsData)
    local panel = PSM.state.modelsPanel
    if not panel then return end

    -- Update info
    if modelsData.totalCount == 0 then
        panel.infoText:SetText("No matching display IDs | 0 pages")
        -- Clear all rows
        for i = 1, MODELS_CONFIG.PETS_PER_PAGE do
            if panel.modelRows[i] then
                panel.modelRows[i]:Hide()
            end
        end
        panel.pageText:SetText("Page 0 of 0")
        return
    end

    -- Extract only display items for pagination
    panel.allModels = {}
    for _, item in ipairs(modelsData.allItems) do
        if item.itemType == "display_with_npcs" then
            table.insert(panel.allModels, item)
        end
    end

    -- Preserve current page if it's still valid, otherwise reset to first page
    local totalPages = math.ceil(#panel.allModels / MODELS_CONFIG.PETS_PER_PAGE)
    if panel.currentPage > totalPages then
        panel.currentPage = 1
    end

    -- Update info text with pages info
    local totalPages = math.ceil(#panel.allModels / MODELS_CONFIG.PETS_PER_PAGE)
    panel.infoText:SetText(string.format("%d display IDs | %d owned", #panel.allModels, modelsData.ownedCount))

    -- Render current page
    self:UpdateVisibleRows()
end

-- Update visible pets for current page (2 columns, 5 per column)
function PSM.ModelsPanel:UpdateVisibleRows()
    local panel = PSM.state.modelsPanel
    if not panel or not panel.allModels then return end

    local totalPets = #panel.allModels
    if totalPets == 0 then
        -- Hide all rows
        for i = 1, MODELS_CONFIG.PETS_PER_PAGE do
            if panel.modelRows[i] then
                panel.modelRows[i]:Hide()
            end
        end
        panel.pageText:SetText("Page 0 of 0")
        return
    end

    -- Calculate pagination
    local maxPages = math.ceil(totalPets / MODELS_CONFIG.PETS_PER_PAGE)
    panel.currentPage = math.min(panel.currentPage, maxPages)
    panel.currentPage = math.max(panel.currentPage, 1)

    local startIndex = (panel.currentPage - 1) * MODELS_CONFIG.PETS_PER_PAGE + 1
    local endIndex = math.min(startIndex + MODELS_CONFIG.PETS_PER_PAGE - 1, totalPets)

    -- Update page text
    panel.pageText:SetText(string.format("Page %d of %d", panel.currentPage, maxPages))

    -- Update navigation buttons
    panel.prevButton:SetEnabled(panel.currentPage > 1)
    panel.nextButton:SetEnabled(panel.currentPage < maxPages)

    -- Hide all rows first
    for i = 1, MODELS_CONFIG.PETS_PER_PAGE do
        if panel.modelRows[i] then
            panel.modelRows[i]:Hide()
            -- Clear 3D model to free memory
            if panel.modelRows[i].model then
                panel.modelRows[i].model:SetDisplayInfo(0)
                panel.modelRows[i].model:Hide()
                if PSM.RotationFrame and PSM.RotationFrame.activeModels then
                    PSM.RotationFrame.activeModels[panel.modelRows[i].model] = nil
                end
            end
        end
    end

    -- Show pets for current page
    local petIndex = 1
    for i = startIndex, endIndex do
        local pet = panel.allModels[i]
        local row = panel.modelRows[petIndex]

        if pet and row then
            self:UpdateItemRow(row, pet, i)
            row:Show()
            petIndex = petIndex + 1
        end
    end
end

-- Initialize basic functionality
function PSM.ModelsPanel:InitializePerformanceOptimizations()
    self:CreateRenderCache()
end

-- Toggle the models panel visibility
function PSM.ModelsPanel:Toggle()
    if not PSM.state.modelsPanel then
        if self.BuildPanel then
            self:BuildPanel()
        else
            print("|cFFFF0000Pet Stable Management: Models panel BuildPanel method not found.|r")
            return
        end
    end

    if PSM.state.modelsPanel:IsVisible() then
        PSM.state.modelsPanel:Hide()
    else
        PSM.state.modelsPanel:Show()
        PSM.state.modelsPanel:Raise()
    end
end

-- Call initialization when panel is built
local originalBuildPanel = PSM.ModelsPanel.BuildPanel
function PSM.ModelsPanel.BuildPanel(...)
    originalBuildPanel(...)
    PSM.ModelsPanel:InitializePerformanceOptimizations()
end