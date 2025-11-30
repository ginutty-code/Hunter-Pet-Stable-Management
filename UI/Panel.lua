-- UI/Panel.lua
-- Main panel creation for PetStableManagement

local addonName = "PetStableManagement"

-- Initialize global namespace
_G.PSM = _G.PSM or {}
local PSM = _G.PSM

function PSM.UI:BuildPanel()
    if PSM.state.panel then return end

    if not StableFrame then
        print(PSM.Config.MESSAGES.STABLE_FRAME_NOT_FOUND)
        return
    end

    local panel = CreateFrame("Frame", "PetStableManagementPanel", UIParent)
    panel:SetSize(PSM.Config.PANEL_WIDTH, PSM.Config.PANEL_HEIGHT)
    panel:SetPoint("TOPLEFT", StableFrame, "TOPRIGHT", 0, 0)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel(50)
    panel:SetToplevel(true)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Apply ElvUI skinning if available
    PSM.UI:ApplyElvUISkin(panel, "frame")

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
        local minWidth = 415
        local minHeight = 280
        panel:SetResizeBounds(minWidth, minHeight, maxW - 16, maxH - 16)
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

    -- Background and border
    panel.border = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.border:SetAllPoints()
    panel.border:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 30, edgeSize = 5,
        insets = {left=4, right=4, top=4, bottom=4}
    })
    panel.border:SetBackdropColor(0, 0, 0, 0.8)
    panel.border:SetFrameLevel(panel:GetFrameLevel() - 1)

-- Close button
    panel.closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    panel.closeButton:SetPoint("TOPRIGHT", -5, -5)
    panel.closeButton:SetSize(20, 20)
    panel.closeButton:SetFrameLevel(panel:GetFrameLevel() + 10)
    panel.closeButton:SetScript("OnClick", function()
        panel:Hide()
    end)
    PSM.UI:ApplyElvUISkin(panel.closeButton, "closebutton")

    -- Panel cleanup on hide
    panel:SetScript("OnHide", function(self)
        if not PSM.state.isStableOpen then
            -- Save filter settings for persistence when not at stable
            PSM.Data:SaveSettings()
            PSM.Data:ClearMemory()
            PSM.Data:ClearUIRows()
        end
    end)
    
    -- Panel shown - recalculate layout
    panel:SetScript("OnShow", function(self)
        PSM.C_Timer.After(0.01, function()
            if PSM.UI.RenderPanel then
                PSM.UI:RenderPanel()
            end
            -- Update filter UI to match current state
            PSM.C_Timer.After(0.05, function()
                PSM.UI:UpdateFilterUI()
            end)
        end)
    end)
    
    -- Maximize button
    panel.isMaximized = false
    panel.maximizeButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.maximizeButton:SetPoint("TOPRIGHT", panel.closeButton, "TOPLEFT", -2, 0)
    panel.maximizeButton:SetSize(70, 25)
    panel.maximizeButton:SetText("Maximize")
    panel.maximizeButton:SetNormalFontObject("GameFontNormalSmall")
    PSM.UI:ApplyElvUISkin(panel.maximizeButton, "button")

    -- Export button
    panel.exportButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.exportButton:SetPoint("TOPLEFT", 10, -5)
    panel.exportButton:SetSize(50, 25)
    panel.exportButton:SetText("Export")
    panel.exportButton:SetNormalFontObject("GameFontNormalSmall")
    panel.exportButton:SetScript("OnClick", function()
        PSM.Export:ShowExportDialog()
    end)
    PSM.UI:ApplyElvUISkin(panel.exportButton, "button")

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
        PSM.C_Timer.After(0.01, function() PSM.UI:RenderPanel() end)
    end)

-- Pet Models button
panel.modelsButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
panel.modelsButton:SetPoint("TOPLEFT", panel.exportButton, "TOPRIGHT", 5, 0)
panel.modelsButton:SetSize(70, 25)
panel.modelsButton:SetText("Pet Models")
panel.modelsButton:SetNormalFontObject("GameFontNormalSmall")
panel.modelsButton:SetScript("OnClick", function()
    PSM.ModelsPanel:Toggle()
end)
PSM.UI:ApplyElvUISkin(panel.modelsButton, "button")


    -- Title
    panel.title = panel:CreateFontString(nil, "OVERLAY")
    panel.title:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    panel.title:SetPoint("TOP", 0, -35)
    panel.title:SetText("Pet Stable Management")
    panel.title:SetTextColor(1, 0.82, 0)

    -- Search box
    panel.searchBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    panel.searchBox:SetSize(150, 22)
    panel.searchBox:SetPoint("TOP", panel.title, "BOTTOM", 0, -10)
    panel.searchBox:SetAutoFocus(false)
    panel.searchBox:SetText("")
    PSM.UI:ApplyElvUISkin(panel.searchBox, "editbox")

    local debouncedSearch = PSM.Utils:Debounce(function()
        PSM.UI:UpdatePanel()
    end, PSM.Config.SEARCH_DELAY)

    panel.searchBox:SetScript("OnTextChanged", function()
        debouncedSearch()
    end)


    -- Filters
    PSM.UI:BuildFilters(panel)

    -- Sort buttons
    PSM.UI:BuildSortButtons(panel)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -145)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 35)

    -- Frame around the rows area
    local rowsFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    rowsFrame:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -5, 5)
    rowsFrame:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 5, -5)
    rowsFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left=4, right=4, top=4, bottom=4}
    })
    rowsFrame:SetBackdropColor(0, 0, 0, 0.1)
    rowsFrame:SetFrameLevel(panel:GetFrameLevel() - 1)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(scrollFrame:GetWidth() - 10, 500)
    scrollFrame:SetScrollChild(content)

    -- Force scrollbar to always reserve space (even when hidden)
    if scrollFrame.ScrollBar then
        scrollFrame.ScrollBar:SetAlpha(1)
    end

    panel.scrollOffset = 0

    -- Add scroll handler for virtual scrolling
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        local newOffset = math.floor(offset / PSM.Config.ROW_HEIGHT)
        if newOffset ~= panel.scrollOffset then
            panel.scrollOffset = newOffset
            PSM.C_Timer.After(0.01, function()
                PSM.UI:UpdateVisibleRows()
            end)
        end
    end)

    -- Stats text
    panel.statsText = panel:CreateFontString(nil, "OVERLAY")
    panel.statsText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    panel.statsText:SetPoint("BOTTOM", 0, 10)
    panel.statsText:SetText("Showing: 0 pets  |  Duplicates: 0 pets (0 groups)")
    panel.statsText:SetTextColor(1, 0.82, 0)

-- Optimized resize handler
    panel:SetScript("OnSizeChanged", function(self, width, height)
        -- Only recalculate if size actually changed significantly
        local widthDiff = math.abs((PSM._lastLayoutWidth or 0) - width)
        local heightDiff = math.abs((PSM._lastLayoutHeight or 0) - height)

        if widthDiff < 10 and heightDiff < 10 then return end -- Ignore small changes

        PSM._lastLayoutWidth = width
        PSM._lastLayoutHeight = height

        if not scrollFrame or not content then return end

        scrollFrame:SetWidth(width - 40)

        -- Use the actual scrollFrame width - it already accounts for scrollbar
        content:SetWidth(scrollFrame:GetWidth())
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT")
        content:SetPoint("TOPRIGHT")

        -- Invalidate cache to force recalculation
        PSM._renderCache = nil

        PSM.C_Timer.After(0.05, function()
            if PSM.UI and PSM.UI.RenderPanel then
                PSM.UI:RenderPanel()
            end
        end)
    end)
    
    -- Force initial content width setup
    PSM.C_Timer.After(0.01, function()
        if scrollFrame and content then
            content:SetWidth(scrollFrame:GetWidth())
        end
    end)
    
    -- Register for ESC key
    table.insert(UISpecialFrames, "PetStableManagementPanel")

    PSM.state.panel = panel
    PSM.state.scrollFrame = scrollFrame
    PSM.state.content = content

    -- Start hidden by default
    panel:Hide()
end