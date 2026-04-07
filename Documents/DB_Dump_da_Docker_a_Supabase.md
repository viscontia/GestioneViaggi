# DB Dump da Docker a Supabase

Procedura testata per copiare il DB locale (Docker PostgreSQL 17) su Supabase, superando i vincoli di PgBouncer e delle restrizioni Supabase.

---

## Problemi noti e soluzioni

| Problema | Causa | Soluzione |
|----------|-------|-----------|
| `permission denied: RI_ConstraintTrigger` | Supabase non concede `SUPERUSER` → `ALTER TABLE DISABLE TRIGGER ALL` bloccato | Rimosso dai servizi di import (script `404`) |
| `cannot drop schema public` | Supabase ha oggetti di sistema nel schema `public` | Filtrare le righe `DROP/CREATE/ALTER SCHEMA public` dal dump |
| `backslash commands are restricted` | pg_dump v17+ aggiunge `\restrict`/`\unrestrict`; PgBouncer li blocca | Filtrare le righe `\restrict` e `\unrestrict` dal dump |
| `SSL error: certificate verify failed` | OpenSSL del Mac non verifica il cert Supabase | Usare `PGSSLMODE=disable` |
| Connessione diretta porta 5432 `No route to host` | Supabase blocca la connessione diretta dall'esterno | Usare il session pooler (stesso host del transaction pooler, porta 5432) |

---

## Procedura Completa

### 1. Generare il dump dal container Docker

```bash
docker exec postgres_db pg_dump \
  -U postgres -d gestione_viaggi \
  --schema=public --clean --if-exists \
  --rows-per-insert=500 \
  > /tmp/full_dump_raw.sql
```

- `--schema=public` — esporta solo lo schema applicativo, esclude `auth`, `storage` ecc.
- `--clean --if-exists` — aggiunge `DROP ... IF EXISTS` prima di ogni `CREATE`
- `--rows-per-insert=500` — genera INSERT invece di COPY (evita i `\.` bloccati da PgBouncer)

### 2. Filtrare le righe incompatibili con Supabase

```bash
grep -v "^DROP SCHEMA IF EXISTS public;" /tmp/full_dump_raw.sql \
  | grep -v "^CREATE SCHEMA public;" \
  | grep -v "^ALTER SCHEMA public OWNER TO" \
  | grep -v "^\\\\restrict " \
  | grep -v "^\\\\unrestrict " \
  > /tmp/full_dump_ready.sql
```

Verifica che non rimangano backslash:
```bash
grep -c "^\\" /tmp/full_dump_ready.sql
# deve restituire 0
```

### 3. Restore su Supabase

```bash
PGSSLMODE=disable psql \
  "host=aws-1-eu-central-1.pooler.supabase.com port=5432 dbname=postgres user=postgres.wqbqvhshojbfuwcuiams password=U9Y7KSjQVfZ3N1Ca" \
  --single-transaction \
  -f /tmp/full_dump_ready.sql
```

- `PGSSLMODE=disable` — necessario perché OpenSSL del Mac non verifica il certificato Supabase
- `port=5432` — session pooler (non il transaction pooler su 6543)
- `--single-transaction` — rollback automatico in caso di errore

### 4. Verificare i conteggi

```bash
PGSSLMODE=disable psql \
  "host=aws-1-eu-central-1.pooler.supabase.com port=5432 dbname=postgres user=postgres.wqbqvhshojbfuwcuiams password=U9Y7KSjQVfZ3N1Ca" \
  -c "
SELECT 'ana_mezzi' AS tabella, COUNT(*) FROM ana_mezzi
UNION ALL SELECT 'ana_mezzi_modelli', COUNT(*) FROM ana_mezzi_modelli
UNION ALL SELECT 'ana_viaggi', COUNT(*) FROM ana_viaggi
UNION ALL SELECT 'ana_date_viaggi', COUNT(*) FROM ana_date_viaggi
UNION ALL SELECT 'ana_clienti', COUNT(*) FROM ana_clienti
UNION ALL SELECT 'mov_clienti_viaggi', COUNT(*) FROM mov_clienti_viaggi
UNION ALL SELECT 'mov_clienti_alloggi', COUNT(*) FROM mov_clienti_alloggi
ORDER BY tabella;"
```

---

## Credenziali Supabase

Le credenziali complete sono in [Progetto_Gestione_Viaggi.md](Progetto_Gestione_Viaggi.md) nella sezione *Database Supabase*.

---

## Note

- Il dump include schema **e** dati: funzioni, trigger, sequenze e record vengono tutti sovrascritti in un colpo solo.
- Non serve applicare script SQL separati (es. fix trigger) prima del restore: sono già inclusi nel dump.
- Se le tabelle target su Supabase hanno dati da preservare, usare invece `--data-only` e gestire i conflitti con TRUNCATE preventivo.
