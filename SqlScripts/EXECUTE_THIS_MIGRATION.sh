#!/bin/bash
# Script di migrazione per aggiornare fn_app_list_users con valuta_default_id
# Eseguire questo script per risolvere il crash del dialogo UserDialog

echo "======================================================"
echo "Migrazione: Update fn_app_list_users per valuta_default_id"
echo "======================================================"
echo ""
echo "IMPORTANTE: Configurare le credenziali del database prima di eseguire"
echo ""
echo "Sostituire i placeholder con i tuoi valori:"
echo "  DB_HOST (default: localhost)"
echo "  DB_PORT (default: 5432)"
echo "  DB_NAME (nome del tuo database)"
echo "  DB_USER (username PostgreSQL)"
echo ""
read -p "Premi INVIO per continuare o CTRL+C per annullare..."

# Configurazione database (MODIFICARE CON I PROPRI VALORI)
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-gestioneviaggi}"
DB_USER="${DB_USER:-postgres}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATION_FILE="$SCRIPT_DIR/Migration_Update_SPs_For_ValutaDefault.sql"

echo ""
echo "Connessione al database:"
echo "  Host: $DB_HOST"
echo "  Port: $DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo ""

# Verifica che il file esista
if [ ! -f "$MIGRATION_FILE" ]; then
    echo "ERRORE: File di migrazione non trovato: $MIGRATION_FILE"
    exit 1
fi

echo "Esecuzione migrazione..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$MIGRATION_FILE"

if [ $? -eq 0 ]; then
    echo ""
    echo "======================================================"
    echo "Migrazione completata con successo!"
    echo "======================================================"
    echo ""
    echo "Verifica che la funzione sia stata aggiornata:"
    echo "  SELECT * FROM fn_app_list_users();"
    echo ""
    echo "La colonna 'valuta_default_id' dovrebbe essere presente."
    echo ""
else
    echo ""
    echo "======================================================"
    echo "ERRORE durante l'esecuzione della migrazione"
    echo "======================================================"
    echo ""
    echo "Verifica:"
    echo "  1. Le credenziali del database"
    echo "  2. Che il database sia in esecuzione"
    echo "  3. I permessi dell'utente"
    echo ""
    exit 1
fi
