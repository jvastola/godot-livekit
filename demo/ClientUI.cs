using Godot;
using System;

[GlobalClass]
public partial class ClientUI : Control
{
    private LineEdit _hostInput;
    private LineEdit _tokenInput;
    private Label _statusLabel;
    private Button _connectButton;
    private LiveKitManager _livekitManager;

    public override void _Ready()
    {
        // Get UI nodes
        _hostInput = GetNode<LineEdit>("VBoxContainer/HostContainer/HostInput");
        _tokenInput = GetNode<LineEdit>("VBoxContainer/TokenContainer/TokenInput");
        _statusLabel = GetNode<Label>("VBoxContainer/StatusLabel");
        _connectButton = GetNode<Button>("VBoxContainer/ConnectButton");

        // Set default values for instant testing
        _hostInput.Text = "ws://localhost:7880";
        _tokenInput.Text = "eyJhbGciOiJIUzI1NiJ9.eyJuYW1lIjoiR29kb3QgVGVzdCBVc2VyIiwidmlkZW8iOnsicm9vbSI6InRlc3Qtcm9vbSIsInJvb21Kb2luIjp0cnVlLCJjYW5QdWJsaXNoIjp0cnVlLCJjYW5TdWJzY3JpYmUiOnRydWV9LCJpc3MiOiJkZXZrZXkiLCJleHAiOjE3NjM5NTQ1MDEsIm5iZiI6MCwic3ViIjoiZ29kb3QtdXNlciJ9.mRre6KcUsHWiXmoTVLSC8-TKoHQCzvjhlLTbe6htwRg";
        _statusLabel.Text = "Ready - Click Connect to join test-room";

        // Connect button signal
        _connectButton.Pressed += OnConnectButtonPressed;

        // Create LiveKitManager directly in C#
        _livekitManager = new LiveKitManager();
        AddChild(_livekitManager);
        
        // Connect to LiveKit signals
        _livekitManager.RoomConnected += OnRoomConnected;
        _livekitManager.Disconnected += OnDisconnected;

        GD.Print("ClientUI initialized successfully with LiveKitManager");
        GD.Print("LiveKit Server: ws://localhost:7880");
        GD.Print("Room: test-room");
        GD.Print("✅ Ready to connect! Click 'Connect' button or just press F5 to run.");
    }

    private void OnConnectButtonPressed()
    {
        string url = _hostInput.Text;
        string token = _tokenInput.Text;

        if (string.IsNullOrEmpty(url) || string.IsNullOrEmpty(token))
        {
            _statusLabel.Text = "URL and Token required";
            return;
        }

        _statusLabel.Text = "Connecting...";
        _connectButton.Disabled = true;

        // Call C# method directly - no GDScript interop needed!
        _livekitManager.ConnectToRoom(url, token);
    }

    private void OnRoomConnected()
    {
        _statusLabel.Text = "Connected to Room!";
        _connectButton.Text = "Disconnect";
        _connectButton.Disabled = false;
        GD.Print("UI: Room connected!");
    }

    private void OnDisconnected()
    {
        _statusLabel.Text = "Disconnected";
        _connectButton.Text = "Connect";
        _connectButton.Disabled = false;
        GD.Print("UI: Disconnected");
    }
}
