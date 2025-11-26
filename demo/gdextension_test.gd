extends Control

# LiveKit Voice Chat UI with Audio Visualization

@onready var server_entry = $Panel/VBoxContainer/ServerEntry
@onready var token_entry = $Panel/VBoxContainer/TokenEntry
@onready var connect_button = $Panel/VBoxContainer/ConnectButton
@onready var disconnect_button = $Panel/VBoxContainer/DisconnectButton
@onready var status_label = $Panel/VBoxContainer/StatusLabel

# Audio controls
@onready var mic_section = $Panel/VBoxContainer/MicSection
@onready var mic_level_bar = $Panel/VBoxContainer/MicSection/MicLevelBar
@onready var threshold_slider = $Panel/VBoxContainer/MicSection/ThresholdSlider
@onready var threshold_label = $Panel/VBoxContainer/MicSection/ThresholdLabel
@onready var mute_button = $Panel/VBoxContainer/MicSection/MuteButton

var hear_audio_check: CheckBox
var mic_threshold: float = 0.1
var is_muted: bool = false
var hear_own_audio: bool = false
const BUFFER_SIZE = 512 # Match mic_visualizer.gd for stability
var audio_bus_name = "LiveKit Mic"
var audio_bus_idx = -1

# Participants
@onready var participant_list = $Panel/VBoxContainer/ParticipantList

var livekit_manager: Node
var participants = {} # Dictionary of participant_id -> AudioStreamPlayer
var capture_effect: AudioEffectCapture
var mic_player: AudioStreamPlayer


func _ready():
	print("=== LiveKit Audio Client UI ===")
	
	# Setup Audio
	_setup_audio()

	# Create LiveKitManager
	if ClassDB.class_exists("LiveKitManager"):
		livekit_manager = ClassDB.instantiate("LiveKitManager")
		add_child(livekit_manager)
		
		# Connect signals
		livekit_manager.room_connected.connect(_on_room_connected)
		livekit_manager.room_disconnected.connect(_on_room_disconnected)
		livekit_manager.participant_joined.connect(_on_participant_joined)
		livekit_manager.participant_left.connect(_on_participant_left)
		livekit_manager.on_audio_frame.connect(_on_audio_frame)
		livekit_manager.error_occurred.connect(_on_error)
	else:
		print("❌ LiveKitManager class not found! Is the GDExtension loaded?")
		status_label.text = "❌ Error: GDExtension not loaded"
		connect_button.disabled = true

	
	# Connect UI signals
	connect_button.pressed.connect(_on_connect_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	mute_button.pressed.connect(_on_mute_toggle)
	threshold_slider.value_changed.connect(_on_threshold_changed)
	
	# Create Hear Own Audio checkbox
	hear_audio_check = CheckBox.new()
	hear_audio_check.text = "Hear Own Audio"
	hear_audio_check.button_pressed = hear_own_audio
	hear_audio_check.toggled.connect(_on_hear_audio_toggled)
	mic_section.add_child(hear_audio_check)
	
	# Initial state
	disconnect_button.disabled = true
	threshold_slider.value = mic_threshold
	_on_threshold_changed(mic_threshold)
	
	# Set local server values for easy testing
	# For CLIENT 1 - use client-1 token
	server_entry.text = "ws://localhost:7880"
	token_entry.text = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjQxODc2NDcsImlzcyI6ImRldmtleSIsIm5iZiI6MTc2NDEwMTI0Nywic3ViIjoiY2xpZW50LTEiLCJ2aWRlbyI6eyJyb29tIjoidGVzdC1yb29tIiwicm9vbUpvaW4iOnRydWUsImNhblB1Ymxpc2giOnRydWUsImNhblN1YnNjcmliZSI6dHJ1ZX19.tR0faOukMG6GJFXrCRVtPmEJhnbig_pirRyjcqvqy3M"
	# For CLIENT 2, change token to: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjQxODc2NDcsImlzcyI6ImRldmtleSIsIm5iZiI6MTc2NDEwMTI0Nywic3ViIjoiY2xpZW50LTIiLCJ2aWRlbyI6eyJyb29tIjoidGVzdC1yb29tIiwicm9vbUpvaW4iOnRydWUsImNhblB1Ymxpc2giOnRydWUsImNhblN1YnNjcmliZSI6dHJ1ZX19.ilVW4UOCDu-OD98Ytfx3IboTIOx6d8Rm5N7aLSQv1ec
	
	status_label.text = "Ready to connect"
	print("✅ LiveKit Audio UI Ready!")

func _setup_audio():
	# Always create a new bus to ensure clean state, matching mic_visualizer.gd
	# This avoids potential issues with reusing buses in unknown states
	audio_bus_idx = AudioServer.bus_count
	AudioServer.add_bus(audio_bus_idx)
	AudioServer.set_bus_name(audio_bus_idx, audio_bus_name)
	
	# Add Capture effect
	capture_effect = AudioEffectCapture.new()
	AudioServer.add_bus_effect(audio_bus_idx, capture_effect)
	
	# Route to Master
	AudioServer.set_bus_send(audio_bus_idx, "Master")
	
	# Mute by default (so we don't hear ourselves unless toggled)
	AudioServer.set_bus_mute(audio_bus_idx, true)
	
	# Ensure volume is 0dB (full volume)
	AudioServer.set_bus_volume_db(audio_bus_idx, 0.0)
	
	# Start microphone input
	mic_player = AudioStreamPlayer.new()
	mic_player.bus = audio_bus_name
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.autoplay = true
	add_child(mic_player)
	mic_player.play()
	
	print("🎤 Audio capture initialized on '%s' bus (idx: %d)" % [audio_bus_name, audio_bus_idx])
	print("   - Send to: Master")
	print("   - Muted: ", AudioServer.is_bus_mute(audio_bus_idx))
	print("   - Volume: ", AudioServer.get_bus_volume_db(audio_bus_idx))

var _debug_timer = 0.0
func _process(delta):
	# Always process mic audio for visualization and local feedback
	_process_mic_audio()
	
	# Debug audio state every 2 seconds
	_debug_timer += delta
	if _debug_timer > 2.0:
		_debug_timer = 0.0
		if audio_bus_idx != -1:
			var is_bus_muted = AudioServer.is_bus_mute(audio_bus_idx)
			var is_player_playing = mic_player.playing
			print("🔊 [Debug] Bus Muted: %s | Player Playing: %s | Hear Own: %s" % [is_bus_muted, is_player_playing, hear_own_audio])
			
			# Force play if stopped
			if not is_player_playing:
				print("⚠️ Player stopped! Restarting...")
				mic_player.play()

func _process_mic_audio():
	if capture_effect and capture_effect.can_get_buffer(BUFFER_SIZE):
		var buffer = capture_effect.get_buffer(BUFFER_SIZE)
		
		# Only push to LiveKit if connected and not muted
		if livekit_manager and livekit_manager.is_room_connected() and not is_muted:
			livekit_manager.push_mic_audio(buffer)
		
		# Visualize level
		var max_amp = 0.0
		for frame in buffer:
			var amp = max(abs(frame.x), abs(frame.y))
			max_amp = max(max_amp, amp)
		
		# Debug buffer content (throttled)
		if _debug_timer > 1.9: # Print just before the other debug print
			print("📊 [Debug] Max Amp: ", max_amp, " | Buffer Size: ", buffer.size())
		
		# Update mic level bar
		mic_level_bar.value = max_amp * 100
		
		# Visual feedback for threshold
		if max_amp > mic_threshold and not is_muted:
			mic_level_bar.modulate = Color.GREEN
		else:
			mic_level_bar.modulate = Color.WHITE


func _on_connect_pressed():
	var server_url = server_entry.text
	var token = token_entry.text
	
	if server_url.is_empty() or token.is_empty():
		status_label.text = "❌ Error: Enter server URL and token"
		return
	
	status_label.text = "⏳ Connecting..."
	connect_button.disabled = true
	
	livekit_manager.connect_to_room(server_url, token)

func _on_disconnect_pressed():
	# livekit_manager.disconnect_from_room() # Assuming this method exists or we just free it?
	# The Rust code didn't implement disconnect explicitly in the new version, 
	# but we can just reload the scene or implement it if needed.
	# For now, let's just reload the scene to disconnect cleanly.
	get_tree().reload_current_scene()


func _on_room_connected():
	print("✅ Connected to room!")
	status_label.text = "✅ Connected"
	connect_button.disabled = true
	disconnect_button.disabled = false
	
	# Add local participant
	_add_participant("You (local)", 0.0)

func _on_room_disconnected():
	print("📴 Disconnected")
	status_label.text = "Disconnected"
	connect_button.disabled = false
	disconnect_button.disabled = true
	
	# Clear participant list
	for child in participant_list.get_children():
		child.queue_free()
	participants.clear()

func _on_participant_joined(identity: String):
	print("👤 Participant joined: ", identity)
	_add_participant(identity, 0.0)
	_update_participant_list()

func _on_participant_left(identity: String):
	print("👋 Participant left: ", identity)
	if participants.has(identity):
		var player = participants[identity]
		if player:
			player.queue_free()
		participants.erase(identity)
		_update_participant_list()

func _on_audio_frame(peer_id: String, frame: PackedVector2Array):
	# Ensure participant exists in dictionary
	if not participants.has(peer_id):
		participants[peer_id] = null
		_update_participant_list()
	
	# Create audio player if needed
	if participants[peer_id] == null:
		_create_participant_audio(peer_id)
	
	var player = participants[peer_id]
	if player:
		var playback = player.get_stream_playback()
		if playback:
			playback.push_buffer(frame)

func _create_participant_audio(peer_id: String):
	# Only create if we don't already have a player for this participant
	if not participants.has(peer_id) or participants[peer_id] == null:
		var player = AudioStreamPlayer.new()
		var generator = AudioStreamGenerator.new()
		generator.buffer_length = 0.1 # 100ms buffer
		generator.mix_rate = 48000
		player.stream = generator
		player.autoplay = true
		add_child(player)
		player.play()
		participants[peer_id] = player
		print("   Created audio player for: ", peer_id)
		_update_participant_list()

func _on_error(msg: String):
	print("❌ Error: ", msg)
	status_label.text = "Error: " + msg
	connect_button.disabled = false


func _on_mute_toggle():
	is_muted = !is_muted
	mute_button.text = "🔇 Muted" if is_muted else "🎤 Mic Active"
	
	# We don't stop the player so we can still see visualization if we wanted,
	# but for now let's just stop pushing audio in _process_mic_audio.
	# Also update visualizer color
	mic_level_bar.modulate = Color.GRAY if is_muted else Color.WHITE

func _on_threshold_changed(value: float):
	mic_threshold = value
	threshold_label.text = "%.2f" % mic_threshold

func _on_hear_audio_toggled(button_pressed: bool):
	hear_own_audio = button_pressed
	if audio_bus_idx != -1:
		# Mute the bus if we DON'T want to hear it
		AudioServer.set_bus_mute(audio_bus_idx, not hear_own_audio)
		print("🔊 Hear own audio: ", hear_own_audio, " (Bus Muted: ", not hear_own_audio, ")")


func _add_participant(name: String, _level: float):
	if not participants.has(name):
		# Add participant with null audio player initially
		# The player will be created when first audio frame arrives
		participants[name] = null
		print("   Added participant to list: ", name)


func _update_participant_list():
	# Clear existing
	for child in participant_list.get_children():
		child.queue_free()
	
	# Update participant count in title
	var participants_title = $Panel/VBoxContainer/ParticipantsTitle
	if participants_title:
		participants_title.text = "👥 Participants (%d)" % participants.size()
	
	# Add all participants
	for participant_id in participants.keys():
		var hbox = HBoxContainer.new()
		
		# Name label
		var name_label = Label.new()
		name_label.text = participant_id
		name_label.custom_minimum_size = Vector2(150, 0)
		hbox.add_child(name_label)
		
		# Status indicator (shows if audio player is active)
		var status_label = Label.new()
		var has_audio = participants[participant_id] != null
		status_label.text = "🔊" if has_audio else "⏸️"
		status_label.custom_minimum_size = Vector2(30, 0)
		hbox.add_child(status_label)
		
		# Audio level bar
		var level_bar = ProgressBar.new()
		level_bar.custom_minimum_size = Vector2(100, 20)
		level_bar.value = 0 # No level info yet
		level_bar.show_percentage = false
		hbox.add_child(level_bar)
		
		participant_list.add_child(hbox)
