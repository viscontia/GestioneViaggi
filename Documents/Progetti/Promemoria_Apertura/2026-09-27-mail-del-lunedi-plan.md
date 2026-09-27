# La mail del lunedì — Piano di implementazione

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** ogni lunedì alle 7:30 il server del sito manda alla segreteria le righe del promemoria,
se ce ne sono e se l'azienda l'ha accesa.

**Architecture:** il database decide destinatari (`fn_promemoria_mail_destinatari`, script 673) e
righe (`fn_promemoria_apertura`, 671). Uno script Python nel progetto Flask (`promemoria_lunedi.py`)
le legge nel contesto dell'app e spedisce con l'SMTP dell'azienda; un timer systemd lo lancia.
Il parametro sta in Funzioni Web del gestionale, come quello del promemoria.

**Tech Stack:** PostgreSQL, Flask + Flask-Mail + pytest (repository
`GitHub/Iscrizione-Viaggi-Offroad PostgreSQL`, ramo nuovo `feature/mail-lunedi`), MAUI Blazor,
systemd sul server Hetzner.

**Disegno:** `2026-09-27-mail-del-lunedi-design.md` (stessa cartella).

---

### Task 1: Script 673 — destinatari (MAUI `SqlScripts/`)

- `673_Promemoria_Mail_Lunedi.sql`:
  - `fn_promemoria_mail_destinatari(p_azienda_id integer) RETURNS text[]` (STABLE, `search_path`
    fissato, nessun GRANT): `'{}'` se la riga `mail_lunedi` manca o è spenta; altrimenti gli
    indirizzi di `parametri->>'destinatari'` (separati da virgola, puliti, vuoti tolti) o, se non
    ce ne sono, l'email con `is_principale` in `ana_aziende_email` (colonna azienda `azienda_fk`).
  - riga `mail_lunedi` **spenta** per ogni azienda (`ON CONFLICT DO NOTHING`, `created_by` obbligatorio).
- `Test_673_…sql` (transazione annullata): spenta → vuoto; accesa senza parametro → l'email
  principale; con `"a@x.it, b@y.it"` → due indirizzi; azienda inesistente → vuoto; chiusa ad
  `anon`/`authenticated`.
- Test prima (fallisce), `./deploy_sql.sh`, test (passa), `Funzioni_DB.md`, commit.

### Task 2: Funzioni Web (MAUI)

- `WebAziendeFunzioniService`: `FunzioneMailLunedi = "mail_lunedi"`,
  `GetDestinatariMailLunediAsync` (legge il parametro grezzo, stringa) e
  `SaveDestinatariMailLunediAsync(aziendaId, string? destinatari)` (JSON `{"destinatari": "…"}`,
  `null` se vuoto; crea la riga se manca, preservando `attiva`).
- `AziendaTabFunzioniWeb.razor`: toggle «Mail del lunedì» (default **spento**) e, se acceso, campo
  «Destinatari» con suggerimento «Vuoto = email principale dell'azienda», validazione del formato
  di ogni indirizzo prima di salvare, bottone Salva.
- Build, commit.

### Task 3: Script Python (Flask, TDD)

- `tests/test_promemoria_lunedi.py` (prima, deve fallire), con funzioni pure:
  - `componi(righe, oggi)` → `(oggetto, blocchi)`: nessuna riga → `None`; blocchi per voce
    nell'ordine ricevuto, con conteggio; oggetto «Cose in sospeso — lunedì 5 ottobre: N».
  - `esegui(azienda_id, leggi_destinatari, leggi_righe, spedisci)` → nessun destinatario o nessuna
    riga → nessun invio; altrimenti un invio.
- `promemoria_lunedi.py`: le due funzioni pure + `main()` che importa `app`, apre
  `app.app_context()`, legge con `db_manager_global` le due funzioni SQL, rende
  `templates/email/promemoria_lunedi.html`, applica `_destinatari_effettivi` e `_allega_logo`,
  `mail.send`. Codice di uscita 1 se l'invio fallisce; nessun dato personale nei log (solo conteggi).
- `templates/email/promemoria_lunedi.html` nello stile di `proposta_segreteria.html`.
- pytest verde (tutta la suite), commit.

### Task 4: Prova in locale

- Accendere `mail_lunedi` per l'azienda 2 nel DB locale; `.env` con `MAIL_DIROTTA_A`;
  `python promemoria_lunedi.py` → mail nella casella di collaudo, oggetto con il conteggio e
  l'indicazione del destinatario originale. Verificarla con Adriano.

### Task 5: Server e documenti

- `deploy/iscrizione-promemoria-2.service` e `.timer` nel repository Flask (documentati in
  `Configurazione_Server_Hetzner.md`).
- ⛔️ Con il via di Adriano: script 673 (e 671, se non già) in PROD, deploy rsync del sito, unità
  systemd, prima prova `systemctl start iscrizione-promemoria-2.service` con la deviazione, poi
  accensione di `mail_lunedi` per SFT e `systemctl enable --now` del timer.
- Note 2.4 (§1, §4), lista 2.4 (§1-bis), commit e push dei due repository.
