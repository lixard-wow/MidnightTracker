# Text Abbreviation Feature Implementation

## Overview
Added comprehensive number abbreviation system to make large currency values more readable.

## What Was Added

### 1. Core Functions (Core.lua)
Added three new utility functions to `addon.Utils`:

#### `AbbreviateNumber(num)`
- Converts large numbers to abbreviated format
- 1,500,000 → "1.5M"
- 5,200 → "5.2K"
- 42 → "42"
- Respects the `abbreviateNumbers` setting

#### `FormatAmount(num)`
- Smart formatting that chooses between abbreviation and comma-separated based on settings
- Uses `AbbreviateNumber()` if enabled (default)
- Falls back to `FormatNumber()` if disabled

### 2. Configuration Option
Added `abbreviateNumbers` setting:
- **Default:** `true` (enabled)
- **Location:** `addon.db.settings.abbreviateNumbers`
- **UI:** Checkbox in General Settings tab
- **Slash Command:** `/mtrack abbreviate` to toggle

### 3. Display Updates

#### Main Currency Display (Display.lua)
**Before:**
```lua
if amount >= 1000000 then
    amountText = format("%.1fM", amount / 1000000)
elseif amount >= 1000 then
    amountText = format("%.1fK", amount / 1000)
else
    amountText = tostring(amount)
end
```

**After:**
```lua
amountText = addon.Utils:AbbreviateNumber(amount)
```

Simplified and centralized the abbreviation logic for both capped and uncapped currencies.

#### Alt Dashboard Crest Columns
Updated all 4 crest columns to use abbreviation:
- Weathered Crest (3285)
- Carved Crest (3288)
- Runed Crest (3289)
- Gilded Crest (3290)

**Before:** `weatheredText:SetText(tostring(amount))`
**After:** `weatheredText:SetText(addon.Utils:AbbreviateNumber(amount))`

### 4. User Controls

#### Slash Commands
```
/mtrack abbreviate    - Toggle abbreviation on/off
/mtrack abbrev        - Short version
```

#### Config Panel
- **Tab:** General Settings
- **Checkbox:** "Abbreviate large numbers (1.5M instead of 1,500,000)"
- **Location:** Below "Show undiscovered currencies"

## Examples

### Main Currency Display
| Setting | Amount | Display |
|---------|--------|---------|
| ON | 2,450,000 | 2.5M |
| ON | 15,750 | 15.8K |
| ON | 350 | 350 |
| OFF | 2,450,000 | 2,450,000 |

### Capped Currencies
| Setting | Amount/Max | Display |
|---------|------------|---------|
| ON | 1250/2000 | 1.3K/2.0K |
| ON | 850000/1000000 | 850.0K/1.0M |
| OFF | 1250/2000 | 1250/2000 |

### Alt Dashboard
| Setting | Gilded Crests | Display |
|---------|---------------|---------|
| ON | 1847 | 1.8K |
| ON | 45 | 45 |
| OFF | 1847 | 1847 |

## Benefits

1. **Readability** - Large numbers are easier to scan at a glance
2. **Space Efficiency** - Shorter text takes less screen space
3. **Consistency** - Same abbreviation logic across all displays
4. **User Control** - Can be toggled on/off per preference
5. **Backward Compatible** - Defaults to ON, but can disable to see full numbers

## Technical Details

### Threshold Logic
- **≥ 1,000,000:** Show as millions (M) with 1 decimal place
- **≥ 1,000:** Show as thousands (K) with 1 decimal place
- **< 1,000:** Show as-is (no abbreviation)

### Decimal Precision
- Uses `%.1f` format for consistency (always 1 decimal place)
- Examples: 1.2M, 5.7K (never 1.25M or 5.73K)

### Settings Integration
- Setting stored in `MidnightTrackerDB.settings.abbreviateNumbers`
- Defaults to `true` for new users
- Existing users will get `true` via `InitializeDefaults()`
- Updates apply immediately when toggled (triggers `UpdateDisplay()`)

## Future Enhancements (Not Implemented)

Possible additions if users request:

1. **Configurable Thresholds** - Let users choose when to abbreviate (e.g., only above 10K)
2. **Different Formats** - Toggle between "1.5M" vs "1,500K" vs "1.5 million"
3. **Tooltip Full Numbers** - Always show full number in tooltip regardless of setting
4. **Context-Aware** - Abbreviate in main display, full numbers in alt dashboard
5. **Per-Currency Override** - Abbreviate some currencies but not others

## Files Modified

1. **Core.lua**
   - Added 3 utility functions
   - Added default setting
   - Added slash command
   - Updated help text

2. **Display.lua**
   - Simplified main currency formatting (lines 385-394)
   - Updated alt dashboard crest columns (4 locations)

3. **Config.lua**
   - Added checkbox in General Settings tab

## Testing Checklist

- [x] Main currency display shows abbreviated numbers
- [x] Capped currencies show both values abbreviated (X/Y format)
- [x] Alt dashboard crest columns abbreviate
- [x] Slash command toggles setting
- [x] Config checkbox toggles setting
- [x] Display updates immediately when toggled
- [x] Setting persists across sessions
- [x] Works with large numbers (millions)
- [x] Works with medium numbers (thousands)
- [x] Doesn't affect small numbers (<1000)
- [x] Tooltips still show full numbers with commas

## Notes

- The tooltip hover already uses `FormatNumber()` which adds commas but doesn't abbreviate - this is intentional for precision
- Original hardcoded abbreviation in Display.lua was replaced with centralized function
- All currency displays now use the same abbreviation logic for consistency
- The setting defaults to `true` (enabled) because abbreviation is generally preferred for readability
