#!/usr/bin/env python3
"""
LiveKit Access Token Generator - Multi-Client Version
Generates tokens for multiple participants
"""

import jwt
import time
from datetime import datetime, timedelta

# CONFIGURE YOUR LIVEKIT CREDENTIALS HERE
API_KEY = "devkey"
API_SECRET = "secret"

# Token configuration
ROOM_NAME = "test-room"
TOKEN_VALIDITY_HOURS = 24

# Participant names for multi-client testing
PARTICIPANTS = ["client-1", "client-2", "client-3"]

def generate_token(room: str, participant: str):
    """Generate a LiveKit access token."""
    
    # Token claims
    now = int(time.time())
    exp = now + (TOKEN_VALIDITY_HOURS * 3600)
    
    claims = {
        "exp": exp,
        "iss": API_KEY,
        "nbf": now,
        "sub": participant,
        "video": {
            "room": room,
            "roomJoin": True,
            "canPublish": True,
            "canSubscribe": True,
        }
    }
    
    # Generate token
    token = jwt.encode(claims, API_SECRET, algorithm="HS256")
    
    return token

if __name__ == "__main__":
    print("=" * 70)
    print("LiveKit Multi-Client Token Generator")
    print("=" * 70)
    print()
    
    print(f"Room: {ROOM_NAME}")
    print(f"Valid for: {TOKEN_VALIDITY_HOURS} hours")
    print()
    
    for i, participant in enumerate(PARTICIPANTS, 1):
        token = generate_token(ROOM_NAME, participant)
        
        print(f"CLIENT {i} ({participant}):")
        print("-" * 70)
        print(token)
        print()
    
    print("=" * 70)
    print("Copy different tokens for each client to test multi-user audio!")
    print()
    
    # Show expiry time
    exp_time = datetime.now() + timedelta(hours=TOKEN_VALIDITY_HOURS)
    print(f"All tokens expire: {exp_time.strftime('%Y-%m-%d %H:%M:%S')}")
