# Quick Start Guide

## Running LiveKit Voice Chat

### 1. Start LiveKit Server
```bash
/opt/homebrew/bin/livekit-server --dev --bind 0.0.0.0
```
Server will start on `localhost:7880` with dev credentials.

### 2. Run in Godot
1. Open Godot Editor
2. Load `demo/ClientUI.tscn`
3. Press **F5** or click Run Scene
4. Click the "Connect" button

That's it! The token is pre-configured to work with the local dev server.

### What Happens
- Connects to `ws://localhost:7880`
- Joins room `test-room`
- Token is pre-filled and valid
- WebRTC connection establishes automatically

### Testing with Multiple Clients
Open multiple Godot instances or run the scene multiple times to test voice chat between clients.

## Regenerate Token (Optional)
If token expires:
```bash
node generate_token.js
```
Copy the new token into `ClientUI.cs` line 24.
