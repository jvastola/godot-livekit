#!/usr/bin/env python3
"""
Quick LiveKit Token Generator - Command Line Version
Quickly generate a token with a specific Nakama user_id

Usage:
  python3 generate_token_quick.py <nakama_user_id>

Example:
  python3 generate_token_quick.py abc123xyz
"""

import sys
from generate_token import generate_token, ROOM_NAME, TOKEN_VALIDITY_HOURS
from datetime import datetime, timedelta

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Error: Missing Nakama user_id argument")
        print()
        print("Usage: python3 generate_token_quick.py <nakama_user_id>")
        print()
        print("Example: python3 generate_token_quick.py abc123xyz")
        sys.exit(1)
    
    nakama_id = sys.argv[1]
    
    print("=" * 70)
    print("LiveKit Token Generator")
    print("=" * 70)
    print()
    print(f"Room: {ROOM_NAME}")
    print(f"Participant (Nakama ID): {nakama_id}")
    print(f"Valid for: {TOKEN_VALIDITY_HOURS} hours")
    print()
    
    token = generate_token(ROOM_NAME, nakama_id)
    
    print("TOKEN:")
    print("-" * 70)
    print(token)
    print()
    
    # Show expiry time
    exp_time = datetime.now() + timedelta(hours=TOKEN_VALIDITY_HOURS)
    print(f"Expires: {exp_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)
