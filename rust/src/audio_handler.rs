use godot::prelude::*;
use godot::classes::{AudioEffectCapture, AudioServer, AudioStreamGeneratorPlayback};
use livekit::track::RemoteAudioTrack;

pub struct AudioHandler {
    capture_effect: Option<Gd<AudioEffectCapture>>,
    sample_rate: i32,
}

impl AudioHandler {
    pub fn new() -> Self {
        Self {
            capture_effect: None,
            sample_rate: 48000, // LiveKit uses 48kHz
        }
    }

    pub fn init_capture(&mut self, bus_index: i32) {
        let mut audio_server = AudioServer::singleton();
        
        if let Some(effect) = audio_server.get_bus_effect(bus_index, 0) {
            if let Ok(capture) = effect.try_cast::<AudioEffectCapture>() {
                self.capture_effect = Some(capture);
                godot_print!("Audio capture initialized");
            }
        }
    }

    /// Capture audio from microphone and return as PCM samples
    pub fn capture_microphone_audio(&mut self) -> Option<Vec<f32>> {
        if let Some(capture) = &mut self.capture_effect {
            let frames_available = capture.get_frames_available();
            
            if frames_available > 0 {
                let buffer_size = (frames_available * 2) as usize; // Stereo
                let mut samples = Vec::with_capacity(buffer_size);
                
                for _ in 0..frames_available {
                    let frame = capture.get_buffer(1);
                    let frame_data = frame.as_slice();
                    for sample in frame_data {
                        let mono = (sample.x + sample.y) / 2.0;
                        samples.push(mono);
                    }
                }
                
                return Some(samples);
            }
        }
        None
    }

    /// Write PCM samples to AudioStreamGeneratorPlayback
    pub fn write_to_playback(
        &self,
        playback: &mut Gd<AudioStreamGeneratorPlayback>,
        samples: &[f32],
    ) {
        // Convert mono to stereo for Godot
        let mut stereo_samples = Vec::with_capacity(samples.len() * 2);
        for &sample in samples {
            stereo_samples.push(Vector2::new(sample, sample));
        }

        // Push frames to playback buffer
        for frame in stereo_samples {
            playback.push_frame(frame);
        }
    }

    pub fn get_sample_rate(&self) -> i32 {
        self.sample_rate
    }
}

impl Default for AudioHandler {
    fn default() -> Self {
        Self::new()
    }
}
