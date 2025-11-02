-- Utils.lua
-- Utility functions for PetStableManagement

local addonName = "PetStableManagement"

-- Initialize global namespace
_G.PSM = _G.PSM or {}
local PSM = _G.PSM

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