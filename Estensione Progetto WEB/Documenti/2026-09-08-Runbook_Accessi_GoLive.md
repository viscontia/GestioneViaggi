# Runbook accessi go-live — verificato il 2026-09-08, sera

> Preparato la sera prima del go-live. **Tutto quello che c'è qui è stato provato davvero**, non
> copiato dai documenti: dove la realtà differiva dalla documentazione, sotto c'è scritto come
> stanno le cose oggi.

---

## 1. Supabase (PROD) — ⚠️ il client di sistema NON funziona

⛔️ **`psql` di Homebrew (v18.1) non si connette**: `SSL error: certificate verify failed`.
Non è un problema di credenziali — è la verifica del certificato del pooler.

✅ **Quello che funziona: il client psql del container Docker (v17).** Provato stasera, risponde.

```bash
cd "/Users/adrianovisconti/Documents/Sviluppo Software/GitHub/Iscrizione-Viaggi-Offroad PostgreSQL"
set -a && . ./.env.supabase && set +a

docker exec -e PGPASSWORD="$DB_PASSWORD" -i postgres_db \
  psql "host=$DB_HOST port=5432 dbname=$DB_NAME user=$DB_USER sslmode=require" \
  -v ON_ERROR_STOP=1 < SqlScripts/NNN_Nome.sql
```

### ⚠️ La porta: 5432, non 6543

| Porta | Modalità | Uso |
|---|---|---|
| **6543** | transaction pooling | quella dell'app in esercizio |
| **5432** | **session pooling** | ⚠️ **questa per applicare gli script** |

I nostri script usano `BEGIN … COMMIT`, `SET LOCAL my.app_user`, `DO $$` con eccezioni e
`GET DIAGNOSTICS`: vogliono una **sessione vera**. Entrambe le porte rispondono (provate
stasera), ma la 5432 è quella giusta per la DDL.

### L'altra strada: l'MCP Supabase

Funziona ed è stata usata tutto il giorno in lettura. ⚠️ Va bene per **verificare**, meno per
applicare 227 script in sequenza: non tiene una sessione fra una chiamata e l'altra.

**Regola pratica di domani:** script con `docker exec … psql`, verifiche con l'MCP.

---

## 2. Server Hetzner — ✅ accesso verificato

```bash
ssh -i ~/.ssh/oci_new_key root@91.99.52.98
```

Provato stasera: risponde. Host `server-prod`. Entrambi i servizi **active**, entrambi i siti
rispondono **200**.

| | |
|---|---|
| Legacy Oracle | `https://iscrizioni.sardegnafuoritraccia.it/` · porta 5001 · `/root/iscrizione-viaggi-app/` |
| **Azienda 2 (la nostra)** | `https://iscrizioni.sardegnafuoritraccia.it/2-976f2734/` · porta 5002 · `/root/iscrizione-viaggi-azienda2/` |

⚠️ L'IP è **sotto ACL**: la connessione funziona solo dall'IP autorizzato. Stasera ha funzionato
da questa macchina — se domani si lavora da un'altra rete, va verificato **per primo**.

### ⛔️ Il server NON ha git

Il documento di marzo diceva «`git pull origin Main-Repository` — se git è configurato».
**Non lo è**: `/root/iscrizione-viaggi-azienda2` non è un repository.

**Quindi il deploy è per forza rsync:**

```bash
rsync -avz -e "ssh -i ~/.ssh/oci_new_key" \
  --exclude='.env' --exclude='.venv' --exclude='venv' \
  --exclude='__pycache__' --exclude='*.pyc' --exclude='.git' --exclude='node_modules' \
  "/Users/adrianovisconti/Documents/Sviluppo Software/GitHub/Iscrizione-Viaggi-Offroad PostgreSQL/" \
  "root@91.99.52.98:/root/iscrizione-viaggi-azienda2/"
```

⚠️ **`--exclude='.env'` non è opzionale**: il `.env` locale contiene `MAIL_DIROTTA_A`. Se finisse
sul server, **nessun cliente riceverebbe niente** e non ce ne accorgeremmo.

### ⚠️ Il bundle React va compilato sul Mac

Non c'è node sul server (e non deve esserci). Prima del rsync:

```bash
cd "/Users/adrianovisconti/Documents/Sviluppo Software/GitHub/Iscrizione-Viaggi-Offroad PostgreSQL"
npm run build
```

**Verifica che il bundle sia quello nuovo** — deve contenere il passo 5 riscritto:

```bash
grep -c "Come volete dormire" static/dist/bundle.js     # dev'essere > 0
```

Stasera, **sul server**, quel conteggio è **0**: il bundle in produzione è ancora quello vecchio,
del **13 maggio**. È la conferma che il passo 5 nuovo non è mai arrivato lì.

### Comandi di servizio

```bash
systemctl restart iscrizione-viaggi-2.service
systemctl status  iscrizione-viaggi-2.service --no-pager | head -5
journalctl -u iscrizione-viaggi-2.service -f          # log dal vivo
journalctl -u iscrizione-viaggi-2.service -n 50 --no-pager
nginx -t && systemctl reload nginx                     # se si tocca nginx
```

---

## 3. Cosa c'è oggi in produzione — la distanza da colmare

| File sul server | Data | |
|---|---|---|
| `app.py` | **13 maggio 2026** | ~4 mesi indietro |
| `static/dist/bundle.js` | **13 maggio 2026** | passo 5 vecchio |
| `Classi_Tabelle_DB/cliente.py` | **21 marzo 2026** | ~6 mesi indietro |
| `requirements.txt` | 23 marzo 2026 | ⚠️ verificare se le dipendenze sono cambiate |

⚠️ Se `requirements.txt` è cambiato, dopo il rsync serve:
`source .venv/bin/activate && pip install -r requirements.txt`

---

## 4. ⚠️ Due cose viste stasera, da sapere

### Il load average è 8,00 e non è traffico

Su 2 CPU, load `8,00 8,00 8,00` — identico sui tre intervalli — ma **nessun processo consuma
CPU**. La causa: **quattro processi bloccati in stato D** (I/O non interrompibile), residui di un
`npm install` / `npm cache clean` lanciati sul server tempo fa:

```
D 939407 npm install     D 939506 npm install
D 939625 npm install     D 939732 npm cache clean
```

⚠️ **Non si uccidono con `kill`**: in stato D il processo non risponde ai segnali. Si liberano
solo con un riavvio del server.

✅ **Non è bloccante per domani**: memoria libera (2,5 GB disponibili), disco al 22%, entrambi i
siti rispondono 200. È rumore che falsa il monitoraggio, non un guasto. ⚠️ Ma se domani si vede
il server lento, si sa già che il load average non è l'indicatore da guardare.

ℹ️ **Uptime: 506 giorni.** Un riavvio pulirebbe i processi bloccati, ma va deciso **prima** o
**dopo** il go-live — non nel mezzo.

### Il `.env` di produzione non l'ho letto

Il tentativo di leggerne anche solo i **nomi** delle chiavi è stato bloccato, correttamente: è
un file di segreti. ⛔️ **Va verificato domani, insieme, e sono le tre voci che fanno fallire la
consegna in silenzio:**

- `MAIL_DIROTTA_A` → **deve essere ASSENTE**. Se c'è, nessun cliente riceve niente.
- `MAIL_AMBIENTE_REALE=si` → **deve esserci**, altrimenti le conferme non partono.
- `GV_SECRET_KEY` → deve esserci, **identica** a quella del gestionale. La imposta Adriano.

```bash
grep -oE "^[A-Z_]+=" /root/iscrizione-viaggi-azienda2/.env    # solo i nomi, mai i valori
```

---

## 5. La sequenza di domani

⛔️ **L'ordine non è negoziabile** (§3.7 della Checklist Go-Live).

| | Cosa | Nota |
|---|---|---|
| 0 | **Backup di Supabase** | senza questo non si comincia |
| 1 | **227 script**, `406` → `636`, in ordine numerico | via `docker exec … psql` porta 5432 |
| 2 | Voci ad attenzione manuale: RLS anon, bucket Storage, backfill `cliente_lingua` | |
| 3 | `GV_SECRET_KEY` in PROD + segreti re-inseriti | **lo fa Adriano** |
| 4 | **Flask nuovo** (rsync + bundle + restart) | |
| 5 | **MAUI 2.0** consegnata | |
| 6 | Verifiche post-applicazione | |

### ⛔️ La finestra pericolosa è fra il passo 1 e il 4

Appena applicati gli script **il sito vecchio si rompe**: chiama `fn_wizard_insert_cliente` e
altre funzioni che il nuovo assetto ha sostituito. Non degrada — si rompe.

**Quindi**: pagina di manutenzione prima del passo 1, tolta dopo il passo 4. E il passo 4 subito
dopo il passo 1, senza pause in mezzo.

### ⛔️ Due script che NON vanno applicati

- `499_Rollback_EstensioneWeb.sql` — contiene `DROP COLUMN`
- `270_Create_FnGetTransazioneInitData.sql` — cerca tre colonne rinominate, fallisce alla prima
  chiamata
- ℹ️ `999_Verify_…` è una verifica, non è nella sequenza

---

## 6. Da fare per primi, domani mattina

1. ☐ **Verificare l'accesso SSH dalla rete di domani** (ACL sull'IP): se non passa, tutto il
   resto è bloccato e va risolto prima.
2. ☐ **Backup di Supabase.**
3. ☐ **Leggere i nomi delle chiavi nel `.env` di produzione** (le tre voci del §4).
4. ☐ **`npm run build` sul Mac** e verificare che il bundle contenga «Come volete dormire».
5. ☐ Decidere se riavviare il server (processi bloccati) **prima** di iniziare.
6. ☐ Consegnare ad Antonio l'elenco delle 26 schede incomplete
   (`Resoconto_Lavori/2026-09-08-Clienti_da_Completare_prima_del_GoLive.md`).

---

*Verificato il 2026-09-08 dalle 20:00. Accessi provati: SSH ✅, Supabase via container ✅,
Supabase via MCP ✅, psql di sistema ⛔️.*
