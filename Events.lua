-- Events.lua
-- Event handling for PetStableManagement

local addonName = "PetStableManagement"

_G.PSM = _G.PSM or {}
local PSM = _G.PSM

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PET_STABLE_SHOW")
eventFrame:RegisterEvent("PET_STABLE_UPDATE")
eventFrame:RegisterEvent("PET_STABLE_CLOSED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

-- Debounce PET_STABLE_UPDATE to avoid multiple rapid updates
local updateTimer = nil
local function ScheduleUpdate()
    if updateTimer then
        updateTimer:Cancel()
    end
    updateTimer = PSM.C_Timer.NewTimer(PSM.Config.UPDATE_DELAY, function()
        if PSM.state.panel and PSM.state.panel:IsVisible() and PSM.state.isStableOpen then
            PSM.Data:CollectStablePets()
            PSM.UI:RenderPanel()
            PSM.UI:UpdatePanelTitle()
            PSM.UI:UpdateSortButtonTexts()
        end
        updateTimer = nil
    end)
end

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    PSM.Utils.SafeCall(function()
        if event == "ADDON_LOADED" and arg1 == addonName then
            -- Initialize minimap button settings
            if not PetStableManagementDB.settings.minimapButton then
                PetStableManagementDB.settings.minimapButton = {
                    hide = false,
                    minimapPos = 220,
                    lock = false
                }
            end

            -- Load settings (including favorites) when addon starts
            PSM.Data:LoadSettingsOnly()

            PSM.Minimap:CreateButton()
            print(PSM.Config.MESSAGES.ADDON_LOADED)

        elseif event == "PET_STABLE_SHOW" then
            PSM.state.isStableOpen = true

            -- Build panel immediately if it doesn't exist
            if not PSM.state.panel then
                PSM.UI:BuildPanel()
            end

            -- Single delayed data collection and render
            PSM.C_Timer.After(0.1, function()
                -- Collect fresh data once
                PSM.Data:CollectStablePets()
                
                if #PSM.state.stablePets > 0 and PSM.state.panel then
                    -- Single render pass
                    PSM.UI:RenderPanel()
                    PSM.UI:UpdatePanelTitle()
                    PSM.UI:UpdateSortButtonTexts()
                    
                    -- Show panel
                    PSM.state.panel:Show()
                    PSM.state.panel:Raise()
                end

                -- Hook release button once
                if StableFrame and StableFrame.ReleasePetButton and not StableFrame.ReleasePetButton.psm_hooked then
                    StableFrame.ReleasePetButton.psm_hooked = true
                    hooksecurefunc(StableFrame.ReleasePetButton, "Click", function()
                        ScheduleUpdate()
                    end)
                end
            end)

        elseif event == "PET_STABLE_UPDATE" then
            -- Use debounced update to avoid rapid successive updates
            if PSM.state.isStableOpen then
                ScheduleUpdate()
            end

        elseif event == "PET_STABLE_CLOSED" then
            PSM.state.isStableOpen = false

            -- Cancel any pending updates
            if updateTimer then
                updateTimer:Cancel()
                updateTimer = nil
            end

            -- Save snapshot before clearing
            if #PSM.state.stablePets > 0 then
                PSM.Data:CreateSnapshot()
            end

            -- If panel is visible, switch to snapshot mode
            if PSM.state.panel and PSM.state.panel:IsVisible() then
                PSM.C_Timer.After(0.05, function()
                    -- Load from saved data for display
                    PSM.Data:LoadPersistentDataForDisplay()
                    PSM.UI:RenderPanel()
                    PSM.UI:UpdatePanelTitle()
                    PSM.UI:UpdateSortButtonTexts()
                end)
            else
                -- Panel not visible, clear everything
                PSM.Data:ClearMemory()
                PSM.Data:ClearUIRows()
            end

        elseif event == "PLAYER_LOGOUT" then
            -- Cancel any pending updates
            if updateTimer then
                updateTimer:Cancel()
                updateTimer = nil
            end
            
            if #PSM.state.stablePets > 0 then
                PSM.Data:SavePersistentData()
            end
            PSM.Data:ClearMemory()
            PSM.Data:ClearUIRows()
        end
    end)
end)