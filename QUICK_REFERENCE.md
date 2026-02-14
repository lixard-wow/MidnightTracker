# MidnightTracker - Quick Reference Guide

## Installation
1. Copy `MidnightTracker` folder to: `World of Warcraft\_retail_\Interface\AddOns\`
2. Restart WoW or type `/reload`
3. Look for minimap icon!

## Using the Addon

### Minimap Icon
- **Hover** - View all tracked currencies and progress
- **Drag** - Move icon around minimap
- **Left-Click** - (Coming soon)
- **Right-Click** - (Coming soon)

### Slash Commands
| Command | Description |
|---------|-------------|
| `/mt` or `/midnighttracker` | Show help |
| `/mt show` | Show minimap icon |
| `/mt hide` | Hide minimap icon |
| `/mt reset` | Reset icon to default position |
| `/mt debug` | Toggle debug mode |

## What's Tracked

### Pre-Patch Event
- Twilight's Blade Insignia

### Upgrade Materials
- Flightstones (weekly cap: 2,000)
- Runed/Carved/Weathered Harbinger Crests
- Valorstones
- Mysterious Fragment
- Crest Fragments

### PvP
- Conquest
- Honor

### Seasonal/Events
- Darkmoon Prize Ticket
- Timewarped Badge
- Champion's Seal
- Ironpaw Token
- Epicurean's Award
- Riders of Azeroth Badge

### Weekly Progress
- Great Vault (Raid/M+/World)
- Bountiful Delves (coming soon)
- Weekly event quests (coming soon)

## Tooltip Color Guide

| Color | Meaning |
|-------|---------|
| 🟢 Green | Plenty of room (<70% of cap) |
| 🟡 Yellow | Getting close (70-95% of cap) |
| 🔴 Red | Near or at cap (>95%) |
| ⚪ White | No cap / unlimited |

## Great Vault Progress

Progress bars show your weekly progress:
- 🟩 Green squares = Threshold reached
- ⬜ Gray squares = Not yet reached
- Format: `X/8 ███` (current progress / max)

**Thresholds:**
- 2 activities = 1 reward choice
- 4 activities = 2 reward choices
- 8 activities = 3 reward choices

## Display Settings

By default:
- ✅ Shows currencies you've discovered
- ✅ Hides currencies at zero
- ✅ Shows all categories
- ✅ Updates every 5 seconds

## Troubleshooting

### Icon not showing?
```
/mt show
```

### Wrong position?
```
/mt reset
```

### Lua errors?
```
/reload
```

### Currency not tracking?
- You must discover the currency first (earn at least 1)
- Check it's included in the tracked list
- Enable debug: `/mt debug`

### Addon not loading?
- Folder must be named exactly `MidnightTracker`
- Enable "Load out of date AddOns" (if on beta/PTR)
- Check AddOns button at character select

## File Locations

**Addon Files:**
```
<WoW>\_retail_\Interface\AddOns\MidnightTracker\
```

**Saved Settings:**
```
<WoW>\WTF\Account\<YourAccount>\SavedVariables\MidnightTracker.lua
```

## FAQ

**Q: Does it track alts?**
A: No, it only tracks your current character. Multi-character tracking is planned for future versions.

**Q: Can I customize what's shown?**
A: Currently minimal customization. Full configuration UI is planned.

**Q: Will it slow down my game?**
A: No, it's very lightweight (<2MB memory, updates every 5 seconds).

**Q: Can I move the icon?**
A: Yes! Just drag it around the minimap.

**Q: What if I get a new currency?**
A: If it's tracked by the addon, it will appear automatically once you earn it.

**Q: Does it work on Classic/TBC/Wrath?**
A: No, it's designed specifically for retail (Midnight expansion).

**Q: Can I hide certain categories?**
A: Not yet in the UI, but you can edit `Data.lua` or wait for the config panel.

## Tips & Tricks

1. **Position for convenience** - Drag the icon where you prefer it
2. **Check before capping** - Glance at the tooltip before weekly reset
3. **Color coding** - Red means you should spend soon!
4. **Weekly reset timer** - Plan your activities accordingly
5. **Great Vault** - Track which categories need more progress

## Coming Soon

- ⏳ Configuration UI panel
- ⏳ Weekly quest tracking
- ⏳ Multi-character comparison
- ⏳ Cap alert notifications
- ⏳ Historical tracking
- ⏳ Left-click UI frame

## Support & Feedback

Found a bug? Have a suggestion?
- Check `README.md` for more details
- Report issues to addon author
- Join the community (if Discord/forum exists)

## Version Info

**Current Version:** 1.0.0
**Last Updated:** 2026-02-13
**Compatible With:** Midnight (11.2.0)

---

💡 **Pro Tip:** Type `/mt` to see all commands anytime!
