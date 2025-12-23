# AFX Nuke Plugins

A collection of high-performance compositing plugins for Foundry Nuke, originally created by [Ryan P Wilson (AuthorityFX)](https://github.com/AuthorityFX/afx-nuke-plugins).

This fork provides **pre-built binaries for Nuke 14.1+** across all platforms, including Metal support for macOS.

## Compatibility

| Platform | Architecture | GPU Acceleration |
|----------|--------------|------------------|
| Windows  | x64          | CUDA             |
| Linux    | x64          | CUDA             |
| macOS    | ARM64/x64    | Metal            |

**Nuke Version:** 14.1 and later

## Installation

1. Download the appropriate folder from `COMPILED/` for your OS
2. Copy the contents to your `.nuke` directory or a custom plugin path
3. Add the path to Nuke:

**Option A:** Add to your `init.py`:
```python
nuke.pluginAddPath('/path/to/afx-plugins')
```

4. Restart Nuke — plugins appear under **Authority FX** in the node menu

## Plugins

### AFXSoftClip
Non-linear exposure reduction. More intuitive than Nuke's native soft clip implementation — originally developed for Eyeon Fusion.

### AFXToneMap
Combined exposure control, soft clipping, and dark contrast adjustment.

### AFXMedian
Extremely fast median filter — an order of magnitude faster than Nuke's native implementation. Features floating-point size control and a sharpness parameter to reduce unwanted morphological changes. **macOS version updated with Metal support.**

### AFXDespill
Uses Rodrigues rotation to shift screen hue. Calculates spill suppression using RGB-based algorithms and outputs a normalized spill matte.

## Changes in This Fork

- Updated for **Nuke 14.1+** compatibility
- **Metal support** for AFXMedian on macOS
- Pre-built binaries for all platforms

## Building from Source

If you need to compile the plugins yourself, see the platform-specific source folders:
- `LINUX_FILES/`
- `WINDOWS_FILES/`
- `MAC_FILES/`

### Requirements
- CUDA Toolkit (Windows/Linux)
- Metal SDK (macOS)
- Nuke NDK (included with Nuke installation)
- CMake

## License

[MPL-2.0](LICENSE)

## Credits

- **Original Author:** Ryan P Wilson / [AuthorityFX](https://github.com/AuthorityFX)
- **This Fork:** [Peter Mercell](https://github.com/petermercell)
