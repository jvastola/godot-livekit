# Android Build Guide for godot-livekit

This guide covers building the `godot-livekit` Rust extension for Android platforms, including the JNI symbol configuration required to prevent WebRTC initialization errors.

## Overview

The Android build includes special JNI symbol configuration to prevent `jni_zero.JniInit` missing errors. This fix is based on [Decentraland's godot-explorer](https://github.com/decentraland/godot-explorer) Android build solution.

## Prerequisites

### Required Tools

1. **Android NDK r28 or later**
   - Download from: https://developer.android.com/ndk/downloads
   - Recommended: NDK r28.1 or newer

2. **Android SDK** (if building full APK)
   - Android Studio or command-line tools
   - API Level 35 recommended

3. **Rust Toolchain**
   - Rust 1.70+ 
   - Android targets installed (see below)

### Install Android Rust Targets

```bash
# Add Android targets for cross-compilation
rustup target add aarch64-linux-android      # ARM64 (modern devices)
rustup target add armv7-linux-androideabi    # ARM32 (older devices)
rustup target add x86_64-linux-android       # x86_64 emulators
rustup target add i686-linux-android         # x86 emulators
```

## Environment Setup

### macOS/Linux

Add to your `~/.zshrc`, `~/.bashrc`, or `~/.profile`:

```bash
# Android NDK (adjust path to your installation)
export ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk/28.1.12345"

# Android SDK (adjust path to your installation) 
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"

# Add NDK toolchain to PATH
export PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin:$PATH"
```

Reload your shell:
```bash
source ~/.zshrc  # or ~/.bashrc
```

### Verify Setup

```bash
# Check NDK is found
echo $ANDROID_NDK_HOME
ls $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/*/bin/aarch64-linux-android*-clang

# Check Rust targets
rustup target list | grep android
```

## Building

### Quick Build (ARM64 only)

For most modern Android devices (Quest 3, recent phones/tablets):

```bash
cd godot-livekit/rust
cargo build --target aarch64-linux-android --release
```

**Build Time**: 
- First build: 30-90 minutes (compiles WebRTC from source)
- Subsequent builds: 1-5 minutes (if no dependency changes)

### Build Output

The compiled library will be at:
```
godot-livekit/rust/target/aarch64-linux-android/release/libgodot_livekit.so
```

The build script automatically copies it to:
```
godot-livekit/addons/godot-livekit/bin/android/libgodot_livekit.so
```

### Building for Multiple Architectures

If you need to support older devices or emulators:

```bash
# ARM64 (modern devices, Quest)
cargo build --target aarch64-linux-android --release

# ARM32 (older devices)
cargo build --target armv7-linux-androideabi --release

# x86_64 (emulators)
cargo build --target x86_64-linux-android --release
```

## Understanding the JNI Fix

### What Was Fixed

The Android build now includes a critical JNI symbol configuration step that:

1. **Exports only necessary JNI symbols** (`Java_org_webrtc_*`)
2. **Strips conflicting symbols** that cause linker errors
3. **Prevents `jni_zero.JniInit` missing errors**

### How It Works

In [`build.rs`](file:///Users/johnnyvastola/GodotPhysicsRig/godot-livekit/rust/build.rs#L9-L17):

```rust
// Configure JNI symbols for Android builds
#[cfg(target_os = "android")]
{
    println!("cargo:warning=Configuring JNI symbols for Android build...");
    webrtc_sys_build::configure_jni_symbols();
    println!("cargo:warning=JNI symbols configured successfully");
}
```

This calls `webrtc_sys_build::configure_jni_symbols()` which:
- Configures the linker to export specific JNI symbols
- Matches LiveKit's WebRTC version exactly
- Avoids ABI mismatches with prebuilt WebRTC binaries

### JNI Initialization

In [`lib.rs`](file:///Users/johnnyvastola/GodotPhysicsRig/godot-livekit/rust/src/lib.rs#L12-L29), the Android JVM is initialized via `JNI_OnLoad`:

```rust
#[cfg(target_os = "android")]
#[no_mangle]
pub unsafe extern "system" fn JNI_OnLoad(vm: *mut jni::sys::JavaVM, _: *mut std::ffi::c_void) -> jni::sys::jint {
    let java_vm = jni::JavaVM::from_raw(vm).expect("Failed to create JavaVM");
    livekit::webrtc::android::initialize_android(&java_vm);
    jni::sys::JNI_VERSION_1_6
}
```

**Critical**: This runs AFTER Godot's JVM initialization, preventing crashes.

## Verification

### Check Build Success

```bash
# Verify .so was built
ls -lh godot-livekit/rust/target/aarch64-linux-android/release/libgodot_livekit.so

# Verify it was copied to addons
ls -lh godot-livekit/addons/godot-livekit/bin/android/libgodot_livekit.so
```

### Verify JNI Symbols

```bash
# Check for WebRTC JNI symbols (should see Java_org_webrtc_*)
nm -D godot-livekit/rust/target/aarch64-linux-android/release/libgodot_livekit.so | grep Java_org_webrtc | head -10

# Check for JNI_OnLoad (should see our custom JNI_OnLoad)
nm -D godot-livekit/rust/target/aarch64-linux-android/release/libgodot_livekit.so | grep JNI_OnLoad
```

### Test on Device

1. **Export Godot Android APK**:
   - Open your Godot project
   - Project → Export → Android
   - Ensure the `godot-livekit` addon is included
   - Export and install APK

2. **Check Android Logcat**:
   ```bash
   adb logcat | grep -i "JNI_OnLoad\|livekit\|webrtc"
   ```

3. **Expected Logs**:
   ```
   JNI_OnLoad: Initializing Android JVM for LiveKit WebRTC
   JNI_OnLoad: Android JVM initialized successfully
   ```

4. **No Errors**:
   - ✅ No `jni_zero.JniInit` not found errors
   - ✅ No `UnsatisfiedLinkError` for WebRTC symbols
   - ✅ LiveKit connects successfully

## Troubleshooting

### Build Errors

#### "linker not found"

**Problem**: Android NDK toolchain not in PATH

**Solution**:
```bash
# Check NDK path
ls $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/*/bin/

# Add to PATH (adjust for your OS)
export PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin:$PATH"
```

#### "webrtc-sys-build not found"

**Problem**: Build dependency not resolved

**Solution**:
```bash
# Update dependencies
cargo update
cargo clean
cargo build --target aarch64-linux-android
```

#### "Build takes forever"

**Problem**: WebRTC compiles from source (expected behavior)

**Info**: First build compiles the entire WebRTC library (~30-90 min). This is NECESSARY to:
- Match LiveKit's exact WebRTC version
- Avoid JNI symbol conflicts
- Build for Android ABI correctly

**Tips**:
- Use `--release` mode (faster runtime, slower compile)
- Build once and cache the target directory
- Subsequent builds are much faster

### Runtime Errors

#### "jni_zero.JniInit not found"

**Problem**: JNI symbols not configured (old build)

**Solution**:
```bash
# Rebuild with new build.rs configuration
cargo clean
cargo build --target aarch64-linux-android --release
```

#### "Room::connect() hangs indefinitely"

**Problem**: JVM not initialized before LiveKit calls

**Solution**: Verify `JNI_OnLoad` is present in your build:
```bash
nm -D target/aarch64-linux-android/release/libgodot_livekit.so | grep JNI_OnLoad
```

Should show: `T JNI_OnLoad` (T = defined in Text section)

#### "Crash on startup"

**Problem**: Possible ABI mismatch or wrong architecture

**Solutions**:
```bash
# Verify you're building for the correct architecture
# Quest 3 uses ARM64
cargo build --target aarch64-linux-android --release

# Check device architecture
adb shell getprop ro.product.cpu.abi
# Should show: arm64-v8a for modern devices
```

## Build Configuration Reference

### Cargo.toml Changes

Added build dependency for JNI symbol configuration:

```toml
[build-dependencies]
webrtc-sys-build = "0.3"
```

### Key Dependencies

- **livekit** (0.7.25): LiveKit Rust SDK with WebRTC bindings
- **webrtc-sys**: Native WebRTC bindings (transitive)
- **webrtc-sys-build**: Build-time WebRTC configuration
- **jni** (0.21): Java Native Interface for Android

## Additional Resources

- [Decentraland godot-explorer](https://github.com/decentraland/godot-explorer) - Source of Android JNI fix
- [LiveKit Rust SDK](https://github.com/livekit/rust-sdks)
- [WebRTC Native Code Android](https://webrtc.github.io/webrtc-org/native-code/android/)
- [Android NDK Guide](https://developer.android.com/ndk/guides)

## Summary

✅ **Working Android Build** requires:
1. NDK r28+ properly configured
2. `webrtc-sys-build` build dependency in Cargo.toml
3. `configure_jni_symbols()` call in build.rs
4. `JNI_OnLoad` implementation in lib.rs
5. Correct target architecture for your device

The fix ensures WebRTC JNI symbols are properly exported, preventing initialization errors on Android.
