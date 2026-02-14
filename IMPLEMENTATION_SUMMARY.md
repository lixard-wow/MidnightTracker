# MidnightTracker - Implementation Summary

## Overview
MidnightTracker is a standalone World of Warcraft addon that tracks currencies, weekly activities, and progression for the Midnight expansion. It displays all tracked information via a minimap tooltip interface.

## File Structure

```
MidnightTracker/
├── MidnightTracker.toc          # Addon manifest and file loader
├── Core.lua                     # Main initialization and event handling
├── Data.lua                     # Currency/activity definitions and helpers
├── Tracker.lua                  # Data fetching and caching logic
├── Minimap.lua                  # Minimap icon and tooltip display
├── README.md                    # User documentation
├── INSTALL.txt                  # Installation guide
├── IMPLEMENTATION_SUMMARY.md    # This file
└── Libs/                        # Embedded libraries
    ├── LibStub/
    │   └── LibStub.lua
    ├── CallbackHandler-1.0/
    │   └── CallbackHandler-1.0.lua
    ├── LibDataBroker-1.1/
    │   └── LibDataBroker-1.1.lua
    └── LibDBIcon-1.0/
        └── LibDBIcon-1.0.lua
```

## Implementation Details

### MidnightTracker.toc
- **Interface Version**: 110200 (Midnight expansion)
- **SavedVariables**: MidnightTrackerDB (stores minimap position and settings)
- **Load Order**: Libraries → Data → Core → Tracker → Minimap
- **Purpose**: Required WoW addon manifest file

### Data.lua
Defines all trackable content and helper functions:

**Currency Categories:**
- Pre-Patch Event (Twilight's Blade Insignia)
- Upgrade Materials (Flightstones, Crests, Valorstones, etc.)
- PvP Currencies (Conquest, Honor)
- Seasonal Events (Darkmoon, Timewalking, etc.)
- Miscellaneous (Crest Fragments, Storm Sigils, etc.)

**Key Functions:**
- `GetTimeUntilWeeklyReset()` - Calculates time until next reset
- `FormatTimeRemaining(seconds)` - Formats time as "Xd Xh" or "Xh Xm"
- `GetCurrencyColor(amount, max)` - Returns color (green/yellow/red) based on cap

**Data Structure:**
```lua
Currencies[CATEGORY] = {
  {currencyID, "Display Name", weeklyMax, iconFileID},
  ...
}
```

### Core.lua
Main addon initialization and framework:

**Initialization:**
- Creates addon namespace (`MidnightTracker`)
- Initializes SavedVariables with defaults
- Registers event handlers (PLAYER_LOGIN, CURRENCY_DISPLAY_UPDATE, etc.)
- Provides utility functions for formatting and printing

**Event Handlers:**
- `PLAYER_LOGIN` - Initialize tracker and minimap on login
- `CURRENCY_DISPLAY_UPDATE` - Update currency cache when values change
- `QUEST_LOG_UPDATE` - Track weekly quest completion

**Slash Commands:**
- `/mt show` - Show minimap icon
- `/mt hide` - Hide minimap icon
- `/mt reset` - Reset icon position
- `/mt debug` - Toggle debug mode
- `/mt config` - Open configuration (planned)

**Utility Functions:**
- `Utils:Print(msg)` - Print with addon prefix
- `Utils:Debug(msg)` - Debug logging (when enabled)
- `Utils:FormatNumber(num)` - Add comma separators (1,234,567)
- `Utils:ColorText(text, r, g, b)` - Apply color codes

### Tracker.lua
Data fetching and caching module:

**Currency Tracking:**
- Uses `C_CurrencyInfo.GetCurrencyInfo(currencyID)` API
- Caches currency data to minimize API calls
- Updates cache every 5 seconds via OnUpdate frame
- Tracks: quantity, max, weekly max, earned this week, discovered status

**Key Functions:**
- `Initialize()` - Sets up periodic update timer
- `UpdateAllCurrencies()` - Refresh all tracked currencies
- `GetCurrency(currencyID)` - Get cached currency data
- `IsCurrencyDiscovered(currencyID)` - Check if player has discovered currency
- `GetGreatVaultProgress()` - Fetch Great Vault data via C_WeeklyRewards API
- `GetAllTrackables()` - Build complete data structure for tooltip

**Smart Display Logic:**
- Only shows currencies the player has discovered
- Hides zero-value currencies (unless setting overridden)
- Respects category visibility settings

**Great Vault Tracking:**
Uses `C_WeeklyRewards.GetActivities()` to track:
- Raid boss kills (thresholds: 2, 4, 8)
- Mythic+ dungeon completions (thresholds: 2, 4, 8)
- World activities/Delves (thresholds: 2, 4, 8)

### Minimap.lua
Minimap icon and tooltip display:

**Initialization:**
- Creates LibDataBroker data object
- Registers with LibDBIcon for minimap management
- Sets up click handlers

**Tooltip Display:**
Organized sections in order:
1. **Header** - Addon name and version
2. **Weekly Reset** - Time until next reset (colored yellow)
3. **Great Vault Progress** - Visual progress bars (█) for each category
4. **Currency Categories** - Organized by type with color coding
5. **Footer** - Click instructions and slash command hint

**Color Coding:**
- Green (0, 1, 0): <70% of cap - plenty of room
- Yellow (1, 1, 0): 70-95% of cap - getting close
- Red (1, 0, 0): >95% of cap - near/at cap
- White (1, 1, 1): No cap or unlimited

**Progress Bars:**
- Green filled (█): Threshold reached
- Gray empty (█): Threshold not reached
- Format: "X/8 ███" (shows current progress and visual bars)

**Functions:**
- `BuildTooltip(tooltip)` - Main tooltip construction
- `AddCurrencyLine(tooltip, currency)` - Add single currency entry
- `AddGreatVaultProgress(tooltip, vaultData)` - Add vault progress bars
- `CreateProgressBars(current, thresholds)` - Generate visual progress indicators
- `Show()/Hide()` - Toggle minimap icon visibility
- `UpdatePosition()` - Refresh icon position

### Libraries (Libs/)

**LibStub.lua**
- Library version management system
- Allows addons to share libraries without conflicts

**CallbackHandler-1.0.lua**
- Event callback system
- Required by LibDataBroker

**LibDataBroker-1.1.lua**
- Data broker protocol
- Standardized way for addons to share data
- Foundation for minimap icon system

**LibDBIcon-1.0.lua**
- Minimap icon management
- Handles dragging, positioning, and click detection
- Manages icon registration and display

## API Usage

### WoW API Calls Used:

**Currency API:**
```lua
C_CurrencyInfo.GetCurrencyInfo(currencyID)
-- Returns: name, quantity, iconFileID, maxQuantity, maxWeeklyQuantity,
--          quantityEarnedThisWeek, discovered, etc.
```

**Weekly Rewards API:**
```lua
C_WeeklyRewards.GetActivities()
-- Returns: Array of activity info with type, progress, thresholds
-- Types: Raid, Activities (M+), World (Delves)
```

**Quest API:**
```lua
C_QuestLog.IsQuestFlaggedCompleted(questID)
-- Returns: true if quest completed this week
```

**Item API:**
```lua
C_Item.GetItemCount(itemID, includeBank)
-- Returns: Number of items owned
```

**Time Functions:**
```lua
GetServerTime() -- Current server timestamp
date(format, timestamp) -- Format timestamp
time(dateTable) -- Convert date table to timestamp
```

## Saved Variables

**MidnightTrackerDB Structure:**
```lua
{
  minimap = {
    hide = false,              -- Whether icon is hidden
    minimapPos = 225,          -- Icon position (degrees)
    lock = false,              -- Whether icon is locked in place
  },
  settings = {
    showZeroCurrencies = false, -- Show currencies with 0 amount
    categories = {
      showPrePatch = true,
      showUpgrade = true,
      showPvP = true,
      showWeekly = true,
      showSeasonal = true,
      showMisc = true,
    },
    debug = false,             -- Enable debug logging
  },
}
```

## Performance Considerations

**Optimization Strategies:**
1. **Caching** - Currency data cached and updated every 5 seconds (not per frame)
2. **Lazy Loading** - Tooltip only built when hovering over icon
3. **Smart Display** - Only shows discovered currencies, reduces processing
4. **Minimal Events** - Only registers necessary game events
5. **Efficient Updates** - Batch currency updates rather than individual calls

**Memory Usage:**
- Expected: <2MB
- Mostly from embedded libraries (~1.5MB)
- Currency cache is minimal (small data structures)

## Current Limitations

**Not Yet Implemented:**
1. Configuration UI panel (planned)
2. Weekly quest completion tracking (data structure ready)
3. Multi-character tracking (current character only)
4. Historical tracking (daily/weekly currency gains)
5. Alert notifications for near-cap currencies
6. Custom category filters beyond show/hide

**Known Constraints:**
1. Requires player to discover currencies before tracking
2. Weekly reset time calculation assumes US servers (configurable in code)
3. Great Vault API may change between expansions
4. Some currency IDs may be placeholders (need actual Midnight IDs)

## Testing Checklist

Before release, verify:
- [ ] Addon loads without Lua errors
- [ ] Minimap icon appears on login
- [ ] Tooltip displays on hover
- [ ] Currency amounts match in-game currency tab
- [ ] Great Vault progress accurate
- [ ] Weekly reset timer calculates correctly
- [ ] Color coding works (test with different currency amounts)
- [ ] Slash commands function properly
- [ ] Icon can be dragged and position saves
- [ ] `/reload` preserves settings
- [ ] Works on fresh character (no currencies discovered)
- [ ] Works on max-level character (many currencies)

## Future Enhancement Ideas

**Phase 2 Features:**
1. Configuration UI using Settings.RegisterCanvasLayoutCategory
2. Left-click to open summary frame (alternative to tooltip)
3. Right-click menu for quick settings
4. Alert system for currencies near cap
5. Track currency gains over time (graphs)

**Phase 3 Features:**
1. Multi-character summary view
2. Account-wide currency tracking
3. Export data to CSV/JSON
4. Integration with other addons (WeakAuras, TellMeWhen)
5. Mobile companion app data export

**Long-term Possibilities:**
1. Machine learning predictions for weekly earnings
2. Optimal farming route suggestions
3. Currency spending recommendations
4. Integration with auction house for gold value
5. Discord bot integration for guild tracking

## Installation for Users

Users should:
1. Copy entire `MidnightTracker/` folder to WoW AddOns directory
2. Ensure folder name is exactly "MidnightTracker"
3. Verify `.toc` file matches folder name
4. Enable addon at character select screen
5. Look for minimap icon after login

See `INSTALL.txt` for detailed user instructions.

## Maintenance Notes

**Updating for New Currencies:**
1. Add entry to appropriate category in `Data.lua`
2. Format: `{currencyID, "Name", weeklyMax, iconFileID}`
3. Get IDs from Wowhead or `/dump C_CurrencyInfo.GetCurrencyInfo(ID)`

**Updating Interface Version:**
1. Edit `MidnightTracker.toc`
2. Change `## Interface:` line to match current expansion version
3. Format: XXYYZZ (11.2.0 = 110200)

**Adding New Categories:**
1. Add to `CATEGORY` table in `Data.lua`
2. Add category key to settings defaults in `Core.lua`
3. Add mapping in `Tracker:GetCategorySettingKey()`

## Developer Notes

**Code Style:**
- Uses WoW addon standard conventions
- Namespace: `MidnightTracker` global, `addon` local
- Events: Centralized in `Core.lua` event handlers
- Modules: Self-contained with public functions
- Comments: Inline for complex logic, function headers for APIs

**Debugging:**
- Enable with `/mt debug`
- Use `addon.Utils:Debug("message")` in code
- Check for Lua errors with `/console scriptErrors 1`
- Test currency IDs with `/dump C_CurrencyInfo.GetCurrencyInfo(ID)`

**Common WoW Addon Gotchas:**
- Folder and TOC names must match exactly
- Files are case-sensitive on Mac
- SavedVariables only persist after proper logout
- `/reload` reloads UI but doesn't reset all state
- API availability varies by expansion (check for nil)

## Version History

**v1.0.0 - Initial Release**
- Core currency tracking
- Minimap tooltip display
- Great Vault progress tracking
- Weekly reset timer
- Category organization
- Smart currency discovery
- Color-coded caps
- Slash command interface

---

**Build Date:** 2026-02-13
**Target Expansion:** Midnight (11.2.0)
**Status:** Complete and ready for testing
