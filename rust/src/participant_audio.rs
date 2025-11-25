use godot::prelude::*;
use godot::engine::{Node, AudioStreamGenerator, AudioStreamPlayer};
use crate::audio_handler::AudioHandler;

#[derive(GodotClass)]
#[class(base=Node)]
pub struct ParticipantAudio {
    base: Base<Node>,
    
    #[var]
    participant_id: GString,
    
    #[var]
    position: Vector3,
    
    audio_handler: AudioHandler,
    audio_player: Option<Gd<AudioStreamPlayer>>,
}

#[godot_api]
impl INode for ParticipantAudio {
    fn init(base: Base<Node>) -> Self {
        Self {
            base,
            participant_id: GString::from(""),
            position: Vector3::ZERO,
            audio_handler: AudioHandler::new(),
            audio_player: None,
        }
    }

    fn ready(&mut self) {
        godot_print!("ParticipantAudio ready for: {}", self.participant_id);
        
        // Create AudioStreamGenerator for real-time audio
        let mut generator = AudioStreamGenerator::new_gd();
        generator.set_mix_rate(48000.0); // 48kHz for LiveKit
        generator.set_buffer_length(0.1); // 100ms buffer
        
        // Create audio player
        let mut player = AudioStreamPlayer::new_gd();
        player.set_stream(generator.upcast());
        player.set_autoplay(true);
        
        self.base_mut().add_child(player.clone().upcast());
        player.play();
        
        self.audio_player = Some(player);
        
        godot_print!("Audio playback initialized for participant");
    }

    fn process(&mut self, _delta: f64) {
        // Audio frame processing would happen here
        // In complete implementation: receive from LiveKit, process, push to playback
    }
}

#[godot_api]
impl ParticipantAudio {
    #[func]
    pub fn set_participant_id(&mut self, id: GString) {
        self.participant_id = id;
    }

    #[func]
    pub fn get_participant_id(&self) -> GString {
        self.participant_id.clone()
    }

    #[func]
    pub fn set_spatial_position(&mut self, pos: Vector3) {
        self.position = pos;
        // In a full implementation, this would adjust 3D audio parameters
        // For now, we're using basic AudioStreamPlayer
    }

    #[func]
    pub fn get_spatial_position(&self) -> Vector3 {
        self.position
    }

    #[func]
    pub fn set_volume_db(&mut self, db: f32) {
        if let Some(player) = &mut self.audio_player {
            player.set_volume_db(db);
        }
    }
}
