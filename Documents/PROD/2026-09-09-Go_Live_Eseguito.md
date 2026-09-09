# Go-live eseguito — 2026-09-09

Resoconto di cosa è stato fatto davvero, nell'ordine in cui è stato fatto, con i numeri
misurati. ⚠️ Include le cose che **non** erano previste e sono saltate fuori strada facendo:
sono la parte più utile da rileggere.

---

## 1. Backup di PROD — fatto e **provato**

`~/Documents/Backup_GoLive/` (fuori dal repository: contiene i dati di 776 clienti).

⛔️ **Non è stato solo fatto: è stato ripristinato** in un database di servizio e confrontato con
PROD voce per voce. Tabelle 68=68, funzioni 469=469, indici 256=256, clienti 776=776,
iscrizioni 1202=1202.

⚠️ **La prova è servita**: al primo tentativo il ripristino ha dato **57 errori** e ha perso 3
tabelle e 81 funzioni, perché mancavano le estensioni `citext` e `pg_trgm`. Senza il tipo
`citext` non si creano `ana_aziende_smtp`, `app_users` e `password_reset_tokens`, e tutto ciò
che ne dipende cade a cascata. **Le estensioni vanno create PRIMA del `pg_restore`** — il
comando esatto è nel `LEGGIMI` accanto ai file.

ℹ️ Il backup **non copre i file dello Storage Supabase** (foto e mappe GPX).

## 2. I 226 script

Dal `406` al `636`, in ordine numerico. ⛔️ `499_Rollback_EstensioneWeb.sql` **escluso** (contiene
`DROP COLUMN`).

**Iniziati 10:30:13, finiti 10:38:29 — 8 minuti e 16 secondi, zero errori.**

Applicati con il client psql del container Docker sulla **porta 5432** (session pooling), non
la 6543: gli script usano `BEGIN…COMMIT`, `SET LOCAL` e blocchi `DO` con eccezioni, e vogliono
una sessione vera. ⚠️ Il `psql` di Homebrew (18.1) **non si connette** a Supabase — errore di
verifica del certificato.

### Verifiche dopo

| | |
|---|---|
| Iscrizioni, viaggi | invariati (1202, 69) |
| Schema nuovo | `cliente_titolo_fk`, `cliente_lingua`, `consenso_marketing` presenti |
| ⭐️ `password_enc` | ora **`bytea`**: la cifratura pgcrypto è attiva |
| 16 funzioni chiave | tutte presenti |
| 7 funzioni morte | sparite |
| Doppioni anagrafici | **zero** |

### ⚠️ Due scostamenti nei conteggi, entrambi corretti

- **Clienti 776 → 800.** Lo script `588`: le 24 persone che avevano viaggiato con SFT usando
  l'anagrafica di un'altra azienda ora hanno la loro scheda in SFT.
- **Alloggi 454 → 449.** Lo script `586` ha eliminato **cinque camere in cui nessuno degli
  occupanti risultava iscritto**: residui di iscrizioni cancellate senza rimuovere la camera.
  Lo script ne prevedeva «un caso solo», ne ha trovati cinque. ✅ Nessuna camera è rimasta senza
  occupanti.

## 3. Oracle: spento e rimosso

⛔️ **Il vecchio sito era ancora pubblico e raggiungibile**, contrariamente a quanto si
credeva: 150 accessi da browser veri in una settimana.

⚠️ **Ma il suo database era morto dal 2 giugno**: `ORA-28001 — the password has expired`, primo
errore alle 15:46 del 2 giugno, **1.548 errori** fino a ieri sera. Serviva la pagina di
iscrizione senza poter leggere né scrivere: chiunque abbia provato a iscriversi in tre mesi ha
visto un errore. ✅ **Nessun dato da recuperare.**

Rimossi: `/root/iscrizione-viaggi-app/` (100 MB), `/opt/oracle/` con wallet e instant client
(199 MB), l'unità systemd, e i riferimenti morti nella configurazione nginx.

⚠️ Le credenziali Oracle erano **in chiaro** nel file systemd. La password di ADMIN è scaduta e
Adriano l'ha persa; l'istanza era su free tier, nessun costo.

## 4. Il sito in produzione

Deploy via **rsync** — ⛔️ il server non ha git, contrariamente a quanto diceva il documento di
marzo. Con `--exclude='.env'`, sempre: il `.env` locale contiene `MAIL_DIROTTA_A`.

**Provato end-to-end**: iscrizione completa (viaggio, mezzo, camera, cane), mail ricevuta,
dati verificati sul database campo per campo.

### ⚠️ Il passaggio all'indirizzo principale ha scoperto un difetto invisibile

Spostando il sito da `/2-976f2734/` a `/`, `bundle.js` ha dato **404** e la pagina è rimasta
bianca: `location /static/` puntava a `/root/iscrizione-viaggi-app/static/`, la cartella
dell'app Oracle **eliminata quella mattina**. Sotto il percorso col token la cosa non si vedeva,
perché quei file passavano da Flask.

⛔️ **Il `noindex` è rimasto**, e nella configurazione c'è scritto perché: la revisione
sull'esposizione dei dati personali (§2.12) è rimandata, e finché non è chiusa il sito non deve
finire nei motori di ricerca. **Va tolto solo dopo quella.**

## 5. Segreti e posta

- `MAIL_AMBIENTE_REALE=si` aggiunta al `.env` del server: ⛔️ senza, il sito è fail-closed e
  **non spedisce niente**.
- `GV_SECRET_KEY` **rigenerata** (la precedente era stata esposta in una sessione di lavoro) e
  messa su Mac e server. ⚠️ Verificata identica sui due lati **confrontando le impronte**, senza
  che il valore passasse da nessuna parte.
- Password SMTP re-inserita e cifrata con la chiave nuova. ✅ Nel log del sito compare
  `Flask-Mail inizializzato da DB` su tutti e quattro i worker.

## 6. Il riavvio del server (la sera prima)

Quattro processi `npm` bloccati in stato D tenevano il load average a **8,00 fisso** su 2 CPU.
Dopo il riavvio: **0,00**, memoria libera da 172 MB a 3,1 GB.

⛔️ **La verifica prima del reboot ha trovato `nginx` `active` ma `disabled`**: senza
`systemctl enable nginx`, dopo il riavvio i siti sarebbero rimasti giù. Era così da chissà
quando — 506 giorni di uptime lo avevano reso invisibile.

ℹ️ Falso allarme su `ssh.service`, anch'esso `disabled`: su Ubuntu 24.04 è `ssh.socket` a
tenere la porta 22. ⚠️ Il riavvio ha impiegato 11 minuti, **tutti nello shutdown** (il boot è
durato 8,5 secondi): i processi in stato D non rispondono ai segnali.

## 7. Due difetti del sito trovati collaudando

- **Tipo mezzo già scelto**: `tipo_mezzo_selezionato_id` mancava dalla lista delle chiavi che la
  home ripulisce dalla sessione — l'unica delle quattro tendine del passo 4 a sopravvivere.
  Sfuggita perché si chiama `tipo_mezzo_` e non `mezzo_` come le altre.
- **Consenso**: la casella nella form non si vedeva. Sostituita da una finestra dedicata da cui
  si esce **solo rispondendo**. ⛔️ Nel cercarlo avevo introdotto io un difetto peggiore — una
  richiesta che si apriva e chiudeva da sola registrando un rifiuto mai espresso — perché
  `onHide` rispondeva «no» a qualunque chiusura. Corretto.

---

## Che cosa resta

⛔️ **Bloccante per il cliente**

- **Consegnare il gestionale 2.0 ad Antonio**, con `GV_SECRET_KEY` sul suo PC. ⚠️ La sua 1.35
  **non riesce più a iscrivere né ad assegnare camere**: usava quattro funzioni che gli script
  hanno eliminato (`sp_mov_clienti_viaggi_create`, `sp_mov_clienti_alloggi_create`,
  `sp_assign_to_first_free_slot`, `fn_get_transazione_init_data`).

⚠️ **Da fare, non bloccante**

- **Chiudere l'esposizione dei dati personali** (§2.12) e solo allora togliere il `noindex`.
- **Consegnare l'elenco delle 26 schede incomplete**
  (`Resoconto_Lavori/2026-09-08-Clienti_da_Completare_prima_del_GoLive.md`): quelle persone non
  si possono iscrivere finché la scheda non è completa.
- **Pulizia ricorrente dei token scaduti**: non li rimuove nessuno.
- **Bucket Storage e RLS `anon`**: da verificare quando arriverà il sito pubblico.
