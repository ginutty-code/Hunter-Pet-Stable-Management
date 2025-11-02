-- UI/Row.lua
-- Row management for PetStableManagement

local addonName = "PetStableManagement"

-- Initialize global namespace
_G.PSM = _G.PSM or {}
local PSM = _G.PSM

PSM.UI.Row = {}

-- Rotation update frame for performance
if not PSM.RotationFrame then
    PSM.RotationFrame = CreateFrame("Frame")
    PSM.RotationFrame.activeModels = {}
    PSM.RotationFrame:SetScript("OnUpdate", function(self, elapsed)
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
end
local RotationFrame = PSM.RotationFrame

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

    -- Separator line at the bottom
    row.separator = row:CreateTexture(nil, "BORDER")
    row.separator:SetHeight(1)
    row.separator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.separator:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.separator:SetColorTexture(0.3, 0.3, 0.3, 0.5)

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
    row.abilitiesHeader:SetPoint("TOPLEFT", row.text, "TOPRIGHT", 0, 20)
    row.abilitiesHeader:SetText("|cFFFFD700Abilities:|r")
    row.abilitiesHeader:SetJustifyH("LEFT")
    row.abilitiesHeader:SetJustifyV("MIDDLE")
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
    row.makeActive:SetText("Make Active")
    row.makeActive:SetNormalFontObject("GameFontNormalSmall")
    row.makeActive:Hide()
    PSM.UI:ApplyElvUISkin(row.makeActive, "button")

    row.companion = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.companion:SetSize(PSM.Config.BUTTON_WIDTH, PSM.Config.BUTTON_HEIGHT)
    row.companion:SetText("Companion")
    row.companion:SetNormalFontObject("GameFontNormalSmall")
    row.companion:Hide()
    PSM.UI:ApplyElvUISkin(row.companion, "button")

    row.stable = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.stable:SetSize(PSM.Config.BUTTON_WIDTH, PSM.Config.BUTTON_HEIGHT)
    row.stable:SetText("Stable")
    row.stable:SetNormalFontObject("GameFontNormalSmall")
    row.stable:Hide()
    PSM.UI:ApplyElvUISkin(row.stable, "button")

    row.release = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.release:SetSize(PSM.Config.BUTTON_WIDTH, PSM.Config.BUTTON_HEIGHT)
    row.release:SetText("Release")
    row.release:SetNormalFontObject("GameFontNormalSmall")
    row.release:Hide()
    PSM.UI:ApplyElvUISkin(row.release, "button")

    -- Move Up button (simple default UI style, no ElvUI skinning)
    row.moveUp = CreateFrame("Button", nil, row)
    row.moveUp:SetSize(24, 24)
    row.moveUp:SetPoint("LEFT", row.text, "LEFT", 0, 0)
    row.moveUp:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
    row.moveUp:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Highlight")
    row.moveUp:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down")
    row.moveUp:Hide()

    -- Move Down button (simple default UI style, no ElvUI skinning)
    row.moveDown = CreateFrame("Button", nil, row)
    row.moveDown:SetSize(24, 24)
    row.moveDown:SetPoint("LEFT", row.moveUp, "RIGHT", 2, 0)
    row.moveDown:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    row.moveDown:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight")
    row.moveDown:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
    row.moveDown:Hide()

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

    -- Update abilities with grouping
    local abilities = type(pet.abilities) == "table" and pet.abilities or {}
    local abilitiesText = ""
    local hasAbilities = false

    -- Check if we have grouped abilities
    if abilities.family or abilities.spec or abilities.pet or abilities.unknown then
        -- New grouped format

        -- Spec abilities (change with spec)
        if abilities.spec and #abilities.spec > 0 then
            abilitiesText = abilitiesText .. "|cFFFFD700[Spec]|r\n"
            for _, ability in ipairs(abilities.spec) do
                abilitiesText = abilitiesText .. "  • " .. ability .. "\n"
            end
            hasAbilities = true
        end

        -- Family abilities (persistent)
        if abilities.family and #abilities.family > 0 then
            abilitiesText = abilitiesText .. "|cFF40FF40[Family]|r\n"
            for _, ability in ipairs(abilities.family) do
                abilitiesText = abilitiesText .. "  • " .. ability .. "\n"
            end
            hasAbilities = true
        end

        -- Pet-specific abilities
        if abilities.pet and #abilities.pet > 0 then
            abilitiesText = abilitiesText .. "|cFF40FFFF[Pet]|r\n"
            for _, ability in ipairs(abilities.pet) do
                abilitiesText = abilitiesText .. "  • " .. ability .. "\n"
            end
            hasAbilities = true
        end

        -- Unknown abilities
        if abilities.unknown and #abilities.unknown > 0 then
            abilitiesText = abilitiesText .. "|cFFAAAAAA[Other]|r\n"
            for _, ability in ipairs(abilities.unknown) do
                abilitiesText = abilitiesText .. "  • " .. ability .. "\n"
            end
            hasAbilities = true
        end
    else
        -- Flat list - fallback
        for _, ability in ipairs(abilities) do
            local abilityName = type(ability) == "table" and ability.name or tostring(ability)
            abilitiesText = abilitiesText .. "• " .. abilityName .. "\n"
            hasAbilities = true
        end
    end

    row.abilitiesList:SetText(abilitiesText)

    if hasAbilities then
        row.abilitiesHeader:Show()
        row.abilitiesList:Show()
    else
        row.abilitiesHeader:Hide()
        row.abilitiesList:Hide()
    end

    -- Position move buttons above the slot text
    if row.moveUp then
        row.moveUp:ClearAllPoints()
        row.moveUp:SetPoint("TOPLEFT", row.text, "TOPLEFT", -5, 25)
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
    if row.moveUp then row.moveUp:Hide() end
    if row.moveDown then row.moveDown:Hide() end
    if row.separator then row.separator:Hide() end
end