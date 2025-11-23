const { AccessToken } = require('livekit-server-sdk');

const API_KEY = 'devkey';
const API_SECRET = 'secret';

async function generateToken() {
    const at = new AccessToken(API_KEY, API_SECRET, {
        identity: 'godot-user',
        name: 'Godot Test User',
    });

    at.addGrant({
        room: 'test-room',
        roomJoin: true,
        canPublish: true,
        canSubscribe: true,
    });

    const token = await at.toJwt();
    console.log('LiveKit Access Token:');
    console.log(token);
    console.log('\nServer URL: ws://localhost:7880');
    console.log('Room: test-room');
    return token;
}

generateToken();
