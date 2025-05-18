# Godot Online P2P - Installation

## Requirements
- **[Godot 4.x](https://godotengine.org/download)**
- **[WebRTC-Native](https://github.com/godotengine/webrtc-native/releases)** _(YOU NEED THIS FOR THE PROJECT TO WORK!)_

## Installation Steps
1. Download the plugin files from the asset library.
2. Enable the plugin in **Project Settings**.
3. Place the **WebRTC-Native** folder inside your project.
4. Configure `go_settings.gd`.

### Example `go_settings.gd` Configuration:
```gdscript
var SERVER_MODE = false  # Set true if running a server
var API_KEY = "your_api_key_here"  # TODO: You can put anything you want less than 128 byte.
var VERSION = "version_roma"  # Production version or use "version_local" for local test
