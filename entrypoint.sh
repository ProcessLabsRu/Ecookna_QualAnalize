#!/bin/bash
set -e

# Start Bot in background
echo "Starting Telegram Bot..."
python -m bot.main &

# Start Web Server in foreground
echo "Starting Web Interface..."
exec uvicorn web.app:app --host 0.0.0.0 --port 8000
