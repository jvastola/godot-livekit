use godot::prelude::*;
use godot::init::InitLevel;

mod audio_handler;
mod livekit_client;

struct LiveKitExtension;

#[gdextension]
unsafe impl ExtensionLibrary for LiveKitExtension {}

#[cfg(target_os = "android")]
#[no_mangle]
pub unsafe extern "system" fn JNI_OnLoad(vm: *mut jni::sys::JavaVM, _: *mut std::ffi::c_void) -> jni::sys::jint {
    android_logger::init_once(
        android_logger::Config::default().with_max_level(log::LevelFilter::Trace),
    );
    log::info!("JNI_OnLoad called");
    
    let vm = unsafe { jni::JavaVM::from_raw(vm).unwrap() };
    livekit::webrtc::android::initialize_android(&vm);
    
    log::info!("LiveKit Android globals initialized");
    
    jni::sys::JNI_VERSION_1_6
}
