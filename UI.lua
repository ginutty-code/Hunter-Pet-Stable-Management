-- UI.lua
-- Optimized UI components for PetStableManagement with performance improvements

local addonName = "PetStableManagement"

-- Initialize global namespace
_G.PSM = _G.PSM or {}
local PSM = _G.PSM

-- Load UI sub-modules
PSM.UI = PSM.UI or {}

-- Performance optimization: Add utility functions
function PSM.UI:CreatePerformanceOptimizations()
    -- Add table hash function for cache keys
    if not PSM.Utils.GetTableHash then
        function PSM.Utils:GetTableHash(tbl)
            if not tbl or not next(tbl) then return "empty" end
            local hash = ""
            for k, v in pairs(tbl) do
                hash = hash .. tostring(k) .. ":" .. tostring(v) .. ","
            end
            return hash
        end
    end
end

-- ElvUI compatibility function
function PSM.UI:ApplyElvUISkin(frame, skinType)
    if not ElvUI or not ElvUI[1] or not ElvUI[1]:GetModule("Skins") then return end
    local S = ElvUI[1]:GetModule("Skins")
    if skinType == "frame" then
        S:HandleFrame(frame, true)
    elseif skinType == "button" then
        S:HandleButton(frame)
    elseif skinType == "editbox" then
        S:HandleEditBox(frame)
    elseif skinType == "closebutton" then
        S:HandleCloseButton(frame)
    elseif skinType == "dropdown" then
        S:HandleDropDownBox(frame)
    elseif skinType == "checkbox" then
        S:HandleCheckBox(frame)
    elseif skinType == "scrollbar" then
        S:HandleScrollBar(frame)
    end
end

-- Initialize UI state
PSM.UI.state = PSM.UI.state or {
    panel = nil,
    scrollFrame = nil,
    content = nil,
    rows = {},
    stablePets = {},
    stablePetsSnapshot = {},
    sortByDisplayID = false,
    sortBySlot = false,
    exoticFilter = false,
    duplicatesOnlyFilter = false,
    selectedSpecs = {},
    selectedFamilies = {},
    selectedModelsFamilies = {},
    favoriteModels = {},
    specList = {},
    familyList = {},
    isStableOpen = false,
    minimapButton = nil,
    exportFrame = nil,
}

-- Alias for backward compatibility
PSM.state = PSM.UI.state

function PSM.UI:SetupRowButtons(row, pet)
    if not row or not pet or not pet.slotID or pet.slotID <= 0 then
        if row then
            row.makeActive:Hide()
            row.companion:Hide()
            row.stable:Hide()
            row.release:Hide()
        end
        return
    end

    -- Make Active button
    row.makeActive:SetScript("OnClick", function()
        if not PSM.state.isStableOpen then
            print(string.format(PSM.Config.MESSAGES.STABLE_MUST_BE_OPEN, "make a pet active"))
            return
        end

        if not C_StableInfo or not C_StableInfo.SetPetSlot then
            print("|cFFFF0000C_StableInfo.SetPetSlot not available.|r")
            return
        end

        PSM.Utils.SafeCall(function()
            local slot1Pet = nil
            for _, p in ipairs(PSM.state.stablePets) do
                if p.slotID == 1 then
                    slot1Pet = p
                    break
                end
            end

            if slot1Pet then
                local displacementSlot = PSM.UI:FindDisplacementSlot()
                if displacementSlot then
                    C_StableInfo.SetPetSlot(1, displacementSlot)
                    PSM.C_Timer.After(0.1, function()
                        C_StableInfo.SetPetSlot(pet.slotID, 1)
                        PSM.C_Timer.After(0.2, function() PSM.UI:UpdatePanel() end)
                    end)
                else
                    print(PSM.Config.MESSAGES.NO_AVAILABLE_SLOTS)
                end
            else
                C_StableInfo.SetPetSlot(pet.slotID, 1)
                PSM.C_Timer.After(0.2, function() PSM.UI:UpdatePanel() end)
            end
        end)
    end)

    if not PSM.state.isStableOpen or (pet.slotID >= 1 and pet.slotID <= 5) then
        row.makeActive:Hide()
    else
        row.makeActive:Show()
    end

    -- Companion button
    row.companion:SetScript("OnClick", function()
        if not PSM.state.isStableOpen then
            print(string.format(PSM.Config.MESSAGES.STABLE_MUST_BE_OPEN, "set a pet as companion"))
            return
        end

        if C_StableInfo and C_StableInfo.SetPetSlot then
            C_StableInfo.SetPetSlot(pet.slotID, 6)
            PSM.C_Timer.After(0.2, function() PSM.UI:UpdatePanel() end)
        end
    end)

    if not PSM.state.isStableOpen or pet.slotID == 6 then
        row.companion:Hide()
    else
        row.companion:Show()
    end

    -- Stable button
    row.stable:SetScript("OnClick", function()
        if not PSM.state.isStableOpen then
            print(string.format(PSM.Config.MESSAGES.STABLE_MUST_BE_OPEN, "stable a pet"))
            return
        end

        if C_StableInfo and C_StableInfo.SetPetSlot then
            local targetSlot = PSM.UI:FindAvailableStableSlot()
            if targetSlot then
                C_StableInfo.SetPetSlot(pet.slotID, targetSlot)
                PSM.C_Timer.After(0.2, function() PSM.UI:UpdatePanel() end)
            else
                print(PSM.Config.MESSAGES.NO_STABLE_SLOTS)
            end
        end
    end)

    if PSM.state.isStableOpen and (pet.slotID >= 1 and pet.slotID <= 5) then
        row.stable:Show()
    else
        row.stable:Hide()
    end

    -- Release button
    row.release:SetScript("OnClick", function()
        if StableFrame and StableFrame.OnPetSelected and StableFrame.ReleasePetButton then
            if pet.slotID >= 1 and pet.slotID <= 5 then
                -- Active pet
                if C_StableInfo and C_StableInfo.GetStablePetInfo then
                    local activePetInfo = C_StableInfo.GetStablePetInfo(pet.slotID)
                    if activePetInfo then
                        StableFrame:OnPetSelected(activePetInfo)
                        PSM.C_Timer.After(0.05, function()
                            local onClick = StableFrame.ReleasePetButton:GetScript("OnClick")
                            if onClick then
                                PSM.Utils.SafeCall(onClick, StableFrame.ReleasePetButton)
                                -- Remove from in-memory data and update saved data
                                for i = #PSM.state.stablePets, 1, -1 do
                                    if PSM.state.stablePets[i].slotID == pet.slotID then
                                        table.remove(PSM.state.stablePets, i)
                                        break
                                    end
                                end
                                -- Update saved data
                                PSM.state.stablePetsSnapshot = {}
                                for _, p in ipairs(PSM.state.stablePets) do
                                    table.insert(PSM.state.stablePetsSnapshot, PSM.Data.DeepCopyPet(p))
                                end
                                PSM.Data:SavePersistentData()
                                PSM.UI:UpdatePanel()
                            end
                        end)
                    end
                end
            else
                -- Stabled pet
                local stabledPetList = StableFrame.StabledPetList
                if stabledPetList and stabledPetList.ScrollBox then
                    local dataProvider = stabledPetList.ScrollBox:GetDataProvider()
                    if dataProvider then
                        local foundPet = nil
                        dataProvider:ForEach(function(node)
                            if not foundPet then
                                local blizzardPet = node:GetData()
                                if blizzardPet and (
                                    (blizzardPet.petNumber and blizzardPet.petNumber == pet.petNumber) or
                                    (blizzardPet.name == pet.name and blizzardPet.icon == pet.icon and blizzardPet.displayID == pet.displayID)
                                ) then
                                    foundPet = blizzardPet
                                end
                            end
                        end, false)

                        if foundPet then
                            StableFrame:OnPetSelected(foundPet)
                            PSM.C_Timer.After(0.05, function()
                                local onClick = StableFrame.ReleasePetButton:GetScript("OnClick")
                                if onClick then
                                    PSM.Utils.SafeCall(onClick, StableFrame.ReleasePetButton)
                                    -- Remove from in-memory data and update saved data
                                    for i = #PSM.state.stablePets, 1, -1 do
                                        if PSM.state.stablePets[i].slotID == pet.slotID then
                                            table.remove(PSM.state.stablePets, i)
                                            break
                                        end
                                    end
                                    -- Update saved data
                                    PSM.state.stablePetsSnapshot = {}
                                    for _, p in ipairs(PSM.state.stablePets) do
                                        table.insert(PSM.state.stablePetsSnapshot, PSM.Data.DeepCopyPet(p))
                                    end
                                    PSM.Data:SavePersistentData()
                                    PSM.UI:UpdatePanel()
                                end
                            end)
                        end
                    end
                end
            end
        end
    end)

    -- Move Up/Down buttons (for ALL pets at stable)
    if PSM.state.isStableOpen and pet.slotID and pet.slotID >= 1 and pet.slotID <= 205 then
        -- Move Up button (decrease slot number)
        row.moveUp:SetScript("OnClick", function()
            PSM.Reorder:MovePetUp(pet)
        end)

        -- Add tooltip
        row.moveUp:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Move Up (to slot " .. (pet.slotID - 1) .. ")")
            GameTooltip:Show()
        end)
        row.moveUp:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        if pet.slotID > 1 then
            row.moveUp:Show()
        else
            row.moveUp:Hide()
        end

        -- Move Down button (increase slot number)
        row.moveDown:SetScript("OnClick", function()
            PSM.Reorder:MovePetDown(pet)
        end)

        -- Add tooltip
        row.moveDown:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Move Down (to slot " .. (pet.slotID + 1) .. ")")
            GameTooltip:Show()
        end)
        row.moveDown:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        if pet.slotID < 205 then
            row.moveDown:Show()
        else
            row.moveDown:Hide()
        end
    else
        row.moveUp:Hide()
        row.moveDown:Hide()
    end

    if PSM.state.isStableOpen then
        row.release:Show()
    else
        row.release:Hide()
    end

    -- Reposition buttons vertically to ensure consistent alignment regardless of visibility
    local buttons = {row.makeActive, row.companion, row.stable, row.release}
    local yOffset = -10
    for _, btn in ipairs(buttons) do
        if btn:IsShown() then
            btn:ClearAllPoints()
            btn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, yOffset)
            yOffset = yOffset - 25 
        end
    end
end

function PSM.UI:FindDisplacementSlot()
    for slot = 2, 5 do
        local occupied = false
        for _, p in ipairs(PSM.state.stablePets) do
            if p.slotID == slot then
                occupied = true
                break
            end
        end
        if not occupied then return slot end
    end

    for slot = 7, 205 do
        local occupied = false
        for _, p in ipairs(PSM.state.stablePets) do
            if p.slotID == slot then
                occupied = true
                break
            end
        end
        if not occupied then return slot end
    end

    return nil
end

function PSM.UI:FindAvailableStableSlot()
    for slot = 7, 205 do
        local occupied = false
        for _, p in ipairs(PSM.state.stablePets) do
            if p.slotID == slot then
                occupied = true
                break
            end
        end
        if not occupied then return slot end
    end
    return nil
end

-- PERFORMANCE OPTIMIZATION: Debounced and cached rendering
function PSM.UI:CreateRenderCache()
    PSM._renderCache = nil
    PSM._renderDebounceTimer = nil
    PSM._lastLayoutWidth = nil
    PSM._lastLayoutHeight = nil
end

-- Cache key generator for expensive calculations
function PSM.UI:GenerateCacheKey()
    local searchText = PSM.state.panel and PSM.state.panel.searchBox:GetText() or ""
    local searchLower = searchText ~= "" and PSM.Utils:NormalizeSearchText(searchText) or ""
    
    return string.format("%d_%s_%s_%s_%s_%s_%s",
        #PSM.state.stablePets,
        searchLower,
        tostring(PSM.state.exoticFilter),
        tostring(PSM.state.duplicatesOnlyFilter),
        PSM.Utils:GetTableHash(PSM.state.selectedSpecs),
        PSM.Utils:GetTableHash(PSM.state.selectedFamilies),
        tostring(PSM.state.sortByDisplayID) .. tostring(PSM.state.sortBySlot)
    )
end

-- Main render function with debouncing
function PSM.UI:RenderPanel()
    if not PSM.state.panel or not PSM.state.content then
        print(PSM.Config.MESSAGES.PANEL_SHOW_FAILED)
        return
    end

    -- Cancel existing debounce timer
    if PSM._renderDebounceTimer then
        PSM._renderDebounceTimer:Cancel()
    end
    
    -- Debounce rendering to avoid excessive calls during rapid changes
    PSM._renderDebounceTimer = PSM.C_Timer.NewTimer(PSM.Config.RENDER_DELAY or 0.01, function()
        self:_RenderPanelImmediate()
    end)
end

-- Immediate rendering function with caching
function PSM.UI:_RenderPanelImmediate()
    if not PSM.state.panel or not PSM.state.content then return end
    
    local cacheKey = self:GenerateCacheKey()
    
    -- Check cache validity
    if PSM._renderCache and PSM._renderCache.key == cacheKey and PSM._renderCache.timestamp then
        local age = GetTime() - PSM._renderCache.timestamp
        if age < 0.1 then -- Cache for 100ms
            self:_ApplyCachedRender(PSM._renderCache.data)
            return
        end
    end
    
    -- Expensive calculation
    local renderData = self:_CalculateRenderData()
    
    -- Cache the result
    PSM._renderCache = {
        key = cacheKey,
        timestamp = GetTime(),
        data = renderData
    }
    
    self:_ApplyCachedRender(renderData)
end

-- Calculate all render data in one pass
function PSM.UI:_CalculateRenderData()
    local searchText = PSM.state.panel.searchBox:GetText() or ""
    local searchLower = searchText ~= "" and PSM.Utils:NormalizeSearchText(searchText) or ""
    
    -- Build duplicate groups from ALL pets first (cached for performance)
    local allGroups = {}
    for i = 1, #PSM.state.stablePets do
        local pet = PSM.state.stablePets[i]
        local key = tostring(pet.icon or 0) .. ":" .. tostring(pet.displayID or 0)
        allGroups[key] = allGroups[key] or {}
        table.insert(allGroups[key], pet)
    end

    -- Pre-build filter flags for faster checks
    local hasSpecsFilter = next(PSM.state.selectedSpecs) ~= nil
    local hasFamilyFilter = next(PSM.state.selectedFamilies) ~= nil
    local hasSearch = searchLower ~= ""
    local needsDuplicatesFilter = PSM.state.duplicatesOnlyFilter
    
    -- Build duplicate keys if needed
    local duplicateKeys = {}
    if needsDuplicatesFilter then
        for key, group in pairs(allGroups) do
            if #group > 1 then
                duplicateKeys[key] = true
            end
        end
    end

    -- Optimized filtering with early exits
    local filteredPets = {}
    local filteredCount = 0
    
    for i = 1, #PSM.state.stablePets do
        local pet = PSM.state.stablePets[i]
        local skip = false

        -- Fast filter checks with early exits
        if PSM.state.exoticFilter and not pet.isExotic then 
            skip = true 
        elseif hasSpecsFilter and not PSM.state.selectedSpecs[pet.specName] then 
            skip = true 
        elseif hasFamilyFilter and not PSM.state.selectedFamilies[pet.familyName] then 
            skip = true 
        elseif needsDuplicatesFilter then
            local key = tostring(pet.icon or 0) .. ":" .. tostring(pet.displayID or 0)
            if not duplicateKeys[key] then skip = true end
        end

        -- Search filtering (only if not already filtered out)
        if not skip and hasSearch then
            local match = false
            
            -- Fast field checks
            local fields = {pet.name, pet.familyName, pet.specName, tostring(pet.displayID or "")}
            for j = 1, #fields do
                if fields[j] and tostring(fields[j]):lower():find(searchLower, 1, true) then
                    match = true
                    break
                end
            end

            -- Abilities search (only if no field match)
            if not match and pet.abilities then
                for _, ability in ipairs(pet.abilities) do
                    if tostring(ability):lower():find(searchLower, 1, true) then
                        match = true
                        break
                    end
                end
            end

            if not match then skip = true end
        end

        if not skip then
            filteredCount = filteredCount + 1
            filteredPets[filteredCount] = pet
        end
    end

    -- Efficient sorting (only if needed)
    if PSM.state.sortByDisplayID then
        table.sort(filteredPets, function(a, b)
            return (a.displayID or 0) < (b.displayID or 0)
        end)
    elseif PSM.state.sortBySlot then
        table.sort(filteredPets, function(a, b)
            return (a.slotID or 0) < (b.slotID or 0)
        end)
    end

    -- Calculate duplicate stats FROM FILTERED PETS ONLY
    local filteredGroups = {}
    for i = 1, filteredCount do
        local pet = filteredPets[i]
        local key = tostring(pet.icon or 0) .. ":" .. tostring(pet.displayID or 0)
        filteredGroups[key] = filteredGroups[key] or {}
        table.insert(filteredGroups[key], pet)
    end

    local duplicatePets, duplicateGroups = 0, 0
    for _, group in pairs(filteredGroups) do
        if #group > 1 then
            duplicateGroups = duplicateGroups + 1
            duplicatePets = duplicatePets + #group
        end
    end

    -- Calculate layout using cached measurements
    local contentWidth = PSM.state.content:GetWidth()
    if not contentWidth or contentWidth <= 0 then
        contentWidth = 470 -- fallback
    end
    
    local desiredColWidth = 400
    local colCount = math.max(1, math.floor((contentWidth + 8) / (desiredColWidth + 8)))
    local colWidth = math.floor((contentWidth - 8 * (colCount - 1)) / colCount)
    colWidth = math.max(colWidth, 400)
    local rowTotal = math.ceil(filteredCount / colCount)

    return {
        filteredPets = filteredPets,
        filteredCount = filteredCount,
        duplicatePets = duplicatePets,
        duplicateGroups = duplicateGroups,
        colCount = colCount,
        colWidth = colWidth,
        rowTotal = rowTotal,
        allGroups = allGroups
    }
end

-- Apply cached render data to UI
function PSM.UI:_ApplyCachedRender(renderData)
    -- Store render data for virtual scrolling
    PSM.state.currentRenderData = renderData

    -- Update stats text
    PSM.state.panel.statsText:SetText(string.format(
        "Showing: %d pets  |  Duplicates: %d pets (%d groups)",
        renderData.filteredCount, renderData.duplicatePets, renderData.duplicateGroups
    ))

    -- Set content height for scrolling
    local rowHeight = PSM.Config.ROW_HEIGHT
    PSM.state.content:SetHeight(math.max(renderData.rowTotal * rowHeight + 10, 100))

    -- Reset scroll
    PSM.state.scrollFrame:SetVerticalScroll(0)
    PSM.state.panel.scrollOffset = 0

    -- Render visible rows
    self:UpdateVisibleRows()
end

-- Update visible rows for virtual scrolling
function PSM.UI:UpdateVisibleRows()
    local renderData = PSM.state.currentRenderData
    if not renderData or not PSM.state.panel then return end

    local panel = PSM.state.panel

    -- Create row pool if not exists
    if not panel.modelRows then
        panel.modelRows = {}
        local ROWS_PER_PAGE = 50
        for i = 1, ROWS_PER_PAGE do
            local row = PSM.UI.Row:EnsureRow(i)
            if row then
                table.insert(panel.modelRows, row)
                row:Hide()
            end
        end
    end

    local totalItems = renderData.filteredCount
    if totalItems == 0 then
        for _, row in ipairs(panel.modelRows) do
            row:Hide()
        end
        return
    end

    local contentWidth = PSM.state.content:GetWidth()
    if not contentWidth or contentWidth <= 0 then contentWidth = 470 end
    local desiredColWidth = 400
    local colCount = math.max(1, math.floor((contentWidth + 8) / (desiredColWidth + 8)))
    local colWidth = math.floor((contentWidth - 8 * (colCount - 1)) / colCount)
    colWidth = math.max(colWidth, 400)
    local rowTotal = math.ceil(totalItems / colCount)

    -- Calculate visible rows
    local scrollFrameHeight = PSM.state.scrollFrame:GetHeight() or 500
    local visibleRowCount = math.ceil(scrollFrameHeight / PSM.Config.ROW_HEIGHT) + 2
    local startRow = math.max(1, panel.scrollOffset + 1)
    local endRow = math.min(rowTotal, startRow + visibleRowCount - 1)

    -- Calculate start and end pet indices
    local startIndex = (startRow - 1) * colCount + 1
    local endIndex = math.min(totalItems, endRow * colCount)

    -- Hide all rows first
    for _, row in ipairs(panel.modelRows) do
        row:Hide()
    end

    -- Render visible rows
    local rowIndex = 1
    for dataIndex = startIndex, endIndex do
        if rowIndex > #panel.modelRows then break end

        local pet = renderData.filteredPets[dataIndex]
        local row = panel.modelRows[rowIndex]

        if pet and row then
            -- Calculate position
            local col = ((dataIndex - 1) % colCount)
            local rowIdx = math.floor((dataIndex - 1) / colCount) + 1

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", PSM.state.content, "TOPLEFT",
                4 + col * (colWidth + 8),
                -(rowIdx - 1) * PSM.Config.ROW_HEIGHT)
            row:SetWidth(colWidth)

            local leftColumnWidth = math.floor(colWidth / 2)
            local rightColumnWidth = colWidth - leftColumnWidth
            local fixedSpace = 2 + PSM.Config.MODEL_SIZE + 6

            if row.text then row.text:SetWidth(leftColumnWidth - fixedSpace) end
            if row.abilitiesHeader then row.abilitiesHeader:SetWidth(rightColumnWidth) end
            if row.abilitiesList then row.abilitiesList:SetWidth(rightColumnWidth) end

            PSM.UI.Row:UpdateRow(row, pet, renderData.allGroups)

            if row.separator then
                row.separator:Show()
            end

            row:Show()
            rowIndex = rowIndex + 1
        end
    end
end

function PSM.UI:UpdatePanel()
    if not PSM.state.panel then
        self:BuildPanel()
    end

    -- Collect data if stable is open
    if PSM.state.isStableOpen then
        -- Only collect if we don't have data yet
        if #PSM.state.stablePets == 0 then
            PSM.Data:CollectStablePets()
        end
    else
        -- Load from saved data if needed
        if #PSM.state.stablePets == 0 then
            if not PSM.Data:LoadPersistentDataForDisplay() then
                print("|cFFFF0000No saved data available!|r")
                return
            end
        end
    end

    self:RenderPanel()
    self:UpdatePanelTitle()
    self:UpdateSortButtonTexts()

    if PSM.state.panel then
        PSM.state.panel:Show()
    end
end

function PSM.UI:UpdatePanelWithSnapshot()
    if not PSM.state.panel then
        self:BuildPanel()
    end

    if PSM.state.isStableOpen then
        -- Clear and collect once
        PSM.Data:ClearMemory()
        PSM.Data:CollectStablePets()
        PSM.Data:CreateSnapshot()
    else 
        if #PSM.state.stablePets == 0 then
            if not PSM.Data:LoadPersistentDataForDisplay() then
                print(PSM.Config.MESSAGES.NO_SNAPSHOT)
                return
            end
        end
    end

    self:RenderPanel()
    self:UpdatePanelTitle()
    self:UpdateSortButtonTexts()

    if PSM.state.panel then
        PSM.state.panel:Show()
    end
end

function PSM.UI:UpdatePanelTitle()
    if not PSM.state.panel or not PSM.state.panel.title then return end

    if not PSM.state.isStableOpen then
        local dataSource = "Pet Stable Management"
        local titleColor = {0.6, 0.8, 1}

        if #PSM.state.stablePets > 0 then
            local formatted = PSM.Data:GetFormattedTimestamp()
            if formatted ~= "Never" then
                dataSource = dataSource .. " (using data from " .. formatted .. ")"
            else
                dataSource = dataSource .. " (using preserved data)"
            end
        elseif PetStableManagementDB and PetStableManagementDB.snapshotData and #PetStableManagementDB.snapshotData > 0 then
            local formatted = PSM.Data:GetFormattedTimestamp()
            if formatted ~= "Never" then
                dataSource = dataSource .. " (using data saved on " .. formatted .. ")"
            else
                dataSource = dataSource .. " (using saved data)"
            end
        else
            dataSource = dataSource .. " (no saved data available)"
            titleColor = {1, 0.7, 0.7}
        end

        PSM.state.panel.title:SetText(dataSource)
        PSM.state.panel.title:SetTextColor(unpack(titleColor))
    else
        PSM.state.panel.title:SetText("Pet Stable Management (Live)")
        PSM.state.panel.title:SetTextColor(unpack(PSM.Config.COLORS.PRIMARY))
    end
end

function PSM.UI:UpdateSortButtonTexts()
    if not PSM.state.panel then return end

    if PSM.state.panel.sortDisplayIDButton then
        local text = PSM.state.sortByDisplayID and "Sorted by Model" or "Sort by Model"
        PSM.state.panel.sortDisplayIDButton:SetText(text)
    end

    if PSM.state.panel.sortSlotButton then
        local text = PSM.state.sortBySlot and "Sorted by Slot" or "Sort by Slot"
        PSM.state.panel.sortSlotButton:SetText(text)
    end
end

-- Optimized OnSizeChanged handler
function PSM.UI:CreateOptimizedSizeChangedHandler()
    if not PSM.state.panel then return end
    
    PSM.state.panel:SetScript("OnSizeChanged", function(self, width, height)
        -- Only recalculate if size actually changed significantly
        local widthDiff = math.abs((PSM._lastLayoutWidth or 0) - width)
        local heightDiff = math.abs((PSM._lastLayoutHeight or 0) - height)
        
        if widthDiff < 10 and heightDiff < 10 then return end -- Ignore small changes
        
        PSM._lastLayoutWidth = width
        PSM._lastLayoutHeight = height
        
        if not PSM.state.scrollFrame or not PSM.state.content then return end

        PSM.state.scrollFrame:SetWidth(width - 40)
        
        -- Use the actual scrollFrame width - it already accounts for scrollbar
        PSM.state.content:SetWidth(PSM.state.scrollFrame:GetWidth())
        PSM.state.content:ClearAllPoints()
        PSM.state.content:SetPoint("TOPLEFT")
        PSM.state.content:SetPoint("TOPRIGHT")

        -- Invalidate cache to force recalculation
        PSM._renderCache = nil
        
        PSM.C_Timer.After(0.05, function() 
            if PSM.UI and PSM.UI.RenderPanel then
                PSM.UI:RenderPanel() 
            end
        end)
    end)
end

-- Initialize performance optimizations
PSM.UI:CreatePerformanceOptimizations()
PSM.UI:CreateRenderCache()
