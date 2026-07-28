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

# Master key dei segreti (SMTP/ESP/Claude, cifrati con pgcrypto).
# La si carica QUI e non dal profilo della shell: questo script gira anche con bash o da una shell
# non interattiva, che ~/.zshrc non lo legge affatto. Senza la key l'app parte lo stesso, ma le
# schede che leggono segreti (Traduzioni, SMTP) mostrano un avviso e disabilitano le funzioni.
SECRET_FILE="$(dirname "$0")/.gv_secret_key.local.sh"
if [ -z "$GV_SECRET_KEY" ] && [ -f "$SECRET_FILE" ]; then
  # shellcheck disable=SC1090
  . "$SECRET_FILE"
fi

if [ -n "$GV_SECRET_KEY" ]; then
  echo "Master key segreti: caricata."
else
  echo "ATTENZIONE: GV_SECRET_KEY non impostata e $SECRET_FILE assente."
  echo "            Traduzioni/SMTP partiranno con le funzioni sui segreti disabilitate."
fi

echo "Launching app from: $APP_PATH"
"$APP_PATH"
