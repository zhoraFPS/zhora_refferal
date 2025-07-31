# 🎯 FiveM ESX Referral System

A comprehensive **Friend Referral System** for FiveM ESX servers that allows players to invite friends and earn rewards for successful referrals.

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![ESX](https://img.shields.io/badge/framework-ESX-green.svg)
![License](https://img.shields.io/badge/license-MIT-yellow.svg)
![Tested](https://img.shields.io/badge/tested%20with-ox__inventory-orange.svg)

## 📋 Table of Contents

- [Preview](#-preview)
- [Features](#-features)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Usage](#-usage)
- [Database Structure](#-database-structure)
- [API Documentation](#-api-documentation)
- [Admin Commands](#-admin-commands)
- [Extension Guide](#-extension-guide)
- [Implementation Notes](#-implementation-notes)
- [Troubleshooting](#-troubleshooting)
- [Changelog](#-changelog)
- [Support](#-support)

## 🎥 Preview

<a href="[https://streamable.com/lzgwf9]">
  <img src="https://img.shields.io/badge/▶️%20Watch-Demo%20Video-red?style=for-the-badge&logoColor=white" alt="Watch Demo Menu">
</a>

<a href="[https://streamable.com/k2rdpg]">
  <img src="https://img.shields.io/badge/▶️%20Watch-Demo%20Video-red?style=for-the-badge&logoColor=white" alt="Watch Demo Test">
</a>

*Click the button above to watch the demo*

## ✨ Features

### 🎮 Player Features
- **Unique Referral Codes**: Auto-generated unique codes for each player (format: `NS-XXXXX`)
- **Modern NUI Interface**: Clean, responsive dashboard for managing referrals
- **Referral Tracking**: View all successfully referred players with join dates
- **Progressive Reward System**: Unlock rewards as you refer more friends
- **Real-time Updates**: Instant UI updates when rewards are unlocked
- **Anti-Cheat Protection**: Prevents self-referral and duplicate redemptions

### 🛠️ Admin Features
- **Testing Commands**: Simulate referrals for testing reward systems
- **Debug Mode**: Comprehensive logging for troubleshooting
- **Database Management**: Automatic table creation and management
- **Permission System**: Role-based access to admin functions

### 🔧 Developer Features
- **Highly Extensible**: Well-documented extension points throughout code
- **Multiple Reward Types**: Support for money, items, and vehicles
- **ox_inventory Compatible**: Tested and working with ox_inventory system
- **Custom Notifications**: Pluggable notification system
- **Performance Optimized**: Efficient database queries and caching
- **Multi-language Ready**: Configurable message system

## 📦 Requirements

- **FiveM Server** with ESX Framework
- **MySQL Database** (or compatible)
- **oxmysql** (Database resource)
- **ESX** compatible server setup

### Recommended & Tested
- **ox_inventory** (Tested and compatible)

### Dependencies
Make sure these resources are started before this script:
```cfg
ensure es_extended
ensure oxmysql
ensure ox_inventory  # If using ox_inventory
```

## 🚀 Installation

### 1. Download & Extract


### 2. Database Setup
The script automatically creates required tables on first run. No manual SQL execution needed!

**Auto-created tables:**
- `player_referrals` - Main referral data
- `referred_connections` - Who referred whom
- `player_unlocked_rewards` - Reward tracking

### 3. Configuration
The configuration is already set up and ready to use. Check `config.lua` for customization options.

### 4. Server Setup
Add to your `server.cfg`:
```cfg
# Add to server.cfg
ensure your-referral-resource-name

# Make sure it loads after required dependencies
```

### 5. Restart Server
```bash
# Restart your server or start the resource
restart your-referral-resource-name
```

## ⚙️ Configuration

### Current Configuration
```lua
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
```

### Reward Types
| Type | Description | Status | Parameters |
|------|-------------|--------|------------|
| `money` | Cash reward | ✅ Working | `reward_value` = amount |
| `item` | Inventory item | ✅ Working (ox_inventory) | `reward_value` = item name, `reward_amount` = quantity |
| `vehicle` | Vehicle reward | ⚠️ **Needs Implementation** | `reward_value` = vehicle model |

## 🎯 Usage

### For Players

#### Opening the Interface
```
/code
```
Opens the referral dashboard where players can:
- View their unique referral code (format: `NS-XXXXX`)
- See referred players list with join dates
- Check available and unlocked rewards
- Enter referral codes from friends

#### Current Reward Structure
1. **1 Referral**: 5.000$ Cash Bonus
2. **3 Referrals**: 5 Lockpicks (ox_inventory item)
3. **5 Referrals**: Sultan Vehicle (requires implementation)

#### Sharing Referral Codes
1. Open dashboard with `/code`
2. Copy your unique referral code (starts with `NS-`)
3. Share with friends joining the server
4. Friends enter your code in their dashboard
5. Earn progressive rewards as friends stay active!

### For Administrators

#### Testing Rewards
```
/admintestref <playerID> <referralCount>
```
Simulates referrals for testing the reward system.

**Examples:**
```
/admintestref 1 1    # Test money reward (5000$)
/admintestref 1 3    # Test item reward (5 lockpicks)
/admintestref 1 5    # Test vehicle reward (sultan - needs implementation)
```

## 🗄️ Database Structure

### player_referrals
| Column | Type | Description |
|--------|------|-------------|
| `id` | INT | Primary key |
| `identifier` | VARCHAR(60) | Player identifier |
| `referral_code` | VARCHAR(50) | Unique referral code (NS-XXXXX) |
| `referred_by_code` | VARCHAR(50) | Code used by this player |
| `join_date` | TIMESTAMP | When player joined |

### referred_connections
| Column | Type | Description |
|--------|------|-------------|
| `id` | INT | Primary key |
| `referrer_identifier` | VARCHAR(60) | Who referred |
| `referred_identifier` | VARCHAR(60) | Who was referred |
| `timestamp` | TIMESTAMP | When referral occurred |

### player_unlocked_rewards
| Column | Type | Description |
|--------|------|-------------|
| `id` | INT | Primary key |
| `player_identifier` | VARCHAR(60) | Player who unlocked |
| `reward_id` | VARCHAR(255) | Unique reward identifier |
| `unlocked_at` | TIMESTAMP | When reward was unlocked |

## 📡 API Documentation

### Server Events

#### `freundeWerben:sendCodeToNUI`
Sends referral code to client NUI
```lua
TriggerClientEvent('freundeWerben:sendCodeToNUI', playerId, code, hasReferred)
-- Example: TriggerClientEvent('freundeWerben:sendCodeToNUI', 1, "NS-ABC12", false)
```

#### `freundeWerben:codeSuccessfullyReferred`
Notifies successful referral redemption
```lua
TriggerClientEvent('freundeWerben:codeSuccessfullyReferred', playerId)
```

#### `freundeWerben:updateRewards`
Triggers NUI reward update
```lua
TriggerClientEvent('freundeWerben:updateRewards', playerId)
```

#### `freundeWerben:showNotification`
Shows notification to player
```lua
TriggerClientEvent('freundeWerben:showNotification', playerId, message)
```

### Server Callbacks

#### `freundeWerben:submitReferralCode`
**Purpose:** Validate and process referral code submission
```lua
ESX.TriggerServerCallback('freundeWerben:submitReferralCode', function(response)
    -- Handle response
end, {code = "NS-ABC12"})
```

**Response Format:**
```lua
{
    status = "ok" | "error",
    message = "Code erfolgreich eingelöst! Vielen Dank für die Empfehlung."
}
```

#### `freundeWerben:getDashboardData`
**Purpose:** Get complete dashboard data for NUI
```lua
ESX.TriggerServerCallback('freundeWerben:getDashboardData', function(response)
    -- Handle dashboard data
end)
```

**Response Format:**
```lua
{
    status = "ok",
    data = {
        myCode = "NS-ABC12",
        hasReferredSomeone = false,
        invitedPlayers = {
            {name = "Max Mustermann", date = "01.01.2024"}
        },
        rewards = Config.Rewards,
        unlockedRewardIds = {"reward_1_money_5000"}
    }
}
```

## 👨‍💼 Admin Commands

### `/admintestref <playerID> <referralCount>`
**Permission:** admin, superadmin, or console
**Purpose:** Test reward system with simulated referrals

**Parameters:**
- `playerID` - Target player's server ID
- `referralCount` - Number of referrals to simulate (≥0)

**Examples:**
```
/admintestref 1 1     # Test money reward (5.000$)
/admintestref 5 3     # Test lockpick reward (5 lockpicks)
/admintestref 12 5    # Test vehicle reward (Sultan - needs implementation)
/admintestref 8 0     # Reset referrals for player ID 8
```

## 🔧 Extension Guide

### Adding New Reward Types

1. **Extend Reward Processing** in `CheckAndGrantRewards()`:
```lua
elseif rewardInfo.reward_type == "xp" then
    -- Add XP reward logic
    exports['esx_xp']:AddXP(xPlayerReferrer.source, rewardInfo.reward_value)
elseif rewardInfo.reward_type == "rank" then
    -- Add rank/job reward logic
    xPlayerReferrer.setJob(rewardInfo.reward_value, 0)
```

2. **Update Configuration**:
```lua
{
    required_referrals = 7,
    reward_type = "xp",
    reward_value = 1000,
    reward_amount = 1,
    label = "1000 XP Bonus für 7 geworbene Freunde"
}
```

### ox_inventory Integration

The script is tested with ox_inventory. Item rewards work automatically:
```lua
{
    required_referrals = 2,
    reward_type = "item",
    reward_value = "phone",
    reward_amount = 1,
    label = "Handy für 2 geworbene Freunde"
}
```

### Customizing Code Format

Change the prefix in config.lua:
```lua
Config.CodePrefix = "MYSERVER-"  -- Results in codes like "MYSERVER-ABC12"
```

### Adding Custom Commands

Add to `InitializeNUIHandlersAndCommand()`:
```lua
RegisterCommand('myreferrals', function(source, args, rawCommand)
    if not clientConfigReady then return end
    ToggleNUI()
end, false)
```

## ⚠️ Implementation Notes

### Vehicle Rewards - Requires Implementation

The vehicle reward system is **prepared but not fully implemented**. You need to add the actual vehicle spawning logic:

```lua
elseif rewardInfo.reward_type == "vehicle" then
    -- EXAMPLE IMPLEMENTATION NEEDED:
    -- 1. Generate license plate
    local plate = exports['esx_vehicleshop']:GeneratePlate() -- If using esx_vehicleshop
    
    -- 2. Add to player_vehicles table
    exports[Config.DatabaseResource]:execute(
        'INSERT INTO owned_vehicles (owner, plate, vehicle) VALUES (@owner, @plate, @vehicle)',
        {
            ['@owner'] = referrerIdentifier,
            ['@plate'] = plate,
            ['@vehicle'] = json.encode({model = GetHashKey(rewardInfo.reward_value), plate = plate})
        }
    )
    
    -- 3. Notify player
    SendClientNotification(xPlayerReferrer.source, 
        ("Du hast ein Fahrzeug (%s) erhalten! Kennzeichen: %s"):format(rewardInfo.reward_value, plate))
```

### Inventory System Compatibility

**Tested Systems:**
- ✅ **ox_inventory** - Fully working
- ❓ **esx_inventory** - Should work (not tested)
- ❓ **qs-inventory** - May need adaptation

### Message Localization

Current setup is in German. To add English:
```lua
Config.Locale = 'de' -- or 'en'

Config.Messages = {
    de = {
        code_not_found = "Dieser Code existiert nicht.",
        -- ... German messages
    },
    en = {
        code_not_found = "This code does not exist.",
        -- ... English messages
    }
}
```

## 🐛 Troubleshooting

### Common Issues

#### "oxmysql resource not found"
**Cause:** oxmysql not started or different name
**Solution:** 
1. Ensure oxmysql is running: `ensure oxmysql`
2. Check resource name matches `Config.DatabaseResource`

#### Item Rewards Not Working with ox_inventory
**Cause:** Item name mismatch or ox_inventory not loaded
**Solution:**
1. Verify item exists in ox_inventory items.lua
2. Check item name spelling (case-sensitive)
3. Ensure ox_inventory starts before this resource

#### Vehicle Rewards Not Working
**Cause:** Vehicle reward logic not implemented
**Solution:**
1. This is expected - vehicle rewards need manual implementation
2. See [Implementation Notes](#-implementation-notes) for guidance
3. Contact your developer to implement vehicle spawning

#### German Messages Not Displaying
**Cause:** Config not loaded or wrong encoding
**Solution:**
1. Check file encoding (UTF-8)
2. Verify Config.Messages structure
3. Enable debug mode to check config loading

### Debug Mode
Enable detailed logging:
```lua
Config.DebugMode = true
```

This will show:
- Player join/leave events with NS- codes
- Item reward processing (ox_inventory)
- Database operations
- Reward unlock notifications
- Error details

### Performance Monitoring
- **Database Queries:** Optimized with prepared statements
- **ox_inventory Integration:** Uses native ESX functions
- **NUI Updates:** Only when interface is open
- **Memory Usage:** Minimal overhead with proper cleanup

## 📋 Changelog

### Version 1.0.0 (Current Release)
- ✅ Complete referral system with NS- prefix codes
- ✅ ox_inventory compatibility (tested)
- ✅ oxmysql database integration
- ✅ German message system
- ✅ Money and item rewards working
- ✅ Admin testing commands
- ✅ Modern NUI dashboard
- ⚠️ Vehicle rewards (framework ready, needs implementation)

### Planned Features
- 🔄 **v1.1.0:** Vehicle reward implementation examples
- 🔄 **v1.2.0:** Multi-language support (EN/DE)
- 🔄 **v1.3.0:** Statistics dashboard for admins
- 🔄 **v1.4.0:** Referral leaderboards
- 🔄 **v1.5.0:** Time-limited referral events

## 💬 Support

### Getting Help
1. **Check Implementation Notes:** Especially for vehicle rewards
2. **Enable Debug Mode:** Set `Config.DebugMode = true`
3. **Check ox_inventory:** Verify item names and compatibility
4. **Verify Dependencies:** oxmysql, ESX, ox_inventory running

### Reporting Issues
Include in your report:
- **Inventory System:** Which inventory system you're using
- **Database Resource:** Confirm oxmysql version
- **Item Names:** For item reward issues, provide item names
- **Error Messages:** Full console output
- **Config File:** Your current configuration

### Known Limitations
- **Vehicle Rewards:** Need manual implementation
- **Inventory Compatibility:** Only tested with ox_inventory
- **Language:** Currently German only (English planned)

### Implementation Services
Need help implementing vehicle rewards or custom features? Contact the development team for professional implementation services.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Credits

**Developed by:** [Your Name/Organization]
**Framework:** ESX Framework Team
**Tested with:** ox_inventory by Overextended
**Database:** oxmysql by Overextended
**Special Thanks:** FiveM Community

---

*Made with ❤️ for the FiveM community*
