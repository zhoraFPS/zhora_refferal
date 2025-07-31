ESX = nil
local nuiOpen = false
local myReferralCode = ""
local hasAlreadyReferred = false
local nuiReady = false
local clientConfigReady = false

-- Initialize NUI callbacks and commands
-- EXTENSION POINT: Add new commands or NUI callback handlers here
function InitializeNUIHandlersAndCommand()
    -- Register the /code command to open the referral interface
    -- EXTENSION POINT: Change command name or add additional commands here
    RegisterCommand('code', function(source, args, rawCommand)
        if not clientConfigReady then return end
        ToggleNUI()
    end, false)

    -- NUI callback for closing the interface
    -- EXTENSION POINT: Add cleanup logic when NUI closes
    RegisterNUICallback('closeNUI', function(data, cb)
        if nuiOpen then ToggleNUI() end
        cb({ status = 'ok' })
    end)

    -- NUI callback for submitting a referral code
    -- EXTENSION POINT: Add client-side validation or preprocessing here
    RegisterNUICallback('submitReferralCode', function(data, cb_nui)
        if not ESX then cb_nui({status = 'error', message = 'ESX not ready'}); return end
        -- Trigger server callback to validate and process the referral code
        ESX.TriggerServerCallback('freundeWerben:submitReferralCode', function(serverResponse)
            if serverResponse then
                if serverResponse.status == 'ok' then
                    -- Success message is already handled by NUI or server-side client notification
                    -- EXTENSION POINT: Add custom success handling here
                elseif serverResponse.status == 'error' and serverResponse.message then
                    ESX.ShowNotification(serverResponse.message)
                else
                    ESX.ShowNotification("An unknown error occurred.")
                end
            end
            cb_nui(serverResponse) -- Important: Send callback to NUI
        end, data)
    end)

    -- NUI callback when the interface is ready to receive data
    -- This ensures the NUI is fully loaded before sending data to it
    -- EXTENSION POINT: Add initial data setup or theme loading here
    RegisterNUICallback('nuiReady', function(data, cb)
        nuiReady = true
        -- Initially hide the NUI and disable focus
        SendNUIMessage({action = 'setVisible', visible = false})
        SetNuiFocus(false, false)
        nuiOpen = false
        -- Send initial data if we already have it
        if myReferralCode ~= "" then
             SendNUIMessage({action = 'updateInitialData', code = myReferralCode, hasReferred = hasAlreadyReferred})
        end
        cb({ status = 'ok' })
    end)
end

-- Initialization thread - waits for ESX and Config to be ready
-- EXTENSION POINT: Add dependencies on other resources here
Citizen.CreateThread(function()
    local esxWaitCount = 0
    -- Wait for ESX to be available
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(250)
        esxWaitCount = esxWaitCount + 1
        if esxWaitCount > 60 then -- Timeout after 15 seconds
            -- Optional: Output error message if ESX couldn't be loaded
            -- print("[FWF Client ERROR] ESX could not be loaded after 15 seconds.")
            return
        end
    end

    local configWaitCount = 0
    -- Wait for config to be loaded
    while not clientConfigReady do
        if _G.Config and _G.Config.CodePrefix then -- Check if config was loaded
            clientConfigReady = true
        else
            Citizen.Wait(250)
            configWaitCount = configWaitCount + 1
            if configWaitCount > 60 then -- Timeout after 15 seconds
                -- Optional: Output error message
                -- print("[FWF Client ERROR] Client Config could not be loaded after 15 seconds.")
                return
            end
        end
    end

    -- Initialize NUI handlers and commands when both ESX and Config are ready
    if ESX and clientConfigReady then
        InitializeNUIHandlersAndCommand()
    end
end)

-- Network event: Receive referral code from server
-- This is triggered when a player joins and gets their referral code
-- EXTENSION POINT: Add additional player data processing here
RegisterNetEvent('freundeWerben:sendCodeToNUI')
AddEventHandler('freundeWerben:sendCodeToNUI', function(code, hasReferred)
    myReferralCode = code
    hasAlreadyReferred = hasReferred
    -- Update NUI if it's ready to receive data
    if nuiReady then 
        SendNUIMessage({action = 'updateInitialData', code = myReferralCode, hasReferred = hasAlreadyReferred}) 
    end
end)

-- Network event: Player successfully used a referral code
-- Updates the local state to reflect that the player has been referred
-- EXTENSION POINT: Add celebration effects, sounds, or other feedback here
RegisterNetEvent('freundeWerben:codeSuccessfullyReferred')
AddEventHandler('freundeWerben:codeSuccessfullyReferred', function()
    hasAlreadyReferred = true
    -- Update NUI to show the new referral status
    if nuiReady then 
        SendNUIMessage({action = 'updateHasReferredStatus', hasReferred = true}) 
    end
end)

-- Network event: Update rewards display
-- Triggered when player unlocks new rewards to refresh the dashboard
-- EXTENSION POINT: Add reward unlock animations or notifications here
RegisterNetEvent('freundeWerben:updateRewards')
AddEventHandler('freundeWerben:updateRewards', function()
    -- Only update if NUI is ready and currently open
    if nuiReady and nuiOpen then
        if ESX then
            -- Fetch fresh dashboard data from server
            ESX.TriggerServerCallback('freundeWerben:getDashboardData', function(cbData)
                if cbData and cbData.status == "ok" then 
                    SendNUIMessage({action = 'updateDashboard', data = cbData.data}) 
                end
            end)
        end
    end
end)

-- Network event: Show notification from server
-- Provides consistent messaging between server and client
-- EXTENSION POINT: Replace with custom notification system (mythic_notify, pNotify, etc.)
RegisterNetEvent('freundeWerben:showNotification')
AddEventHandler('freundeWerben:showNotification', function(message)
    if ESX and message then
        ESX.ShowNotification(message)
    end
end)

-- Toggle NUI visibility and focus
-- This is the main function for opening/closing the referral interface
-- EXTENSION POINT: Add animations, sound effects, or UI state management here
function ToggleNUI()
    if not clientConfigReady then return end -- Ensure config is loaded
    
    -- Check if NUI is ready before proceeding
    if not nuiReady then
        if ESX and _G.Config and _G.Config.Messages and _G.Config.Messages.nui_not_ready then 
            ESX.ShowNotification(_G.Config.Messages.nui_not_ready) 
        end
        return
    end
    
    -- Toggle the NUI state
    nuiOpen = not nuiOpen
    SetNuiFocus(nuiOpen, nuiOpen) -- Enable/disable mouse cursor and input
    SendNUIMessage({action = 'setVisible', visible = nuiOpen})

    -- When opening NUI, fetch fresh data from server
    if nuiOpen then
        if ESX then
            ESX.TriggerServerCallback('freundeWerben:getDashboardData', function(cbData)
                -- Double-check if NUI is still open (in case user closed it quickly)
                if nuiOpen then
                    if cbData and cbData.status == "ok" then
                        -- Send dashboard data to NUI
                        SendNUIMessage({action = 'updateDashboard', data = cbData.data})
                    else
                        -- Show error message in NUI
                        SendNUIMessage({ 
                            action = 'showError', 
                            message = (cbData and cbData.message or "Error loading data.") 
                        })
                    end
                end
            end)
        end
    end
end

-- Input handling thread for ESC key
-- Allows players to close the NUI with the ESC key
-- EXTENSION POINT: Add other keybinds or input handling here
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0) -- Check every frame
        -- Check if ESC key is pressed while NUI is open
        if nuiOpen and IsControlJustReleased(0, 200) then -- 200 is the ESCAPE key
            ToggleNUI()
        end
    end
end)