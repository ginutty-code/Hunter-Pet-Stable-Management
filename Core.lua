-- Core.lua
-- Core initialization and global setup for PetStableManagement

local addonName = "PetStableManagement"

-- Initialize global namespace
_G.PSM = _G.PSM or {}
local PSM = _G.PSM

-- Initialize persistent data storage
PetStableManagementDB = PetStableManagementDB or {
    version = "3.0.0",
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
    exportFrame = nil,
}