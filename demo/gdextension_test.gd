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
var input_device_option: OptionButton
var mic_threshold: float = 0.1
var is_muted: bool = false
var hear_own_audio: bool = false
const BUFFER_SIZE = 4096 # Increased to capture all frames (16ms @ 48kHz is ~800 frames)
var audio_bus_name = "LiveKit Mic"
var audio_bus_idx = -1

# Participants
@onready var participant_list = $Panel/VBoxContainer/ParticipantList

var livekit_manager: Node
var participants = {} # Dictionary of participant_id -> { "player": AudioStreamPlayer, "level": float, "level_bar": ProgressBar, "muted": bool, "volume": float }
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
		
		# Set sample rate
		var mix_rate = AudioServer.get_mix_rate()
		livekit_manager.set_mic_sample_rate(int(mix_rate))
		print("🎤 Set LiveKit mic sample rate to: ", mix_rate)
	else:
		print("❌ LiveKitManager class not found! Is the GDExtension loaded?")
		status_label.text = "❌ Error: GDExtension not loaded"
		connect_button.disabled = true

	
	# Connect UI signals
	connect_button.pressed.connect(_on_connect_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	mute_button.pressed.connect(_on_mute_toggle)
	threshold_slider.value_changed.connect(_on_threshold_changed)
	
	# Create Input Device Selector
	input_device_option = OptionButton.new()
	input_device_option.item_selected.connect(_on_input_device_selected)
	mic_section.add_child(input_device_option)
	_update_input_device_list()

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
	
	# Fix UI Overflow: Wrap ParticipantList in a ScrollContainer
	_setup_scroll_container()

func _setup_scroll_container():
	var parent = participant_list.get_parent()
	if parent:
		var scroll = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size.y = 200 # Ensure some height
		
		# We need to move participant_list inside scroll
		# But we can't easily move it if it's an onready node that might be referenced elsewhere by path
		# Instead, let's just reparent it.
		parent.remove_child(participant_list)
		parent.add_child(scroll)
		scroll.add_child(participant_list)
		
		# Ensure list expands
		participant_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		participant_list.size_flags_vertical = Control.SIZE_EXPAND_FILL

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
	
	# List available input devices
	var input_devices = AudioServer.get_input_device_list()
	print("🎤 Available Input Devices: ", input_devices)
	print("🎤 Current Input Device: ", AudioServer.get_input_device())
	print("🎤 Audio Mix Rate: ", AudioServer.get_mix_rate())
	
	# Start microphone input
	mic_player = AudioStreamPlayer.new()
	mic_player.bus = audio_bus_name
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.autoplay = true
	add_child(mic_player)
	mic_player.play() # Ensure it's playing
	
	print("🎤 Audio capture initialized on '%s' bus (idx: %d)" % [audio_bus_name, audio_bus_idx])
	print("   - Send to: Master")
	# Use volume for "mute" to avoid disabling capture if that's the issue
	AudioServer.set_bus_mute(audio_bus_idx, false)
	AudioServer.set_bus_volume_db(audio_bus_idx, -80.0) # Effectively muted
	print("   - Muted (via volume): ", AudioServer.get_bus_volume_db(audio_bus_idx) < -60)
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

	# Update participant levels
	for p_id in participants:
		var p_data = participants[p_id]
		if p_data.has("level_bar") and p_data["level_bar"]:
			p_data["level_bar"].value = p_data["level"] * 100
			# Decay level
			p_data["level"] = lerp(p_data["level"], 0.0, 10.0 * delta)

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
		var p_data = participants[identity]
		if p_data and p_data.get("player"):
			p_data["player"].queue_free()
		participants.erase(identity)
		_update_participant_list()

func _on_audio_frame(peer_id: String, frame: PackedVector2Array):
	# Ensure participant exists in dictionary
	if not participants.has(peer_id):
		_add_participant(peer_id, 0.0)
		_update_participant_list()
	
	var p_data = participants[peer_id]
	
	# Create audio player if needed
	if p_data["player"] == null:
		_create_participant_audio(peer_id)
		p_data = participants[peer_id] # Refresh ref
	
	# Calculate level
	var max_amp = 0.0
	for sample in frame:
		var amp = max(abs(sample.x), abs(sample.y))
		max_amp = max(max_amp, amp)
	
	# Update level (keep max for visibility)
	p_data["level"] = max(p_data["level"], max_amp)

	var player = p_data["player"]
	if player and not p_data["muted"]:
		var playback = player.get_stream_playback()
		if playback:
			# Apply volume scaling
			var vol = p_data.get("volume", 1.0)
			if vol != 1.0:
				var scaled_frame = PackedVector2Array()
				scaled_frame.resize(frame.size())
				for i in range(frame.size()):
					scaled_frame[i] = frame[i] * vol
				playback.push_buffer(scaled_frame)
			else:
				playback.push_buffer(frame)

func _create_participant_audio(peer_id: String):
	# Only create if we don't already have a player for this participant
	if not participants.has(peer_id):
		_add_participant(peer_id, 0.0)
		
	var p_data = participants[peer_id]
	if p_data["player"] == null:
		var player = AudioStreamPlayer.new()
		var generator = AudioStreamGenerator.new()
		generator.buffer_length = 0.1 # 100ms buffer
		generator.mix_rate = 48000
		player.stream = generator
		player.autoplay = true
		add_child(player)
		player.play()
		
		p_data["player"] = player
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
		# "Mute" by lowering volume, "Unmute" by raising it
		var volume_db = 0.0 if hear_own_audio else -80.0
		AudioServer.set_bus_volume_db(audio_bus_idx, volume_db)
		print("🔊 Hear own audio: ", hear_own_audio, " (Volume: ", volume_db, "dB)")

func _update_input_device_list():
	input_device_option.clear()
	var devices = AudioServer.get_input_device_list()
	var current_device = AudioServer.get_input_device()
	for i in range(devices.size()):
		var device_name = devices[i]
		input_device_option.add_item(device_name)
		if device_name == current_device:
			input_device_option.selected = i

func _on_input_device_selected(index: int):
	var device_name = input_device_option.get_item_text(index)
	AudioServer.set_input_device(device_name)
	print("🎤 Switched Input Device to: ", device_name)
	
	# Restart player just in case driver restart stopped it
	if mic_player:
		mic_player.stop()
		mic_player.play()


func _add_participant(name: String, _level: float):
	if not participants.has(name):
		# Add participant with null audio player initially
		participants[name] = {
			"player": null,
			"level": 0.0,
			"level_bar": null,
			"muted": false,
			"volume": 1.0
		}
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
		var p_data = participants[participant_id]
		var hbox = HBoxContainer.new()
		
		# Name label
		var name_label = Label.new()
		name_label.text = participant_id
		name_label.custom_minimum_size = Vector2(150, 0)
		hbox.add_child(name_label)
		
		# Mute Button
		var mute_btn = Button.new()
		mute_btn.text = "🔇" if p_data["muted"] else "🔊"
		mute_btn.toggle_mode = true
		mute_btn.button_pressed = p_data["muted"]
		mute_btn.pressed.connect(_on_participant_mute_toggled.bind(participant_id, mute_btn))
		hbox.add_child(mute_btn)
		
		# Audio level bar
		var level_bar = ProgressBar.new()
		level_bar.custom_minimum_size = Vector2(100, 20)
		level_bar.value = p_data["level"] * 100
		level_bar.show_percentage = false
		hbox.add_child(level_bar)
		
		# Volume Slider
		var vol_slider = HSlider.new()
		vol_slider.custom_minimum_size = Vector2(100, 0)
		vol_slider.min_value = 0.0
		vol_slider.max_value = 2.0
		vol_slider.step = 0.1
		vol_slider.value = p_data["volume"]
		vol_slider.value_changed.connect(_on_participant_volume_changed.bind(participant_id))
		hbox.add_child(vol_slider)
		
		# Store ref to bar
		p_data["level_bar"] = level_bar
		
		participant_list.add_child(hbox)

func _on_participant_volume_changed(value: float, participant_id: String):
	if participants.has(participant_id):
		participants[participant_id]["volume"] = value
		print("Volume for ", participant_id, " set to ", value)

func _on_participant_mute_toggled(participant_id: String, btn: Button):
	if participants.has(participant_id):
		var p_data = participants[participant_id]
		p_data["muted"] = !p_data["muted"]
		btn.text = "🔇" if p_data["muted"] else "🔊"
		print("Toggled mute for ", participant_id, ": ", p_data["muted"])
