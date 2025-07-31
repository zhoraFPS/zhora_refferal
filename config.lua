Config = {}

-- Code Generation Settings
Config.CodePrefix = "NS-"  -- Referral codes will look like "NS-ABC12"

-- Database Settings  
Config.DatabaseResource = "oxmysql"  -- Using oxmysql as database resource
Config.PlayerReferralTable = "player_referrals"
Config.ReferredConnectionsTable = "referred_connections"
Config.UnlockedRewardsTable = "player_unlocked_rewards"

-- System Settings
Config.DebugMode = false  -- Set to true for detailed logging

-- Reward System (Current Setup)
Config.Rewards = {
    {
        required_referrals = 1,
        reward_type = "money",
        reward_value = 5000,
        reward_amount = 1,
        label = "5.000$ für den ersten geworbenen Freund"
    },
    {
        required_referrals = 3,
        reward_type = "item",
        reward_value = "lockpick",
        reward_amount = 5,
        label = "5 Lockpicks für 3 geworbene Freunde"
    },
    {
        required_referrals = 5,
        reward_type = "vehicle",
        reward_value = "sultan",
        reward_amount = 1,
        label = "Ein Sultan für 5 geworbene Freunde"
    }
}

-- Message System (German)
Config.Messages = {
    code_not_found = "Dieser Code existiert nicht.",
    code_already_used = "Du hast bereits einen Code eingelöst.",
    cannot_refer_self = "Du kannst deinen eigenen Code nicht verwenden.",
    code_accepted = "Code erfolgreich eingelöst! Vielen Dank für die Empfehlung.",
    reward_unlocked = "Du hast eine neue Belohnung freigeschaltet: ",
    error_db = "Ein Datenbankfehler ist aufgetreten.",
    nui_not_ready = "Die Benutzeroberfläche ist noch nicht bereit."
}