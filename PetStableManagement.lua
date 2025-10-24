-- PetStableManagement.lua
-- Version: 2.0.0

local addonName = "PetStableManagement"

-- Initialize global namespace
_G.PSM = _G.PSM or {}
local PSM = _G.PSM

-- Initialize persistent data storage
PetStableManagementDB = PetStableManagementDB or {
    version = "2.0.0",
    lastUpdated = nil,
    snapshotData = {},
    settings = {
        sortByDisplayID = false,
        sortBySlot = false,
        exoticFilter = false,
        duplicatesOnlyFilter = false,
        minimapButton = {
            hide = false,
            minimapPos = 220,
            lock = false
        }
    }
}

--------------------------------------------------------------------------------
-- WOW API REFERENCES
--------------------------------------------------------------------------------
PSM.CreateFrame = CreateFrame
PSM.StableFrame = StableFrame
PSM.UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
PSM.UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth
PSM.UIDropDownMenu_SetText = UIDropDownMenu_SetText
PSM.UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
PSM.UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
PSM.C_Timer = C_Timer
PSM.hooksecurefunc = hooksecurefunc
PSM.C_StableInfo = C_StableInfo
PSM.C_Spell = C_Spell
PSM.GetSpellInfo = GetSpellInfo
PSM.UIParent = UIParent
PSM.GameTooltip = GameTooltip
PSM.GetCursorPosition = GetCursorPosition
PSM.ToggleDropDownMenu = ToggleDropDownMenu
PSM.EasyMenu = EasyMenu

--------------------------------------------------------------------------------
-- STATE MANAGEMENT
--------------------------------------------------------------------------------
PSM.state = {
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
    specList = {},
    familyList = {},
    isStableOpen = false,
    minimapButton = nil,
}

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------
PSM.Config = {
    -- UI Dimensions
    ROW_HEIGHT = 120,
    PANEL_WIDTH = 500,
    PANEL_HEIGHT = 640,
    BUTTON_WIDTH = 80,
    BUTTON_HEIGHT = 22,
    MODEL_SIZE = 90,
    ICON_SIZE = 60,
    TEXT_WIDTH = 180,
    ABILITIES_WIDTH = 180,
    
    -- Font Sizes
    FONT_SIZES = {
        TITLE = 12,
        STATS = 10,
        PET_TEXT = 9,
        ABILITIES_HEADER = 9,
        ABILITIES_TEXT = 8,
    },
    
    -- Layout
    CONTENT_PADDING = 10,
    SCROLL_BAR_WIDTH = 20,
    COLUMN_SPACING = 8,
    RESIZE_HANDLE_SIZE = 16,
    
    -- Timing
    UPDATE_DELAY = 1,
    SEARCH_DELAY = 0.3,
    SNAPSHOT_DELAY = 0.3,
    RENDER_DELAY = 0.01,
    
    -- Pet Stable
    MAX_STABLE_SLOTS = 205,
    ACTIVE_PET_SLOTS = 5,
    COMPANION_SLOT = 6,
    
    -- Search
    MAX_SEARCH_RESULTS = 205,
    MIN_SEARCH_LENGTH = 1,
    
    -- Colors
    COLORS = {
        PRIMARY = {1, 0.82, 0},
        SECONDARY = {0.7, 0.7, 1},
        ERROR = {1, 0.2, 0.2},
        WARNING = {1, 0.8, 0.2},
        SUCCESS = {0.2, 1, 0.2},
        DUPLICATE = {1, 0.6, 0.6},
        BACKGROUND = {0, 0, 0, 0.25},
        BACKGROUND_DUPLICATE = {0.35, 0, 0, 0.35},
    },
    
    -- Messages
    MESSAGES = {
        STABLE_FRAME_NOT_FOUND = "|cFFFF0000StableFrame not found!|r",
        PANEL_CREATION_FAILED = "|cFFFF0000Panel creation failed!|r",
        PANEL_SHOW_FAILED = "|cFFFF0000Panel failed to show!|r",
        STABLE_MUST_BE_OPEN = "|cFFFF0000Stable must be open to %s!|r",
        NO_AVAILABLE_SLOTS = "|cFFFF0000No available slots to displace pet from slot 1!|r",
        NO_STABLE_SLOTS = "|cFFFF0000No available stable slots found! (Max 205 slots)|r",
        SNAPSHOT_CREATED = "|cFF00FF00Pet data snapshot created: %d pets saved.|r",
        NO_SNAPSHOT = "|cFFFF8800No snapshot available. Please open the stable to load pet data.|r",
        ADDON_LOADED = "|cFF00FF00Pet Stable Management loaded. Use /psm or click the minimap button to toggle the panel.|r",
    }
}

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
PSM.Utils = {}

function PSM.Utils.SafeCall(func, ...)
    if type(func) == "function" then
        local success, result = pcall(func, ...)
        if success then
            return result
        else
            print(string.format("|cFFFF0000Error: %s|r", tostring(result)))
            return nil
        end
    end
    return nil
end

function PSM.Utils:GetSpellNameCompat(spellID)
    if not spellID or type(spellID) ~= "number" then
        return nil
    end
    
    local spellName = nil
    if PSM.C_Spell and PSM.C_Spell.GetSpellName then
        spellName = PSM.Utils.SafeCall(PSM.C_Spell.GetSpellName, spellID)
    end
    if not spellName and PSM.GetSpellInfo then
        spellName = PSM.Utils.SafeCall(PSM.GetSpellInfo, spellID)
    end
    
    return spellName
end

function PSM.Utils:NormalizeSearchText(text)
    if type(text) ~= "string" then return "" end
    return text:lower():gsub("^%s+", ""):gsub("%s+$", "")
end

function PSM.Utils:SafeStringFormat(formatStr, ...)
    if type(formatStr) ~= "string" then return "" end
    
    local args = {...}
    for i, arg in ipairs(args) do
        if arg == nil then
            args[i] = "nil"
        elseif type(arg) ~= "string" and type(arg) ~= "number" then
            args[i] = tostring(arg)
        end
    end
    
    local success, result = pcall(string.format, formatStr, unpack(args))
    return success and result or formatStr
end

function PSM.Utils:FormatColorText(text, color)
    if not text or not color then return text or "" end
    
    local r, g, b = color[1] or 1, color[2] or 1, color[3] or 1
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor(r * 255),
        math.floor(g * 255),
        math.floor(b * 255),
        text)
end

function PSM.Utils:ClearTable(tbl)
    if type(tbl) == "table" then
        for k in pairs(tbl) do
            tbl[k] = nil
        end
    end
end

function PSM.Utils:Debounce(func, delay)
    if type(func) ~= "function" then
        return function() end
    end
    
    local timer = nil
    delay = delay or PSM.Config.UPDATE_DELAY
    
    return function(...)
        local args = {...}
        if timer then
            timer:Cancel()
        end
        
        timer = PSM.C_Timer.NewTimer(delay, function()
            PSM.Utils.SafeCall(func, unpack(args))
        end)
    end
end

--------------------------------------------------------------------------------
-- MINIMAP BUTTON
--------------------------------------------------------------------------------
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
    
    -- Icon - Using a raptor icon
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

    -- Show panel with available data
    if PSM.state.isStableOpen then
        PSM.UI:UpdatePanel()
    else
        PSM.UI:UpdatePanelWithSnapshot()
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

--------------------------------------------------------------------------------
-- DATA MANAGEMENT
--------------------------------------------------------------------------------
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

    PetStableManagementDB.snapshotData = {}

    local savedCount = 0
    for _, pet in ipairs(PSM.state.stablePetsSnapshot) do
        local petCopy = DeepCopyPet(pet)
        if petCopy then
            table.insert(PetStableManagementDB.snapshotData, petCopy)
            savedCount = savedCount + 1
        end
    end

    PetStableManagementDB.settings = {
        sortByDisplayID = PSM.state.sortByDisplayID or false,
        sortBySlot = PSM.state.sortBySlot or false,
        exoticFilter = PSM.state.exoticFilter or false,
        duplicatesOnlyFilter = PSM.state.duplicatesOnlyFilter or false,
        minimapButton = PetStableManagementDB.settings.minimapButton or {
            hide = false,
            minimapPos = 220,
            lock = false
        }
    }


    collectgarbage("collect")
end

function PSM.Data:LoadPersistentDataForDisplay()
    if not PetStableManagementDB or not PetStableManagementDB.snapshotData then
        return false
    end
    
    if type(PetStableManagementDB.snapshotData) ~= "table" or #PetStableManagementDB.snapshotData == 0 then
        return false
    end
    
    PSM.state.stablePets = {}
    PSM.state.specList = {}
    PSM.state.familyList = {}
    
    for _, pet in ipairs(PetStableManagementDB.snapshotData) do
        if type(pet) == "table" and pet.name and pet.icon then
            table.insert(PSM.state.stablePets, DeepCopyPet(pet))
        end
    end
    
    self:RebuildSpecAndFamilyLists()
    
    if PetStableManagementDB.settings then
        PSM.state.sortByDisplayID = PetStableManagementDB.settings.sortByDisplayID or false
        PSM.state.sortBySlot = PetStableManagementDB.settings.sortBySlot or false
        PSM.state.exoticFilter = PetStableManagementDB.settings.exoticFilter or false
        PSM.state.duplicatesOnlyFilter = PetStableManagementDB.settings.duplicatesOnlyFilter or false
    end
    
   
    return true
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
    if #PSM.state.stablePets == 0 then
        print("|cFFFF8800WARNING: No pets to snapshot!|r")
        return
    end
    
    PSM.state.stablePetsSnapshot = {}
    
    local snapshotCount = 0
    for _, pet in ipairs(PSM.state.stablePets) do
        if pet and type(pet) == "table" and pet.name then
            table.insert(PSM.state.stablePetsSnapshot, DeepCopyPet(pet))
            snapshotCount = snapshotCount + 1
        end
    end
    
    self:SavePersistentData()
    
    print("|cFF00FF00PetStableManagement: Collected data for " .. snapshotCount .. " pets and saved to database.|r")
    
    self:ClearMemory()
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
    
    PSM.state.stablePets = {}
    
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
            
            processedPet._originalData = petData
            
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
    local abilities = {}
    local abilitySet = {}
    local abilityFields = {"petAbilities", "specAbilities", "abilities"}
    
    for _, fieldName in ipairs(abilityFields) do
        local fieldData = petInfo[fieldName]
        if fieldData and type(fieldData) == "table" then
            for _, ability in ipairs(fieldData) do
                local abilityName = self:GetAbilityName(ability)
                if abilityName and not abilitySet[abilityName] then
                    table.insert(abilities, abilityName)
                    abilitySet[abilityName] = true
                end
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

function PSM.Data:ClearMemory()
    for i = #PSM.state.stablePets, 1, -1 do
        PSM.state.stablePets[i] = nil
    end
    for i = #PSM.state.stablePetsSnapshot, 1, -1 do
        PSM.state.stablePetsSnapshot[i] = nil
    end
    for i = #PSM.state.specList, 1, -1 do
        PSM.state.specList[i] = nil
    end
    for i = #PSM.state.familyList, 1, -1 do
        PSM.state.familyList[i] = nil
    end
    
    PSM.state.stablePets = {}
    PSM.state.stablePetsSnapshot = {}
    PSM.state.specList = {}
    PSM.state.familyList = {}
    PSM.state.selectedSpecs = {}
    PSM.state.selectedFamilies = {}
    
    collectgarbage("collect")
end

--------------------------------------------------------------------------------
-- UI - ROW MANAGEMENT
--------------------------------------------------------------------------------
PSM.UI = {}
PSM.UI.Row = {}

-- Rotation update frame for performance
local RotationFrame = CreateFrame("Frame")
RotationFrame.activeModels = {}
RotationFrame:SetScript("OnUpdate", function(self, elapsed)
    for model in pairs(self.activeModels) do
        if model.isRotating and model.lastX then
            local x = GetCursorPosition()
            local diff = (x - model.lastX) * 0.01
            model.rotation = model.rotation + diff
            model:SetRotation(model.rotation)
            model.lastX = x
        end
    end
end)

function PSM.UI.Row:EnsureRow(i)
    if not i or i < 1 then return nil end
    if PSM.state.rows[i] then return PSM.state.rows[i] end
    
    if not PSM.state.content then
        print(PSM.Config.MESSAGES.PANEL_SHOW_FAILED)
        return nil
    end
    
    local row = CreateFrame("Frame", nil, PSM.state.content)
    row:SetSize(PSM.Config.PANEL_WIDTH, PSM.Config.ROW_HEIGHT)
    
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(unpack(PSM.Config.COLORS.BACKGROUND))
    
    row.model = CreateFrame("PlayerModel", nil, row)
    row.model:SetSize(PSM.Config.MODEL_SIZE, PSM.Config.MODEL_SIZE)
    row.model:SetPoint("LEFT", row, "LEFT", 2, 0)
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
        RotationFrame.activeModels[row.model] = nil
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
            RotationFrame.activeModels[self] = true
        end
    end)
    
    row.model:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.isRotating = false
            RotationFrame.activeModels[self] = nil
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
    
    -- Icon fallback
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(PSM.Config.ICON_SIZE, PSM.Config.ICON_SIZE)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.icon:Hide()
    
    -- Pet info text
    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetFont("Fonts\\FRIZQT__.TTF", PSM.Config.FONT_SIZES.PET_TEXT)
    row.text:SetPoint("LEFT", row.model, "RIGHT", 6, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("MIDDLE")
    row.text:SetWidth(PSM.Config.TEXT_WIDTH)
    
    -- Abilities header
    row.abilitiesHeader = row:CreateFontString(nil, "OVERLAY")
    row.abilitiesHeader:SetFont("Fonts\\FRIZQT__.TTF", PSM.Config.FONT_SIZES.ABILITIES_HEADER)
    row.abilitiesHeader:SetPoint("TOPLEFT", row.text, "TOPRIGHT", 10, 0)
    row.abilitiesHeader:SetText("|cFFFFD700Abilities:|r")
    row.abilitiesHeader:SetJustifyH("LEFT")
    row.abilitiesHeader:SetWidth(PSM.Config.ABILITIES_WIDTH)
    row.abilitiesHeader:Hide()
    
    -- Abilities list
    row.abilitiesList = row:CreateFontString(nil, "OVERLAY")
    row.abilitiesList:SetFont("Fonts\\FRIZQT__.TTF", PSM.Config.FONT_SIZES.ABILITIES_TEXT)
    row.abilitiesList:SetPoint("TOPLEFT", row.abilitiesHeader, "BOTTOMLEFT", 0, -2)
    row.abilitiesList:SetWidth(PSM.Config.ABILITIES_WIDTH)
    row.abilitiesList:SetJustifyH("LEFT")
    row.abilitiesList:SetJustifyV("TOP")
    row.abilitiesList:Hide()
    
    -- Buttons
    row.makeActive = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.makeActive:SetSize(PSM.Config.BUTTON_WIDTH, PSM.Config.BUTTON_HEIGHT)
    row.makeActive:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -5)
    row.makeActive:SetText("Make Active")
    row.makeActive:Hide()
    
    row.companion = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.companion:SetSize(PSM.Config.BUTTON_WIDTH, PSM.Config.BUTTON_HEIGHT)
    row.companion:SetPoint("TOPRIGHT", row.makeActive, "BOTTOMRIGHT", 0, -3)
    row.companion:SetText("Companion")
    row.companion:Hide()
    
    row.stable = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.stable:SetSize(PSM.Config.BUTTON_WIDTH, PSM.Config.BUTTON_HEIGHT)
    row.stable:SetPoint("TOPRIGHT", row.companion, "BOTTOMRIGHT", 0, -3)
    row.stable:SetText("Stable")
    row.stable:Hide()
    
    row.release = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.release:SetSize(PSM.Config.BUTTON_WIDTH, PSM.Config.BUTTON_HEIGHT)
    row.release:SetPoint("TOPRIGHT", row.stable, "BOTTOMRIGHT", 0, -3)
    row.release:SetText("Release")
    row.release:Hide()
    
    PSM.state.rows[i] = row
    return row
end

function PSM.UI.Row:UpdateRow(row, pet, groups)
    if not row or not pet then return end
    
    -- Display model or icon
    if pet.displayID and pet.displayID > 0 then
        row.model:SetDisplayInfo(pet.displayID)
        row.model:Show()
        row.icon:Hide()
    else
        row.icon:SetTexture(pet.icon)
        row.icon:Show()
        row.model:Hide()
    end
    
    -- Update text
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
    if groups[key] and #groups[key] > 1 then
        row.text:SetTextColor(unpack(PSM.Config.COLORS.DUPLICATE))
        row.bg:SetColorTexture(unpack(PSM.Config.COLORS.BACKGROUND_DUPLICATE))
    else
        row.text:SetTextColor(1, 1, 1)
        row.bg:SetColorTexture(unpack(PSM.Config.COLORS.BACKGROUND))
    end
    
    -- Update abilities
    local abilities = type(pet.abilities) == "table" and pet.abilities or {}
    local abilitiesText = ""
    for _, ability in ipairs(abilities) do
        local abilityName = type(ability) == "table" and ability.name or tostring(ability)
        abilitiesText = abilitiesText .. "• " .. abilityName .. "\n"
    end
    
    row.abilitiesList:SetText(abilitiesText)
    
    if #abilities > 0 then
        row.abilitiesHeader:Show()
        row.abilitiesList:Show()
    else
        row.abilitiesHeader:Hide()
        row.abilitiesList:Hide()
    end
    
    -- Setup buttons
    PSM.UI:SetupRowButtons(row, pet)
    
    row:Show()
end

function PSM.UI.Row:HideRow(i)
    local row = PSM.state.rows[i]
    if not row then return end
    
    row:Hide()
    if row.model then 
        row.model:Hide()
        row.model.isRotating = false
        RotationFrame.activeModels[row.model] = nil
    end
    if row.icon then row.icon:Hide() end
    if row.text then row.text:SetText("") end
    if row.abilitiesHeader then row.abilitiesHeader:Hide() end
    if row.abilitiesList then 
        row.abilitiesList:Hide()
        row.abilitiesList:SetText("")
    end
    if row.makeActive then row.makeActive:Hide() end
    if row.companion then row.companion:Hide() end
    if row.stable then row.stable:Hide() end
    if row.release then row.release:Hide() end
end

--------------------------------------------------------------------------------
-- UI - BUTTON CONTROLS
--------------------------------------------------------------------------------

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
                    C_Timer.After(0.1, function()
                        C_StableInfo.SetPetSlot(pet.slotID, 1)
                        C_Timer.After(0.2, function() PSM.UI:UpdatePanel() end)
                    end)
                else
                    print(PSM.Config.MESSAGES.NO_AVAILABLE_SLOTS)
                end
            else
                C_StableInfo.SetPetSlot(pet.slotID, 1)
                C_Timer.After(0.2, function() PSM.UI:UpdatePanel() end)
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
            C_Timer.After(0.2, function() PSM.UI:UpdatePanel() end)
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
                C_Timer.After(0.2, function() PSM.UI:UpdatePanel() end)
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
                        C_Timer.After(0.05, function()
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
                                    table.insert(PSM.state.stablePetsSnapshot, DeepCopyPet(p))
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
                            C_Timer.After(0.05, function()
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
                                        table.insert(PSM.state.stablePetsSnapshot, DeepCopyPet(p))
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
    
    if PSM.state.isStableOpen then
        row.release:Show()
    else
        row.release:Hide()
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

--------------------------------------------------------------------------------
-- UI - PANEL CREATION
--------------------------------------------------------------------------------

function PSM.UI:BuildPanel()
    if PSM.state.panel then return end
    
    if not StableFrame then
        print(PSM.Config.MESSAGES.STABLE_FRAME_NOT_FOUND)
        return
    end
    
    local panel = CreateFrame("Frame", "PetStableManagementPanel", UIParent)
    panel:SetSize(PSM.Config.PANEL_WIDTH, PSM.Config.PANEL_HEIGHT)
    panel:SetPoint("TOPLEFT", StableFrame, "TOPRIGHT", 0, 0)
    panel:SetFrameStrata("MEDIUM")
    panel:SetFrameLevel(50)
    panel:SetToplevel(true)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- ESC key handling
    panel:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            if not PSM.state.isStableOpen then
                PSM.Data:ClearMemory()
            end
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    panel:EnableKeyboard(true)
    panel:SetPropagateKeyboardInput(true)
    
    -- Resizable
    panel:SetResizable(true)
    if panel.SetResizeBounds then
        local maxW = UIParent:GetWidth() or 1920
        local maxH = UIParent:GetHeight() or 1080
        panel:SetResizeBounds(300, 200, maxW - 16, maxH - 16)
    end
    
    -- Resize handle
    panel.resizeButton = CreateFrame("Button", nil, panel)
    panel.resizeButton:SetSize(16, 16)
    panel.resizeButton:SetPoint("BOTTOMRIGHT", -2, 2)
    panel.resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    panel.resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    panel.resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    panel.resizeButton:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            panel:StartSizing("BOTTOMRIGHT")
        end
    end)
    panel.resizeButton:SetScript("OnMouseUp", function()
        panel:StopMovingOrSizing()
    end)
    
    -- Background
    panel.border = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.border:SetAllPoints()
    panel.border:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 30, edgeSize = 5,
        insets = {left=4, right=4, top=4, bottom=4}
    })
    panel.border:SetBackdropColor(0, 0, 0, 0.7)
    panel.border:SetFrameLevel(panel:GetFrameLevel() - 1)
    
    -- Close button
    panel.closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    panel.closeButton:SetPoint("TOPRIGHT", -5, -5)
    panel.closeButton:SetSize(20, 20)
    panel.closeButton:SetFrameLevel(panel:GetFrameLevel() + 10)
    panel.closeButton:SetScript("OnClick", function()
        panel:Hide()
        if not PSM.state.isStableOpen then
            PSM.Data:ClearMemory()
        end
    end)
    
    -- Maximize button
    panel.isMaximized = false
    panel.maximizeButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.maximizeButton:SetPoint("TOPRIGHT", panel.closeButton, "TOPLEFT", -2, 0)
    panel.maximizeButton:SetSize(50, 20)
    panel.maximizeButton:SetText("Maximize")
    
    panel.maximizeButton:SetScript("OnClick", function()
        if panel.isMaximized then
            panel.isMaximized = false
            panel:ClearAllPoints()
            if panel._prevGeometry then
                local p = panel._prevGeometry.point
                panel:SetPoint(p[1], p[2], p[3], p[4], p[5])
                panel:SetSize(panel._prevGeometry.width, panel._prevGeometry.height)
            else
                panel:SetPoint("TOPLEFT", StableFrame, "TOPRIGHT", 0, 0)
            end
            panel.maximizeButton:SetText("Maximize")
        else
            panel.isMaximized = true
            panel._prevGeometry = {
                point = {panel:GetPoint(1)},
                width = panel:GetWidth(),
                height = panel:GetHeight()
            }
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 8, -8)
            panel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -8, 8)
            panel.maximizeButton:SetText("Restore")
        end
        C_Timer.After(0.01, function() PSM.UI:RenderPanel() end)
    end)
    
    -- Title
    panel.title = panel:CreateFontString(nil, "OVERLAY")
    panel.title:SetFont("Fonts\\FRIZQT__.TTF", PSM.Config.FONT_SIZES.TITLE, "OUTLINE")
    panel.title:SetPoint("TOP", 0, -25)
    panel.title:SetText("Pet Stable Management")
    panel.title:SetTextColor(1, 0.82, 0)
    
    -- Search box
    panel.searchBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    panel.searchBox:SetSize(130, 22)
    panel.searchBox:SetPoint("TOP", panel.title, "BOTTOM", 0, -15)
    panel.searchBox:SetAutoFocus(false)
    panel.searchBox:SetText("")
    
    local debouncedSearch = PSM.Utils:Debounce(function()
        PSM.UI:UpdatePanel()
    end, PSM.Config.SEARCH_DELAY)
    
    panel.searchBox:SetScript("OnTextChanged", function()
        debouncedSearch()
    end)
    
    local searchLabel = panel:CreateFontString(nil, "OVERLAY")
    searchLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
    searchLabel:SetPoint("BOTTOM", panel.searchBox, "TOP", 0, 1)
    searchLabel:SetText("Search:")
    
    -- Filters
    PSM.UI:BuildFilters(panel)
    
    -- Sort buttons
    PSM.UI:BuildSortButtons(panel)
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -145)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 35)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(scrollFrame:GetWidth() - 10, 500)
    scrollFrame:SetScrollChild(content)
    
    -- Stats text
    panel.statsText = panel:CreateFontString(nil, "OVERLAY")
    panel.statsText:SetFont("Fonts\\FRIZQT__.TTF", PSM.Config.FONT_SIZES.STATS, "OUTLINE")
    panel.statsText:SetPoint("BOTTOM", 0, 10)
    panel.statsText:SetText("Showing: 0 pets  |  Duplicates: 0 pets (0 groups)")
    panel.statsText:SetTextColor(1, 0.82, 0)
    
    -- Resize handler
    panel:SetScript("OnSizeChanged", function(self, width, height)
        if not scrollFrame or not content then return end
        
        scrollFrame:SetWidth(width - 20)
        content:SetWidth(scrollFrame:GetWidth() - 10)
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT")
        content:SetPoint("TOPRIGHT")
        
        C_Timer.After(0.05, function() PSM.UI:RenderPanel() end)
    end)
    
    -- Register for ESC key
    table.insert(UISpecialFrames, "PetStableManagementPanel")
    
    PSM.state.panel = panel
    PSM.state.scrollFrame = scrollFrame
    PSM.state.content = content
    
    -- Start hidden by default
    panel:Hide()
end

--------------------------------------------------------------------------------
-- UI - FILTERS
--------------------------------------------------------------------------------

function PSM.UI:BuildFilters(panel)
    -- Exotic filter
    panel.exoticCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    panel.exoticCheck:SetPoint("TOPLEFT", 12, -80)
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
    panel.duplicatesCheck:SetPoint("TOPLEFT", panel.exoticCheck, "TOPRIGHT", 120, 0)
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
    panel.specDrop:SetPoint("TOPLEFT", panel.exoticCheck, "BOTTOMLEFT", -15, -5)
    UIDropDownMenu_SetWidth(panel.specDrop, 100)
    
    UIDropDownMenu_Initialize(panel.specDrop, function()
        local info = UIDropDownMenu_CreateInfo()
        info.text = "  All Specs"
        info.value = "ALL"
        info.checked = (not next(PSM.state.selectedSpecs))
        info.func = function()
            PSM.Utils:ClearTable(PSM.state.selectedSpecs)
            UIDropDownMenu_SetText(panel.specDrop, "All Specs")
            C_Timer.After(0.1, function() PSM.UI:UpdatePanel() end)
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
                C_Timer.After(0.1, function() PSM.UI:UpdatePanel() end)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(panel.specDrop, "All Specs")
    
    -- Family dropdown
    panel.familyDrop = CreateFrame("Frame", "PetDupFamilyDrop", panel, "UIDropDownMenuTemplate")
    panel.familyDrop:SetPoint("TOPLEFT", panel.duplicatesCheck, "BOTTOMLEFT", -15, -5)
    UIDropDownMenu_SetWidth(panel.familyDrop, 100)
    
    UIDropDownMenu_Initialize(panel.familyDrop, function()
        local info = UIDropDownMenu_CreateInfo()
        info.text = "  All Families"
        info.value = "ALL"
        info.checked = (not next(PSM.state.selectedFamilies))
        info.func = function()
            PSM.Utils:ClearTable(PSM.state.selectedFamilies)
            UIDropDownMenu_SetText(panel.familyDrop, "All Families")
            C_Timer.After(0.1, function() PSM.UI:UpdatePanel() end)
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
                C_Timer.After(0.1, function() PSM.UI:UpdatePanel() end)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(panel.familyDrop, "All Families")
end

function PSM.UI:BuildSortButtons(panel)
    panel.sortSlotButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.sortSlotButton:SetSize(90, 22)
    panel.sortSlotButton:SetPoint("TOPRIGHT", -35, -95)
    panel.sortSlotButton:SetText("Sort by Slot")
    panel.sortSlotButton:SetScript("OnClick", function()
        PSM.state.sortBySlot = not PSM.state.sortBySlot
        if PSM.state.sortBySlot then
            PSM.state.sortByDisplayID = false
        end
        PSM.UI:UpdatePanel()
    end)
    
    panel.sortDisplayIDButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.sortDisplayIDButton:SetSize(90, 22)
    panel.sortDisplayIDButton:SetPoint("TOPRIGHT", panel.sortSlotButton, "BOTTOMRIGHT", 0, -5)
    panel.sortDisplayIDButton:SetText("Sort by Model")
    panel.sortDisplayIDButton:SetScript("OnClick", function()
        PSM.state.sortByDisplayID = not PSM.state.sortByDisplayID
        if PSM.state.sortByDisplayID then
            PSM.state.sortBySlot = false
        end 
        PSM.UI:UpdatePanel()
    end)
end

--------------------------------------------------------------------------------
-- UI - RENDERING
--------------------------------------------------------------------------------

function PSM.UI:RenderPanel()
    if not PSM.state.panel or not PSM.state.content then
        print(PSM.Config.MESSAGES.PANEL_SHOW_FAILED)
        return
    end
    
    local searchText = PSM.state.panel.searchBox:GetText() or ""
    local searchLower = PSM.Utils:NormalizeSearchText(searchText)
    
    -- Build duplicate groups
    local groups = {}
    for _, pet in ipairs(PSM.state.stablePets) do
        local key = tostring(pet.icon or 0) .. ":" .. tostring(pet.displayID or 0)
        groups[key] = groups[key] or {}
        table.insert(groups[key], pet)
    end
    
    -- Filter pets
    local filteredPets = {}
    local duplicateKeys = {}
    
    if PSM.state.duplicatesOnlyFilter then
        for key, group in pairs(groups) do
            if #group > 1 then
                duplicateKeys[key] = true
            end
        end
    end
    
    for _, pet in ipairs(PSM.state.stablePets) do
        local skip = false
        
        if PSM.state.exoticFilter and not pet.isExotic then skip = true end
        if not skip and next(PSM.state.selectedSpecs) and not PSM.state.selectedSpecs[pet.specName] then skip = true end
        if not skip and next(PSM.state.selectedFamilies) and not PSM.state.selectedFamilies[pet.familyName] then skip = true end
        
        if not skip and PSM.state.duplicatesOnlyFilter then
            local key = tostring(pet.icon or 0) .. ":" .. tostring(pet.displayID or 0)
            if not duplicateKeys[key] then skip = true end
        end
        
        if not skip and searchLower ~= "" then
            local match = false
            local fields = {pet.name, pet.familyName, pet.specName, tostring(pet.displayID or "")}
            for _, field in ipairs(fields) do
                if field and tostring(field):lower():find(searchLower, 1, true) then
                    match = true
                    break
                end
            end
            
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
            table.insert(filteredPets, pet)
        end
    end
    
    -- Sort pets
    if PSM.state.sortByDisplayID then
        table.sort(filteredPets, function(a, b)
            return (a.displayID or 0) < (b.displayID or 0)
        end)
    elseif PSM.state.sortBySlot then
        table.sort(filteredPets, function(a, b)
            return (a.slotID or 0) < (b.slotID or 0)
        end)
    end
    
    -- Update stats
    local duplicatePets, duplicateGroups = 0, 0
    for _, group in pairs(groups) do
        if #group > 1 then
            duplicateGroups = duplicateGroups + 1
            duplicatePets = duplicatePets + #group
        end
    end
    
    PSM.state.panel.statsText:SetText(string.format(
        "Showing: %d pets  |  Duplicates: %d pets (%d groups)",
        #filteredPets, duplicatePets, duplicateGroups
    ))
    
    -- Calculate layout
    local contentWidth = PSM.state.content:GetWidth() or 470
    local desiredColWidth = 400
    local colCount = math.max(1, math.floor((contentWidth + 8) / (desiredColWidth + 8)))
    local colWidth = math.floor((contentWidth - 8 * (colCount - 1)) / colCount)
    colWidth = math.max(colWidth, 220)
    local rowTotal = math.ceil(#filteredPets / colCount)
    
    -- Render rows
    for i, pet in ipairs(filteredPets) do
        local row = PSM.UI.Row:EnsureRow(i)
        if row then
            local rowIdx = ((i - 1) % rowTotal)
            local col = math.floor((i - 1) / rowTotal)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", PSM.state.content, "TOPLEFT",
                4 + col * (colWidth + 8),
                -(rowIdx) * PSM.Config.ROW_HEIGHT)
            row:SetWidth(colWidth)
            
            if row.text then row.text:SetWidth(math.min(180, colWidth - 320)) end
            if row.abilitiesHeader then row.abilitiesHeader:SetWidth(math.min(180, colWidth - 250)) end
            if row.abilitiesList then row.abilitiesList:SetWidth(math.min(180, colWidth - 250)) end
            
            PSM.UI.Row:UpdateRow(row, pet, groups)
        end
    end
    
    -- Hide unused rows
    for i = #filteredPets + 1, #PSM.state.rows do
        PSM.UI.Row:HideRow(i)
    end
    
    -- Resize content
    PSM.state.content:SetHeight(math.max(rowTotal * PSM.Config.ROW_HEIGHT + 10, 100))
end

function PSM.UI:UpdatePanel()
    if not PSM.state.panel then
        self:BuildPanel()
    end

    -- Collect data if stable is open
    if PSM.state.isStableOpen then
        PSM.Data:CollectStablePets()
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

--------------------------------------------------------------------------------
-- EVENT HANDLING
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PET_STABLE_SHOW")
eventFrame:RegisterEvent("PET_STABLE_UPDATE")
eventFrame:RegisterEvent("PET_STABLE_CLOSED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    PSM.Utils.SafeCall(function()
        if event == "ADDON_LOADED" and arg1 == addonName then
            -- Initialize minimap button settings if not present
            if not PetStableManagementDB.settings.minimapButton then
                PetStableManagementDB.settings.minimapButton = {
                    hide = false,
                    minimapPos = 220,
                    lock = false
                }
            end
            
            -- Create minimap button
            PSM.Minimap:CreateButton()
            
            -- Single welcome message
            print(PSM.Config.MESSAGES.ADDON_LOADED)
            
        elseif event == "PET_STABLE_SHOW" then
            PSM.state.isStableOpen = true
            
            C_Timer.After(PSM.Config.SNAPSHOT_DELAY, function()
                -- Collect fresh data
                PSM.Data:CollectStablePets()
                
                if #PSM.state.stablePets > 0 then
                    -- Build panel if it doesn't exist
                    if not PSM.state.panel then
                        PSM.UI:BuildPanel()
                    end
                    
                    -- Update and show panel
                    if PSM.state.panel then
                        PSM.UI:UpdatePanel()
                        PSM.state.panel:Show()
                        PSM.state.panel:Raise()
                    end
                end
                
                -- Hook release button
                if StableFrame and StableFrame.ReleasePetButton and not StableFrame.ReleasePetButton.psm_hooked then
                    StableFrame.ReleasePetButton.psm_hooked = true
                    hooksecurefunc(StableFrame.ReleasePetButton, "Click", function()
                        C_Timer.After(0.1, function()
                            if PSM.UI and PSM.UI.UpdatePanel then
                                PSM.UI:UpdatePanel()
                            end
                        end)
                    end)
                end
            end)
            
        elseif event == "PET_STABLE_UPDATE" then
            if PSM.state.panel and PSM.state.panel:IsVisible() and PSM.state.isStableOpen then
                C_Timer.After(PSM.Config.UPDATE_DELAY, function()
                    -- Re-collect data before updating
                    PSM.Data:CollectStablePets()
                    PSM.UI:UpdatePanel()
                end)
            end
            
        elseif event == "PET_STABLE_CLOSED" then
            PSM.state.isStableOpen = false

            -- Save snapshot before closing
            if #PSM.state.stablePets > 0 then
                PSM.Data:CreateSnapshot()
            end

            if PSM.state.panel and PSM.state.panel:IsVisible() then
                C_Timer.After(PSM.Config.UPDATE_DELAY, function()
                    PSM.UI:UpdatePanelWithSnapshot()
                end)
            else
                PSM.Data:ClearMemory()
            end
            
        elseif event == "PLAYER_LOGOUT" then
            if #PSM.state.stablePets > 0 then
                PSM.Data:SavePersistentData()
            end
            PSM.Data:ClearMemory()
        end
    end)
end)

--------------------------------------------------------------------------------
-- SLASH COMMANDS
--------------------------------------------------------------------------------

SLASH_PETSTABLEMANAGEMENT1 = "/psm"
SlashCmdList["PETSTABLEMANAGEMENT"] = function(msg)
    local command = msg:lower():trim()
    
    if command == "show" then
        PSM.Minimap:Show()
        print("|cFF00FF00Pet Stable Management: Minimap button shown.|r")
    elseif command == "hide" then
        PSM.Minimap:Hide()
        print("|cFFFFAA00Pet Stable Management: Minimap button hidden. Use /psm show to show it again.|r")
    else
        PSM.Minimap:TogglePanel()
    end
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

-- Initialization message is handled in ADDON_LOADED event
