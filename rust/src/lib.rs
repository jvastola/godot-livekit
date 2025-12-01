use godot::prelude::*;


mod audio_handler;
mod livekit_client;

struct LiveKitExtension;

#[gdextension]
unsafe impl ExtensionLibrary for LiveKitExtension {}

#[cfg(target_os = "android")]
#[no_mangle]
pub unsafe extern "system" fn JNI_OnLoad(vm: *mut jni::sys::JavaVM, _: *mut std::ffi::c_void) -> jni::sys::jint {
    // CRITICAL: Initialize Android JVM for LiveKit WebRTC
    // Without this, Room::connect() will hang indefinitely on Android
    godot_print!("🔧 JNI_OnLoad: Initializing Android JVM for LiveKit WebRTC");
    
    // Convert raw pointer to JavaVM reference
    // SAFETY: vm is guaranteed to be valid by the Android runtime
    let java_vm = jni::JavaVM::from_raw(vm).expect("Failed to create JavaVM from raw pointer");
    
    // Initialize the WebRTC Android JVM
    // This MUST be called before any LiveKit/WebRTC operations on Android
    livekit::webrtc::android::initialize_android(&java_vm);
    
    godot_print!("✅ JNI_OnLoad: Android JVM initialized successfully");
    jni::sys::JNI_VERSION_1_6
}

// Android WebRTC codec workaround
// The WebRTC Android library checks for AV1 codec support by calling this function.
// Without this export, the Java side may crash or fail to initialize.
#[cfg(target_os = "android")]
#[allow(non_snake_case)]
#[no_mangle]
pub extern "C" fn Java_org_webrtc_LibaomAv1Decoder_nativeIsSupported() -> bool {
    godot_print!("🎥 WebRTC: AV1 decoder probe (returning true)");
    true
}
