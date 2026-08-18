# IconForge

A jailbreak-only iOS/iPadOS application for complete Home Screen icon customization.

## Requirements

- Jailbroken iOS/iPadOS 14–18
- Root or rootless filesystem access
- Swift 5.9+

## Features

- Discover all installed applications
- Replace application icons with custom images
- Built-in icon editor with adjustments, effects, and shape masking
- Create, import, export, and share `.iconpack` files
- Backup and restore original icons
- Bulk icon application
- Diagnostics and logging
- Supports rootful and rootless jailbreaks

## Build

1. Open the project in Xcode
2. Select your jailbroken device as the build target
3. Build and sign with a jailbreak-compatible method (e.g., AltStore, Sideloadly, or directly via `make package install` with Theos)
4. Install on device

## Architecture

- **UI Layer** — SwiftUI views and view models
- **Core Layer** — App discovery, icon rendering, backup, pack management
- **Jailbreak Layer** — Jailbreak detection, filesystem access, icon cache, respring
- **Backends** — iOS version-specific icon application implementations (iOS 14–18)
- **Security** — Path sanitization, validation, operation guards
