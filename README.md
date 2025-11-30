# Pet Stable Management

A World of Warcraft addon that provides an advanced pet stable management panel with sorting, filtering, and persistent data storage capabilities.

## Description

Pet Stable Management is a comprehensive addon suite for World of Warcraft hunters, providing two powerful tools for pet management:

1. **Owned Pets Management**: An advanced stable panel for organizing, sorting, and maintaining your existing pet collection
2. **Tameable Pets Discovery**: A pet model browser to explore and discover new pets to tame in the wild

Together, these tools give you complete control over your pet hunting journey, from stable cleanup to finding your next rare capture.

## Features

### Owned Pets Management (Main Panel)
- **Advanced Sorting**: Sort pets by display ID, slot number, or other criteria
- **Powerful Filtering**: Filter by exotic pets, duplicates only, pet families, and specializations
- **Visual Indicators**: Duplicate pets highlighted with red background for easy identification
- **Persistent Data Storage**: Maintains pet data snapshots for offline viewing and analysis
- **Minimap Button**: Quick access to the management panel
- **CSV Export**: Export your pet data to CSV format for external analysis
- **Pet Reordering**: Easily reorder pets within your stable
- **Slash Commands**: Access features via chat commands
- **Snapshot Mode**: View saved pet data even when the stable is closed

### Tameable Pets Discovery (Pet Models Panel)
- **Pet Model Browser**: Browse through extensive pet model data to discover interesting looks you haven't tamed yet
- **Owned Model Highlighting**: Models you already own are highlighted in green for quick identification
- **Favorites System**: Add promising models to your favorites list for later tracking
- **NPC Information**: Get NPC IDs and names for Wowhead research on spawn locations and taming strategies
- **Memory Optimized**: Minimal data footprint to keep performance smooth while providing essential information

## Installation

1. Download the addon files
2. Extract the `PetStableManagement` folder to your World of Warcraft addons directory:
   - Retail: `World of Warcraft/_retail_/Interface/AddOns/`
3. Restart World of Warcraft or reload your UI with `/reload`
4. The addon will automatically load when you log in

## Usage

### Accessing the Panel
- Open your pet stable (visit a stable master)
- The Pet Stable Management panel will appear automatically
- Alternatively, use the minimap button for quick access

### Sorting and Filtering
- Use the sort buttons to organize pets by different criteria
- Apply filters to show only exotic pets, duplicates, or specific families/specializations

### Exporting Data
- Click the "Export" button in the panel
- Copy the CSV data and paste it into a spreadsheet or text editor
- The export includes detailed pet information including abilities, levels, and stats

### Snapshot Mode
- When the stable is closed, the panel switches to snapshot mode
- View your last saved pet data without needing to visit a stable master

### Pet Models Panel
- Access the pet model browser to explore tameable pets
- Browse different models, families, and specializations
- Add interesting models to your favorites for later research
- Get NPC information to look up spawn locations and taming details on Wowhead

## Slash Commands

- `/psm` - Toggle the main panel
- `/psm show` - Show the minimap button
- `/psm hide` - Hide the minimap button
- `/psm models` - Toggle the pet models panel
- `/petswap [slot1] [slot2]` - Swap pets between stable slots (requires being at a stable master)

## Settings

The addon saves settings in `PetStableManagementDB`. You can modify:
- Sorting preferences
- Filter settings
- Minimap button position and visibility
- Other UI preferences

## Compatibility

- Requires World of Warcraft Retail
- Optional dependency: Blizzard_StableUI
- Compatible with most UI mods (ElvUI skinning support included)

## Credits

- **Author**: Ginutty
- **Version**: 4.0.0
- Inspired by the need for better pet stable management in World of Warcraft

## Support

If you encounter issues or have suggestions, please add your comments on CurseForge.

## Changelog

### Version 4.0.0
- Major UI overhaul
- Added CSV export functionality
- Improved sorting and filtering options
- Enhanced persistent data storage
- Added minimap button
- Pet reordering capabilities
- Snapshot mode for offline viewing
- **New: Pet Models Panel** - Browse and discover tameable pet models with favorites system and NPC information for research