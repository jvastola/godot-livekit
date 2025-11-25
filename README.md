# Godot LiveKit Voice Chat Demo

Real-time voice chat for Godot 4 using LiveKit and Rust GDExtension.

## Features

- ✨ **Native Rust GDExtension** - High-performance LiveKit integration
- 🎤 **Real-time Voice Chat** - Multi-participant audio streaming
- 🎵 **Audio Visualization** - Mic levels and participant indicators
- 🚀 **Simple API** - Easy-to-use GDScript interface
- 🔊 **Spatial Audio Ready** - Built on AudioStreamPlayer for 3D positioning

## Quick Start

### 1. Prerequisites

- **Godot 4.2+**
- **Rust toolchain** (for building): https://rustup.rs/
- **LiveKit Server** (for testing): https://docs.livekit.io/home/self-hosting/local/

### 2. Build the GDExtension

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Build the extension
cd rust
cargo build --release

# On Windows, the DLL is automatically copied to addons/godot-livekit/bin/windows/
# On macOS:
cp target/release/libgodot_livekit.dylib ../addons/godot-livekit/bin/macos/libgodot_livekit.dylib
# On Linux:
cp target/release/libgodot_livekit.so ../addons/godot-livekit/bin/linux/libgodot_livekit.so
```

### 3. Start LiveKit Server

#### Using Docker (Recommended)
```bash
docker run --rm -p 7880:7880 \
  -e LIVEKIT_KEYS="devkey: secret" \
  livekit/livekit-server --dev
```

#### Using Local Binary
```bash
# Download from https://github.com/livekit/livekit/releases
livekit-server --dev --bind 0.0.0.0
```

The server runs on `ws://localhost:7880` with dev credentials.

### 4. Generate Access Tokens

```bash
# Using Python (recommended)
python generate_token.py

# The script generates tokens for multiple clients
# Copy the token for your client from the output
```

### 5. Run the Demo

1. Open project in Godot
2. Enable the plugin: **Project → Project Settings → Plugins → godot-livekit**
3. Restart Godot
4. Run the demo: **demo/GDExtensionTest.tscn** (F5)
5. The demo is pre-configured with a token for local development
6. Click **Connect**

### 6. Test with Multiple Clients

Open multiple Godot instances or use a web browser:

**Web Browser Testing:**
1. Go to https://meet.livekit.io/custom
2. Enter:
   - Server URL: `ws://localhost:7880`
   - Token: *(use CLIENT 2 or CLIENT 3 token from `MULTI_CLIENT_TOKENS.md`)*
3. Join and speak - you should hear each other!

## Usage

### Basic Example

```gdscript
extends Control

var livekit_manager: Node

func _ready():
	# Create LiveKitManager
	livekit_manager = ClassDB.instantiate("LiveKitManager")
	add_child(livekit_manager)
	
	# Connect signals
	livekit_manager.room_connected.connect(_on_room_connected)
	livekit_manager.participant_joined.connect(_on_participant_joined)
	
	# Connect to room
	livekit_manager.connect_to_room(
		"ws://localhost:7880",
		"your_access_token"
	)

func _on_room_connected():
	print("Connected to LiveKit room!")

func _on_participant_joined(identity: String):
	print("Participant joined: ", identity)
```

### API Reference

#### LiveKitManager

**Methods:**
- `connect_to_room(url: String, token: String)` - Connect to a LiveKit room
- `push_mic_audio(buffer: PackedVector2Array)` - Push microphone audio to the room
- `is_room_connected() -> bool` - Check if connected to room

**Signals:**
- `room_connected()` - Emitted when successfully connected
- `room_disconnected()` - Emitted when disconnected
- `participant_joined(identity: String)` - New participant joined
- `participant_left(identity: String)` - Participant left
- `on_audio_frame(peer_id: String, frame: PackedVector2Array)` - Audio data from participant
- `error_occurred(message: String)` - Error occurred

## Project Structure

```
godot-livekit/
├── rust/                      # Rust GDExtension source
│   ├── src/
│   │   ├── livekit_client.rs # Main LiveKit client
│   │   ├── audio_handler.rs  # Audio processing
│   │   └── lib.rs           # Library entry
│   └── Cargo.toml           # Rust dependencies
├── addons/godot-livekit/     # Godot plugin
│   ├── bin/                 # Platform-specific libraries
│   └── godot_livekit.gdextension
├── demo/                     # Demo scenes
│   ├── GDExtensionTest.tscn # Main demo scene
│   └── gdextension_test.gd  # Demo UI script
├── livekit-server/          # Local server setup
└── generate_token.py        # Token generation script
```

## Platform Support

| Platform | Status | Architecture |
|----------|--------|--------------|
| Windows  | ✅ Tested | x86_64 |
| macOS    | ✅ Tested | Universal (Intel + Apple Silicon) |
| Linux    | ✅ Supported | x86_64 |
| Android  | 🚧 Planned | arm64 |
| iOS      | 🚧 Planned | arm64 |

## Building for Different Platforms

### Windows
```bash
cd rust
cargo build --release
# Output: target/release/godot_livekit.dll
```

### macOS (Universal Binary)
```bash
cd rust
rustup target add x86_64-apple-darwin aarch64-apple-darwin
cargo build --release --target x86_64-apple-darwin
cargo build --release --target aarch64-apple-darwin
lipo -create \
  target/x86_64-apple-darwin/release/libgodot_livekit.dylib \
  target/aarch64-apple-darwin/release/libgodot_livekit.dylib \
  -output ../addons/godot-livekit/bin/macos/libgodot_livekit.dylib
```

### Linux
```bash
cd rust
cargo build --release
cp target/release/libgodot_livekit.so ../addons/godot-livekit/bin/linux/
```

## Troubleshooting

### "LiveKitManager class not found"
- Ensure the plugin is enabled in Project Settings → Plugins
- Restart Godot after building the extension
- Check that the library exists for your platform in `addons/godot-livekit/bin/`

### No audio from participants
- Audio input must be enabled: **Project Settings → Audio → driver/enable_input**
- Check that both clients are in the same room
- Verify tokens are valid and not expired (use `generate_token.py`)

### Connection fails
- Ensure LiveKit server is running on port 7880
- Check firewall settings
- Verify server URL starts with `ws://` (not `wss://` for local dev)

### Build errors
```bash
# Clean and rebuild
cd rust
cargo clean
cargo build --release
```

## Development

See additional documentation:
- [RUST_DEVELOPMENT.md](RUST_DEVELOPMENT.md) - Rust development guide
- [PARTICIPANT_FIX.md](PARTICIPANT_FIX.md) - Participant display fix details
- [MULTI_CLIENT_TOKENS.md](MULTI_CLIENT_TOKENS.md) - Multi-client testing guide

## License

MIT License - see LICENSE file for details.

## Credits

Built with:
- [godot-rust (gdext)](https://github.com/godot-rust/gdext)
- [LiveKit Rust SDK](https://github.com/livekit/rust-sdks)
- [LiveKit](https://livekit.io/)
