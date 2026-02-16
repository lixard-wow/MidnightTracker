# Great Vault Threshold Fix

## Issue
The Great Vault thresholds for raid progress were incorrectly showing as **2/4/8** instead of the correct **2/4/6** bosses needed for vault slots.

## Root Cause
In `Tracker.lua`, the vault progress was initialized with hardcoded thresholds:
```lua
raid = {current = 0, max = 8, thresholds = {2, 4, 8}, levels = {0, 0, 0}},
```

This was incorrect for War Within Season 3 raid requirements.

## Correct Thresholds (War Within)

### Raid (Nerub-ar Palace / Liberation of Undermine)
- **Slot 1:** Kill 2 raid bosses
- **Slot 2:** Kill 4 raid bosses
- **Slot 3:** Kill 6 raid bosses ✅ (was incorrectly 8)

### Mythic+ Dungeons
- **Slot 1:** Complete 1 M+ dungeon (any level) ✅ (was incorrectly 2)
- **Slot 2:** Complete 4 M+ dungeons
- **Slot 3:** Complete 8 M+ dungeons

### World Content (Delves, World Quests, etc.)
- **Slot 1:** Complete 2 world activities ✅ (was correct)
- **Slot 2:** Complete 5 world activities ✅ (was incorrectly 4)
- **Slot 3:** Complete 8 world activities ✅ (was correct)

## Fix Applied

### 1. Corrected Hardcoded Defaults
Updated the default thresholds in `Tracker.lua`:
```lua
local progress = {
    raid = {current = 0, max = 8, thresholds = {2, 4, 6}, levels = {0, 0, 0}},
    mythicplus = {current = 0, max = 8, thresholds = {1, 4, 8}, levels = {0, 0, 0}},
    world = {current = 0, max = 8, thresholds = {2, 5, 8}, levels = {0, 0, 0}},
}
```

### 2. Added Dynamic API Threshold Reading
Enhanced the `assignLevels()` function to extract actual thresholds from the WoW API:
```lua
-- Extract thresholds from API (overrides hardcoded defaults)
local apiThresholds = {}
for i, activity in ipairs(activityList) do
    if i <= 3 then
        progressData.levels[i] = activity.level or 0
        if activity.threshold then
            apiThresholds[i] = activity.threshold
        end
    end
end

-- Use API thresholds if available, otherwise keep defaults
if #apiThresholds == 3 then
    progressData.thresholds = apiThresholds
end
```

## Benefits

1. **Immediate Fix:** Corrects the displayed thresholds to match current game behavior
2. **Future-Proof:** Dynamically reads from API, so changes in future seasons will be automatic
3. **Backward Compatible:** Keeps hardcoded defaults as fallback if API is unavailable
4. **Accurate Display:** Users will now see correct progress (e.g., "7/6" shows all 3 slots unlocked)

## Example Before/After

### Before (Incorrect)
```
Raid Progress: 7/8
Vault Slots: 2 ✓ | 4 ✓ | 8 ✗  (slot 3 shown as locked despite 7 bosses)
```

### After (Correct)
```
Raid Progress: 7/8
Vault Slots: 2 ✓ | 4 ✓ | 6 ✓  (all 3 slots unlocked)
```

## Impact

### Displays Affected
- Main vault progress display
- Alt dashboard vault columns
- Checklist vault tasks
- Minimap tooltip vault progress
- Weekly Tracker panel

### User Experience
- Accurately reflects vault slot unlock status
- Prevents confusion about vault requirements
- Shows correct progress bars (e.g., 7/6 = complete, not 7/8 = incomplete)

## Testing

To verify the fix:
1. Kill 7 raid bosses in current tier
2. Check vault display - should show all 3 slots unlocked (7 >= 6)
3. Hover tooltip - should show thresholds as "2/4/6" not "2/4/8"
4. Alt dashboard - should show 3/3 vault slots for characters with 6+ bosses

## Historical Context

These thresholds have changed over expansions:
- **Shadowlands:** 3/5/10 bosses for raid vault
- **Dragonflight Season 1-2:** 2/4/8 bosses
- **Dragonflight Season 3:** 2/4/6 bosses (changed!)
- **War Within Season 1-3:** 2/4/6 bosses (current)

The dynamic API reading ensures we automatically adapt to any future changes.

## Files Modified

- **Tracker.lua** (lines 150-152, 174-192)
  - Updated hardcoded defaults
  - Added API threshold extraction
  - Enhanced assignLevels() function

## Date Fixed
2026-02-15
