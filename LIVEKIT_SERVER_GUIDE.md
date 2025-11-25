# LiveKit Local Server - Quick Start Guide

## Server Status
✅ LiveKit server is running locally

## Connection Details
- **Server URL**: `ws://localhost:7880`
- **API Key**: `devkey`
- **API Secret**: `secret`

## Test Token (Valid for 24 hours)
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjQxODY4OTIsImlzcyI6ImRldmtleSIsIm5iZiI6MTc2NDEwMDQ5Miwic3ViIjoidGVzdC11c2VyIiwidmlkZW8iOnsicm9vbSI6InRlc3Qtcm9vbSIsInJvb21Kb2luIjp0cnVlLCJjYW5QdWJsaXNoIjp0cnVlLCJjYW5TdWJzY3JpYmUiOnRydWV9fQ.lRsf98UYDUbICxBXYmXgEYda3A3cqSPAFtIRm8ez7iU
```
- **Room**: test-room
- **Participant**: test-user
- **Expires**: 2025-11-26 11:54:52

## Testing in Godot

### Single Client Test
1. Open `demo/GDExtensionTest.tscn` in Godot
2. Enter connection details:
   - Server URL: `ws://localhost:7880`
   - Token: *(copy from above)*
3. Click "Connect"
4. Speak into your microphone to test audio capture

### Multi-Client Test
To test with multiple participants:

**Client 1 (Godot)**
1. Use the token above in GDExtensionTest.tscn
2. Connect and test

**Client 2 (Web Browser)**
1. Visit: https://meet.livekit.io/custom
2. Enter:
   - LiveKit URL: `ws://localhost:7880`
   - Token: *(copy from above or generate new one with different participant name)*
3. Join room

**Client 3 (Another Godot instance)**
1. Generate a new token with different participant name:
   ```bash
   python generate_token.py
   ```
   (Edit `PARTICIPANT_NAME` in the script first)
2. Use in another Godot instance

## Generate New Tokens
```bash
cd c:\Users\Admin\godot-livekit
python generate_token.py
```

Edit [generate_token.py](file:///c:/Users/Admin/godot-livekit/generate_token.py) to change:
- `ROOM_NAME` - Room to join
- `PARTICIPANT_NAME` - Unique identifier for each participant

## Stop Server
Press Ctrl+C in the terminal where server is running

## Server Logs
Check terminal for connection status and debugging info
