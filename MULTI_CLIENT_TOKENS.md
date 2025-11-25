# Multi-Client Testing Quick Guide

## Generated Tokens (Valid until 2025-11-26 12:07:27)

### CLIENT 1 (client-1) - Already set in script
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjQxODc2NDcsImlzcyI6ImRldmtleSIsIm5iZiI6MTc2NDEwMTI0Nywic3ViIjoiY2xpZW50LTEiLCJ2aWRlbyI6eyJyb29tIjoidGVzdC1yb29tIiwicm9vbUpvaW4iOnRydWUsImNhblB1Ymxpc2giOnRydWUsImNhblN1YnNjcmliZSI6dHJ1ZX19.tR0faOukMG6GJFXrCRVtPmEJhnbig_pirRyjcqvqy3M
```

### CLIENT 2 (client-2) - For second Godot instance
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjQxODc2NDcsImlzcyI6ImRldmtleSIsIm5iZiI6MTc2NDEwMTI0Nywic3ViIjoiY2xpZW50LTIiLCJ2aWRlbyI6eyJyb29tIjoidGVzdC1yb29tIiwicm9vbUpvaW4iOnRydWUsImNhblB1Ymxpc2giOnRydWUsImNhblN1YnNjcmliZSI6dHJ1ZX19.ilVW4UOCDu-OD98Ytfx3IboTIOx6d8Rm5N7aLSQv1ec
```

### CLIENT 3 (client-3) - For third client or web browser
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjQxODc2NDcsImlzcyI6ImRldmtleSIsIm5iZiI6MTc2NDEwMTI0Nywic3ViIjoiY2xpZW50LTMiLCJ2aWRlbyI6eyJyb29tIjoidGVzdC1yb29tIiwicm9vbUpvaW4iOnRydWUsImNhblB1Ymxpc2giOnRydWUsImNhblN1YnNjcmliZSI6dHJ1ZX19.cIdwmm3jhkoFzDrjQuE5nYtlkw3C_rzlpcnYIp_FyAo
```

## Quick Test Steps

### Two Godot Instances
1. **First Instance**: Just run the demo (already has client-1 token)
2. **Second Instance**: Open another Godot, paste CLIENT 2 token, connect
3. Both should stay connected and hear each other!

### With Web Browser
1. Open https://meet.livekit.io/custom
2. Enter:
   - LiveKit URL: `ws://localhost:7880`
   - Token: *(CLIENT 3 token from above)*
3. Join room and test audio

## Each client needs a different token!
The reason they were disconnecting is because they all used the same identity ("test-user"). Now each has a unique identity (client-1, client-2, client-3).
