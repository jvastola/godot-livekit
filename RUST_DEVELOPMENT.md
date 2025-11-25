# Rust Development Guide

This guide covers setting up the development environment for building the LiveKit GDExtension.

## Prerequisites

### 1. Install Rust

```bash
# Windows (PowerShell)
Invoke-WebRequest -Uri https://win.rustup.rs -OutFile rustup-init.exe
.\rustup-init.exe

# Linux/macOS
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

After installation, restart your terminal and verify:
```bash
rustc --version
cargo --version
```

### 2. Install Godot 4.2+

Download from https://godotengine.org/download

## Building

### Windows (Primary Development Platform)

```bash
cd rust
cargo build --release
```

The compiled DLL will be automatically copied to `addons/godot-livekit/bin/windows/godot_livekit.dll`.

### Linux

```bash
cd rust
cargo build --release --target x86_64-unknown-linux-gnu
```

### macOS

```bash
cd rust
cargo build --release --target x86_64-apple-darwin
# For Apple Silicon
cargo build --release --target aarch64-apple-darwin
```

### Android (Quest Standalone)

```bash
# Install Android NDK r25c
# Set ANDROID_NDK_HOME environment variable

# Add Android target
rustup target add aarch64-linux-android

# Build
cd rust
cargo build --release --target aarch64-linux-android
```

## Cross-Compilation Setup

### Linux → Windows

```bash
# Install MinGW
sudo apt install mingw-w64

# Add Windows target
rustup target add x86_64-pc-windows-gnu

# Build
cargo build --release --target x86_64-pc-windows-gnu
```

### macOS Cross-Compilation

Install OSXCross: https://github.com/tpoechtrager/osxcross

```bash
rustup target add x86_64-apple-darwin
rustup target add aarch64-apple-darwin
```

## Project Structure

```
rust/
├── Cargo.toml           # Dependencies and project config
├── build.rs             # Build script (copies libs to addon/)
├── .cargo/
│   └── config.toml      # Cross-compilation settings
└── src/
    ├── lib.rs           # GDExtension entry point
    ├── livekit_client.rs    # Main LiveKit client node
    ├── audio_handler.rs     # Audio capture/playback
    └── participant_audio.rs # Per-participant spatial audio
```

## Development Workflow

### 1. Make Changes

Edit Rust source files in `rust/src/`

### 2. Build

```bash
cd rust
cargo build --release
```

### 3. Test in Godot

1. Open project in Godot
2. The GDExtension will hot-reload (may need editor restart)
3. Run the demo scene

### 4. Debugging

**Rust Side:**
```bash
# Build with debug symbols
cargo build

# Run tests
cargo test

# Check for errors
cargo clippy
```

**Godot Side:**
- Use `godot_print!()` macro for logging
- Check Godot's Output panel for Rust logs
- Use Godot's debugger for GDScript side

**Crashes:**
- Build in debug mode for better stack traces
- Use `RUST_BACKTRACE=1` environment variable
- Check logs in Godot's console

## Common Issues

### "undefined reference to dlopen" (Linux)

Add to `Cargo.toml`:
```toml
[dependencies.godot]
features = ["experimental-threads"]
```

### Linker errors on Windows

Ensure Visual Studio Build Tools are installed with C++ workload.

### Android NDK not found

```bash
# Set environment variable
export ANDROID_NDK_HOME=/path/to/android-ndk-r25c

# Or edit ~/.cargo/config.toml
[target.aarch64-linux-android]
ar = "/path/to/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar"
linker = "/path/to/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android33-clang"
```

## Testing

### Unit Tests

```bash
cargo test
```

### Integration Tests

1. Build the extension
2. Open Godot project
3. Run `demo/client_ui_gdext.tscn`
4. Connect to a LiveKit server
5. Verify audio input/output

## CI/CD (GitHub Actions Example)

```yaml
name: Build GDExtension

on: [push, pull_request]

jobs:
  build:
    strategy:
      matrix:
        platform:
          - { name: Windows, os: windows-latest, target: x86_64-pc-windows-msvc }
          - { name: Linux, os: ubuntu-latest, target: x86_64-unknown-linux-gnu }
          - { name: macOS, os: macos-latest, target: x86_64-apple-darwin }
    
    runs-on: ${{ matrix.platform.os }}
    
    steps:
      - uses: actions/checkout@v3
      - uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          target: ${{ matrix.platform.target }}
      
      - name: Build
        run: |
          cd rust
          cargo build --release --target ${{ matrix.platform.target }}
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: ${{ matrix.platform.name }}
          path: addons/godot-livekit/bin/
```

## Debugging GDExtensions

### Enable Rust Backtraces

```bash
# Windows PowerShell
$env:RUST_BACKTRACE=1
godot

# Linux/macOS
RUST_BACKTRACE=1 godot
```

### Debug Prints

```rust
use godot::prelude::*;

godot_print!("Debug: {}", some_value);
godot_warn!("Warning: Something might be wrong");
godot_error!("Error: {}", error_message);
```

### GDB/LLDB Debugging

```bash
# Linux
gdb --args godot --path /path/to/project

# macOS
lldb -- godot --path /path/to/project
```

## Resources

- [godot-rust Book](https://godot-rust.github.io/)
- [LiveKit Rust SDK Docs](https://docs.rs/livekit/)
- [Godot GDExtension Docs](https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/index.html)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `cargo fmt` and `cargo clippy`
5. Test on your platform
6. Submit a pull request

Please ensure all tests pass and code is formatted before submitting.
