#!/bin/bash

# Kill any existing instances
echo "Killing existing GestioneViaggi processes..."
pkill -f "GestioneViaggi" || true

# Build the project
echo "Building project for net9.0-maccatalyst..."
dotnet build -f net9.0-maccatalyst

# Check if build was successful
if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

# Launch the app directly from the app bundle
APP_PATH="./bin/Debug/net9.0-maccatalyst/maccatalyst-arm64/GestioneViaggi.app/Contents/MacOS/GestioneViaggi"

echo "Launching app from: $APP_PATH"
"$APP_PATH"
