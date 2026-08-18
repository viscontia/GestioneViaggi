#!/bin/bash
# Campiona la memoria mentre si lavora, per rispondere a una domanda sola:
# l'applicazione accumula, oppure e' la macchina che e' gia' satura?
#
# Nasce dalle chiusure improvvise del 2026-08-18. Il registro di sistema ha mostrato i processi
# ausiliari di WebKit che cadono in cascata (rete, GPU, rendering) e WebKit che ricarica la pagina
# da solo. La swap era a 12.7 GB su 14.3: la macchina uccideva processi per fare spazio, e quelli
# di WebKit sono i primi candidati perche' sono fatti per essere ricreati.
#
# Quel numero pero' non dice DI CHI sia la memoria. Questo script segue nel tempo:
#   - il processo .NET dell'applicazione
#   - i tre processi WebKit che le appartengono (rendering, rete, GPU)
#   - swap e memoria libera di sistema
#
# Se la colonna dell'applicazione sale e non scende mai, il problema e' anche nostro.
# Se resta piatta mentre la swap si riempie, e' l'ambiente.
#
# Uso:  ./Scripts/misura-memoria.sh [secondi_fra_un_campione_e_l_altro]
# Ferma con Ctrl-C. Scrive a video e in ~/Library/Logs/gestioneviaggi-memoria-<data>.csv

INTERVALLO="${1:-10}"
USCITA="$HOME/Library/Logs/gestioneviaggi-memoria-$(date +%Y-%m-%d).csv"

# In MB, perche' ps riporta in KB e nessuno ragiona in KB.
mb() { awk -v k="${1:-0}" 'BEGIN { printf "%.0f", k/1024 }'; }

# RSS totale di tutti i processi il cui comando contiene il testo dato.
rss_di() {
    local somma
    somma=$(ps -Ao rss=,command= | grep -i -- "$1" | grep -v grep | awk '{s+=$1} END {print s+0}')
    mb "$somma"
}

if [ ! -f "$USCITA" ]; then
    echo "quando,app_mb,webcontent_mb,networking_mb,gpu_mb,swap_usata_mb,memoria_libera_pct" > "$USCITA"
fi

printf '%-8s %8s %8s %8s %8s %10s %8s\n' ORA APP RENDER RETE GPU SWAP LIBERA%
echo "Registro: $USCITA   (Ctrl-C per fermare)"

while true; do
    ora=$(date +%H:%M:%S)
    app=$(rss_di "GestioneViaggi.app/Contents/MacOS")
    web=$(rss_di "WebKit.WebContent")
    net=$(rss_di "WebKit.Networking")
    gpu=$(rss_di "WebKit.GPU")

    # sysctl riporta la swap come "1234.00M" o "1.20G": si normalizza in MB.
    swap=$(sysctl -n vm.swapusage | sed -n 's/.*used = \([0-9.]*\)\([MG]\).*/\1 \2/p' \
           | awk '{ printf "%.0f", ($2=="G") ? $1*1024 : $1 }')
    libera=$(memory_pressure 2>/dev/null | sed -n 's/.*free percentage: \([0-9]*\)%.*/\1/p')

    printf '%-8s %8s %8s %8s %8s %10s %8s\n' \
           "$ora" "$app" "$web" "$net" "$gpu" "${swap:-?}" "${libera:-?}"
    echo "$ora,$app,$web,$net,$gpu,${swap:-},${libera:-}" >> "$USCITA"

    sleep "$INTERVALLO"
done
