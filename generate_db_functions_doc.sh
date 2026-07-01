#!/bin/bash
# Rigenera l'appendice auto-generata in fondo a Documents/Funzioni_DB.md interrogando pg_catalog
# sul DB Docker reale. La parte curata a mano (sopra il marker) non viene mai toccata.
set -e

CONTAINER="postgres_db"
DB="gestione_viaggi"
USER="postgres"
REF="Documents/Funzioni_DB.md"
MARKER_START="<!-- AUTO-GENERATED-START (generate_db_functions_doc.sh — NON modificare a mano, rigenerato da deploy_sql.sh) -->"
MARKER_END="<!-- AUTO-GENERATED-END -->"

TMP_CURATED=$(mktemp)
TMP_APPENDIX=$(mktemp)
trap 'rm -f "$TMP_CURATED" "$TMP_APPENDIX"' EXIT

# Tutto ciò che precede il marker (parte curata a mano). Se il marker non esiste ancora
# (prima esecuzione), awk stampa l'intero file: l'appendice verrà aggiunta in fondo.
awk -v marker="$MARKER_START" '$0 == marker {exit} {print}' "$REF" > "$TMP_CURATED"

QUERY_LIST="
SELECT p.proname || '|' ||
       pg_catalog.pg_get_function_arguments(p.oid) || '|' ||
       pg_catalog.pg_get_function_result(p.oid) || '|' ||
       COALESCE(d.description, '')
FROM pg_catalog.pg_proc p
LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
LEFT JOIN pg_catalog.pg_description d ON p.oid = d.objoid
WHERE n.nspname = 'public'
  AND p.prokind != 'a'
  AND NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_depend dep
      WHERE dep.objid = p.oid AND dep.deptype = 'e'
  )
ORDER BY p.proname;
"

QUERY_NAMES="
SELECT p.proname FROM pg_catalog.pg_proc p
LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prokind != 'a'
  AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_depend dep WHERE dep.objid = p.oid AND dep.deptype = 'e')
ORDER BY p.proname;
"

{
  echo "$MARKER_START"
  echo
  echo "## 📌 Appendice Auto-Generata (pg_catalog)"
  echo
  echo "> Rigenerata automaticamente da \`generate_db_functions_doc.sh\` (invocato da \`deploy_sql.sh\`) leggendo lo schema reale su Docker \`$CONTAINER\`."
  echo "> Non modificare questa sezione a mano: viene sovrascritta ad ogni deploy."
  echo
  echo "| Function | Argomenti | Output | Commento DB (\`COMMENT ON FUNCTION\`) |"
  echo "|---|---|---|---|"
} > "$TMP_APPENDIX"

docker exec -i "$CONTAINER" psql -U "$USER" -d "$DB" -t -A -c "$QUERY_LIST" \
  | while IFS='|' read -r name args result descr; do
      [ -z "$name" ] && continue
      echo "| \`$name\` | $args | $result | $descr |" >> "$TMP_APPENDIX"
    done

{
  echo
  echo "### Funzioni nel DB non citate nella parte curata sopra"
  echo
} >> "$TMP_APPENDIX"

docker exec -i "$CONTAINER" psql -U "$USER" -d "$DB" -t -A -c "$QUERY_NAMES" \
  | while read -r name; do
      [ -z "$name" ] && continue
      grep -q "\`$name\`" "$TMP_CURATED" || echo "- \`$name\`" >> "$TMP_APPENDIX"
    done

if ! grep -q '^- `' "$TMP_APPENDIX"; then
  echo "(nessuna — tutte le funzioni risultano citate sopra)" >> "$TMP_APPENDIX"
fi

echo "$MARKER_END" >> "$TMP_APPENDIX"

MISSING=$(grep -c '^- `' "$TMP_APPENDIX" || true)

{
  cat "$TMP_CURATED"
  echo
  cat "$TMP_APPENDIX"
} > "$REF.new"
mv "$REF.new" "$REF"

echo "Appendice rigenerata in fondo a $REF"
if [ "$MISSING" -gt 0 ]; then
  echo "⚠️  $MISSING funzione/i non citate nella parte curata — vedi fondo di $REF"
fi
