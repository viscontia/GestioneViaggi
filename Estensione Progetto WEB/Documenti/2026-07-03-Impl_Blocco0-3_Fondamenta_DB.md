# Fondamenta DB Estensione Web (Blocchi 0–3) — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Creare lo strato dati completo dell'estensione web (schema + funzioni PL/pgSQL + RLS di lettura pubblica) su DB locale Docker, verificato, fino al primo checkpoint — senza ancora alcuna UI.

**Architecture:** DB-First. Tutte le nuove tabelle `web_*` + modifiche a `ana_*` come script SQL numerati (da 406), deployati con `./deploy_sql.sh`. Audit via UNA funzione trigger condivisa `trg_web_audit()`. Isolamento multi-tenant nelle funzioni (il gestionale gira come superuser `postgres`); le RLS sono il confine SOLO per la lettura pubblica del sito (ruolo `anon`, testato con `SET ROLE anon`). Nessuna dipendenza da Supabase in locale (le RLS sono role-based pure).

**Tech Stack:** PostgreSQL 17 (Docker `postgres_db`), PL/pgSQL, `deploy_sql.sh` + `generate_db_functions_doc.sh`. Estensioni presenti: `citext`, `pgcrypto`. C# seam (solo interfaccia) in questo chunk.

**Design doc di riferimento:** `Estensione Progetto WEB/Documenti/2026-07-03-Piano_Operativo_Estensione_Web_design.md`.
**Spec campo-per-campo (fonte di verità colonne):** `Estensione Progetto WEB/Documenti/Dettaglio_Tabelle_DB.md` (citata come *Spec §X.Y*).

---

## CONVENZIONI RIUSABILI (definite una volta, applicate ovunque)

### Blocco standard "coda" di ogni tabella `web_*` (audit + FK azienda + RLS)
Ogni nuova tabella di dominio termina con:

```sql
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ
);
-- audit trigger condiviso
CREATE TRIGGER trg_<tabella>_audit BEFORE INSERT OR UPDATE ON <tabella>
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
-- indice tenant
CREATE INDEX idx_<tabella>_azienda ON <tabella>(azienda_id);
-- RLS: superadmin bypass (come tabelle esistenti)
ALTER TABLE <tabella> ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON <tabella>
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
```
> `created_by` è `NOT NULL` ma viene popolato dal trigger `trg_web_audit()` (priorità `my.app_user` → `current_user` → `'system'`), quindi gli INSERT via funzione non devono passarlo esplicitamente.

**⚠️ Nota naming:** le nuove tabelle usano `azienda_id` (come da Spec), NON `azienda_fk` del legacy. Scelta consapevole per coerenza interna delle `web_*`.

### PK dei target FK (verificati sul DB reale)
`ana_aziende(azienda_id)` · `ana_viaggi(viaggio_id)` · `ana_clienti(cliente_id)` · `ana_date_viaggi(data_viaggio_id)` · `ana_tipo_viaggi(tipo_viaggi_id)` · `ana_controparti(controparte_id)` · `ana_aziende_email(email_id)`. **`ana_fornitori`: PK da riconfermare** (serve solo per `ana_clienti.controparte_fk`, che è predisposizione Fase 4 — vedi Task 1.19).

### Pattern TDD-per-DB (ogni task tabella/funzione)
1. **Verifica-che-fallisce**: query che deve dare errore/0 righe finché l'oggetto non esiste.
2. **Run** → conferma il fallimento atteso.
3. **Crea** lo script `SqlScripts/NNN_*.sql`.
4. **Deploy**: `./deploy_sql.sh SqlScripts/NNN_*.sql`.
5. **Run verifica** → ora passa.
6. **Documenta** (funzioni → parte curata `Documents/Funzioni_DB.md`).
7. **Commit**.

---

## BLOCCO 0 — Preparazione

### Task 0.1: Branch dedicato + backup DB locale
**Files:** nessuno (git + dump).

**Step 1:** Creare il branch di lavoro.
```bash
cd "/Users/adrianovisconti/Documents/Sviluppo Software/MAUI/GestioneViaggi"
git checkout -b feature/estensione-web
```
**Step 2:** Backup del DB locale (ripristinabile).
```bash
docker exec -t postgres_db pg_dump -U postgres -Fc gestione_viaggi \
  > "Backup_DB/gestione_viaggi_pre_estensione_web_2026-07-03.backup"
```
**Step 3 (verifica):** il file esiste ed è > 0 byte.
```bash
ls -la Backup_DB/gestione_viaggi_pre_estensione_web_2026-07-03.backup
```
Expected: file presente, dimensione non nulla.

**Step 4: Commit** (solo il branch; il backup non va in git se è grande — verificare `.gitignore` di `Backup_DB/`).

### Task 0.2: Ruolo `anon` locale (C3)
**Files:** Create `SqlScripts/406_Setup_RoleAnon.sql`

**Step 1: Verifica-che-fallisce**
```bash
docker exec -i postgres_db psql -U postgres -d gestione_viaggi -c "SELECT 1 FROM pg_roles WHERE rolname='anon';"
```
Expected: 0 righe.

**Step 2: Script** — `406_Setup_RoleAnon.sql`:
```sql
-- Ruolo di sola lettura per il traffico pubblico del sito (equivalente locale dell'anon Supabase).
-- NON login, NON superuser: subisce le RLS. I GRANT SELECT specifici sono negli script delle tabelle web.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN
        CREATE ROLE anon NOLOGIN;
    END IF;
END $$;
GRANT USAGE ON SCHEMA public TO anon;
```

**Step 3: Deploy**
```bash
./deploy_sql.sh SqlScripts/406_Setup_RoleAnon.sql
```

**Step 4: Verifica passa**
```bash
docker exec -i postgres_db psql -U postgres -d gestione_viaggi -c "SELECT rolname, rolcanlogin, rolbypassrls FROM pg_roles WHERE rolname='anon';"
```
Expected: 1 riga, `rolcanlogin=f`, `rolbypassrls=f`.

**Step 5: Commit.**

### Task 0.3: Funzione audit condivisa `trg_web_audit()`
**Files:** Create `SqlScripts/407_Create_FnTrgWebAudit.sql`

**Step 1: Verifica-che-fallisce**
```bash
docker exec -i postgres_db psql -U postgres -d gestione_viaggi -c "SELECT proname FROM pg_proc WHERE proname='trg_web_audit';"
```
Expected: 0 righe.

**Step 2: Script** — replica la logica generica esistente (`trg_ana_viaggi_audit`) in forma condivisa:
```sql
CREATE OR REPLACE FUNCTION public.trg_web_audit()
RETURNS trigger LANGUAGE plpgsql AS $function$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.created_by IS NULL THEN
            NEW.created_by := COALESCE(current_setting('my.app_user', true), current_user, 'system');
        END IF;
        IF NEW.created IS NULL THEN
            NEW.created := CURRENT_TIMESTAMP;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        NEW.updated    := CURRENT_TIMESTAMP;
        NEW.updated_by := COALESCE(current_setting('my.app_user', true), current_user, 'system');
    END IF;
    RETURN NEW;
END;
$function$;
```

**Step 3: Deploy** `./deploy_sql.sh SqlScripts/407_Create_FnTrgWebAudit.sql`
**Step 4: Verifica** `proname='trg_web_audit'` → 1 riga.
**Step 5: Documenta** in `Documents/Funzioni_DB.md` (parte curata: sezione "Estensione Web / Utility").
**Step 6: Commit.**

### Task 0.4: Seam storage `IWebMediaStorage` (solo interfaccia + config)
**Files:**
- Create `Services/Shared/Storage/IWebMediaStorage.cs`
- Create `Services/Shared/Storage/WebMediaStorageOptions.cs`
- Modify `MauiProgram.cs` (registrazione opzioni; implementazione concreta arriverà al Blocco 7)
- Modify `appsettings.Development.json` / `appsettings.json` (sezione `WebMediaStorage`)

**Step 1:** Interfaccia (nessuna impl concreta ora):
```csharp
namespace GestioneViaggi.Services.Shared.Storage;

/// <summary>Astrazione upload/URL dei media web (Supabase Storage). storage_path = sorgente di verità.</summary>
public interface IWebMediaStorage
{
    Task<string> UploadAsync(string storagePath, Stream content, string contentType, CancellationToken ct = default);
    string BuildPublicUrl(string storagePath);            // ricompone l'URL dal base-URL d'ambiente
    Task DeleteAsync(string storagePath, CancellationToken ct = default);
}
```
**Step 2:** Opzioni:
```csharp
namespace GestioneViaggi.Services.Shared.Storage;

public sealed class WebMediaStorageOptions
{
    public string BaseUrl { get; set; } = "";     // es. https://<ref>.supabase.co/storage/v1/object/public
    public string Bucket  { get; set; } = "tour-media";
    public string ServiceKey { get; set; } = "";   // solo per upload/delete lato server
}
```
**Step 3:** Config in `appsettings.Development.json` (bucket di TEST) e `appsettings.json` (prod), sezione `"WebMediaStorage": { "BaseUrl": "...", "Bucket": "tour-media", "ServiceKey": "..." }`. **Non committare la ServiceKey reale** (usare user-secrets / placeholder).
**Step 4:** In `MauiProgram.cs` registrare le opzioni (bind della sezione). **Nessuna** registrazione di implementazione ora.
**Step 5 (verifica):** `dotnet build` compila.
**Step 6: Commit.**

> Fine Blocco 0: ambiente pronto, anon testabile, audit condiviso pronto, seam definito.

---

## BLOCCO 1 — Schema DB completo (Spec = `Dettaglio_Tabelle_DB.md`)

**Ordine FK obbligatorio** (Spec §NOTE TRASVERSALI): categorie_sport → alter tipo_viaggi → tour_contenuti → itinerario → passaggi → immagini → mappa → traduzioni → newsletter(iscritti/invii/destinatari/soppressioni) → aziende_funzioni → aziende_esp → predisposizioni pagamenti → blog → alter ana_clienti → alter ana_aziende.

**Numerazione:** da `408`. Ogni tabella = uno script `NNN_Create_<Nome>.sql`; ogni alter = `NNN_Alter_<Tabella>_<motivo>.sql`.

**Template di verifica per ogni tabella** (adatta il nome):
```bash
# fallisce prima:
docker exec -i postgres_db psql -U postgres -d gestione_viaggi -c "\d web_categorie_sport"
# passa dopo il deploy: mostra colonne, PK, indici, policy superadmin_bypass_all, trigger audit
```

### Task 1.1: `web_categorie_sport` — ESEMPIO COMPLETO (template per le altre)
**Files:** Create `SqlScripts/408_Create_WebCategorieSport.sql`
Spec §2.1. Script completo:
```sql
CREATE TABLE web_categorie_sport (
    web_categorie_sport_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codice      VARCHAR(20)  NOT NULL,   -- FUORISTRADA, QUAD, MOTO_ENDURO, MOTO_STRADALE
    etichetta   VARCHAR(50)  NOT NULL,
    slug        VARCHAR(50)  NOT NULL,
    ordine      INTEGER      NOT NULL DEFAULT 0,
    azienda_id  INTEGER      NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,
    created_by  VARCHAR(50)  NOT NULL,
    created     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    updated     TIMESTAMPTZ,
    CONSTRAINT uq_web_categorie_sport_codice UNIQUE (azienda_id, codice),
    CONSTRAINT uq_web_categorie_sport_slug   UNIQUE (azienda_id, slug)
);
CREATE INDEX idx_web_categorie_sport_azienda ON web_categorie_sport(azienda_id);
CREATE TRIGGER trg_web_categorie_sport_audit BEFORE INSERT OR UPDATE ON web_categorie_sport
    FOR EACH ROW EXECUTE FUNCTION trg_web_audit();
ALTER TABLE web_categorie_sport ENABLE ROW LEVEL SECURITY;
CREATE POLICY superadmin_bypass_all ON web_categorie_sport
    FOR ALL TO app_superadmin USING (true) WITH CHECK (true);
```
Deploy → verifica `\d web_categorie_sport` mostra PK identity, 2 unique, indice, trigger, policy → commit.

### Task 1.2: Alter `ana_tipo_viaggi` + `web_categoria_fk`
Spec §1.3. `409_Alter_AnaTipoViaggi_WebCategoria.sql`:
```sql
ALTER TABLE ana_tipo_viaggi
    ADD COLUMN web_categoria_fk INTEGER NULL
    REFERENCES web_categorie_sport(web_categorie_sport_id) ON DELETE SET NULL;
```
Verifica: colonna presente, FK valida.

### Task 1.3: `web_tour_contenuti` (1:1 `ana_viaggi`)
Spec §2.2. `410_Create_WebTourContenuti.sql`. Colonne come da Spec (sottotitolo, descrizione_html, difficolta CHECK, durata_testo, luoghi_visitati, info_*_html, slug, meta_title/description, stato_pubblicazione CHECK+default 'bozza', ordine, data_pubblicazione) + coda standard. `viaggio_id_fk INTEGER NOT NULL UNIQUE REFERENCES ana_viaggi(viaggio_id)`. Unique `(azienda_id, slug)`. Indice `(azienda_id, stato_pubblicazione)`. CHECK: `difficolta IN ('turistica','media','medio_alta','alta')`, `stato_pubblicazione IN ('bozza','pubblicato','archiviato')`.

### Task 1.4: `web_tour_itinerario` (N)
Spec §2.3. `411_*`. `viaggio_id_fk → ana_viaggi`, `giorno_numero`, `titolo_giornata`, `ordine`; Unique `(viaggio_id_fk, giorno_numero)` + coda standard.

### Task 1.5: `web_tour_itinerario_passaggi` (N)
Spec §2.4. `412_*`. `itinerario_id_fk BIGINT NOT NULL REFERENCES web_tour_itinerario(web_tour_itinerario_id) ON DELETE CASCADE`, `testo_html`, `immagine_url`, `immagine_storage_path`, `immagine_didascalia`, `ordine` + coda standard.

### Task 1.6: `web_tour_immagini` (N)
Spec §2.5. `413_*`. `viaggio_id_fk`, `tipo CHECK('principale','galleria') default 'galleria'`, `url`, `storage_path`, `alt_text`, `titolo`, `larghezza`, `altezza`, `mime`, `ordine` + coda. Indice `(viaggio_id_fk, tipo, ordine)`. **Regola "una sola principale per tour":** unique parziale `CREATE UNIQUE INDEX uq_web_tour_immagini_principale ON web_tour_immagini(viaggio_id_fk) WHERE tipo='principale';`.

### Task 1.7: `web_tour_mappa` (1:1)
Spec §2.6. `414_*`. `viaggio_id_fk ... UNIQUE`, `gpx_originale TEXT` (solo server), `gpx_filename`, bbox `NUMERIC(9,6)` x4, `provider default 'geoapify'`, `stile default 'osm-bright'`, `parametri_render JSONB`, `immagine_url`, `immagine_storage_path`, `data_generazione` + coda.

### Task 1.8: `web_traduzioni` (polimorfica)
Spec §2.7. `415_*`. `entita`, `entita_id BIGINT`, `campo`, `lingua CHAR(2) CHECK('FR','EN','DE','ES')`, `testo`, `tradotto_auto default true`, `revisionato default false`, `obsoleto default false`, `data_traduzione` + coda. Unique `(entita, entita_id, campo, lingua)`.

### Task 1.9–1.12: Newsletter
`416`–`419`: `web_newsletter_iscritti` (Spec §2.8, email CITEXT, Unique `(azienda_id,email)`, `token_disiscrizione`, `cliente_fk → ana_clienti`), `web_newsletter_invii` (§2.9), `web_newsletter_invii_destinatari` (§2.10, `invio_id_fk ... ON DELETE CASCADE`), `web_newsletter_soppressioni` (§2.11, Unique `(azienda_id,email)`). Tutte + coda standard.

### Task 1.13: `web_aziende_funzioni`
Spec §2.12. `420_*`. `funzione`, `attiva default false`, `parametri JSONB`; Unique `(azienda_id, funzione)` + coda.

### Task 1.14: `ana_aziende_esp`
Spec §2.13. `421_*`. `azienda_id UNIQUE`, `provider`, `api_key_enc JSONB NOT NULL` (cifrata lato app, pattern `password_enc`), `sender_email CITEXT`, `sender_name`, `sender_domain`, `attivo default false` + coda.

### Task 1.15–1.18: Predisposizioni pagamenti (create ma non cablate)
`422`–`427`: `web_pagamenti_config` (§2.14), `web_pagamenti_regole` (§2.15), `web_pagamenti_reminder_regole` (§2.16), `web_pagamenti_transazioni` (§2.17, `mov_transazione_fk BIGINT` link idempotenza — NESSUNA modifica a `mov_transazioni`), `web_pagamenti_reminder_log` (§2.18, Unique `(transazione_fk, reminder_regola_fk)`). Tutte + coda + CHECK come da Spec.

### Task 1.19: `web_blog_articoli` (predisposizione)
Spec §2.19. `428_*`. Come Spec + coda.

### Task 1.20: Alter `ana_clienti` (consenso marketing + controparte)
Spec §1.1 + §1.4. `429_Alter_AnaClienti_Web.sql`:
```sql
ALTER TABLE ana_clienti
    ADD COLUMN consenso_marketing        BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN consenso_marketing_data   TIMESTAMPTZ NULL,
    ADD COLUMN consenso_marketing_fonte  VARCHAR(30) NULL,
    ADD COLUMN controparte_fk            INTEGER NULL;  -- FK aggiunta dopo aver confermato PK ana_fornitori
```
> **DA CONFERMARE** prima di aggiungere la FK di `controparte_fk`: PK reale di `ana_fornitori` (il target secondo Spec §1.4). Se ambiguo, lasciare la colonna senza FK in questo chunk (è predisposizione Fase 4) e aggiungere il vincolo nel piano Fase 4.

### Task 1.21: Alter `ana_aziende` (token iscrizione)
Spec §1.2. `430_Alter_AnaAziende_Token.sql`:
```sql
ALTER TABLE ana_aziende ADD COLUMN token_iscrizione VARCHAR(64) NULL;
```

### Task 1.22: Verifica d'insieme schema + rollback
- Verifica: tutte le tabelle presenti, tutte con policy `superadmin_bypass_all` e trigger audit.
```bash
docker exec -i postgres_db psql -U postgres -d gestione_viaggi -c "
SELECT tablename FROM pg_tables WHERE tablename LIKE 'web_%' ORDER BY 1;"
docker exec -i postgres_db psql -U postgres -d gestione_viaggi -c "
SELECT c.relname FROM pg_class c WHERE c.relname LIKE 'web_%' AND c.relkind='r' AND NOT c.relrowsecurity;"  # atteso: 0 righe
```
- Aggiornare la parte curata di `Documents/Funzioni_DB.md` (nuove tabelle, non solo funzioni) e verificare l'appendice auto-generata.
- **Rollback pronto:** script `SqlScripts/499_Rollback_EstensioneWeb.sql` con `DROP TABLE IF EXISTS ... CASCADE` in ordine inverso + `ALTER TABLE ... DROP COLUMN` per gli alter. **Commit** a fine blocco.

**→ Checkpoint 1: schema completo deployato e verificato.**

---

## BLOCCO 2 — Funzioni PL/pgSQL CRUD + servizio (1° rilascio)

Stile: `fn_<verbo>_<entita>(p_...)`, `LANGUAGE plpgsql`, INSERT ... `RETURNING <pk> INTO v_new_id; RETURN v_new_id`. Multi-tenant: le funzioni filtrano SEMPRE per `p_azienda_id`. Numerazione da `431`.

### Task 2.1: CRUD `web_categorie_sport` — ESEMPIO COMPLETO (template)
**Files:** Create `SqlScripts/431_Create_FnWebCategorieSport_Crud.sql`

**Step 1: Verifica-che-fallisce**
```bash
docker exec -i postgres_db psql -U postgres -d gestione_viaggi -c "SELECT fn_web_categorie_sport_list(1);"
```
Expected: errore "function does not exist".

**Step 2: Script** (get/list/insert/update/delete). Esempio insert + list:
```sql
CREATE OR REPLACE FUNCTION fn_web_categorie_sport_insert(
    p_azienda_id INTEGER, p_codice VARCHAR, p_etichetta VARCHAR, p_slug VARCHAR, p_ordine INTEGER DEFAULT 0)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO web_categorie_sport(codice, etichetta, slug, ordine, azienda_id)
    VALUES (p_codice, p_etichetta, p_slug, p_ordine, p_azienda_id)
    RETURNING web_categorie_sport_id INTO v_id;
    RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION fn_web_categorie_sport_list(p_azienda_id INTEGER)
RETURNS SETOF web_categorie_sport LANGUAGE sql STABLE AS $$
    SELECT * FROM web_categorie_sport WHERE azienda_id = p_azienda_id ORDER BY ordine, etichetta;
$$;
```
(+ `_get(p_id, p_azienda_id)`, `_update(...)`, `_delete(p_id, p_azienda_id)` analoghi.)

**Step 3: Deploy** `./deploy_sql.sh SqlScripts/431_*.sql`
**Step 4: Verifica passa** — inserisci e rileggi con un'azienda di test:
```bash
docker exec -i postgres_db psql -U postgres -d gestione_viaggi -c "
SELECT set_config('my.app_user','test',true);
SELECT fn_web_categorie_sport_insert(1,'FUORISTRADA','Fuoristrada','fuoristrada',0);
SELECT web_categorie_sport_id, codice, created_by FROM fn_web_categorie_sport_list(1);"
```
Expected: 1 riga, `created_by='test'` (prova che il trigger audit + GUC funzionano).
**Step 5: Documenta** in `Funzioni_DB.md`. **Step 6: Commit.**

### Task 2.2–2.10: CRUD delle restanti entità del 1° rilascio
Applica il template (get/list/insert/update/delete, sempre filtrando `p_azienda_id`) a: `web_tour_contenuti`, `web_tour_itinerario`, `web_tour_itinerario_passaggi`, `web_tour_immagini`, `web_tour_mappa`, `web_traduzioni`, `web_newsletter_iscritti`, `web_newsletter_invii` (+ destinatari/soppressioni), `web_aziende_funzioni`, `ana_aziende_esp`. Uno script per entità (`432`…). Ogni task: verifica-fallisce → script → deploy → insert/list di prova con isolamento multi-azienda → doc → commit.
> **Fuori da questo chunk:** funzioni pagamenti (predisposizione) e blog.

### Task 2.11: Funzioni di servizio
- `fn_web_tour_pubblicati(p_azienda_id INTEGER, p_lingua CHAR(2))` — lista tour con `stato_pubblicazione='pubblicato'`, join categoria via `ana_tipo_viaggi.web_categoria_fk`, testi in lingua da `web_traduzioni` (fallback IT).
- `fn_web_destinatari_newsletter(p_azienda_id INTEGER)` — UNION dedup (per email normalizzata) di `ana_clienti` con `consenso_marketing=true` + `web_newsletter_iscritti` con `stato='attivo'`, MENO `web_newsletter_soppressioni`.
- `fn_web_prezzo_da(p_viaggio_id INTEGER)` — prezzo minimo "da".
Ogni funzione: test con dati fixture + verifica dedup/isolamento. Doc + commit.

**Verifica blocco:** ogni funzione richiamabile; un'azienda non vede i dati di un'altra (test con due `p_azienda_id`).

---

## BLOCCO 3 — Strato lettura pubblica + RLS (ruolo `anon`)

**Principio:** `anon` legge SOLO contenuti pubblicati; nega tutto il resto. Tabelle-contenuto con anon read (Spec §NOTE): `web_tour_contenuti` (gated `stato='pubblicato'`), `web_tour_itinerario`, `web_tour_itinerario_passaggi`, `web_tour_immagini`, `web_tour_mappa` (gated via tour pubblicato), `web_categorie_sport`, `web_traduzioni`, `web_blog_articoli` (gated `stato='pubblicato'`). Numerazione da `450`.

### Task 3.1: Policy + GRANT anon — ESEMPIO COMPLETO
**Files:** Create `SqlScripts/450_Rls_AnonRead_WebContenuti.sql`

**Step 1: Verifica-che-fallisce** (anon NON deve ancora leggere nulla):
```bash
docker exec -i postgres_db psql -U postgres -d gestione_viaggi -c "
SET ROLE anon; SELECT count(*) FROM web_tour_contenuti; RESET ROLE;"
```
Expected: errore permission denied (nessun GRANT).

**Step 2: Script** — contenuti (gated su stato) + una figlia (gated su tour pubblicato):
```sql
-- CONTENUTI: solo pubblicati
GRANT SELECT ON web_tour_contenuti TO anon;
CREATE POLICY anon_read_pubblicati ON web_tour_contenuti
    FOR SELECT TO anon USING (stato_pubblicazione = 'pubblicato');

-- CATEGORIE: pubbliche
GRANT SELECT ON web_categorie_sport TO anon;
CREATE POLICY anon_read_all ON web_categorie_sport FOR SELECT TO anon USING (true);

-- ITINERARIO: solo se il tour è pubblicato (evita leak di bozze)
GRANT SELECT ON web_tour_itinerario TO anon;
CREATE POLICY anon_read_if_tour_pubblicato ON web_tour_itinerario
    FOR SELECT TO anon USING (EXISTS (
        SELECT 1 FROM web_tour_contenuti c
        WHERE c.viaggio_id_fk = web_tour_itinerario.viaggio_id_fk
          AND c.stato_pubblicazione = 'pubblicato'));
```
Ripetere il pattern "gated via tour pubblicato" per `web_tour_itinerario_passaggi` (join su itinerario→contenuti), `web_tour_immagini`, `web_tour_mappa`; `web_blog_articoli` gated su `stato='pubblicato'`.

**`web_traduzioni` → `USING(true)` (DECISO).** NON fare gating dinamico sul campo polimorfico `entita`: una policy che, in base a `entita`, sceglie a quale tabella fare join sarebbe un mostro di performance e manutenzione. Una singola riga di traduzione isolata (es. il testo EN di una giornata) fuori dal suo contesto **non è un leak critico**, e il sito Next.js interroga sempre le traduzioni **partendo dalle entità principali** (tour pubblicati), quindi l'isolamento effettivo avviene a monte.
```sql
GRANT SELECT ON web_traduzioni TO anon;
CREATE POLICY anon_read_all ON web_traduzioni FOR SELECT TO anon USING (true);
```

**Step 3: Deploy** `./deploy_sql.sh SqlScripts/450_*.sql`

**Step 4: Verifica passa** — tre asserzioni chiave:
```bash
docker exec -i postgres_db psql -U postgres -d gestione_viaggi -c "
-- (a) bozza NON visibile ad anon
SET ROLE anon;
SELECT count(*) AS bozze_viste FROM web_tour_contenuti WHERE stato_pubblicazione='bozza';  -- atteso 0
-- (b) anon NON vede tabelle operative
SELECT count(*) FROM ana_clienti;  -- atteso: permission denied
RESET ROLE;"
```
Expected: (a) 0; (b) errore permission denied (nessun GRANT su `ana_clienti` per anon).

**Step 5: Commit.**

### Task 3.4: Iscrizione newsletter dal sito pubblico (anon INSERT)
**Files:** Create `SqlScripts/451_Rls_AnonInsert_NewsletterIscritti.sql`
Il sito pubblico deve consentire agli utenti **anon di iscriversi** a `web_newsletter_iscritti` (unico caso di scrittura pubblica). Il trigger `trg_web_audit()` popola automaticamente `created_by='anon'` (nessun `my.app_user` dal sito) → in DB si distinguono a colpo d'occhio gli iscritti arrivati dal form pubblico.

**Step 1: Verifica-che-fallisce**
```bash
docker exec -i postgres_db psql -U postgres -d gestione_viaggi -c "
SET ROLE anon; INSERT INTO web_newsletter_iscritti(email, azienda_id, token_disiscrizione) VALUES ('a@b.it',1,'tok'); RESET ROLE;"
```
Expected: permission denied.

**Step 2: Script** — GRANT + policy INSERT vincolata (niente scritture arbitrarie: solo stato attivo/consenso):
```sql
GRANT INSERT ON web_newsletter_iscritti TO anon;
-- PK GENERATED ALWAYS AS IDENTITY: la sequenza è gestita internamente, nessun GRANT sequence necessario.
CREATE POLICY anon_insert_iscrizione ON web_newsletter_iscritti
    FOR INSERT TO anon
    WITH CHECK (stato = 'attivo' AND consenso = true);
```
> **Alternativa più blindata (da valutare in Fase 3, contro spam):** esporre invece una funzione `SECURITY DEFINER` `fn_web_newsletter_signup(...)` che valida/normalizza email, genera `token_disiscrizione`, applica rate-limit, e revocare l'INSERT diretto ad anon. Per questo chunk basta il GRANT+policy sopra; la scelta finale si chiude quando si costruisce il form (double opt-in, Passo 3.5).

**Step 3: Deploy** → **Step 4: Verifica** l'INSERT come `anon` ora riesce con `stato='attivo', consenso=true` e viene rifiutato altrimenti; `created_by` risulta `'anon'`. **Step 5: Commit.**

### Task 3.2: Verifica negazione esplicita (defense-in-depth)
Assicurare che `anon` NON abbia GRANT su NESSUNA tabella operativa/contabile/config/pagamenti/newsletter. Query di audit:
```bash
docker exec -i postgres_db psql -U postgres -d gestione_viaggi -c "
SELECT table_name, privilege_type FROM information_schema.role_table_grants
WHERE grantee='anon' ORDER BY 1;"
```
Expected: SOLO `SELECT` sulle tabelle-contenuto web previste + `INSERT` su `web_newsletter_iscritti` (Task 3.4). Nessun grant su tabelle operative/contabili/config/pagamenti. Se compare altro → revocare.
**Estendere l'audit ai GRANT sulle FUNZIONI** (non solo tabelle) — vedi Task 3.5:
```bash
docker exec -i postgres_db psql -U postgres -d gestione_viaggi -c "
SELECT routine_name, privilege_type FROM information_schema.role_routine_grants
WHERE grantee IN ('anon','PUBLIC') ORDER BY 1;"
```
Commit.

### Task 3.3: Funzioni/viste di lettura per il sito
Esporre (o riusare `fn_web_tour_pubblicati`) le letture per: lista tour, dettaglio, itinerario, immagini, mappa, categorie, prezzi/date, traduzioni — tutte già filtrate su pubblicato e per lingua.
> **SECURITY INVOKER (default, da NON cambiare):** in PostgreSQL le funzioni sono `SECURITY INVOKER` di default → quando il sito le chiama impersonando `anon`, la funzione **rispetta le RLS** delle tabelle sottostanti. È esattamente il comportamento voluto: le RLS di Task 3.1/3.4 restano il confine anche attraverso le funzioni. NON usare `SECURITY DEFINER` per le funzioni di lettura pubblica (bypasserebbe le RLS). (`SECURITY DEFINER` è invece corretto solo per l'eventuale `fn_web_newsletter_signup`, dove serve scavalcare controllatamente — vedi Task 3.4.)

Verifica: eseguite come `anon` restituiscono solo pubblicati. Doc + commit.

### Task 3.5: Hardening EXECUTE per `anon` (chiudere l'ereditarietà da PUBLIC) — *emerso da code review Task 0.2/0.3*
**Files:** Create `SqlScripts/452_Rls_Harden_AnonExecute.sql`
**Problema:** in PostgreSQL ogni funzione ha `EXECUTE` di default a `PUBLIC`; `anon` è membro implicito di `PUBLIC` → eredita l'`EXECUTE` su TUTTE le funzioni, incluse le ~23 `SECURITY DEFINER` esistenti (auth, gestione utenti) che girano come owner-superuser e **bypassano le RLS**. Va chiuso PRIMA che `anon` sia raggiungibile dal sito (Supabase: anon key → ruolo `anon`).

**Step 1: Verifica-che-fallisce (mostra il buco)**
```bash
docker exec -i postgres_db psql -U postgres -d gestione_viaggi -c "
SELECT count(*) AS funzioni_eseguibili_da_public
FROM information_schema.role_routine_grants WHERE grantee='PUBLIC' AND privilege_type='EXECUTE';"
```
Expected: numero > 0 (il buco esiste).

**Step 2: Script** — revoca l'EXECUTE di massa da PUBLIC e ri-concede SOLO le funzioni di lettura pubblica del sito ad `anon`:
```sql
-- Chiude l'ereditarietà: nessuna funzione eseguibile da PUBLIC (quindi da anon) per default.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
-- (difesa in profondità) nessuna creazione oggetti da PUBLIC nello schema
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
-- Ri-concede l'EXECUTE SOLO sulle funzioni di lettura pubblica destinate al sito (Task 3.3).
-- Elencare esplicitamente ogni fn_web_* pubblica, es.:
-- GRANT EXECUTE ON FUNCTION fn_web_tour_pubblicati(INTEGER, CHAR) TO anon;
```
> **⚠️ Impatto da verificare PRIMA del deploy:** il gestionale si connette come superuser `postgres` (bypassa i grant → non impattato). Verificare però che i ruoli applicativi `app_tenant_user`/`app_tenant_admin`/`app_readonly` **non** dipendano dall'EXECUTE ereditato da PUBLIC per funzionare (oggi l'app gira come `postgres`, quindi il rischio è teorico, ma va confermato). Se dipendessero, concedere esplicitamente l'EXECUTE ai ruoli `app_*` sulle funzioni che usano, invece di lasciarlo a PUBLIC. **Non deployare finché questo impatto non è confermato.**

**Step 3: Deploy** → **Step 4: Verifica** `anon` (via `SET ROLE anon`) NON può più chiamare una funzione `SECURITY DEFINER` sensibile, e PUÒ chiamare le `fn_web_*` pubbliche esplicitamente concesse. Ripetere l'audit routine-grants del Task 3.2. **Step 5: Commit.**

**→ Checkpoint finale del chunk: DB "pronto per il sito" — schema + funzioni + RLS anon (tabelle E funzioni) verificati, senza UI.**

---

## Ordine di esecuzione e commit
Sequenziale 0 → 1 → 2 → 3. Commit frequenti (uno per task). A fine **Blocco 1** e fine **Blocco 3**: fermarsi per revisione (checkpoint concordati nel design doc). Deploy in produzione (Supabase) NON in questo chunk: si fa a fine fase, con backup preventivo, dopo test verdi.

## Note di rischio note (da tenere d'occhio)
- **`ana_fornitori` PK** da confermare prima della FK di `ana_clienti.controparte_fk` (Task 1.20) — altrimenti lasciare colonna senza vincolo (predisposizione).
- **`web_traduzioni` gating anon**: DECISO `USING(true)` (no gating dinamico sul campo polimorfico `entita` — sarebbe insostenibile per performance/manutenzione; isolamento a monte via le entità principali). Vedi Task 3.1.
- **ServiceKey storage**: mai in git (Task 0.4).
