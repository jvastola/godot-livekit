# Quick Reference: LiveKit GDExtension API

## LiveKitClient Node

### Creating Instance

```gdscript
# Method 1: Add programmatically
var livekit = LiveKitClient.new()
add_child(livekit)

# Method 2: Attach to XR Camera for spatial audio
var livekit = LiveKitClient.new()
$XROrigin3D/XRCamera3D.add_child(livekit)
```

### Connection

```gdscript
# Connect to room
livekit.connect_to_room("https://your-server.com", "your_token_here")

# Disconnect
livekit.disconnect()

# Check status
if livekit.is_room_connected():
    print("Connected!")
```

### Properties

```gdscript
livekit.server_url = "https://your-server.com"
livekit.room_name = "my-vr-room"
livekit.participant_name = "Player1"
```

### Signals

```gdscript
func _ready():
    livekit.room_connected.connect(_on_connected)
    livekit.room_disconnected.connect(_on_disconnected)
    livekit.participant_joined.connect(_on_participant_joined)
    livekit.participant_left.connect(_on_participant_left)
    livekit.track_subscribed.connect(_on_track_subscribed)

func _on_connected():
    print("Room connected!")

func _on_participant_joined(identity: String):
    print("Participant joined: ", identity)
    
func _on_track_subscribed(participant_id: String, track_sid: String):
    print("Audio track from: ", participant_id)
```

## ParticipantAudio Node

### Creating Audio Players

```gdscript
# Create audio player for participant
var audio_player = livekit.create_participant_audio(participant_id)

# It's automatically added as a child of LiveKitClient
# Access it later:
var audio = livekit.get_node("Audio_" + participant_id)
```

### Spatial Positioning

```gdscript
# Set 3D position
audio_player.set_spatial_position(Vector3(5, 0, 0))

# Adjust volume/attenuation
audio_player.set_attenuation(-6.0)  # dB

# Since it extends AudioStreamPlayer3D, you can use all normal properties:
audio_player.unit_db = -6.0
audio_player.max_distance = 100.0
audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
```

## VR Example

```gdscript
extends Node3D

var livekit: LiveKitClient
var avatar_positions := {}  # Dictionary tracking avatar positions

func _ready():
    # Setup LiveKit
    livekit = LiveKitClient.new()
    $XROrigin3D/XRCamera3D.add_child(livekit)
    
    livekit.participant_joined.connect(_on_participant_joined)
    livekit.connect_to_room(SERVER_URL, get_token())

func _on_participant_joined(identity: String):
    # Create avatar
    var avatar = preload("res://avatar.tscn").instantiate()
    avatar.name = "Avatar_" + identity
    add_child(avatar)
    
    # Create spatial audio (attached to LiveKit camera)
    var audio = livekit.create_participant_audio(identity)
    
    # Store for position updates
    avatar_positions[identity] = {
        "avatar": avatar,
        "audio": audio
    }

func _process(_delta):
    # Update audio positions to match avatars
    for identity in avatar_positions:
        var data = avatar_positions[identity]
        var avatar_pos = data.avatar.global_position
        var camera_pos = $XROrigin3D/XRCamera3D.global_position
        
        # Audio position is relative to camera (since it's a child)
        var relative_pos = avatar_pos - camera_pos
        data.audio.set_spatial_position(relative_pos)
```

## Common Patterns

### 1. Simple Voice Chat

```gdscript
var livekit = LiveKitClient.new()
add_child(livekit)
livekit.connect_to_room(url, token)

livekit.participant_joined.connect(func(id):
    livekit.create_participant_audio(id)
)
```

### 2. Distance-Based Volume

```gdscript
func update_audio_volumes():
    var my_pos = $Player.global_position
    
    for child in livekit.get_children():
        if child is ParticipantAudio:
            var distance = my_pos.distance_to(child.global_position)
            var volume = clamp(20.0 - distance * 0.5, -80.0, 0.0)
            child.set_attenuation(volume)
```

### 3. Mute/Unmute Participants

```gdscript
func mute_participant(identity: String):
    var audio = livekit.get_node_or_null("Audio_" + identity)
    if audio:
        audio.volume_db = -80.0  # Effectively mute

func unmute_participant(identity: String):
    var audio = livekit.get_node_or_null("Audio_" + identity)
    if audio:
        audio.volume_db = 0.0
```

## Debugging

```gdscript
# Enable verbose logging (add to autoload/global script)
func _ready():
    # Set audio driver for input
    ProjectSettings.set_setting("audio/driver/enable_input", true)
    
    # Check if LiveKitClient is available
    if ClassDB.class_exists("LiveKitClient"):
        print("✅ LiveKitClient GDExtension loaded")
    else:
        print("❌ LiveKitClient not found - check addon installation")

# Monitor connections
func _process(_delta):
    if livekit:
        print("Connected: ", livekit.is_room_connected())
        print("Participant count: ", livekit.get_child_count())
```

## Performance Tips

1. **Limit Audio Players**: Don't create audio players for >20 participants simultaneously
2. **Update Rate**: Update positions at 30-60 Hz, not every frame (unless VR)
3. **Culling**: Disable audio for participants beyond max hearing distance
4. **Attenuation**: Use logarithmic attenuation for natural sound falloff

```gdscript
# Example: Cull distant audio
const MAX_AUDIO_DISTANCE = 50.0

func _process(_delta):
    var my_pos = $Player.global_position
    for child in livekit.get_children():
        if child is AudioStreamPlayer3D:
            var distance = my_pos.distance_to(child.global_position)
            child.stream_paused = distance > MAX_AUDIO_DISTANCE
```
