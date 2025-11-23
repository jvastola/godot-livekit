extends SceneTree

func _init():
	var peer = WebRTCPeerConnection.new()
	if peer:
		print("WebRTC is working!")
	else:
		print("WebRTC failed to initialize.")
	quit()
