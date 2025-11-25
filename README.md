# LiveKit GDExtension for Godot 4

Native LiveKit client implementation using Rust GDExtension for high-performance spatial audio in Godot VR/XR applications.

## Features

✨ **Native Integration**
- Direct access to Godot's audio system (no WebSocket IPC overhead)
- Per-participant AudioStreamPlayer3D with automatic spatialization
- Single process architecture (< 1ms latency for position updates)

🎵 **Spatial Audio**
- Godot handles HRTF and 3D audio processing
- Automatic attenuation and doppler effects
- Easy positioning via XRCamera3D parent-child relationships

🚀 **Performance**
- Zero IPC overhead
- Direct memory access
- Typical frame latency: < 1ms vs 2-5ms with WebSocket bridge

🎮 **Developer Experience**
- Simple GDScript API
- Signals for all events
- Works as a standard Godot addon

## Installation

### End Users (Pre-built Binaries)

1. Download the latest release for your platform
2. Extract to your project's `addons/` directory
3. Enable the plugin in Godot: Project → Project Settings → Plugins → LiveKit GDExtension
4. Restart Godot

### Developers (Building from Source)

#### Prerequisites
- Rust toolchain: https://rustup.rs/
- Godot 4.2+

#### Build Instructions

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Build for your platform
cd rust
cargo build --release

# The library will automatically be copied to addons/godot-livekit/bin/
```

#### Cross-Compilation

See [RUST_DEVELOPMENT.md](RUST_DEVELOPMENT.md) for detailed cross-compilation instructions.

## Usage

### Basic Example

```gdscript
extends Node3D

@onready var livekit_client = LiveKitClient.new()

func _ready():
	# Add LiveKitClient as child of XRCamera3D for automatic position tracking
	$XRCamera3D.add_child(livekit_client)
	
	# Connect signals
	livekit_client.room_connected.connect(_on_room_connected)
	livekit_client.participant_joined.connect(_on_participant_joined)
	
	# Connect to room
	livekit_client.connect_to_room(
		"https://your-livekit-server.com",
		"your_access_token"
	)

func _on_room_connected():
	print("Connected to LiveKit room!")

func _on_participant_joined(identity: String):
	print("Participant joined: ", identity)
	
	# Create spatial audio for participant
	var participant_audio = livekit_client.create_participant_audio(identity)
	
	# Position in 3D space
	participant_audio.set_spatial_position(Vector3(5, 0, 0))
```

### VR Spatial Audio Example

```gdscript
extends Node3D

var livekit_client: LiveKitClient
var participant_positions := {}

func _ready():
	livekit_client = LiveKitClient.new()
	livekit_client.server_url = "https://your-server.com"
	livekit_client.room_name = "vr-room"
	livekit_client.participant_name = "Player1"
	
	# Attach to XR camera for automatic listener positioning
	$XROrigin3D/XRCamera3D.add_child(livekit_client)
	
	livekit_client.participant_joined.connect(_on_participant_joined)
	livekit_client.track_subscribed.connect(_on_track_subscribed)

func _on_participant_joined(identity: String):
	# Create 3D audio player (extends AudioStreamPlayer3D)
	var audio_player = livekit_client.create_participant_audio(identity)
	audio_player.set_attenuation(-6.0)  # Adjust volume
	participant_positions[identity] = audio_player

func update_participant_position(identity: String, pos: Vector3):
	if identity in participant_positions:
		participant_positions[identity].set_spatial_position(pos)
```

## API Reference

### LiveKitClient (Node)

Main client class for LiveKit room management.

#### Properties
- `server_url : String` - LiveKit server URL
- `room_name : String` - Room name to join
- `participant_name : String` - Local participant name

#### Methods
- `connect_to_room(url: String, token: String)` - Connect to LiveKit room
- `disconnect()` - Disconnect from room
- `is_room_connected() -> bool` - Check connection status
- `create_participant_audio(participant_id: String) -> Node` - Create audio player for participant
- `get_local_participant_id() -> String` - Get local participant identity

#### Signals
- `room_connected()` - Emitted when connected to room
- `room_disconnected()` - Emitted when disconnected
- `participant_joined(identity: String)` - Emitted when participant joins
- `participant_left(identity: String)` - Emitted when participant leaves
- `track_subscribed(participant_identity: String, track_sid: String)` - Emitted when audio track is subscribed

### ParticipantAudio (AudioStreamPlayer3D)

Spatial audio player for individual participants.

#### Methods
- `set_participant_id(id: String)` - Set participant identifier
- `get_participant_id() -> String` - Get participant identifier
- `push_audio_frame(samples: PackedFloat32Array)` - Push audio samples for playback
- `set_spatial_position(position: Vector3)` - Set 3D position
- `set_attenuation(db: float)` - Set volume attenuation

## Architecture

```
Godot Process
├── Game Scene (GDScript)
├── GDExtension Plugin (Rust)
│   ├── LiveKitClient (manages room connection)
│   ├── AudioHandler (captures mic, processes audio)
│   └── ParticipantAudio (per-participant 3D audio)
└── Godot Audio System (HRTF, spatialization, output)
```

## Platform Support

| Platform | Status | Architecture |
|----------|--------|--------------|
| Windows | ✅ Supported | x86_64 |
| Linux | ✅ Supported | x86_64 |
| macOS | ✅ Supported | Universal |
| Android (Quest) | 🚧 Planned | arm64 |
| iOS | 🚧 Planned | arm64 |

## Performance Metrics

Compared to WebSocket bridge approach:

| Metric | GDExtension | WebSocket Bridge |
|--------|-------------|------------------|
| Position Update Latency | < 1ms | 2-5ms |
| CPU Overhead | Minimal | Moderate |
| Memory Usage | Lower | Higher (2 processes) |
| Build Complexity | Medium | Low |
| Debugging Ease | Medium | High |

## Troubleshooting

### "GDExtension not found" error
- Ensure the library is built for your platform
- Check that the `.gdextension` file points to the correct library path
- Try rebuilding: `cd rust && cargo build --release`

### No audio from participants
- Verify audio input is enabled in Project Settings → Audio → driver/enable_input
- Check that AudioStreamPlayer3D nodes are created for participants
- Ensure participants are publishing audio tracks

### Crashes in Godot editor
- This is a development issue - file a bug report with stack trace
- Try building in debug mode: `cargo build` (without --release)
- Check compatibility with your Godot version (requires 4.2+)

## Contributing

See [RUST_DEVELOPMENT.md](RUST_DEVELOPMENT.md) for development setup and guidelines.

## License

MIT License - see LICENSE file for details.

## Credits

Built with:
- [godot-rust (gdext)](https://github.com/godot-rust/gdext)
- [LiveKit Rust SDK](https://github.com/livekit/rust-sdks)
