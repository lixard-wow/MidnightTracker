# MidnightTracker

A comprehensive World of Warcraft addon for tracking Midnight expansion currencies, weekly activities, and progression.

## Features

- **Minimap Icon**: Lightweight minimap button with tooltip display
- **Currency Tracking**: Automatically tracks all discovered Midnight expansion currencies
- **Smart Display**: Shows currencies you've discovered, hides zero-value currencies by default
- **Category Organization**: Currencies organized by type (Pre-Patch, Upgrade Materials, PvP, etc.)
- **Weekly Reset Timer**: Displays time until next weekly reset
- **Great Vault Progress**: Track your raid, Mythic+, and world activity progress
- **Color Coding**: Visual indicators for currency caps (green/yellow/red)
- **Current Character Only**: Focuses on your active character's progress

## Installation

1. **Locate your WoW AddOns folder:**
   - Windows: `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\`
   - Mac: `/Applications/World of Warcraft/_retail_/Interface/AddOns/`

2. **Copy the entire `MidnightTracker` folder into the AddOns directory**

3. **Restart World of Warcraft** (or type `/reload` if already in-game)

4. **Verify the addon is loaded:**
   - At character select, click "AddOns" button
   - Find "MidnightTracker" in the list and ensure it's checked

## Usage

### Minimap Icon
- **Hover** over the minimap icon to view all tracked currencies and progress
- **Drag** the icon around the minimap to reposition it
- The icon appears automatically when you first log in

### Slash Commands
- `/mt` or `/midnighttracker` - Show available commands
- `/mt show` - Show the minimap icon
- `/mt hide` - Hide the minimap icon
- `/mt reset` - Reset minimap icon position to default
- `/mt debug` - Toggle debug mode

## Tracked Content

### Pre-Patch Event
- Twilight's Blade Insignia

### Upgrade Materials
- Flightstones
- Runed/Carved/Weathered Harbinger Crests
- Valorstones
- Mysterious Fragment

### PvP Currencies
- Conquest
- Honor

### Seasonal Events
- Darkmoon Prize Ticket
- Timewarped Badge
- Champion's Seal
- And more...

### Weekly Activities
- Great Vault Progress (Raids, Mythic+, World/Delves)
- Weekly quest tracking (coming soon)

## Configuration

Currently, the addon works out of the box with minimal configuration needed. Advanced settings will be added in future versions.

## Troubleshooting

### Addon not loading
- Ensure the folder is named exactly `MidnightTracker`
- Verify the `.toc` file is named `MidnightTracker.toc`
- Check that "Load out of date AddOns" is enabled if playing on beta/PTR

### Minimap icon not showing
- Type `/mt show` to display the icon
- Check that the icon isn't hidden behind other addon icons

### Currency not displaying
- The addon only shows currencies you've discovered
- Zero-value currencies are hidden by default
- Use `/mt debug` to enable debug mode for troubleshooting

## Future Enhancements

- Configuration UI panel
- Multi-character tracking and comparison
- Historical tracking (currency gained per day/week)
- Alert notifications when near caps
- Custom category filters
- Weekly quest completion tracking
- More detailed Great Vault information

## Support

For bug reports, feature requests, or questions:
- Create an issue on GitHub (if repository is set up)
- Contact the addon author

## Version History

### 1.0.0 (Initial Release)
- Core currency tracking functionality
- Minimap icon with tooltip display
- Great Vault progress tracking
- Category-based organization
- Weekly reset timer
- Slash command support

## Credits

- Built with LibStub, LibDataBroker-1.1, and LibDBIcon-1.0
- Designed for the World of Warcraft Midnight expansion

## License

This addon is free to use and modify for personal use.
