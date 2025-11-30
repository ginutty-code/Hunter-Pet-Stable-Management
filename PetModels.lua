-- PetModels.lua
-- Simplified loader for hunter pet model data from PetModelsData.lua

local addonName = "PetStableManagement"

_G.PSM = _G.PSM or {}
local PSM = _G.PSM

PSM.PetModels = PSM.PetModels or {}

-- Get family models (process raw data on demand)
function PSM.PetModels:GetFamilyModels(familyName)
    if not familyName then return nil end

    -- Check if already processed
    if self[familyName] and self[familyName].displayIds then
        return self[familyName]
    end

    -- Check if raw data exists in PSM.PetModels
    local rawData = self[familyName]
    if rawData and type(rawData) == "table" then
        -- Process the raw data
        return self:ProcessNewFormatData(familyName, rawData)
    end

    -- Check _G.PetData for the family data
    if _G.PetData and _G.PetData[familyName] and type(_G.PetData[familyName]) == "table" then
        return self:ProcessNewFormatData(familyName, _G.PetData[familyName])
    end

    return nil
end

-- Process new format data into flat display ID structure (skip categories for performance)
function PSM.PetModels:ProcessNewFormatData(familyName, familyData)
    -- Convert new format to flat display ID structure
    self[familyName] = {
        displayIds = {} -- Flat list of display IDs with their NPCs
    }

    -- Group NPCs by display ID from flat family data (no categories)
    local displayIdMap = {}

    -- Process each NPC in the family data
    for npcId, npcData in pairs(familyData) do
        local displayIds = npcData.display_ids or {}
        for _, displayId in ipairs(displayIds) do
            if not displayIdMap[displayId] then
                displayIdMap[displayId] = {
                    displayId = displayId,
                    npcs = {}
                }
            end

            table.insert(displayIdMap[displayId].npcs, {
                npcId = tonumber(npcId) or npcId,
                name = npcData.name,
                zones = npcData.zones,
                level = npcData.level
               
            })
        end
    end

    -- Convert to flat display ID list
    for _, displayData in pairs(displayIdMap) do
        table.insert(self[familyName].displayIds, displayData)
    end

    -- Sort display IDs for consistent ordering
    table.sort(self[familyName].displayIds, function(a, b)
        return a.displayId < b.displayId
    end)

    return self[familyName]
end

-- Get display ID count for a family
function PSM.PetModels:GetModelCount(familyName)
    local family = self:GetFamilyModels(familyName)
    return family and #family.displayIds or 0
end

-- Get specific display ID info
function PSM.PetModels:GetModelInfo(familyName, displayId)
    local family = self:GetFamilyModels(familyName)
    if not family then return nil end

    for _, displayData in ipairs(family.displayIds) do
        if tostring(displayData.displayId) == tostring(displayId) then
            return displayData
        end
    end

    return nil
end

-- Get all NPCs for a specific display ID
function PSM.PetModels:GetAllPetsForDisplay(familyName, displayId)
    local family = self:GetFamilyModels(familyName)
    if not family then return {} end

    for _, displayData in ipairs(family.displayIds) do
        if tostring(displayData.displayId) == tostring(displayId) then
            return displayData.npcs
        end
    end

    return {}
end

-- Get all available families from the loaded data
function PSM.PetModels:GetAvailableFamilies()
    local families = {}

    -- Check PSM.PetModels first
    for name in pairs(self) do
        if type(self[name]) == "table" and name ~= "families" then
            families[name] = true
        end
    end

    -- Check _G.PetModelsData
    if _G.PetModelsData then
        for name in pairs(_G.PetModelsData) do
            if type(_G.PetModelsData[name]) == "table" and name ~= "families" then
                families[name] = true
            end
        end
    end

    -- Check _G.PetData (the actual data source from PetModelsData.lua)
    if _G.PetData then
        for name in pairs(_G.PetData) do
            if type(_G.PetData[name]) == "table" then
                families[name] = true
            end
        end
    end

    -- Convert to sorted list
    local result = {}
    for name in pairs(families) do
        table.insert(result, name)
    end
    table.sort(result)
    return result
end

-- Get list of available family files (not used)
function PSM.PetModels:GetAvailableFamilyFiles()
    return {}
end

-- Preload all families
function PSM.PetModels:PreloadAllFamilies()
    local families = self:GetAvailableFamilies()
    local loadedCount = 0
    local startTime = debugprofilestop()

    for _, familyName in ipairs(families) do
        if self:GetFamilyModels(familyName) then
            loadedCount = loadedCount + 1
        end
    end

    local endTime = debugprofilestop()
    local elapsed = endTime - startTime

    print(string.format("[%s] Preloaded %d families in %.2fms", addonName, loadedCount, elapsed))
    return loadedCount, elapsed
end

-- Get loading statistics
function PSM.PetModels:GetLoadingStats()
    local families = self:GetAvailableFamilies()
    local totalFamilies = #families
    local loadedCount = 0
    for _, familyName in ipairs(families) do
        if self[familyName] and self[familyName].displayIds then
            loadedCount = loadedCount + 1
        end
    end

    return {
        totalFamilies = totalFamilies,
        loadedFamilies = loadedCount,
        pendingFamilies = totalFamilies - loadedCount,
        loadPercentage = totalFamilies > 0 and (loadedCount / totalFamilies) * 100 or 0
    }
end


-- Clear cache
function PSM.PetModels:ClearCache()
    local families = self:GetAvailableFamilies()
    for _, familyName in ipairs(families) do
        self[familyName] = nil
    end
end
