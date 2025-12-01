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
    ChatMessage(String, String, u64), // sender_identity, message, timestamp
    ParticipantMetadataChanged(String, String), // identity, username
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
    room: Arc<Mutex<Option<Arc<Room>>>>, // Store room for sending messages
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
            room: Arc::new(Mutex::new(None)),
            is_connected: Arc::new(Mutex::new(false)),
            mic_sample_rate: 48000, // Default
            disconnect_tx: None,
        }
    }

    fn ready(&mut self) {
        // Create tokio runtime - single-threaded on Android to avoid JNI thread attachment crashes
        self.runtime = Some(
            if cfg!(target_os = "android") {
                tokio::runtime::Builder::new_current_thread()
                    .enable_all()
                    .build()
                    .expect("Failed to create tokio runtime")
            } else {
                tokio::runtime::Builder::new_multi_thread()
                    .enable_all()
                    .build()
                    .expect("Failed to create tokio runtime")
            }
        );

        #[cfg(target_os = "android")]
        log::info!("LiveKitManager::ready: Relying on lazy WebRTC init (JNI_OnLoad skipped crash fix)");
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
                InternalEvent::ChatMessage(sender, message, timestamp) => {
                    self.base_mut().emit_signal(
                        "chat_message_received",
                        &[sender.to_variant(), message.to_variant(), (timestamp as i64).to_variant()],
                    );
                }
                InternalEvent::ParticipantMetadataChanged(identity, username) => {
                    self.base_mut().emit_signal(
                        "participant_name_changed",
                        &[identity.to_variant(), username.to_variant()],
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
    #[signal]
    fn chat_message_received(sender: GString, message: GString, timestamp: i64);
    #[signal]
    fn participant_name_changed(identity: GString, username: GString);

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
        
        // Clear channels and room
        self.audio_sender = None;
        self.event_receiver = None;
        *self.room.lock().unwrap() = None;
        
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
        let room_storage = self.room.clone(); // Clone the Arc<Mutex> to store room later
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
                    
                    // Check for existing metadata
                    let metadata = participant.metadata();
                    if !metadata.is_empty() {
                        if let Ok(json) = serde_json::from_str::<serde_json::Value>(&metadata) {
                            if let Some(username) = json.get("username").and_then(|v| v.as_str()) {
                                event_tx
                                    .send(InternalEvent::ParticipantMetadataChanged(
                                        participant.identity().to_string(),
                                        username.to_string(),
                                    ))
                                    .ok();
                            }
                        }
                    }
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
                    1000, // queue_size_ms - audio buffer queue size in milliseconds
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
                
                // Store the room reference for sending messages
                let room_arc = Arc::new(room);
                *room_storage.lock().unwrap() = Some(room_arc.clone());

                // Spawn a task to feed audio data to the source
                tokio::spawn(async move {
                    let mut buffer: Vec<i16> = Vec::new();
                    // 10ms at 48kHz = 480 samples
                    let samples_per_10ms = (mic_sample_rate / 100) as usize; 

                    while let Some(samples) = audio_rx.recv().await {
                        // Convert f32 samples to i16 and append to buffer
                        for sample in samples {
                            let s = (sample.clamp(-1.0, 1.0) * 32767.0) as i16;
                            buffer.push(s);
                        }

                        // Process chunks of 10ms
                        while buffer.len() >= samples_per_10ms {
                            let chunk: Vec<i16> = buffer.drain(0..samples_per_10ms).collect();
                            
                            let frame = AudioFrame {
                                data: std::borrow::Cow::Owned(chunk),
                                sample_rate: mic_sample_rate as u32,
                                num_channels: 1,
                                samples_per_channel: samples_per_10ms as u32,
                            };
                            
                            if let Err(e) = source.capture_frame(&frame).await {
                                godot_error!("Failed to capture audio frame: {:?}", e);
                            }
                        }
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
                                RoomEvent::ChatMessage { message, participant } => {
                                    // Use built-in ChatMessage event
                                    let sender_identity = participant
                                        .map(|p| p.identity().to_string())
                                        .unwrap_or_else(|| "Unknown".to_string());
                                    
                                    event_tx
                                        .send(InternalEvent::ChatMessage(
                                            sender_identity,
                                            message.message,
                                            message.timestamp as u64,
                                        ))
                                        .ok();
                                }
                                RoomEvent::ParticipantMetadataChanged { participant, old_metadata: _, metadata } => {
                                    // Extract username from metadata
                                    if !metadata.is_empty() {
                                        if let Ok(json) = serde_json::from_str::<serde_json::Value>(&metadata) {
                                            if let Some(username) = json.get("username").and_then(|v| v.as_str()) {
                                                event_tx
                                                    .send(InternalEvent::ParticipantMetadataChanged(
                                                        participant.identity().to_string(),
                                                        username.to_string(),
                                                    ))
                                                    .ok();
                                            }
                                        }
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

    #[func]
    pub fn send_chat_message(&self, message: GString) {
        let room = self.room.lock().unwrap();
        if let Some(room) = room.as_ref() {
            let room_clone = room.clone();
            let msg = message.to_string();
            
            if let Some(runtime) = &self.runtime {
                runtime.spawn(async move {
                    // Use LiveKit's built-in send_chat_message
                    if let Err(e) = room_clone.local_participant()
                        .send_chat_message(msg, None, None)
                        .await
                    {
                        godot_error!("Failed to send chat message: {:?}", e);
                    }
                });
            }
        } else {
            godot_warn!("Cannot send chat message: not connected to room");
        }
    }

    #[func]
    pub fn update_username(&self, new_name: GString) {
        let room = self.room.lock().unwrap();
        if let Some(room) = room.as_ref() {
            let room_clone = room.clone();
            let name = new_name.to_string();
            
            if let Some(runtime) = &self.runtime {
                runtime.spawn(async move {
                    // Use LocalParticipant.set_metadata to update username
                    // This triggers RoomEvent::ParticipantMetadataChanged on other clients
                    let metadata = serde_json::json!({
                        "username": name
                    }).to_string();
                    
                    if let Err(e) = room_clone.local_participant().set_metadata(metadata).await {
                        godot_error!("Failed to update username: {:?}", e);
                    } else {
                        godot_print!("Username updated to: {}", name);
                    }
                });
            }
        } else {
            godot_warn!("Cannot update username: not connected to room");
        }
    }
    #[func]
    pub fn get_local_identity(&self) -> GString {
        if let Some(room) = self.room.lock().unwrap().as_ref() {
            return room.local_participant().identity().to_string().into();
        }
        "local".into()
    }
}

