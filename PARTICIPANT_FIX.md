# Participant Display Fix

## Problem
When connecting to a LiveKit room via web browser, the Godot client would show "0 participants" even though the browser client showed it was connected. This happened because:

1. **GDScript UI Bug**: Participants were only added to the UI when audio frames arrived, not when they actually joined the room
2. **Rust SDK Bug**: When connecting to a room with existing participants, the code only listened for NEW participants joining, but didn't check for participants already in the room

## Solutions Applied

### 1. Fixed GDScript UI (`demo/gdextension_test.gd`)

**Before**: Participants only appeared when audio data arrived
**Now**: Participants appear immediately when they join

Changes:
- `_on_participant_joined()`: Now calls `_update_participant_list()` to show the participant immediately
- `_on_participant_left()`: Properly cleans up audio players before removing participants
- `_add_participant()`: Actually adds participants to the dictionary (with `null` initially)
- `_create_participant_audio()`: Only creates audio player if one doesn't exist yet
- `_on_audio_frame()`: Safely handles participants without audio players
- `_update_participant_list()`: Shows participant count and status indicator (🔊 for active audio, ⏸️ for no audio yet)

### 2. Fixed Rust SDK (`rust/src/livekit_client.rs`)

**Before**: Only detected participants who joined AFTER you connected
**Now**: Also detects participants who were ALREADY in the room when you connect

Added code after room connection:
```rust
// Notify about participants already in the room
for participant in room.remote_participants().values() {
    event_tx
        .send(InternalEvent::ParticipantJoined(participant.identity().to_string()))
        .ok();
}
```

## Testing

To verify the fix works:

1. **Connect web browser first**:
   - Open https://meet.livekit.io/custom
   - Enter server URL: `ws://localhost:7880`
   - Use CLIENT 3 token from `MULTI_CLIENT_TOKENS.md`
   - Join the room

2. **Then connect Godot**:
   - Run the Godot demo (`demo/GDExtensionTest.tscn`)
   - Click "Connect"
   - You should now see the web browser participant appear in the list!

3. **Test the reverse**:
   - Connect Godot first
   - Then connect web browser
   - Both should see each other

## What You'll See Now

✅ **Participant Count**: Title shows "👥 Participants (N)" where N is the actual count
✅ **Status Indicator**: 
   - 🔊 = Participant has active audio streaming
   - ⏸️ = Participant joined but no audio yet
✅ **Real-time Updates**: Participants appear/disappear as they join/leave
✅ **Works Both Ways**: Godot sees web clients, web clients see Godot

## Files Changed

1. `demo/gdextension_test.gd` - UI logic fixes
2. `rust/src/livekit_client.rs` - Enumerate existing participants on connect
3. `addons/godot-livekit/bin/windows/godot_livekit.dll` - Rebuilt library
