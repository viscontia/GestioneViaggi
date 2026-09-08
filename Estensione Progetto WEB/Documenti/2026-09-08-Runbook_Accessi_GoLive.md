# Runbook accessi go-live — verificato il 2026-09-08, sera

> Preparato la sera del 2026-09-08, il giorno prima del go-live. **Tutto quello che c'è qui è
> stato provato davvero**, non copiato dai documenti: in quattro punti la realtà differiva dalla
> documentazione di marzo, e sotto c'è scritto come stanno le cose.
>
> ⚠️ **Da leggere per primo il §6**, che è la lista di cosa fare all'inizio.

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

## 4. Lo stato del server, e le tre voci ancora da verificare

### ✅ FATTO: il server è stato riavviato (2026-09-08, 20:19 → 20:31)

Deciso da Adriano appena visti i quattro processi bloccati. **Riavviato ieri sera, non domani**:
se qualcosa non fosse ripartito, c'era tutta la sera per sistemarlo.

⛔️ **La verifica prima del riavvio ha trovato un problema serio: `nginx` era `active` ma
`disabled`.** Senza socket activation, dopo il riavvio i due siti sarebbero rimasti giù finché
qualcuno non lo avviava a mano dalla console. Era così da chissà quando: 506 giorni di uptime
lo avevano reso invisibile. Corretto con `systemctl enable nginx` **prima** del reboot.

ℹ️ Falso allarme su `ssh.service`, che risultava `disabled`: su Ubuntu 24.04 c'è la **socket
activation**, e `ssh.socket` è `enabled` e `active`. L'accesso non si sarebbe perso. ⚠️ Verificato
prima di allarmare — la differenza fra i due casi è tutta lì.

**Esito, misurato dopo:**

| | Prima | Dopo |
|---|---|---|
| Processi bloccati in stato D | **4** | **0** |
| Load average | **8,00** fisso | **0,00** |
| Memoria libera | 172 MB | **3,1 GB** |
| nginx / Flask legacy / Flask azienda 2 | attivi | **tutti attivi** |
| I due siti dall'esterno | 200 | **200** (0,8s e 0,55s) |
| Servizi falliti al boot | — | **nessuno** |

⚠️ **Il riavvio ha impiegato circa 11 minuti**, e vale la pena sapere dove sono andati: il **boot
è durato 8,5 secondi** (`systemd-analyze`), quindi **erano tutti nello shutdown**. I quattro
processi in stato D non rispondono ai segnali: systemd li attende uno per uno prima di forzare.
ℹ️ Nessun `fsck`, che pure era l'ipotesi più ovvia dopo 506 giorni — l'ipotesi era sbagliata e i
tempi di boot lo dimostrano.

ℹ️ Da qui in avanti un riavvio è un'operazione da un minuto: i processi bloccati erano
l'anomalia, non la norma.

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
   resto è bloccato e va risolto prima di ogni altra cosa.
2. ☐ **Backup di Supabase.** Senza questo non si comincia.
3. ☐ **Leggere i nomi delle chiavi nel `.env` di produzione** — le tre voci del §4 che fanno
   fallire la consegna in silenzio.
4. ☐ **`npm run build` sul Mac**, poi verificare che il bundle contenga «Come volete dormire».
5. ☐ **Pagina di manutenzione sul sito** prima di applicare gli script.
6. ☐ Consegnare ad Antonio l'elenco delle 26 schede incomplete
   (`Resoconto_Lavori/2026-09-08-Clienti_da_Completare_prima_del_GoLive.md`).

✅ **Il riavvio del server è già stato fatto ieri sera** — vedi §4. Non va rifatto.

---

## 7. Se qualcosa va storto

**Il server non risponde più.** Console Hetzner dal pannello (Cloud Console): dà accesso allo
schermo della macchina anche senza rete. ⚠️ **Solo Adriano ha il pannello Hetzner** — io non
posso arrivarci.

**Uno script fallisce a metà sequenza.** ⛔️ Non si prosegue con i successivi: si legge l'errore,
si capisce, e si decide. Gli script sono in ordine di dipendenza, e uno saltato rende insensati
quelli dopo. Con `-v ON_ERROR_STOP=1` psql si ferma da solo — ⚠️ è il motivo per cui va sempre
messo.

**Il sito nuovo non parte dopo il rsync.** `journalctl -u iscrizione-viaggi-2.service -n 50
--no-pager` dice quasi sempre il perché in chiaro. Le cause più probabili: dipendenze cambiate
(`pip install -r requirements.txt`) o una chiave mancante nel `.env`.

**Le mail non arrivano.** Le tre voci del §4, in quest'ordine: `MAIL_DIROTTA_A` assente,
`MAIL_AMBIENTE_REALE=si` presente, `GV_SECRET_KEY` presente e identica a quella del gestionale.
Nel log del sito deve comparire `Flask-Mail inizializzato da DB (…)`.

**Serve tornare indietro.** ⛔️ `499_Rollback_EstensioneWeb.sql` **non è la via**: contiene
`DROP COLUMN` e cancella dati. Il ritorno indietro vero è il **backup del passo 0**.

---

*Verificato il 2026-09-08 dalle 20:00 alle 22:35. Accessi provati: SSH ✅, Supabase via container ✅,
Supabase via MCP ✅, psql di sistema ⛔️. Server riavviato e ripartito pulito ✅.*
