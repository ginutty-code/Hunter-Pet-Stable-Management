-- Config.lua
-- Configuration constants for PetStableManagement

local addonName = "PetStableManagement"

-- Initialize global namespace
_G.PSM = _G.PSM or {}
local PSM = _G.PSM

PSM.Config = {
    -- UI Dimensions
    ROW_HEIGHT = 120,
    PANEL_WIDTH = 550,
    PANEL_HEIGHT = 640,
    BUTTON_WIDTH = 100,
    BUTTON_HEIGHT = 22,
    MODEL_SIZE = 100,
    ICON_SIZE = 60,
    TEXT_WIDTH = 200,
    ABILITIES_WIDTH = 200,

    -- Font Sizes
    FONT_SIZES = {
        TITLE = 12,
        STATS = 11,
        PET_TEXT = 10,
        ABILITIES_HEADER = 10,
        ABILITIES_TEXT = 10,
    },

    -- Layout
    CONTENT_PADDING = 10,
    SCROLL_BAR_WIDTH = 20,
    COLUMN_SPACING = 8,
    RESIZE_HANDLE_SIZE = 16,

    -- Timing
    UPDATE_DELAY = 0.3,
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