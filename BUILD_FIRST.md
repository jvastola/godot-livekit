# Building the LiveKit GDExtension

## For End Users

**You don't need to build anything!** Just download and enable the addon:

1. Download the latest release for your platform from the Releases page
2. Extract to your Godot project's `addons/` folder
3. Enable the plugin: **Project → Project Settings → Plugins → LiveKit GDExtension**
4. Restart Godot

## For Developers

If you're contributing or building from source:

### Prerequisites
1. Install Rust from https://rustup.rs/
2. Have Godot 4.2+ installed

### Build Steps

```bash
# Navigate to rust directory
cd rust

# Build the extension (release mode)
cargo build --release
```

The compiled library will automatically be copied to `addons/godot-livekit/bin/` for your platform.

### Verify Installation

1. Open the project in Godot
2. Go to **Project → Project Settings → Plugins**
3. You should see "LiveKit GDExtension" - enable it
4. Run the demo scene: **demo/ClientUI.tscn**

## Quick Start

1. Run a LiveKit server locally:
   ```bash
   docker run --rm -p 7880:7880 livekit/livekit-server --dev
   ```

2. Generate a token:
   ```bash
   node generate_token.js
   ```

3. In Godot, run the demo and paste the token

4. Click "Connect" - you should see "Connected to Room!"

---

For detailed development instructions, see [RUST_DEVELOPMENT.md](RUST_DEVELOPMENT.md).

For usage examples and API reference, see [README.md](README.md).
