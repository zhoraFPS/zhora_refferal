ESX = nil
local serverConfigReady = false
local esxReady = false

-- Helper function to send notifications via client event
-- EXTENSION POINT: You can modify this to use different notification systems
-- (e.g., mythic_notify, pNotify, or custom notification systems)
function SendClientNotification(targetSource, message)
    if targetSource and message and TriggerClientEvent then -- Ensure TriggerClientEvent exists
        TriggerClientEvent('freundeWerben:showNotification', targetSource, message)
    end
end

-- Main server logic initialization
-- This function sets up all ESX event handlers and server callbacks
-- EXTENSION POINT: Add new event handlers or callbacks here
function InitializeServerLogic()
    if not esxReady or not serverConfigReady then
        -- No print in production code, error is already handled in initialization thread
        return
    end
    InitializeDatabase()

    -- Event handler for when a player loads into the server
    -- EXTENSION POINT: Add additional player initialization logic here
    AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
        if not ESX or not serverConfigReady then return end
        if not xPlayer or not xPlayer.identifier then return end
        local identifier = xPlayer.identifier

        if _G.Config.DebugMode then print(("[FWF Server] Player loaded: %s (%s)"):format(xPlayer.name or "Unknown", identifier)) end

        -- Check if player already has a referral code in database
        exports[_G.Config.DatabaseResource]:fetch(string.format("SELECT referral_code, referred_by_code FROM %s WHERE identifier = @identifier", _G.Config.PlayerReferralTable), {['@identifier'] = identifier}, function(result)
            if result and #result > 0 then
                if _G.Config.DebugMode then print(("[FWF Server] Player %s already has code: %s"):format(xPlayer.name, result[1].referral_code)) end
                -- Send existing code to client NUI
                TriggerClientEvent('freundeWerben:sendCodeToNUI', playerId, result[1].referral_code, result[1].referred_by_code ~= nil)
            else
                -- Generate new unique referral code for new player
                local newCode = GenerateUniqueReferralCode(identifier)
                if _G.Config.DebugMode then print(("[FWF Server] Generating new code for %s: %s"):format(xPlayer.name, newCode)) end
                -- Insert new code into database
                exports[_G.Config.DatabaseResource]:execute(string.format("INSERT INTO %s (identifier, referral_code) VALUES (@identifier, @code)", _G.Config.PlayerReferralTable), {['@identifier'] = identifier, ['@code'] = newCode}, function(affectedRows)
                    if affectedRows and affectedRows > 0 then
                        if _G.Config.DebugMode then print(("[FWF Server] New code %s for player %s saved to DB."):format(newCode, xPlayer.name)) end
                        TriggerClientEvent('freundeWerben:sendCodeToNUI', playerId, newCode, false)
                    else
                        -- In case of error, don't direct output, but send notification to client (if appropriate)
                        SendClientNotification(playerId, _G.Config.Messages.error_db)
                    end
                end)
            end
        end)
    end)

    -- Server callback for when a player submits a referral code
    -- EXTENSION POINT: Add additional validation or custom referral logic here
    ESX.RegisterServerCallback('freundeWerben:submitReferralCode', function(source, cb, data)
        if not serverConfigReady then cb({status='error', message='Server error (Config not ready)'}); return end
        if not ESX then cb({status='error', message='Server error (ESX not ready)'}); return end

        local xPlayer = ESX.GetPlayerFromId(source)
        local enteredCode = data.code

        if not xPlayer then cb({ status = "error", message = "Player not found." }); return end
        if not enteredCode or enteredCode == "" then cb({ status = "error", message = _G.Config.Messages.code_empty or "Please enter a code." }); return end -- Configurable message

        if _G.Config.DebugMode then print(("[FWF Server] Player %s trying to redeem code: %s"):format(xPlayer.name, enteredCode)) end

        -- Check if player has already used a referral code
        local playerReferralData = exports[_G.Config.DatabaseResource]:fetchSync(string.format("SELECT referred_by_code FROM %s WHERE identifier = @identifier", _G.Config.PlayerReferralTable), {['@identifier'] = xPlayer.identifier})

        if playerReferralData and #playerReferralData > 0 and playerReferralData[1].referred_by_code then
            if _G.Config.DebugMode then print(("[FWF Server] Player %s has already redeemed a code."):format(xPlayer.name)) end
            SendClientNotification(source, _G.Config.Messages.code_already_used)
            cb({ status = "error", message = _G.Config.Messages.code_already_used })
            return
        end

        -- Find the referrer by the entered code
        exports[_G.Config.DatabaseResource]:fetch(string.format("SELECT identifier, referral_code FROM %s WHERE referral_code = @code", _G.Config.PlayerReferralTable), {['@code'] = enteredCode}, function(referrerResult)
            if referrerResult and #referrerResult > 0 then
                local referrerIdentifier = referrerResult[1].identifier
                local referrerActualCode = referrerResult[1].referral_code

                -- Prevent self-referral
                if referrerIdentifier == xPlayer.identifier then
                    if _G.Config.DebugMode then print(("[FWF Server] Player %s tried to redeem own code."):format(xPlayer.name)) end
                    SendClientNotification(source, _G.Config.Messages.cannot_refer_self)
                    cb({ status = "error", message = _G.Config.Messages.cannot_refer_self })
                    return
                end

                -- Update the player's record to show they were referred
                exports[_G.Config.DatabaseResource]:execute(string.format("UPDATE %s SET referred_by_code = @referrerCode WHERE identifier = @referredIdentifier", _G.Config.PlayerReferralTable), {['@referrerCode'] = referrerActualCode, ['@referredIdentifier'] = xPlayer.identifier}, function(updateAffected)
                    if updateAffected and updateAffected > 0 then
                        -- Create a connection record between referrer and referred player
                        exports[_G.Config.DatabaseResource]:execute(string.format("INSERT INTO %s (referrer_identifier, referred_identifier) VALUES (@referrer, @referred)", _G.Config.ReferredConnectionsTable), {['@referrer'] = referrerIdentifier, ['@referred'] = xPlayer.identifier}, function(insertAffected)
                            if insertAffected and insertAffected > 0 then
                                if _G.Config.DebugMode then print(("[FWF Server] Code %s from %s redeemed for referrer %s."):format(enteredCode, xPlayer.name, referrerIdentifier)) end
                                SendClientNotification(source, _G.Config.Messages.code_accepted)
                                TriggerClientEvent('freundeWerben:codeSuccessfullyReferred', source)
                                -- Check and grant rewards to the referrer
                                CheckAndGrantRewards(referrerIdentifier, nil)
                                cb({ status = "ok", message = _G.Config.Messages.code_accepted })
                            else
                                SendClientNotification(source, _G.Config.Messages.error_db)
                                cb({ status = "error", message = _G.Config.Messages.error_db .. " (Connection)"})
                            end
                        end)
                    else
                        SendClientNotification(source, _G.Config.Messages.error_db)
                        cb({ status = "error", message = _G.Config.Messages.error_db .. " (Update)"})
                    end
                end)
            else
                if _G.Config.DebugMode then print(("[FWF Server] Entered code %s not found."):format(enteredCode)) end
                SendClientNotification(source, _G.Config.Messages.code_not_found)
                cb({ status = "error", message = _G.Config.Messages.code_not_found })
            end
        end)
    end)

    -- Server callback to get dashboard data for the NUI interface
    -- EXTENSION POINT: Add additional dashboard data or statistics here
    ESX.RegisterServerCallback('freundeWerben:getDashboardData', function(source, cb)
        if not serverConfigReady then cb({status='error', message='Server error (Config not ready)'}); return end
        if not ESX then cb({status='error', message='Server error (ESX not ready)'}); return end
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then cb({ status = "error", message = "Player not found." }); return end

        local identifier = xPlayer.identifier
        local responseData = {
            myCode = "",
            hasReferredSomeone = false,
            invitedPlayers = {},
            rewards = {},
            unlockedRewardIds = {}
        }

        -- Get player info (code, whether already referred)
        local playerInfo = exports[_G.Config.DatabaseResource]:fetchSync(string.format("SELECT referral_code, referred_by_code FROM %s WHERE identifier = @identifier", _G.Config.PlayerReferralTable), {['@identifier'] = identifier})
        if playerInfo and #playerInfo > 0 then
            responseData.myCode = playerInfo[1].referral_code
            responseData.hasReferredSomeone = playerInfo[1].referred_by_code ~= nil
        end

        -- Get referred players with their names from users table (if available)
        -- EXTENSION POINT: Modify this query to include additional player information
        local invited = exports[_G.Config.DatabaseResource]:fetchSync(string.format("SELECT pr.identifier, pr.join_date, COALESCE(u.firstname, 'Unknown') AS firstname, COALESCE(u.lastname, '') AS lastname FROM %s rc JOIN %s pr ON rc.referred_identifier = pr.identifier LEFT JOIN users u ON pr.identifier = u.identifier WHERE rc.referrer_identifier = @identifier ORDER BY pr.join_date DESC", _G.Config.ReferredConnectionsTable, _G.Config.PlayerReferralTable), {['@identifier'] = identifier})
        if invited then
            for _, invitee in ipairs(invited) do
                local dateStr = "Unknown Date"
                if invitee.join_date then
                    if type(invitee.join_date) == 'number' then -- Assumption: Unix Timestamp
                        dateStr = os.date("%d.%m.%Y", invitee.join_date)
                    elseif type(invitee.join_date) == 'string' then -- Assumption: 'YYYY-MM-DD HH:MM:SS' or similar SQL format
                        local y,m,d = string.match(tostring(invitee.join_date), "(%d%d%d%d)-(%d%d)-(%d%d)")
                        if y then dateStr = d .. "." .. m .. "." .. y else dateStr = tostring(invitee.join_date) end
                    end
                end
                table.insert(responseData.invitedPlayers, {name = invitee.firstname .. " " .. invitee.lastname, date = dateStr})
            end
        end

        responseData.rewards = _G.Config.Rewards -- Directly from config

        -- Get unlocked rewards for this player
        local unlocked = exports[_G.Config.DatabaseResource]:fetchSync(string.format("SELECT reward_id FROM %s WHERE player_identifier = @identifier", _G.Config.UnlockedRewardsTable), {['@identifier'] = identifier})
        if unlocked then
            for _, reward in ipairs(unlocked) do
                table.insert(responseData.unlockedRewardIds, reward.reward_id)
            end
        end
        if _G.Config.DebugMode then print(("[FWF Server] Dashboard data sent for %s. Referred: %d"):format(xPlayer.name, #responseData.invitedPlayers)) end
        cb({ status = "ok", data = responseData })
    end)

    -- Admin command for testing referral rewards
    -- Usage: /admintestref <playerID> <numberOfReferrals>
    -- EXTENSION POINT: Add additional admin commands or modify permission checking
    RegisterCommand('admintestref', function(cmdSource, args, rawCommand)
        if not ESX then
            if cmdSource > 0 then TriggerClientEvent('chat:addMessage', cmdSource, { args = {"^1[Admin Referral Test]^0 Server error: ESX not ready."} })
            else print("[FWF Admin ERROR] admintestref: ESX is nil!") end
            return
        end
        if not serverConfigReady then
            if cmdSource > 0 then SendClientNotification(cmdSource, "Server error: Config not ready.")
            else print("[FWF Admin ERROR] admintestref: Config is nil!") end
            return
        end

        -- Check admin permissions
        local xPlayerAdmin = ESX.GetPlayerFromId(cmdSource)
        local isAdmin = false
        if xPlayerAdmin then
            local adminGroup = xPlayerAdmin.getGroup()
            if adminGroup == 'admin' or adminGroup == 'superadmin' then isAdmin = true end
        elseif cmdSource == 0 then -- Console
            isAdmin = true
        end

        if isAdmin then
            local targetPlayerId = tonumber(args[1])
            local simulatedReferrals = tonumber(args[2])
            if not targetPlayerId or not simulatedReferrals or simulatedReferrals < 0 then
                local usageMsg = "Usage: /admintestref <TargetPlayerID> <NumberOfReferrals (>=0)>"
                if cmdSource > 0 then SendClientNotification(cmdSource, usageMsg) else print(usageMsg) end
                return
            end

            local xTargetPlayer = ESX.GetPlayerFromId(targetPlayerId)
            if xTargetPlayer then
                local msg = ("Testing rewards for PlayerID %d (%s) with %d simulated referrals."):format(targetPlayerId, xTargetPlayer.name, simulatedReferrals)
                if cmdSource > 0 then SendClientNotification(cmdSource, msg) else print(msg) end
                if _G.Config.DebugMode then print(("[FWF Admin Test] Running CheckAndGrantRewards for %s with %d referrals."):format(xTargetPlayer.identifier, simulatedReferrals)) end
                CheckAndGrantRewards(xTargetPlayer.identifier, simulatedReferrals)
                local confirmMsg = ("Reward check executed for PlayerID %d."):format(targetPlayerId)
                if cmdSource > 0 then SendClientNotification(cmdSource, confirmMsg) else print(confirmMsg) end
            else
                local errorMsg = ("Player with ID %d not found or not online."):format(targetPlayerId)
                if cmdSource > 0 then SendClientNotification(cmdSource, errorMsg) else print(errorMsg) end
            end
        else
            local noPermMsg = "You don't have permission for this command."
            if cmdSource > 0 then SendClientNotification(cmdSource, noPermMsg) else print(noPermMsg) end
        end
    end, false) -- false = command is not restricted by default ACE permissions
    -- if _G.Config.DebugMode then print("[FWF Server] All ESX-dependent functions and callbacks initialized.") end -- Less verbose
end

-- Initialization thread - waits for ESX and Config to be ready
-- EXTENSION POINT: Add additional initialization checks here if you depend on other resources
Citizen.CreateThread(function()
    local esxWaitCount = 0
    -- Wait for ESX to be available
    while not esxReady do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(250)
        if ESX ~= nil then
            esxReady = true
            if _G.Config and _G.Config.DebugMode then print("[FWF Server] ESX Shared Object RECEIVED!") end
        else
            esxWaitCount = esxWaitCount + 1
            if esxWaitCount > 60 then -- 15 seconds
                print("[FWF Server ERROR] ESX could not be loaded after 15 seconds. Script will not initialize.")
                return
            end
        end
    end

    local configWaitCount = 0
    -- Wait for config to be loaded
    while not serverConfigReady do
        if _G.Config and _G.Config.CodePrefix then -- Simple check if config was loaded
            serverConfigReady = true
            if _G.Config.DebugMode then print("[FWF Server] Config is ready.") end
        else
            Citizen.Wait(250)
            configWaitCount = configWaitCount + 1
            if configWaitCount > 60 then -- 15 seconds
                print("[FWF Server ERROR] Config could not be loaded after 15 seconds. Script will not initialize.")
                return
            end
        end
    end

    -- Initialize server logic when both ESX and Config are ready
    if esxReady and serverConfigReady then
        InitializeServerLogic()
        if _G.Config.DebugMode then print("[FWF Server] Initialization completed.") end
    else
        print("[FWF Server ERROR] ESX or Config not ready. Server logic will NOT be initialized.")
    end
end)

-- Database initialization function
-- Creates all necessary tables if they don't exist
-- EXTENSION POINT: Add new tables or modify existing table structures here
function InitializeDatabase()
    if not serverConfigReady then return end
    if not _G.Config or not _G.Config.DatabaseResource then
        print("[FWF Server ERROR] InitializeDatabase: Config or DatabaseResource is nil")
        return
    end

    -- Wait for database resource to be available
    local dbResourceReady = false
    local dbWaitCount = 0
    while not dbResourceReady do
        if exports[_G.Config.DatabaseResource] then
            dbResourceReady = true
        else
            Citizen.Wait(500)
            dbWaitCount = dbWaitCount + 1
            if dbWaitCount > 20 then -- 10 seconds
                print(("[FWF Server ERROR] Database resource '%s' not found after 10 seconds."):format(_G.Config.DatabaseResource))
                return
            end
        end
    end
    if _G.Config.DebugMode then print(("[FWF Server] DB Resource %s is ready."):format(_G.Config.DatabaseResource)) end

    -- Database table creation queries
    -- EXTENSION POINT: Modify these queries to add new columns or tables
    local queries = {
        -- Main player referral table
        string.format([[
            CREATE TABLE IF NOT EXISTS %s (
                id INT AUTO_INCREMENT PRIMARY KEY,
                identifier VARCHAR(60) NOT NULL UNIQUE,
                referral_code VARCHAR(50) NOT NULL UNIQUE,
                referred_by_code VARCHAR(50) DEFAULT NULL,
                join_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        ]], _G.Config.PlayerReferralTable),
        -- Referral connections table (who referred whom)
        string.format([[
            CREATE TABLE IF NOT EXISTS %s (
                id INT AUTO_INCREMENT PRIMARY KEY,
                referrer_identifier VARCHAR(60) NOT NULL,
                referred_identifier VARCHAR(60) NOT NULL UNIQUE,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (referrer_identifier) REFERENCES %s(identifier) ON DELETE CASCADE,
                FOREIGN KEY (referred_identifier) REFERENCES %s(identifier) ON DELETE CASCADE
            );
        ]], _G.Config.ReferredConnectionsTable, _G.Config.PlayerReferralTable, _G.Config.PlayerReferralTable),
        -- Unlocked rewards table
        string.format([[
            CREATE TABLE IF NOT EXISTS %s (
                id INT AUTO_INCREMENT PRIMARY KEY,
                player_identifier VARCHAR(60) NOT NULL,
                reward_id VARCHAR(255) NOT NULL,
                unlocked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (player_identifier) REFERENCES %s(identifier) ON DELETE CASCADE,
                UNIQUE KEY unique_reward (player_identifier, reward_id)
            );
        ]], _G.Config.UnlockedRewardsTable, _G.Config.PlayerReferralTable)
    }

    -- Execute table creation queries
    for i, query in ipairs(queries) do
        exports[_G.Config.DatabaseResource]:execute(query, {}, function(affectedRows, err)
            if err and _G.Config.DebugMode then
                print(("[FWF Server] DB Error in initialization query %d: %s"):format(i, json.encode(err)))
            end
        end)
    end
    if _G.Config.DebugMode then print("[FWF Server] Database initialized.") end
end

-- Generates a unique referral code for a player
-- Format: [CONFIG_PREFIX][LAST_5_CHARS_OF_IDENTIFIER][4_RANDOM_CHARS]
-- EXTENSION POINT: Modify the code generation algorithm here
function GenerateUniqueReferralCode(identifier)
    if not serverConfigReady then return "ERRCODE" end
    -- Take the last 5 alphanumeric characters of the identifier for more uniqueness
    local playerIdentifierPart = string.upper(string.sub(identifier:gsub("[^%w]", ""), -5))
    if string.len(playerIdentifierPart) < 5 then -- Fallback if identifier is too short
        playerIdentifierPart = playerIdentifierPart .. string.rep("X", 5 - string.len(playerIdentifierPart))
    end

    local randomPart = ""
    for _ = 1, 4 do -- Generate 4 random alphanumeric characters
        randomPart = randomPart .. string.char(math.random(0, 1) == 0 and math.random(48, 57) or math.random(65, 90)) -- 0-9 or A-Z
    end
    local code = _G.Config.CodePrefix .. playerIdentifierPart .. randomPart

    -- Check if code already exists (sync, as it needs to be fast and conflicts are rare)
    local result = exports[_G.Config.DatabaseResource]:scalarSync(string.format("SELECT COUNT(*) FROM %s WHERE referral_code = @code", _G.Config.PlayerReferralTable), {['@code'] = code})

    if result and result > 0 then
        Citizen.Wait(50) -- Short pause before retry
        return GenerateUniqueReferralCode(identifier) -- Recursive call on collision
    else
        return code
    end
end

-- Main reward checking and granting function
-- EXTENSION POINT: This is where you can add custom reward logic
function CheckAndGrantRewards(referrerIdentifier, forcedReferredCount)
    if not serverConfigReady then return end
    if not ESX then return end

    -- Get the referrer player object
    local xPlayerReferrer = ESX.GetPlayerFromIdentifier(referrerIdentifier)
    if not xPlayerReferrer then
        if _G.Config.DebugMode then print(("[FWF Server] CheckAndGrantRewards: Referrer %s not online or not found."):format(referrerIdentifier)) end
        return
    end

    local referredCount
    -- Use forced count for testing, otherwise get from database
    if forcedReferredCount ~= nil and type(forcedReferredCount) == 'number' then
        referredCount = forcedReferredCount
        if _G.Config.DebugMode then print(("[FWF Server] CheckAndGrantRewards for %s: Using forced referral count: %d"):format(xPlayerReferrer.name, referredCount)) end
    else
        -- Performance note: scalarSync is okay here as it's only called once per reward check
        local referredCountResult = exports[_G.Config.DatabaseResource]:scalarSync(string.format("SELECT COUNT(*) FROM %s WHERE referrer_identifier = @identifier", _G.Config.ReferredConnectionsTable), {['@identifier'] = referrerIdentifier})
        referredCount = (referredCountResult and type(referredCountResult) == 'number') and referredCountResult or 0
        if _G.Config.DebugMode then print(("[FWF Server] CheckAndGrantRewards for %s: %d players referred from DB."):format(xPlayerReferrer.name, referredCount)) end
    end

    -- Performance optimization suggestion: Get all already unlocked rewards for this player once
    local unlockedRewardsMap = {}
    local unlockedResult = exports[_G.Config.DatabaseResource]:fetchSync(string.format("SELECT reward_id FROM %s WHERE player_identifier = @identifier", _G.Config.UnlockedRewardsTable), {['@identifier'] = referrerIdentifier})
    if unlockedResult then
        for _, unlocked_reward in ipairs(unlockedResult) do
            unlockedRewardsMap[unlocked_reward.reward_id] = true
        end
    end

    -- Check each reward in the config
    for i, rewardInfo in ipairs(_G.Config.Rewards) do
        -- Create safe reward ID (replace dots with underscores)
        local safeRewardValue = string.gsub(tostring(rewardInfo.reward_value), "%.", "_")
        local rewardId = "reward_" .. i .. "_" .. rewardInfo.reward_type .. "_" .. safeRewardValue

        -- Check if player has enough referrals for this reward
        if referredCount >= rewardInfo.required_referrals then
            -- Check against the pre-loaded map instead of another DB call
            if not unlockedRewardsMap[rewardId] then
                if _G.Config.DebugMode then print(("[FWF Server] Unlocking reward: %s for %s"):format(rewardInfo.label, xPlayerReferrer.name)) end

                -- Grant different types of rewards
                -- EXTENSION POINT: Add new reward types here
                if rewardInfo.reward_type == "money" then 
                    xPlayerReferrer.addMoney(rewardInfo.reward_value)
                elseif rewardInfo.reward_type == "item" then 
                    xPlayerReferrer.addInventoryItem(rewardInfo.reward_value, rewardInfo.reward_amount)
                elseif rewardInfo.reward_type == "vehicle" then
                    -- IMPLEMENTATION NEEDED: Add actual vehicle granting logic here
                    -- Example: exports['esx_vehicleshop']:GeneratePlate() and then DB entry in player_vehicles
                    SendClientNotification(xPlayerReferrer.source, ("You received a vehicle (%s) as reward! (Vehicle granting logic needs to be implemented)"):format(rewardInfo.reward_value))
                    if _G.Config.DebugMode then print(("[FWF Server] NOTE: Vehicle reward '%s' for %s - actual granting needs to be implemented."):format(rewardInfo.reward_value, xPlayerReferrer.name)) end
                end

                -- Record that this reward has been unlocked
                exports[_G.Config.DatabaseResource]:execute(string.format("INSERT INTO %s (player_identifier, reward_id) VALUES (@identifier, @rewardId)", _G.Config.UnlockedRewardsTable), {['@identifier'] = referrerIdentifier, ['@rewardId'] = rewardId}, function(affectedRows)
                    if affectedRows and affectedRows > 0 then
                        SendClientNotification(xPlayerReferrer.source, _G.Config.Messages.reward_unlocked .. rewardInfo.label)
                        TriggerClientEvent('freundeWerben:updateRewards', xPlayerReferrer.source) -- Trigger NUI update
                    end
                end)
            elseif _G.Config.DebugMode then
                 print(("[FWF Server] Reward '%s' (%s) already unlocked by %s."):format(rewardInfo.label, rewardId, xPlayerReferrer.name))
            end
        end
    end
end