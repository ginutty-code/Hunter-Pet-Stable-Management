-- Data.lua
-- Data management and collection for PetStableManagement

local addonName = "PetStableManagement"

_G.PSM = _G.PSM or {}
local PSM = _G.PSM

PSM.Data = {}

-- Deep copy a pet table
local function DeepCopyPet(pet)
    if type(pet) ~= "table" then return pet end
    local copy = {}
    for k, v in pairs(pet) do
        if type(v) == "table" then
            copy[k] = DeepCopyPet(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function PSM.Data:SavePersistentData()
    if not PetStableManagementDB then
        PetStableManagementDB = {}
    end

    PetStableManagementDB.version = "2.0.0"
    PetStableManagementDB.lastUpdated = date and date("%Y-%m-%d %H:%M:%S") or tostring(time())

    -- Clear old snapshot
    PetStableManagementDB.snapshotData = {}

    -- Save directly from stablePets
    local savedCount = 0
    for _, pet in ipairs(PSM.state.stablePets) do
        local petCopy = DeepCopyPet(pet)
        if petCopy then
            table.insert(PetStableManagementDB.snapshotData, petCopy)
            savedCount = savedCount + 1
        end
    end

    self:SaveSettings()

    collectgarbage("collect")
    return savedCount
end

function PSM.Data:SaveSettings()
    if not PetStableManagementDB then
        PetStableManagementDB = {}
    end

    PetStableManagementDB.settings = {
        sortByDisplayID = PSM.state.sortByDisplayID or false,
        sortBySlot = PSM.state.sortBySlot or false,
        exoticFilter = PSM.state.exoticFilter or false,
        duplicatesOnlyFilter = PSM.state.duplicatesOnlyFilter or false,
        selectedSpecs = DeepCopyPet(PSM.state.selectedSpecs) or {},
        selectedFamilies = DeepCopyPet(PSM.state.selectedFamilies) or {},
        selectedModelsFamilies = DeepCopyPet(PSM.state.selectedModelsFamilies) or {},
        favoriteModels = DeepCopyPet(PSM.state.favoriteModels) or {},
        minimapButton = PetStableManagementDB.settings and PetStableManagementDB.settings.minimapButton or {
            hide = false,
            minimapPos = 220,
            lock = false
        }
    }
end

function PSM.Data:LoadPersistentDataForDisplay()
    if not PetStableManagementDB or not PetStableManagementDB.snapshotData then
        return false
    end

    if type(PetStableManagementDB.snapshotData) ~= "table" or #PetStableManagementDB.snapshotData == 0 then
        return false
    end

    -- Clear current data, but preserve filters when stable is open
    self:ClearMemory(PSM.state.isStableOpen)

    -- Load pets from saved data
    for _, pet in ipairs(PetStableManagementDB.snapshotData) do
        if type(pet) == "table" and pet.name and pet.icon then
            table.insert(PSM.state.stablePets, DeepCopyPet(pet))
        end
    end

    self:RebuildSpecAndFamilyLists()

    -- Load settings
    if PetStableManagementDB.settings then
        PSM.state.sortByDisplayID = PetStableManagementDB.settings.sortByDisplayID or false
        PSM.state.sortBySlot = PetStableManagementDB.settings.sortBySlot or false
        PSM.state.exoticFilter = PetStableManagementDB.settings.exoticFilter or false
        PSM.state.duplicatesOnlyFilter = PetStableManagementDB.settings.duplicatesOnlyFilter or false
        PSM.state.selectedSpecs = DeepCopyPet(PetStableManagementDB.settings.selectedSpecs) or {}
        PSM.state.selectedFamilies = DeepCopyPet(PetStableManagementDB.settings.selectedFamilies) or {}
        PSM.state.selectedModelsFamilies = DeepCopyPet(PetStableManagementDB.settings.selectedModelsFamilies) or {}
        PSM.state.favoriteModels = DeepCopyPet(PetStableManagementDB.settings.favoriteModels) or {}
    end

    return true
end

function PSM.Data:LoadSettingsOnly()
    -- Load settings independently of pet data
    if PetStableManagementDB and PetStableManagementDB.settings then
        PSM.state.sortByDisplayID = PetStableManagementDB.settings.sortByDisplayID or false
        PSM.state.sortBySlot = PetStableManagementDB.settings.sortBySlot or false
        PSM.state.exoticFilter = PetStableManagementDB.settings.exoticFilter or false
        PSM.state.duplicatesOnlyFilter = PetStableManagementDB.settings.duplicatesOnlyFilter or false
        PSM.state.selectedSpecs = DeepCopyPet(PetStableManagementDB.settings.selectedSpecs) or {}
        PSM.state.selectedFamilies = DeepCopyPet(PetStableManagementDB.settings.selectedFamilies) or {}
        PSM.state.selectedModelsFamilies = DeepCopyPet(PetStableManagementDB.settings.selectedModelsFamilies) or {}
        PSM.state.favoriteModels = DeepCopyPet(PetStableManagementDB.settings.favoriteModels) or {}
    end
end

function PSM.Data:GetFormattedTimestamp()
    if not PetStableManagementDB or not PetStableManagementDB.lastUpdated then
        return "Never"
    end

    local timestamp = PetStableManagementDB.lastUpdated
    if type(timestamp) == "number" then
        return date("%Y-%m-%d %H:%M:%S", timestamp)
    else
        return tostring(timestamp)
    end
end

function PSM.Data:CreateSnapshot()
    -- Save current data to persistent storage
    local count = self:SavePersistentData()
    
    if count > 0 then
        print("|cFF00FF00PetStableManagement: Saved " .. count .. " pets to database.|r")
    end
end

function PSM.Data:RebuildSpecAndFamilyLists()
    PSM.state.specList = {}
    PSM.state.familyList = {}

    local specSet = {}
    local familySet = {}

    for _, pet in ipairs(PSM.state.stablePets) do
        local specName = self:GetPetSpecName(pet)
        local familyName = self:GetPetFamilyName(pet)

        if specName and not specSet[specName] then
            table.insert(PSM.state.specList, specName)
            specSet[specName] = true
        end

        if familyName and not familySet[familyName] then
            table.insert(PSM.state.familyList, familyName)
            familySet[familyName] = true
        end
    end

    table.sort(PSM.state.specList)
    table.sort(PSM.state.familyList)
end

function PSM.Data:GetPetSpecName(pet)
    if not pet then return nil end
    return pet.specName or pet.specialization or nil
end

function PSM.Data:GetPetFamilyName(pet)
    if not pet then return nil end
    return pet.familyName or (pet.family and pet.family.name) or pet.type or nil
end

function PSM.Data:CollectStablePets()
    if not PSM.state.isStableOpen then
        print("|cFFFF0000ERROR: CollectStablePets called when stable is NOT open!|r")
        return
    end

    -- Clear existing data before collecting, but preserve filter selections
    self:ClearMemory(true)

    if not PSM.StableFrame then
        print(PSM.Config.MESSAGES.STABLE_FRAME_NOT_FOUND)
        return
    end

    self:CollectActivePets()
    self:CollectStabledPets()
    self:RebuildSpecAndFamilyLists()
    self:ValidateCollectedData()
end

function PSM.Data:CollectActivePets()
    if not PSM.C_StableInfo or not PSM.C_StableInfo.GetStablePetInfo then
        return
    end

    for slot = 1, PSM.Config.ACTIVE_PET_SLOTS do
        local petInfo = PSM.Utils.SafeCall(PSM.C_StableInfo.GetStablePetInfo, slot)

        if petInfo and petInfo.name and petInfo.icon then
            local petData = self:ProcessPetInfo(petInfo, slot, true)
            if petData then
                table.insert(PSM.state.stablePets, petData)
            end
        end
    end
end

function PSM.Data:CollectStabledPets()
    local stabledPetList = PSM.StableFrame.StabledPetList
    if not stabledPetList then return end

    local scrollBox = stabledPetList.ScrollBox
    if not scrollBox then return end

    local dataProvider = scrollBox:GetDataProvider()
    if not dataProvider then return end

    dataProvider:ForEach(function(node)
        local petData = node:GetData()
        if petData and petData.icon then
            local processedPet = DeepCopyPet(petData)
            processedPet.isActive = false
            self:NormalizePetData(processedPet)
            processedPet.abilities = self:ExtractPetAbilities(processedPet)

            if not processedPet.modelSceneID then
                processedPet.modelSceneID = 783
            end

            processedPet._originalData = nil

            if processedPet and processedPet.name then
                table.insert(PSM.state.stablePets, processedPet)
            end
        end
    end, false)
end

function PSM.Data:ProcessPetInfo(petInfo, slotID, isActive)
    if not petInfo or not petInfo.name or not petInfo.icon then
        return nil
    end

    local familyName = self:GetPetFamilyName(petInfo)
    local specName = self:GetPetSpecName(petInfo)
    local abilities = self:ExtractPetAbilities(petInfo)

    return {
        slotID = slotID,
        name = petInfo.name,
        icon = petInfo.icon,
        displayID = petInfo.displayID or 0,
        petNumber = petInfo.petNumber or 0,
        petLevel = petInfo.level or 0,
        familyName = familyName,
        specName = specName,
        specID = petInfo.specID or petInfo.specId or nil,
        isExotic = self:GetPetExoticStatus(petInfo),
        isActive = isActive,
        abilities = abilities,
        modelSceneID = 783,
    }
end

function PSM.Data:ExtractPetAbilities(petInfo)
    local abilities = {
        family = {},
        spec = {},
        pet = {},
        unknown = {}
    }

    local abilitySet = {}

    -- Process spec abilities
    if petInfo.specAbilities and type(petInfo.specAbilities) == "table" then
        for _, ability in ipairs(petInfo.specAbilities) do
            local abilityName = self:GetAbilityName(ability)
            if abilityName and not abilitySet[abilityName] then
                table.insert(abilities.spec, abilityName)
                abilitySet[abilityName] = true
            end
        end
    end

    -- Process pet-specific abilities
    if petInfo.petAbilities and type(petInfo.petAbilities) == "table" then
        for _, ability in ipairs(petInfo.petAbilities) do
            local abilityName = self:GetAbilityName(ability)
            if abilityName and not abilitySet[abilityName] then
                table.insert(abilities.pet, abilityName)
                abilitySet[abilityName] = true
            end
        end
    end

    -- Process general abilities
    if petInfo.abilities and type(petInfo.abilities) == "table" then
        for _, ability in ipairs(petInfo.abilities) do
            local abilityName = self:GetAbilityName(ability)
            if abilityName and not abilitySet[abilityName] then
                if #abilities.spec > 0 or #abilities.pet > 0 then
                    table.insert(abilities.family, abilityName)
                else
                    table.insert(abilities.unknown, abilityName)
                end
                abilitySet[abilityName] = true
            end
        end
    end

    return abilities
end

function PSM.Data:GetAbilityName(ability)
    if type(ability) == "number" then
        return PSM.Utils:GetSpellNameCompat(ability)
    elseif type(ability) == "string" then
        return ability
    elseif type(ability) == "table" then
        return ability.name or ability.Name or nil
    end
    return nil
end

function PSM.Data:NormalizePetData(petData)
    if not petData then return end

    if not petData.familyName then
        petData.familyName = self:GetPetFamilyName(petData)
    end

    if not petData.specName then
        petData.specName = self:GetPetSpecName(petData)
    end

    if petData.isExotic == nil then
        petData.isExotic = self:GetPetExoticStatus(petData)
    end
end

function PSM.Data:GetPetExoticStatus(petInfo)
    if not petInfo then return false end
    local isExotic = petInfo.isExotic or petInfo.Exotic
    return isExotic and true or false
end

function PSM.Data:ValidateCollectedData()
    local validPets = {}

    for _, pet in ipairs(PSM.state.stablePets) do
        if pet and type(pet) == "table" and pet.name then
            if not pet.icon or pet.icon == "" then
                pet.icon = "Interface\\Icons\\INV_Misc_QuestionMark"
            end
            if not pet.displayID then pet.displayID = 0 end
            if not pet.familyName then pet.familyName = "Unknown" end
            if not pet.specName then pet.specName = "Unknown" end
            table.insert(validPets, pet)
        end
    end

    PSM.state.stablePets = validPets
end

function PSM.Data:ClearMemory(preserveFilters)
    -- Clear stablePets
    for i = #PSM.state.stablePets, 1, -1 do
        PSM.state.stablePets[i] = nil
    end
    PSM.state.stablePets = {}

    -- Clear snapshot
    for i = #PSM.state.stablePetsSnapshot, 1, -1 do
        PSM.state.stablePetsSnapshot[i] = nil
    end
    PSM.state.stablePetsSnapshot = {}

    -- Clear filter lists
    for i = #PSM.state.specList, 1, -1 do
        PSM.state.specList[i] = nil
    end
    PSM.state.specList = {}

    for i = #PSM.state.familyList, 1, -1 do
        PSM.state.familyList[i] = nil
    end
    PSM.state.familyList = {}

    -- Only clear selected filters if not preserving
    if not preserveFilters then
        PSM.state.selectedSpecs = {}
        PSM.state.selectedFamilies = {}
    end

    collectgarbage("collect")
end

-- Clear UI rows to free memory
function PSM.Data:ClearUIRows()
    if not PSM.state.rows then return end
    
    for i = #PSM.state.rows, 1, -1 do
        local row = PSM.state.rows[i]
        if row then
            -- Hide and clear model
            if row.model then
                row.model:Hide()
                row.model:ClearModel()
                row.model.isRotating = false
                if PSM.RotationFrame and PSM.RotationFrame.activeModels then
                    PSM.RotationFrame.activeModels[row.model] = nil
                end
            end
            
            -- Clear text
            if row.text then row.text:SetText("") end
            if row.abilitiesList then row.abilitiesList:SetText("") end
            
            row:Hide()
        end
    end
    
    collectgarbage("collect")
end