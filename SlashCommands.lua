-- SlashCommands.lua
-- Slash commands for PetStableManagement

local addonName = "PetStableManagement"

-- Initialize global namespace
_G.PSM = _G.PSM or {}
local PSM = _G.PSM

SLASH_PETSTABLEMANAGEMENT1 = "/psm"
SLASH_PETSWAP1 = "/petswap"

SlashCmdList["PETSTABLEMANAGEMENT"] = function(msg)
    local command = msg:lower():trim()

    if command == "show" then
        PSM.Minimap:Show()
        print("|cFF00FF00Pet Stable Management: Minimap button shown.|r")
    elseif command == "hide" then
        PSM.Minimap:Hide()
        print("|cFFFFAA00Pet Stable Management: Minimap button hidden. Use /psm show to show it again.|r")
    elseif command == "models" then
        PSM.ModelsPanel:Toggle()
    else
        PSM.Minimap:TogglePanel()
    end
end

SlashCmdList["PETSWAP"] = function(msg)
    local args = {}
    for arg in msg:gmatch("%S+") do
        table.insert(args, arg)
    end

    if #args < 2 then
        print("|cFFFF0000Usage: /petswap [starting slot] [destination slot]|r")
        print("|cFFFFAA00Example: /petswap 5 10|r")
        return
    end

    local startSlot = tonumber(args[1])
    local destSlot = tonumber(args[2])

    if not startSlot or not destSlot then
        print("|cFFFF0000Invalid slot numbers. Both must be numbers between 1 and 205.|r")
        return
    end

    if startSlot < 1 or startSlot > 205 or destSlot < 1 or destSlot > 205 then
        print("|cFFFF0000Slot numbers must be between 1 and 205.|r")
        return
    end

    if startSlot == destSlot then
        print("|cFFFFAA00Source and destination slots are the same.|r")
        return
    end

    if not PSM.state.isStableOpen then
        print("|cFFFF0000You must be at a stable master to change pet slots.|r")
        return
    end

    -- Check if source slot has a pet
    local sourcePet = C_StableInfo.GetStablePetInfo(startSlot)
    if not sourcePet then
        print(string.format("|cFFFF0000No pet found in slot %d.|r", startSlot))
        return
    end

    -- Perform the slot change
    if PSM.Reorder:SwapPetSlots(startSlot, destSlot) then
        -- Success message is handled in SwapPetSlots
    else
        print("|cFFFF0000Failed to move pet.|r")
    end
end