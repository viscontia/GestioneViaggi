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
docker exec -i postgres_db psql -U postgres -d gestione_viaggi < "$SCRIPT"

echo "==> Rigenero l'appendice auto-generata in fondo a Documents/Funzioni_DB.md..."
./generate_db_functions_doc.sh

echo "==> Fatto. Se l'appendice segnala funzioni non citate, documentale a mano nella parte curata di Documents/Funzioni_DB.md."
