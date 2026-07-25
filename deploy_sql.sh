#!/bin/bash
# Deploy di uno script SQL su Docker + rigenerazione automatica dello snapshot funzioni DB.
# Uso: ./deploy_sql.sh SqlScripts/NNN_NomeScript.sql
set -e

SCRIPT="$1"
if [ -z "$SCRIPT" ]; then
  echo "Uso: ./deploy_sql.sh SqlScripts/NNN_NomeScript.sql"
  exit 1
fi
if [ ! -f "$SCRIPT" ]; then
  echo "File non trovato: $SCRIPT"
  exit 1
fi

echo "==> Deploy $SCRIPT su Docker (postgres_db)..."
# ON_ERROR_STOP=1: senza, psql stampa l'errore ma esce 0, quindi uno script fallito a meta'
# sembrerebbe deployato (e l'appendice verrebbe rigenerata su uno stato incoerente).
# E' anche la stessa modalita' con cui gli script vengono applicati in PROD (checklist go-live).
if ! docker exec -i postgres_db psql -U postgres -d gestione_viaggi -v ON_ERROR_STOP=1 < "$SCRIPT"; then
  echo "==> DEPLOY FALLITO: correggi lo script e rilancia. Documents/Funzioni_DB.md NON e' stato toccato."
  exit 1
fi

echo "==> Rigenero l'appendice auto-generata in fondo a Documents/Funzioni_DB.md..."
./generate_db_functions_doc.sh

echo "==> Fatto. Se l'appendice segnala funzioni non citate, documentale a mano nella parte curata di Documents/Funzioni_DB.md."
