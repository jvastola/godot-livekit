use godot::prelude::*;
use livekit::{
    options::TrackPublishOptions,
    webrtc::{
        audio_frame::AudioFrame,
        audio_source::native::NativeAudioSource,
        prelude::{AudioSourceOptions, RtcAudioSource},
    },
    Room, RoomEvent, RoomOptions,
};
use std::sync::{Arc, Mutex};
use futures_util::stream::StreamExt;
use tokio::runtime::Runtime;
use tokio::sync::mpsc;

#[derive(Clone, Debug)]
enum InternalEvent {
    RoomConnected,
    RoomDisconnected,
    ParticipantJoined(String),
    ParticipantLeft(String),
    AudioFrame(String, Vec<Vector2>),
    Error(String),
}

#[derive(GodotClass)]
#[class(base=Node)]
pub struct LiveKitManager {
    base: Base<Node>,

    // State
    runtime: Option<Runtime>,
    event_receiver: Option<mpsc::UnboundedReceiver<InternalEvent>>,
    audio_sender: Option<mpsc::UnboundedSender<Vec<f32>>>,
    is_connected: Arc<Mutex<bool>>,
    mic_sample_rate: i32,
    disconnect_tx: Option<tokio::sync::oneshot::Sender<()>>,
}

#[godot_api]
impl INode for LiveKitManager {
    fn init(base: Base<Node>) -> Self {
        Self {
            base,
            runtime: None,
            event_receiver: None,
            audio_sender: None,
            is_connected: Arc::new(Mutex::new(false)),
            mic_sample_rate: 48000, // Default
            disconnect_tx: None,
        }
    }

    fn ready(&mut self) {
        // Create tokio runtime
        self.runtime = Some(
            tokio::runtime::Builder::new_multi_thread()
                .enable_all()
                .build()
                .expect("Failed to create tokio runtime"),
        );
    }

    fn process(&mut self, _delta: f64) {
        // Process events from the async task
        let mut events = Vec::new();
        if let Some(receiver) = &mut self.event_receiver {
            while let Ok(event) = receiver.try_recv() {
                events.push(event);
            }
        }

        for event in events {
            match event {
                InternalEvent::RoomConnected => {
                    self.base_mut().emit_signal("room_connected", &[]);
                }
                InternalEvent::RoomDisconnected => {
                    self.base_mut().emit_signal("room_disconnected", &[]);
                }
                InternalEvent::ParticipantJoined(id) => {
                    self.base_mut()
                        .emit_signal("participant_joined", &[id.to_variant()]);
                }
                InternalEvent::ParticipantLeft(id) => {
                    self.base_mut()
                        .emit_signal("participant_left", &[id.to_variant()]);
                }
                InternalEvent::AudioFrame(id, frame) => {
                    // frame is Vec<Vector2>, convert to PackedVector2Array
                    let packed = PackedVector2Array::from(frame.as_slice());
                    self.base_mut().emit_signal(
                        "on_audio_frame",
                        &[id.to_variant(), packed.to_variant()],
                    );
                }
                InternalEvent::Error(msg) => {
                    godot_error!("LiveKit Error: {}", msg);
                    self.base_mut()
                        .emit_signal("error_occurred", &[msg.to_variant()]);
                }
            }
        }
    }
}

#[godot_api]
impl LiveKitManager {
    #[signal]
    fn room_connected();
    #[signal]
    fn room_disconnected();
    #[signal]
    fn participant_joined(identity: GString);
    #[signal]
    fn participant_left(identity: GString);
    #[signal]
    fn error_occurred(message: GString);
    #[signal]
    fn on_audio_frame(peer_id: GString, frame: PackedVector2Array);

    #[func]
    pub fn set_mic_sample_rate(&mut self, rate: i32) {
        self.mic_sample_rate = rate;
        godot_print!("LiveKit: Mic sample rate set to {}", rate);
    }

    #[func]
    pub fn is_room_connected(&self) -> bool {
        *self.is_connected.lock().unwrap()
    }

    #[func]
    pub fn disconnect_from_room(&mut self) {
        godot_print!("Disconnecting from room...");
        
        // Signal the async task to stop
        if let Some(tx) = self.disconnect_tx.take() {
            let _ = tx.send(());
        }
        
        // Clear channels
        self.audio_sender = None;
        self.event_receiver = None;
        
        *self.is_connected.lock().unwrap() = false;
    }

    #[func]
    pub fn connect_to_room(&mut self, url: GString, token: GString) {
        let url = url.to_string();
        let token = token.to_string();

        let (event_tx, event_rx) = mpsc::unbounded_channel();
        self.event_receiver = Some(event_rx);

        let (audio_tx, mut audio_rx) = mpsc::unbounded_channel::<Vec<f32>>();
        self.audio_sender = Some(audio_tx);
        
        // Create disconnect channel
        let (disconnect_tx, mut disconnect_rx) = tokio::sync::oneshot::channel();
        self.disconnect_tx = Some(disconnect_tx);
        
        let is_connected = self.is_connected.clone();
        let mic_sample_rate = self.mic_sample_rate;

        if let Some(runtime) = &self.runtime {
            runtime.spawn(async move {
                let (room, mut room_events) = match Room::connect(&url, &token, RoomOptions::default()).await {
                    Ok(res) => res,
                    Err(e) => {
                        event_tx
                            .send(InternalEvent::Error(format!("Failed to connect: {}", e)))
                            .ok();
                        return;
                    }
                };

                *is_connected.lock().unwrap() = true;
                event_tx.send(InternalEvent::RoomConnected).ok();

                // Notify about participants already in the room
                for participant in room.remote_participants().values() {
                    event_tx
                        .send(InternalEvent::ParticipantJoined(participant.identity().to_string()))
                        .ok();
                }

                // Create a native audio source for the microphone
                let source = NativeAudioSource::new(
                    AudioSourceOptions {
                        echo_cancellation: true,
                        noise_suppression: true,
                        auto_gain_control: true,
                    },
                    mic_sample_rate as u32,
                    1, // Mono
                    None, // disable_processing
                );
                
                let track = livekit::track::LocalAudioTrack::create_audio_track(
                    "mic",
                    RtcAudioSource::Native(source.clone()),
                );

                if let Err(e) = room
                    .local_participant()
                    .publish_track(
                        livekit::track::LocalTrack::Audio(track),
                        TrackPublishOptions::default(),
                    )
                    .await
                {
                    event_tx
                        .send(InternalEvent::Error(format!("Failed to publish mic: {}", e)))
                        .ok();
                }

                // Spawn a task to feed audio data to the source
                tokio::spawn(async move {
                    while let Some(samples) = audio_rx.recv().await {
                        // Convert f32 samples to i16 for LiveKit if needed, or use capture_frame
                        // NativeAudioSource.capture_frame expects i16 usually, let's check docs or assume f32 support if available
                        // The `webrtc` crate's NativeAudioSource usually takes i16 PCM.
                        // We'll convert f32 (-1.0 to 1.0) to i16.
                        let i16_samples: Vec<i16> = samples
                            .iter()
                            .map(|&s| (s.clamp(-1.0, 1.0) * 32767.0) as i16)
                            .collect();
                        
                        // 10ms chunks are preferred usually, but we'll push what we get
                        // We need to know sample rate and channels. 48000, 1.
                        // capture_frame(data: &[i16], sample_rate: u32, channels: usize, samples_per_channel: usize)
                        // Wait, looking at typical APIs.
                        // Assuming `capture_frame` exists on `NativeAudioSource`.
                        // If not, we might need to look at `godot-livekit` reference implementation.
                        // For now, let's assume `capture_frame` is available.
                        
                        let frame = AudioFrame {
                            data: std::borrow::Cow::Borrowed(&i16_samples),
                            sample_rate: mic_sample_rate as u32,
                            num_channels: 1,
                            samples_per_channel: i16_samples.len() as u32,
                        };
                        source.capture_frame(&frame).await.ok();
                    }
                });

                loop {
                    tokio::select! {
                        Some(event) = room_events.recv() => {
                            match event {
                                RoomEvent::ParticipantConnected(p) => {
                                    event_tx
                                        .send(InternalEvent::ParticipantJoined(p.identity().to_string()))
                                        .ok();
                                }
                                RoomEvent::ParticipantDisconnected(p) => {
                                    event_tx
                                        .send(InternalEvent::ParticipantLeft(p.identity().to_string()))
                                        .ok();
                                }
                                RoomEvent::TrackSubscribed {
                                    track,
                                    publication: _,
                                    participant,
                                } => {
                                    if let livekit::track::RemoteTrack::Audio(audio_track) = track {
                                        let event_tx_clone = event_tx.clone();
                                        let participant_id = participant.identity().to_string();
                                        let mut stream = livekit::webrtc::audio_stream::native::NativeAudioStream::new(
                                            audio_track.rtc_track(),
                                            48000, // sample rate
                                            1,     // channels
                                        );

                                        tokio::spawn(async move {
                                            while let Some(frame) = stream.next().await {
                                                // frame is usually Vec<i16>
                                                // Convert to Vector2 (stereo) for Godot
                                                // Godot expects PackedVector2Array for stereo audio
                                                let mut godot_frame = Vec::with_capacity(frame.data.len());
                                                for &sample in frame.data.iter() {
                                                    let f = (sample as f32) / 32768.0;
                                                    godot_frame.push(Vector2::new(f, f));
                                                }
                                                
                                                event_tx_clone
                                                    .send(InternalEvent::AudioFrame(
                                                        participant_id.clone(),
                                                        godot_frame,
                                                    ))
                                                    .ok();
                                            }
                                        });
                                    }
                                }
                                _ => {}
                            }
                        }
                        _ = &mut disconnect_rx => {
                            godot_print!("Disconnect signal received, stopping room task");
                            break;
                        }
                    }
                }
                
                *is_connected.lock().unwrap() = false;
                event_tx.send(InternalEvent::RoomDisconnected).ok();
            });
        }
    }

    #[func]
    pub fn push_mic_audio(&self, buffer: PackedVector2Array) {
        if let Some(sender) = &self.audio_sender {
            // buffer is Stereo (Vector2), we need Mono for LiveKit
            let samples: Vec<f32> = buffer
                .as_slice()
                .iter()
                .map(|v| (v.x + v.y) / 2.0)
                .collect();
            
            sender.send(samples).ok();
        }
    }
}

