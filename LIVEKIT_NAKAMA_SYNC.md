# LiveKit-Nakama ID Synchronization Guide

## Overview

For the LiveKit participant list to display 3D positions correctly, the LiveKit participant ID must match the Nakama user_id. This is because:

- **Nakama** creates NetworkPlayer instances named `RemotePlayer_<nakama_user_id>`
- **LiveKit** identifies participants using the JWT token's `sub` (subject) claim
- The LiveKit UI searches for NetworkPlayers by matching these IDs

## Quick Start

### Step 1: Connect to Nakama First

1. Launch Godot and open your scene
2. Open the Network UI (multiplayer panel)
3. Either:
   - **Host a Match**: Click "Host Match" and note the match ID
   - **Join a Match**: Enter an existing match ID and click "Join Match"
4. Wait for "Connected" status
5. **Important**: Note your Nakama user_id from the console output (e.g., `"abc123xyz"`)

### Step 2: Generate LiveKit Token with Nakama ID

#### Option A: Command Line (Easiest)

```bash
cd godot-livekit
python3 generate_token_quick.py <your_nakama_user_id>
```

Example:
```bash
python3 generate_token_quick.py abc123xyz
```

This will print your token. Copy it for the next step.

#### Option B: Check LiveKit UI

The LiveKit UI now displays your Nakama user_id automatically:
1. Open the LiveKit UI in Godot
2. Look for the green hint message showing: `"ℹ️ Nakama ID: abc123xyz"`
3. Use this ID when generating your token

### Step 3: Connect to LiveKit

1. Open the LiveKit UI panel
2. Paste your generated token (with matching Nakama ID) into the Token field
3. Click "Connect"
4. Wait for "Connected" status

### Step 4: Verify Position Display

In the LiveKit participants list, you should now see:
- ✅ `Pos: (x.x, y.y, z.z)` in **GREEN** (working!)
- ❌ `Pos: Not Found` in **RED** (ID mismatch)

If you see red "Not Found":
- Check that your LiveKit token's `sub` claim matches your Nakama user_id
- Verify you're connected to both Nakama AND LiveKit
- Make sure the NetworkPlayer exists in the scene tree

## Multi-Client Testing

### Client 1:
```bash
# Get Nakama ID from console after connecting
# Example: "user_abc123"
cd godot-livekit
python3 generate_token_quick.py user_abc123
# Copy the token
```

In Godot Client 1:
1. Connect to Nakama (host or join match)
2. Paste token into LiveKit UI
3. Connect to LiveKit

### Client 2:
```bash
# Get Nakama ID from console after connecting  
# Example: "user_xyz789"
cd godot-livekit
python3 generate_token_quick.py user_xyz789
# Copy the token
```

In Godot Client 2:
1. Connect to same Nakama match as Client 1
2. Paste token into LiveKit UI
3. Connect to LiveKit

### Verification:
- Both clients should see each other in Nakama (3D player boxes visible)
- Both clients should see each other in LiveKit participants list
- Positions should show in GREEN and update when players move
- Audio should work bidirectionally

## Troubleshooting

### "Pos: Not Found" appears in red

**Cause**: LiveKit participant ID doesn't match Nakama user_id

**Solution**:
1. Check your Nakama user_id in the console or LiveKit UI hint
2. Regenerate your LiveKit token with that exact ID
3. Reconnect to LiveKit with the new token

### No hint label appears in LiveKit UI

**Cause**: NetworkManager autoload not loaded or not connected to Nakama

**Solution**:
1. Ensure NetworkManager is set up as an autoload in Project Settings
2. Connect to Nakama first before opening LiveKit UI
3. Restart Godot if needed

### Positions don't update  

**Cause**: NetworkPlayer not receiving position updates from Nakama

**Solution**:
1. Verify both players are in the same Nakama match
2. Check console for Nakama state updates
3. Try moving around - position should change

## Technical Details

### How It Works

1. When you connect to Nakama, `NetworkManager.get_nakama_user_id()` returns your session user_id
2. PlayerNetworkComponent spawns NetworkPlayer instances named `RemotePlayer_<user_id>`  
3. LiveKit participant joins with identity from JWT `sub` claim
4. LiveKit UI calls `_find_network_player(participant_id)` to locate the NetworkPlayer
5. If IDs match, it can get `network_player.global_position` and display it

### Token Structure

LiveKit JWT must have:
```json
{
  "sub": "<nakama_user_id>",  // MUST match Nakama!
  "iss": "devkey",
  "exp": <timestamp>,
  "nbf": <timestamp>,
  "video": {
    "room": "test-room",
    "roomJoin": true,
    "canPublish": true,
    "canSubscribe": true
  }
}
```

The critical field is `"sub"` - this is the participant identity that LiveKit uses.
