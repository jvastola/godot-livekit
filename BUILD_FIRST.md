# IMPORTANT: Build C# Project First!

The Godot editor should have just opened. Follow these steps:

## Step 1: Build C# Project
1. In Godot Editor, look at the **top menu bar**
2. Click **Build** → **Build Project**
3. Wait for "Build succeeded" message in the Output panel

## Step 2: Run the Project
1. Press **F5** (or click the Play button in top-right)
2. UI should appear with token already filled in
3. Click **"Connect"** button
4. Status should change to "Connecting..." then "Connected to Room!"

## Troubleshooting

### If Build menu is missing:
1. Make sure you opened `godot-livekit` project
2. Check bottom panel for "MSBuild" tab - that indicates C# is loaded

### If "Build Failed":
1. Check Output panel for errors
2. Try: **Project** → **Tools** → **C#** → **Create C# solution**
3. Then try Build again

### If token field is empty:
The token should auto-fill to a long string starting with "eyJh..."
If it's empty, the C# class didn't load properly - rebuild is needed.

## Expected Output in Console
When you click Connect, you should see:
```
ClientUI initialized successfully with LiveKitManager
LiveKit Server: ws://localhost:7880
Room: test-room
✅ Ready to connect!
Connecting to ws://localhost:7880...
WebSocket connected, waiting for JoinResponse...
Joined Room: test-room
```

---

**The key issue**: C# classes must be built THROUGH Godot's build system, not just `dotnet build`. Once you click "Build Project" in Godot, it will work!
