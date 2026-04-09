#!/bin/bash
# ============================================================
# Script di migrazione PostgreSQL: Docker Locale → Supabase
# Progetto: Gestione Viaggi Offroad
# ============================================================

set -e

# --- CONFIGURAZIONE ---
DOCKER_CONTAINER="postgres_db"
LOCAL_DB="gestione_viaggi"
LOCAL_USER="postgres"

SUPABASE_HOST="aws-1-eu-central-1.pooler.supabase.com"
SUPABASE_PORT="6543"
SUPABASE_SESSION_PORT="5432"  # Session Pooler: supporta DDL/import completo
SUPABASE_DB="postgres"
SUPABASE_USER="postgres.wqbqvhshojbfuwcuiams"
SUPABASE_PASSWORD="U9Y7KSjQVfZ3N1Ca"
SUPABASE_URI="postgresql://${SUPABASE_USER}:${SUPABASE_PASSWORD}@${SUPABASE_HOST}:${SUPABASE_PORT}/${SUPABASE_DB}"
# URI per operazioni DDL/import: usa Session Pooler (porta 5432) invece del Transaction Pooler (6543)
# Il Transaction Pooler (PgBouncer) non supporta prepared statements e SET SESSION usati durante l'import
SUPABASE_SESSION_URI="postgresql://${SUPABASE_USER}:${SUPABASE_PASSWORD}@${SUPABASE_HOST}:${SUPABASE_SESSION_PORT}/${SUPABASE_DB}"

DUMP_FILE="/tmp/migration_dump_$(date +%Y%m%d_%H%M%S).sql"

# --- COLORI ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- STEP 1: Verifica Docker ---
log_info "Verifica container Docker '${DOCKER_CONTAINER}'..."
if ! docker ps --format '{{.Names}}' | grep -q "^${DOCKER_CONTAINER}$"; then
    log_error "Container '${DOCKER_CONTAINER}' non in esecuzione. Avvialo con: docker start ${DOCKER_CONTAINER}"
    exit 1
fi
log_info "Container Docker OK"

# --- STEP 2: Verifica connessione Supabase ---
log_info "Verifica connessione Supabase..."
if ! PGPASSWORD="${SUPABASE_PASSWORD}" psql "${SUPABASE_URI}" -c "SELECT 1;" > /dev/null 2>&1; then
    log_error "Impossibile connettersi a Supabase. Verifica credenziali e rete."
    exit 1
fi
log_info "Connessione Supabase OK"

# --- STEP 3: pg_dump dal Docker locale ---
log_info "Esecuzione pg_dump da Docker locale..."
docker exec "${DOCKER_CONTAINER}" pg_dump \
    -U "${LOCAL_USER}" \
    -d "${LOCAL_DB}" \
    --no-owner \
    --no-privileges \
    --no-tablespaces \
    --schema=public \
    --schema=staging \
    --format=plain > "${DUMP_FILE}" 2>&1

DUMP_SIZE=$(wc -c < "${DUMP_FILE}" | tr -d ' ')
DUMP_LINES=$(wc -l < "${DUMP_FILE}" | tr -d ' ')
log_info "Dump creato: ${DUMP_FILE} (${DUMP_SIZE} bytes, ${DUMP_LINES} righe)"

# --- STEP 4: Pulizia dump per compatibilita' Supabase ---
log_info "Pulizia dump per Supabase..."

# Rimuovi \restrict e \unrestrict
sed -i '' '/^\\restrict/d' "${DUMP_FILE}"
sed -i '' '/^\\unrestrict/d' "${DUMP_FILE}"

# Fix schema statements
sed -i '' 's/^CREATE SCHEMA public;/-- CREATE SCHEMA public; -- gia esistente su Supabase/' "${DUMP_FILE}"
sed -i '' 's/^CREATE SCHEMA staging;/CREATE SCHEMA IF NOT EXISTS staging;/' "${DUMP_FILE}"

log_info "Dump pulito"

# --- STEP 5: Abilita estensioni su Supabase ---
log_info "Abilitazione estensioni su Supabase..."
PGPASSWORD="${SUPABASE_PASSWORD}" psql "${SUPABASE_URI}" -c "
    CREATE EXTENSION IF NOT EXISTS citext;
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
    CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
" 2>&1
log_info "Estensioni OK"

# --- STEP 6: Pulisci schema esistente su Supabase ---
log_warn "Pulizia schema public su Supabase (DROP CASCADE)..."
read -p "Confermi la pulizia dello schema public su Supabase? (y/N): " CONFIRM
if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
    log_warn "Operazione annullata dall'utente"
    exit 0
fi

PGPASSWORD="${SUPABASE_PASSWORD}" psql "${SUPABASE_URI}" -c "
    DROP SCHEMA IF EXISTS public CASCADE;
    CREATE SCHEMA public;
    DROP SCHEMA IF EXISTS staging CASCADE;
" 2>&1
log_info "Schema puliti"

# Riabilita estensioni (DROP CASCADE le rimuove)
PGPASSWORD="${SUPABASE_PASSWORD}" psql "${SUPABASE_URI}" -c "
    CREATE EXTENSION IF NOT EXISTS citext;
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
    CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
" 2>&1

# --- STEP 7: Import dump su Supabase ---
# IMPORTANTE: usa Session Pooler (porta 5432) invece del Transaction Pooler (6543)
# Il Transaction Pooler non supporta le funzionalità di sessione necessarie per l'import DDL
log_info "Import dump su Supabase via Session Pooler (potrebbe richiedere qualche minuto)..."
PGPASSWORD="${SUPABASE_PASSWORD}" psql "${SUPABASE_SESSION_URI}" -f "${DUMP_FILE}" 2>&1 | grep -E "^psql:.*ERROR" || true
if PGPASSWORD="${SUPABASE_PASSWORD}" psql "${SUPABASE_SESSION_URI}" -c "SELECT COUNT(*) FROM pg_tables WHERE schemaname='public';" > /dev/null 2>&1; then
    log_info "Import completato"
else
    log_error "Import fallito: impossibile connettersi o verificare le tabelle"
    exit 1
fi

# --- STEP 8: Fix FK orfani ---
log_info "Fix FK orfani in mov_clienti_viaggi..."
PGPASSWORD="${SUPABASE_PASSWORD}" psql "${SUPABASE_SESSION_URI}" -c "
    UPDATE mov_clienti_viaggi mcv SET mezzo_modello_id_fk = NULL
    WHERE mezzo_modello_id_fk IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM ana_mezzi_modelli WHERE mezzo_modello_id = mcv.mezzo_modello_id_fk);
" 2>&1

# Ricrea FK constraint se mancante
PGPASSWORD="${SUPABASE_PASSWORD}" psql "${SUPABASE_SESSION_URI}" -c "
    DO \$\$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'mov_clienti_viaggi_mezzo_modello_id_fk_fkey') THEN
            ALTER TABLE mov_clienti_viaggi
            ADD CONSTRAINT mov_clienti_viaggi_mezzo_modello_id_fk_fkey
            FOREIGN KEY (mezzo_modello_id_fk) REFERENCES ana_mezzi_modelli(mezzo_modello_id);
        END IF;
    END \$\$;
" 2>&1
log_info "FK fix completato"

# --- STEP 9: Crea ruoli applicativi ---
log_info "Creazione ruoli applicativi..."
PGPASSWORD="${SUPABASE_PASSWORD}" psql "${SUPABASE_SESSION_URI}" -c "
    DO \$\$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_superadmin') THEN CREATE ROLE app_superadmin NOLOGIN; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_azienda_admin') THEN CREATE ROLE app_azienda_admin NOLOGIN; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_azienda_readonly') THEN CREATE ROLE app_azienda_readonly NOLOGIN; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_azienda_user') THEN CREATE ROLE app_azienda_user NOLOGIN; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_readonly') THEN CREATE ROLE app_readonly NOLOGIN; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_tenant_admin') THEN CREATE ROLE app_tenant_admin NOLOGIN; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_tenant_user') THEN CREATE ROLE app_tenant_user NOLOGIN; END IF;
    END \$\$;
" 2>&1
log_info "Ruoli OK"

# --- STEP 10: Verifica ---
log_info "=== VERIFICA MIGRAZIONE ==="

echo ""
echo "--- Conteggio oggetti ---"
PGPASSWORD="${SUPABASE_PASSWORD}" psql "${SUPABASE_SESSION_URI}" -c "
    SELECT 'Tabelle public' as oggetto, count(*)::text as valore FROM pg_tables WHERE schemaname = 'public'
    UNION ALL SELECT 'Tabelle staging', count(*)::text FROM pg_tables WHERE schemaname = 'staging'
    UNION ALL SELECT 'Funzioni/Procedure', count(*)::text FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.prokind IN ('f','p')
    UNION ALL SELECT 'Trigger', count(*)::text FROM information_schema.triggers WHERE trigger_schema = 'public'
    UNION ALL SELECT 'FK Constraints', count(*)::text FROM pg_constraint c JOIN pg_namespace n ON c.connamespace = n.oid WHERE n.nspname = 'public' AND c.contype = 'f'
    UNION ALL SELECT 'Indici', count(*)::text FROM pg_indexes WHERE schemaname = 'public'
    ORDER BY oggetto;
"

echo ""
echo "--- Conteggio righe tabelle chiave ---"
PGPASSWORD="${SUPABASE_PASSWORD}" psql "${SUPABASE_SESSION_URI}" -c "
    SELECT 'ana_aziende' as tbl, count(*) FROM ana_aziende UNION ALL
    SELECT 'ana_clienti', count(*) FROM ana_clienti UNION ALL
    SELECT 'ana_viaggi', count(*) FROM ana_viaggi UNION ALL
    SELECT 'app_users', count(*) FROM app_users UNION ALL
    SELECT 'mov_transazioni', count(*) FROM mov_transazioni
    ORDER BY tbl;
"

echo ""
log_info "=== MIGRAZIONE COMPLETATA ==="
log_info "Dump salvato in: ${DUMP_FILE}"
