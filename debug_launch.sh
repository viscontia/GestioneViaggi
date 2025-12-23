#!/bin/bash
APP_NAME="GestioneViaggi"
LOG_FILE="maui_syslog.txt"

# Kill existings
pkill -f "$APP_NAME"

# Start log capture
echo "Starting log capture..."
log stream --predicate "process == \"$APP_NAME\"" --style syslog > "$LOG_FILE" &
LOG_PID=$!

# Launch App
echo "Launching App..."
open "bin/Debug/net9.0-maccatalyst/maccatalyst-arm64/GestioneViaggi.app"

# Wait
sleep 10

# Stop log capture
kill $LOG_PID
echo "Log capture stopped."
