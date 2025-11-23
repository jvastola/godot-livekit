using Godot;
using LiveKit.Proto;
using Google.Protobuf;
using System;

[GlobalClass]
public partial class LiveKitManager : Node
{
    [Signal]
    public delegate void RoomConnectedEventHandler();

    [Signal]
    public delegate void DisconnectedEventHandler();

    private WebSocketPeer _ws = new WebSocketPeer();
    private bool _connected = false;
    private string _token;
    private WebRtcPeerConnection _publisher;
    private WebRtcPeerConnection _subscriber;
    
    // Audio capture components
    private AudioStreamPlayer _micPlayer;
    private int _audioBusIndex;
    private string _localTrackCid;
    private Godot.Collections.Dictionary<string, AudioStreamPlayer> _remotePlayers = new();

    public override void _Ready()
    {
        SetProcess(false);
        _publisher = new WebRtcPeerConnection();
        _subscriber = new WebRtcPeerConnection();
        
        _publisher.SessionDescriptionCreated += OnPublisherSessionDescriptionCreated;
        _publisher.Connect("ice_candidate_created", Callable.From<string, int, string>(OnPublisherIceCandidateCreated));
        
        _subscriber.SessionDescriptionCreated += OnSubscriberSessionDescriptionCreated;
        _subscriber.Connect("ice_candidate_created", Callable.From<string, int, string>(OnSubscriberIceCandidateCreated));
        _subscriber.Connect("track_added", Callable.From<int>(OnTrackAdded));
        
        // Initialize WebSocket
        _ws = new WebSocketPeer();
        
        // Setup microphone audio capture
        SetupMicrophone();
    }
    
    private void SetupMicrophone()
    {
        // Create audio player for microphone
        _micPlayer = new AudioStreamPlayer();
        _micPlayer.Stream = new AudioStreamMicrophone();
        _micPlayer.Autoplay = true;
        AddChild(_micPlayer);
        
        // Create "Record" audio bus if it doesn't exist
        _audioBusIndex = AudioServer.GetBusIndex("Record");
        if (_audioBusIndex == -1)
        {
            _audioBusIndex = AudioServer.BusCount;
            AudioServer.AddBus(_audioBusIndex);
            AudioServer.SetBusName(_audioBusIndex, "Record");
            
            // Add AudioEffectCapture to the bus
            var captureEffect = new AudioEffectCapture();
            AudioServer.AddBusEffect(_audioBusIndex, captureEffect, 0);
            
            GD.Print("✅ Created 'Record' audio bus with capture effect");
        }
        
        _micPlayer.Bus = "Record";
        GD.Print("🎤 Microphone setup complete");
    }

    public void ConnectToRoom(string url, string token)
    {
        GD.Print($"Connecting to {url}...");
        
        // LiveKit WS URL format
        string wsUrl = url.Replace("http", "ws");
        if (!wsUrl.EndsWith("/rtc"))
        {
             wsUrl += "/rtc";
        }
        wsUrl += $"?access_token={token}&protocol=8&sdk=godot&version=0.1.0";
        _token = token;
        
        Error err = _ws.ConnectToUrl(wsUrl);
        if (err != Error.Ok)
        {
            GD.PrintErr("Failed to connect to WebSocket");
            return;
        }
        SetProcess(true);
    }

    public override void _Process(double delta)
    {
        _ws.Poll();
        var state = _ws.GetReadyState();
        if (state == WebSocketPeer.State.Open)
        {
            if (!_connected)
            {
                _connected = true;
                GD.Print("✅ WebSocket connected, waiting for JoinResponse...");
            }
            while (_ws.GetAvailablePacketCount() > 0)
            {
                var packet = _ws.GetPacket();
                GD.Print($"📦 Received packet of {packet.Length} bytes");
                HandleMessage(packet);
            }
        }
        else if (state == WebSocketPeer.State.Connecting)
        {
            // Still connecting
        }
        else if (state == WebSocketPeer.State.Closed)
        {
            if (_connected)
            {
                var code = _ws.GetCloseCode();
                var reason = _ws.GetCloseReason();
                GD.Print($"❌ WebSocket closed: {code} - {reason}");
                _connected = false;
                SetProcess(false);
                EmitSignal(SignalName.Disconnected);
            }
        }
    }

    private void SendRequest(SignalRequest req)
    {
        _ws.PutPacket(req.ToByteArray());
    }

    private void OnPublisherSessionDescriptionCreated(string type, string sdp)
    {
        SetLocalDescription(_publisher, type, sdp);
        if (type == "offer")
        {
            var req = new SignalRequest
            {
                Offer = new SessionDescription { Type = type, Sdp = sdp }
            };
            SendRequest(req);
        }
        else if (type == "answer")
        {
             var req = new SignalRequest
            {
                Answer = new SessionDescription { Type = type, Sdp = sdp }
            };
            SendRequest(req);
        }
    }
    
    private void OnSubscriberSessionDescriptionCreated(string type, string sdp)
    {
        SetLocalDescription(_subscriber, type, sdp);
        if (type == "answer")
        {
             var req = new SignalRequest
            {
                Answer = new SessionDescription { Type = type, Sdp = sdp }
            };
            SendRequest(req);
        }
    }

    private void OnPublisherIceCandidateCreated(string media, int index, string name)
    {
        var req = new SignalRequest
        {
            Trickle = new TrickleRequest
            {
                CandidateInit = $"{{\"candidate\":\"{name}\",\"sdpMid\":\"{media}\",\"sdpMLineIndex\":{index}}}",
                Target = SignalTarget.Publisher
            }
        };
        SendRequest(req);
    }
    
    private void OnSubscriberIceCandidateCreated(string media, int index, string name)
    {
        var req = new SignalRequest
        {
            Trickle = new TrickleRequest
            {
                CandidateInit = $"{{\"candidate\":\"{name}\",\"sdpMid\":\"{media}\",\"sdpMLineIndex\":{index}}}",
                Target = SignalTarget.Subscriber
            }
        };
        SendRequest(req);
    }

    private void SetLocalDescription(WebRtcPeerConnection pc, string type, string sdp)
    {
        pc.SetLocalDescription(type, sdp);
    }

    private void HandleMessage(byte[] packet)
    {
        try
        {
            var response = SignalResponse.Parser.ParseFrom(packet);
            
            switch (response.MessageCase)
            {
                case SignalResponse.MessageOneofCase.Join:
                    GD.Print("Joined Room: " + response.Join.Room.Name);
                    
                    // Parse ICE servers
                    var iceServers = new Godot.Collections.Array();
                    foreach (var server in response.Join.IceServers)
                    {
                        var entry = new Godot.Collections.Dictionary();
                        var urls = new Godot.Collections.Array();
                        foreach (var url in server.Urls)
                        {
                            urls.Add(url);
                        }
                        entry["urls"] = urls;
                        if (!string.IsNullOrEmpty(server.Username))
                        {
                            entry["username"] = server.Username;
                            entry["credential"] = server.Credential;
                        }
                        iceServers.Add(entry);
                    }
                    
                    var config = new Godot.Collections.Dictionary
                    {
                        { "iceServers", iceServers }
                    };
                    
                    _publisher.Initialize(config);
                    _subscriber.Initialize(config);
                    
                    // Add audio track to publisher
                    AddAudioTrack();
                    
                    EmitSignal(SignalName.RoomConnected);
                    break;
                case SignalResponse.MessageOneofCase.Offer:
                    GD.Print("Received Offer");
                    _subscriber.SetRemoteDescription("offer", response.Offer.Sdp);
                    _subscriber.Call("create_answer"); 
                    break;
                case SignalResponse.MessageOneofCase.Answer:
                    GD.Print("Received Answer");
                    _publisher.SetRemoteDescription("answer", response.Answer.Sdp);
                    break;
                case SignalResponse.MessageOneofCase.Trickle:
                    // HandleTrickle(response.Trickle);
                    break;
            }
        }
        catch (Exception e)
        {
            GD.PrintErr("Error parsing message: " + e.Message);
        }
    }
    
    private void AddAudioTrack()
    {
        try
        {
            // Generate a client ID for this track
            _localTrackCid = Guid.NewGuid().ToString("N").Substring(0, 16);
            
            // Add media stream track to publisher
            // Note: Godot's WebRTC will automatically capture from the microphone
            var trackId = _publisher.Call("add_track", "audio", _micPlayer.Stream).AsInt32();
            
            GD.Print($"🎵 Added audio track to publisher (Track ID: {trackId}, CID: {_localTrackCid})");
            
            // Send AddTrackRequest to LiveKit server
            var addTrackRequest = new SignalRequest
            {
                AddTrack = new AddTrackRequest
                {
                    Cid = _localTrackCid,
                    Name = "microphone",
                    Type = TrackType.Audio,
                    Source = TrackSource.Microphone,
                    DisableDtx = false,
                    DisableRed = false
                }
            };
            
            SendRequest(addTrackRequest);
            GD.Print("📤 Sent AddTrackRequest to LiveKit server");
        }
        catch (Exception e)
        {
            GD.PrintErr($"❌ Error adding audio track: {e.Message}");
        }
    }
    
    private void OnTrackAdded(int trackId)
    {
        try
        {
            GD.Print($"🔊 Remote audio track added (Track ID: {trackId})");
            
            // Create an AudioStreamPlayer for the remote participant
            var remotePlayer = new AudioStreamPlayer();
            var trackKey = $"track_{trackId}";
            
            // Get the media stream track from subscriber
            remotePlayer.Stream = _subscriber.Call("get_track", trackId).As<AudioStream>();
            remotePlayer.Autoplay = true;
            remotePlayer.VolumeDb = 0.0f;
            
            AddChild(remotePlayer);
            _remotePlayers[trackKey] = remotePlayer;
            
            GD.Print($"✅ Remote audio player created and playing");
        }
        catch (Exception e)
        {
            GD.PrintErr($"❌ Error handling remote track: {e.Message}");
        }
    }
}



