-- Reorder.lua
-- Pet reordering logic for PetStableManagement

local addonName = "PetStableManagement"

-- Initialize global namespace
_G.PSM = _G.PSM or {}
local PSM = _G.PSM

PSM.Reorder = PSM.Reorder or {}

function PSM.Reorder:CanReorderPets()
    return PSM.state.isStableOpen
end

function PSM.Reorder:SwapPetSlots(slot1, slot2)
    if not PSM.Reorder:CanReorderPets() then
        print("|cFFFF0000Must be at stable master to reorder pets|r")
        return false
    end

    if not C_StableInfo or not C_StableInfo.SetPetSlot then
        print("|cFFFF0000SetPetSlot API not available|r")
        return false
    end

    -- Validate slots
    if not slot1 or not slot2 or slot1 == slot2 then
        print("|cFFFF0000Invalid slot numbers|r")
        return false
    end

    if slot1 < 1 or slot1 > 205 or slot2 < 1 or slot2 > 205 then
        print("|cFFFF0000Slots must be between 1 and 205|r")
        return false
    end

    -- Get pet info
    local pet1 = C_StableInfo.GetStablePetInfo(slot1)
    local pet2 = C_StableInfo.GetStablePetInfo(slot2)

    if not pet1 then
        print("|cFFFF0000No pet in slot " .. slot1 .. "|r")
        return false
    end

    -- If slot2 is empty, just move pet1 there
    if not pet2 then
        print("|cFFFFAA00Swapping pets from slot " .. slot1 .. " to slot " .. slot2 .. "...|r")
        PSM.Utils.SafeCall(C_StableInfo.SetPetSlot, slot1, slot2)
        PSM.C_Timer.After(0.3, function()
            PSM.UI:UpdatePanel()
        end)
        return true
    end

    -- Both slots occupied - swap them directly
    print("|cFFFFAA00Swapping pets from slot " .. slot1 .. " to slot " .. slot2 .. "...|r")

    -- Move pet1 to slot2, which automatically swaps them
    PSM.Utils.SafeCall(C_StableInfo.SetPetSlot, slot1, slot2)
    PSM.C_Timer.After(0.3, function()
        PSM.UI:UpdatePanel()
    end)

    return true
end

function PSM.Reorder:MovePetUp(pet)
    if not pet or not pet.slotID then return false end

    local currentSlot = pet.slotID

    -- Can't move up from slot 1
    if currentSlot <= 1 then
        print("|cFFFFAA00Pet is already in slot 1 (top position)|r")
        return false
    end

    -- Move up by exactly 1 slot
    local targetSlot = currentSlot - 1

    -- Check if target slot is empty
    local targetPetInfo = C_StableInfo.GetStablePetInfo(targetSlot)

    if not targetPetInfo then
        -- Target slot is empty, just move there
        return self:SwapPetSlots(currentSlot, targetSlot)
    else
        -- Target slot is occupied, swap with it
        return self:SwapPetSlots(currentSlot, targetSlot)
    end
end

function PSM.Reorder:MovePetDown(pet)
    if not pet or not pet.slotID then return false end

    local currentSlot = pet.slotID

    -- Can't move down from slot 205
    if currentSlot >= 205 then
        print("|cFFFFAA00Pet is already in slot 205 (bottom position)|r")
        return false
    end

    -- Move down by exactly 1 slot
    local targetSlot = currentSlot + 1

    -- Check if target slot is empty
    local targetPetInfo = C_StableInfo.GetStablePetInfo(targetSlot)

    if not targetPetInfo then
        -- Target slot is empty, just move there
        return self:SwapPetSlots(currentSlot, targetSlot)
    else
        -- Target slot is occupied, swap with it
        return self:SwapPetSlots(currentSlot, targetSlot)
    end
end
