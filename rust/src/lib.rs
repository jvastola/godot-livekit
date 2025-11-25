use godot::prelude::*;
use godot::init::InitLevel;

mod audio_handler;
mod livekit_client;

struct LiveKitExtension;

#[gdextension]
unsafe impl ExtensionLibrary for LiveKitExtension {}
