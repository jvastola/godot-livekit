extends Control

# This script visualizes microphone input as a waveform.
# It does not depend on any other project code.

var audio_bus_index : int = -1
var effect_capture : AudioEffectCapture = null
var audio_buffer = []
var frequency_bands = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
const BUFFER_SIZE = 512
const MIC_THRESHOLD = 0.05  # Activation threshold for mic
var is_mic_active = false
var peak_level = 0.0


func _ready():
	# Get the master bus
	audio_bus_index = 0
	
	# Create and add the capture effect to master bus
	effect_capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(audio_bus_index, effect_capture)
	
	# Create microphone stream and player
	var mic_stream = AudioStreamMicrophone.new()
	var player = AudioStreamPlayer.new()
	player.stream = mic_stream
	player.bus = AudioServer.get_bus_name(audio_bus_index)  # Route to master bus where we capture
	add_child(player)
	player.play()

	set_process(true)


func _process(_delta):
	# Get captured audio data
	if effect_capture and effect_capture.can_get_buffer(BUFFER_SIZE):
		var buffer = effect_capture.get_buffer(BUFFER_SIZE)
		if buffer.size() > 0:
			peak_level = 0.0
			for i in range(buffer.size()):
				audio_buffer.append(buffer[i])
				if audio_buffer.size() > BUFFER_SIZE:
					audio_buffer.pop_front()
				# Calculate peak level
				var amplitude = buffer[i]
				if amplitude is Vector2:
					amplitude = amplitude.x
				var abs_amp = abs(float(amplitude))
				peak_level = max(peak_level, abs_amp)
			
			# Update frequency bands for bar visualization
			_update_frequency_bands()
			is_mic_active = peak_level > MIC_THRESHOLD
	
	queue_redraw()


func _update_frequency_bands():
	# Divide buffer into frequency bands and calculate average amplitude
	var band_size = audio_buffer.size() / frequency_bands.size()
	if band_size == 0:
		return
	
	for band_idx in range(frequency_bands.size()):
		var sum = 0.0
		var count = 0
		var start = band_idx * band_size
		var end = min(start + band_size, audio_buffer.size())
		
		for i in range(start, end):
			var amplitude = audio_buffer[i]
			if amplitude is Vector2:
				amplitude = amplitude.x
			sum += abs(float(amplitude))
			count += 1
		
		if count > 0:
			frequency_bands[band_idx] = sum / count


func _draw():
	var w = size.x
	var h = size.y
	
	# Draw background
	draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.05, 0.1, 1))
	
	# Draw center line
	draw_line(Vector2(0, h / 2), Vector2(w, h / 2), Color(0.3, 0.3, 0.3, 0.5), 1.0)
	
	# Draw mic activation indicator
	if is_mic_active:
		draw_rect(Rect2(10, 10, 20, 20), Color(0, 1, 0, 1))
		_draw_text_with_outline(Vector2(35, 15), "MIC ACTIVE", Color(0, 1, 0))
	else:
		draw_rect(Rect2(10, 10, 20, 20), Color(0.5, 0.5, 0.5, 0.5))
		_draw_text_with_outline(Vector2(35, 15), "MIC IDLE", Color(0.5, 0.5, 0.5))
	
	# Draw waveform
	_draw_waveform(w, h)
	
	# Draw frequency bars
	_draw_frequency_bars(w, h)
	
	# Draw peak level indicator
	_draw_peak_level(w, h)


func _draw_waveform(w: float, h: float):
	if audio_buffer.size() < 2:
		return
	
	var mid = h / 2.5  # Adjust midpoint
	var step = w / float(audio_buffer.size())
	var points = PackedVector2Array()
	
	for i in range(audio_buffer.size()):
		var x = i * step
		var amplitude = audio_buffer[i]
		if amplitude is Vector2:
			amplitude = amplitude.x
		var y = mid - float(amplitude) * mid * 8.0
		y = clamp(y, 0, h)
		points.append(Vector2(x, y))
	
	draw_polyline(points, Color(0, 1, 0, 0.8), 1.5)


func _draw_frequency_bars(w: float, h: float):
	var bar_width = w / frequency_bands.size()
	var bar_spacing = 2.0
	var bar_start_y = h * 0.7
	
	for i in range(frequency_bands.size()):
		var bar_height = frequency_bands[i] * (h * 0.25) * 10.0  # Scale up for visibility
		var x = i * bar_width + bar_spacing
		var y = bar_start_y
		
		# Color gradient based on frequency
		var color = Color(0, 1, 0).lerp(Color(1, 0, 0), float(i) / frequency_bands.size())
		color.a = 0.7
		
		draw_rect(Rect2(x, y - bar_height, bar_width - bar_spacing * 2, bar_height), color)
		draw_rect(Rect2(x, y, bar_width - bar_spacing * 2, 1), Color(0.3, 0.3, 0.3, 1))


func _draw_peak_level(w: float, h: float):
	var peak_bar_width = w * peak_level
	draw_rect(Rect2(0, h - 10, peak_bar_width, 10), Color(1, 1, 0, 0.7))
	draw_rect(Rect2(peak_bar_width, h - 10, w - peak_bar_width, 10), Color(0.1, 0.1, 0.1, 0.7))


func _draw_text_with_outline(pos: Vector2, text: String, color: Color):
	var font = get_theme_default_font()
	var font_size = get_theme_default_font_size()
	
	# Draw outline
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx != 0 or dy != 0:
				draw_string(font, pos + Vector2(dx, dy), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)
	
	# Draw main text
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
