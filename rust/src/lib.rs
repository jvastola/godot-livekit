use godot::prelude::*;


mod audio_handler;
mod livekit_client;

struct LiveKitExtension;

#[gdextension]
unsafe impl ExtensionLibrary for LiveKitExtension {}

#[cfg(target_os = "android")]
#[no_mangle]
pub unsafe extern "system" fn JNI_OnLoad(_vm: *mut jni::sys::JavaVM, _: *mut std::ffi::c_void) -> jni::sys::jint {
    // Skip explicit WebRTC init - causes SIGTRAP in jni_zero::InitVM on Quest 3 during lib load
    // Godot JNI VM is ready; LiveKit will init lazily on first use
    log::info!("JNI_OnLoad: Skipped WebRTC init to avoid crash");
    jni::sys::JNI_VERSION_1_6
}
