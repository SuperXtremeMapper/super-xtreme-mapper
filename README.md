# Super Xtreme Mapper

A native macOS TSI editor for Traktor Pro. Create, edit, and manage your MIDI controller mappings with a modern, intuitive interface.

**Free and open source.**

**Website:** [superxtrememapper.github.io/super-xtreme-mapper](https://superxtrememapper.github.io/super-xtreme-mapper)

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-native-green)
![License](https://img.shields.io/badge/license-MIT-orange)
![Status](https://img.shields.io/badge/status-beta-yellow)

## Features

- **Visual Mapping Table** - See all your mappings at a glance in a clean, sortable table. Filter by I/O type, assignment, or search for specific commands.

- **Full MIDI Control** - Edit channels, CC numbers, notes, and all MIDI parameters. Full support for buttons, faders, encoders, and LEDs.

- **Modifier Logic** - Full support for Traktor's 8-modifier system. Set conditions for when mappings activate and define modifier changes.

- **Drag & Drop** - Copy mappings between files with simple drag and drop. Open multiple TSI files side by side.

- **All Traktor Commands** - Access to the complete Traktor command library with 500+ commands. Browse by category or search.

- **Native macOS** - Built with SwiftUI for Apple Silicon. Fast, memory efficient, with full dark mode and keyboard shortcut support.

## Installation

### Download

Download the latest `.dmg` from the [Releases](https://github.com/SuperXtremeMapper/super-xtreme-mapper/releases) page.

### Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1/M2/M3) or Intel

### Gatekeeper Notice

Since SXM is not signed with an Apple Developer certificate, macOS will initially block the app. To install:

1. Download and open the `.dmg` file
2. Drag Super Xtreme Mapper to your Applications folder
3. **Right-click** (or Control-click) the app and select **Open**
4. Click **Open** in the dialog that appears
5. The app will open normally from now on

**Alternative:** Go to `System Settings > Privacy & Security` and click "Open Anyway".

## Building from Source

### Prerequisites

- Xcode 15.0+
- macOS 13.0+

### Build

```bash
git clone https://github.com/SuperXtremeMapper/super-xtreme-mapper.git
cd super-xtreme-mapper/XtremeMapping
open XtremeMapping.xcodeproj
```

Build and run with `Cmd+R` in Xcode.

## The Story

We used to love [Xtreme Mapping](https://www.xtrememapping.com/). It was the only decent TSI editor out there, and it made creating custom Traktor mappings almost enjoyable.

Then Apple Silicon happened, and Xtreme Mapping stopped working. Our attempts to contact the original author were met with silence. After years of waiting and hoping, we decided to take matters into our own hands.

Using **Claude Code**, we reverse-engineered a completely new TSI editor from a combination of Xtreme Mapping screenshots, the [CMDR editor](https://cmdr-editor.github.io/cmdr/) source code, and [IvanZ's](https://github.com/ivanz) invaluable TSI format research.

The result is Super Xtreme Mapper: a love letter to the original, rebuilt from the ground up for modern Macs.

## Technical Details

### TSI File Format

TSI files are XML documents containing Base64-encoded binary data. The binary data uses an ID3v2-like frame format for storing controller mappings. This project includes a complete Swift implementation for parsing and writing TSI files.

### Architecture

```
XtremeMapping/
├── Models/
│   ├── TSI/              # TSI file parsing and writing
│   │   ├── TSIParser     # XML/binary extraction
│   │   ├── TSIInterpreter # Frame interpretation
│   │   ├── TSIWriter     # File serialization
│   │   └── TraktorCommands # Command database
│   ├── MappingEntry      # Individual mapping model
│   ├── MappingFile       # Document model
│   └── Device            # Controller device model
├── Views/
│   ├── ContentView       # Main document view
│   ├── MappingsTableView # Mapping list table
│   ├── SettingsPanel     # Mapping editor panel
│   └── Components/       # Reusable UI components
└── Utilities/
    └── CommandCategoryMatcher # Command categorization
```

## Credits & Acknowledgments

- **Vincenzo Pietropaolo** - Creator of the original Xtreme Mapping that inspired this project
- **[IvanZ](https://github.com/ivanz)** - TSI format research and documentation
- **[CMDR Team](https://cmdr-editor.github.io/cmdr/)** - Traktor command database and editor reference
- **[Anthropic Claude](https://claude.ai)** - AI-assisted development

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

Traktor is a registered trademark of Native Instruments GmbH. This project is **not affiliated with, endorsed by, or sponsored by Native Instruments**. All product names, logos, and brands are property of their respective owners.

---

**Important:** This is beta software. Always backup your TSI files before editing them. We are not responsible for any data loss or corrupted mappings.

## Contact

- Email: [SXTREMEMAPPER@PROTON.ME](mailto:SXTREMEMAPPER@PROTON.ME)
- Issues: [GitHub Issues](https://github.com/SuperXtremeMapper/super-xtreme-mapper/issues)
- Discussions: [GitHub Discussions](https://github.com/SuperXtremeMapper/super-xtreme-mapper/discussions)
