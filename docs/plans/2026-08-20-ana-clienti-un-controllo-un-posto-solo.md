# Piano — `ana_clienti`: un controllo, un posto solo

## Contesto

`ana_clienti` è la tabella più trasversale del sistema: la usano il gestionale MAUI, il sito di
iscrizione Flask, le stampe, la contabilità e la newsletter. L'analisi del 2026-08-20
(`Documents/2026-08-20-Analisi_Validazioni_e_CRUD_AnaClienti.md`) ha mostrato che **le sue regole non
vivono in nessun posto in particolare**: vivono in tre o quattro posti diversi, che non si parlano e
in qualche caso si contraddicono.

Il caso che riassume tutto: l'algoritmo del codice fiscale — quello che calcola il codice atteso da
cognome, nome, data di nascita, sesso e comune, e gestisce l'omocodia — **esiste due volte**, in due
linguaggi:

| Dove | Righe | Stato |
|---|---|---|
| `Validation/Fiscal/CodiceFiscaleValidator.cs` (MAUI) | ~550 | `CalculateExpectedCodiceFiscale`, `ValidateAgainstAnagrafica`, `CheckOmocodia` sono **orfani** |
| `codice_fiscale_utils.py` (Flask) | 342 | in uso, esposto da `/api/validate_cf` |

Stesso algoritmo, destini opposti: uno gira, l'altro è morto. E i codici catastali su cui entrambi si
appoggiano stanno già nel database, in `ana_geo_comuni.comune_codfisc`.

Gli altri buchi accertati, tutti misurati su PROD:

- **Il controllo anti-omonimia si autodisattiva.** Gira solo se ci sono *sia* la data di nascita *sia*
  il codice fiscale — cioè è cieco sul **42% dei clienti** (327 su 778 non hanno il CF). Risultato:
  5 gruppi di omonimi, fra cui le due schede di ANTONIO TOLU fuse a mano il 2026-08-20.
- **L'iscrizione al viaggio non valida niente.** `MovClientiViaggiService` traduce solo gli errori del
  database. Si iscrive un pilota senza email e nessuno lo ferma: è successo 11 volte.
- **Il sito non raccoglie il consenso email.** Le tre colonne esistono (`consenso_marketing` + `_data`
  + `_fonte`, pensate per *dimostrare* il consenso), il sito non ne valorizza nessuna. Verificato:
  nel progetto Flask non c'è traccia di consenso, solo la pagina dell'informativa.
- **Le regole si contraddicono fra loro** dentro MAUI: email obbligatoria per il model e per il
  validatore, facoltativa per il delegato del dialog — che è quello che vince.

> **Nota che pesa sul metodo:** la scheda duplicata di TOLU è stata creata il **2026-05-13**, con
> `created_by` vuoto — lo stesso giorno dell'ultimo commit del repository Flask. È verosimilmente il
> residuo di una prova fatta sul sito **direttamente su produzione**. Il sito scrive in PROD senza le
> guardie del gestionale: è il motivo per cui non basta sistemare MAUI.

**Esito atteso:** ogni regola su `ana_clienti` esiste **una volta sola**, nel database, e i due
client la chiamano. In C# e in Python resta solo l'immediatezza dell'interfaccia.

**Vincolo di consegna:** il nuovo Flask, MAUI 2.0 e il nuovo DB su Supabase devono arrivare
**insieme**. Nessuno dei tre funziona da solo con gli altri due vecchi.

---

## Principio guida

Una regola sta nel database se deve valere **per chiunque scriva**. Sta nel client solo se serve a
rendere l'errore immediato mentre si digita. Il client non è mai l'unico posto in cui la regola esiste.

Corollario pratico: quando il client mostra un messaggio prima di chiamare il database, quel
messaggio **anticipa** una regola che esiste comunque a valle. Non la sostituisce.

---

## Fase 0 — Già fatta (2026-08-20)

`SqlScripts/541`, `542`, `543`: sei invarianti come `CHECK`, tre vincoli del gruppo 2 (due `NOT VALID`),
bonifica dei dati eseguita su PROD e in locale. Messaggi tradotti in `Helpers/DatabaseExceptionHelper`.
Nulla da rifare: è il pavimento su cui poggia il resto.

---

## Fase 1 — Il motore del codice fiscale scende nel database

È il primo passo perché **tutto il resto si appoggia qui**: senza un codice fiscale verificabile, il
controllo anti-omonimia resta debole e il CRUD non ha su cosa fondare l'identità di una persona.

**Nuovo `SqlScripts/544`:**

| Funzione | Scopo |
|---|---|
| `fn_cf_calcola(p_cognome, p_nome, p_data_nascita, p_sesso, p_comune_id)` | Il codice atteso. Legge il codice catastale da `ana_geo_comuni.comune_codfisc` |
| `fn_cf_verifica(p_cf, p_cognome, p_nome, p_data_nascita, p_sesso, p_comune_id)` | Esito completo: forma, carattere di controllo, corrispondenza con l'anagrafica, omocodia, **nome e cognome invertiti** (`547`) |
| `fn_cf_decodifica(p_cf)` | Da codice a data di nascita, sesso e comune — è ciò che ha permesso di verificare Tolu |

**Da dove si porta il codice:** la versione C# (`Validation/Fiscal/CodiceFiscaleValidator.cs`) è la più
completa e gestisce l'omocodia; la versione Python (`codice_fiscale_utils.py`) è quella collaudata sul
campo. Si porta la prima, **usando la seconda come riscontro**.

**Verifica — è la parte che rende sicuro il porting:** si fanno passare **tutti i codici fiscali reali
di PROD** attraverso le tre implementazioni e si confrontano gli esiti. Le due esistenti diventano
oracoli di test: se le tre concordano su ogni riga, il porting è corretto. Se divergono, la divergenza
è essa stessa un difetto da capire.

---

## Fase 2 — Il controllo anti-omonimia, che ora ha su cosa poggiare

**Nuovo `SqlScripts/545`:** `fn_ana_clienti_verifica_duplicato(p_azienda_id, p_cognome, p_nome,
p_data_nascita, p_comune_nascita_id, p_cf, p_email, p_escludi_cliente_id)` → esito a tre livelli:

| Coincidenza | Esito |
|---|---|
| Stesso **codice fiscale** | **blocco** — è la stessa persona, sempre |
| Stessi cognome, nome, **data e comune di nascita** | **blocco**, con l'indicazione di quale scheda esiste già |
| Stessi cognome e nome soltanto | **avviso** — l'omonimia esiste davvero |

**Nessuno dei tre livelli pretende il codice fiscale per funzionare.** È l'errore che ha reso inerte il
controllo attuale, e non va ripetuto.

Sostituisce: la guardia in `ClienteService.cs` (~riga 476) e, lato sito,
`fn_wizard_check_cf_esistenza`, `fn_wizard_find_email_by_anagrafica`, `fn_wizard_find_email_by_cf`.

---

## Fase 3 — Il CRUD unico

**Nuovo `SqlScripts/546`:** `fn_ana_clienti_insert`, `_update`, `_delete`.

- **Copertura completa delle colonne**: le 33 di `sp_ana_clienti_create` + `cliente_titolo_fk` +
  **`consenso_marketing` con data e fonte** + `cliente_lingua`. Oggi consenso e lingua passano da
  funzioni separate (`fn_ana_clienti_set_consenso`, `_set_lingua`): vengono assorbite, perché il
  consenso va raccolto **nel momento in cui l'anagrafica nasce**, non dopo.
- **Dentro la funzione** vivono le regole che non possono essere `CHECK`: «data di rilascio non nel
  futuro» (`CURRENT_DATE` non è `IMMUTABLE`) e la verifica del codice fiscale contro l'anagrafica.
- **Chiama** `fn_ana_clienti_verifica_duplicato` e `fn_cf_verifica`.

**Ritira** (`SqlScripts/548`, in fondo): `sp_ana_clienti_create/_update/_delete` — scritte e mai
collegate da nessuno — e `fn_wizard_insert_cliente`/`_update_cliente`.

---

## Fase 4 — L'iscrizione al viaggio

**Nuovo `SqlScripts/547`:** `fn_mov_clienti_viaggi_insert` / `_update`, con dentro la regola che oggi
non esiste da nessuna parte: **iscrivendo qualcuno come pilota, la sua anagrafica deve avere l'email**.

Il ruolo si legge da `ana_tipo_partecipante.tipo_partecipante_pilota`. È il punto in cui il ruolo si
conosce con certezza — e prende automaticamente anche i 7 clienti che sono pilota in un viaggio e
passeggero in un altro.

Sostituisce `fn_wizard_insert_prenotazione` e riempie il vuoto di `MovClientiViaggiService`.

---

## Fase 5 — I due client si allineano

### MAUI

| File | Cosa cambia |
|---|---|
| `Repositories/ClienteRepository.cs` | 1271 righe di SQL inline → chiamate alle funzioni. È il file che porta via più tempo |
| `Services/CRUD/ClienteService.cs` | la guardia anti-duplicato sparisce: la fa il database |
| `Services/CRUD/MovClientiViaggiService.cs` | chiama `fn_mov_clienti_viaggi_insert` |
| `Validation/Business/ClienteValidator.cs` | secondo la mappa della Parte H dell'analisi: **4 metodi da eliminare** (`ValidateTitolo`, `ValidateSesso`, `ValidatePassengerEmailDifferentFromPilot`, `ValidatePassengerEmailUnique`), il resto ridotto ad anticipazione |
| `Validation/Fiscal/CodiceFiscaleValidator.cs` | i tre metodi orfani si eliminano: la logica è nel DB |
| `Components/Shared/ClienteDialog.razor.cs` | la domanda non memorizzata «questa persona guiderà?» che decide se pretendere l'email |
| **Gestione partecipanti** | **popup «manca l'email»**: iscrivendo un pilota senza email, si chiede se inserirla subito e si aggiorna l'anagrafica senza uscire dalla schermata. Il `riferimento` restituito da `fn_mov_clienti_viaggi_valida` porta il `cliente_id` su cui aprirlo; la scrittura passa da `fn_ana_clienti_update`, che valida l'email *(deciso il 2026-08-20)* |
| `Helpers/DatabaseExceptionHelper.cs` | messaggi per i nuovi rifiuti |

**Restano in C#** gli avvisi non bloccanti, che sono presentazione e non regole:
`CoerenzaNomeSessoValidator` (nome che smentisce il sesso), documento scaduto, email già usata.

### Flask — `Iscrizione-Viaggi-Offroad PostgreSQL`

| File | Cosa cambia |
|---|---|
| `codice_fiscale_utils.py` (342 righe) | **si elimina**: l'algoritmo è nel database |
| `app.py` — `/api/validate_cf` (~riga 871) | delega a `fn_cf_verifica` invece di calcolare in Python |
| `Classi_Tabelle_DB/cliente.py` (487 righe) | `insert_cliente`/`update_cliente` chiamano le funzioni canoniche; spariscono i controlli duplicati |
| `Classi_Tabelle_DB/mov_clienti_viaggi_dao.py` | chiama `fn_mov_clienti_viaggi_insert` |
| `static/js/steps/Step2Content.jsx`, `Step3Content.jsx` | **spunta del consenso email, una per ciascun partecipante** — non pre-spuntata e distinta dall'accettazione delle condizioni: sono due consensi diversi |

**Restano intatte** le ~30 `fn_wizard_*` di sola lettura (viaggi, date, mezzi, alloggi, geografia):
non si sovrappongono a niente e non c'è motivo di toccarle.

---

## Fase 6 — Consegna coordinata

Aggiornare `Estensione Progetto WEB/Documenti/2026-07-10-Checklist_Go_Live_PROD.md` §2.8 e §4: la
consegna diventa **un evento solo con tre componenti**, e l'ordine non è negoziabile.

1. Script DB (`406`→`548`) su Supabase.
2. Flask nuovo in produzione.
3. MAUI 2.0 consegnata.

Fra il passo 1 e il 2 il sito vecchio **non funziona più**: le funzioni che chiama non ci sono. La
finestra fra i due va tenuta stretta e provata prima in staging.

---

## Verifica

- **Motore CF (Fase 1):** i codici fiscali reali di PROD attraverso le tre implementazioni, confronto
  a tre. È il test che rende accettabile il porting.
- **Ogni funzione nuova:** provata in transazione annullata su PROD in sola lettura, con i casi veri
  già noti — le due schede TOLU, gli 11 piloti senza email, le tre coppie che condividono la casella.
- **MAUI:** build, poi collaudo a runtime dei percorsi cliente (i test xUnit non girano da CLI in
  questo progetto: `dotnet build` + prova nell'app).
- **Flask:** i suoi test più un'iscrizione completa dal sito che finisca correttamente a database,
  consenso compreso.
- **Prova incrociata, la più importante:** la stessa anagrafica sbagliata — email malformata, codice
  fiscale incoerente, pilota senza email — inserita **dal gestionale e dal sito**. Deve essere
  rifiutata da entrambi, con lo stesso messaggio.

---

## Rischi

- **Il porting del motore CF è il pezzo più delicato.** Mitigato dal confronto a tre: le due
  implementazioni esistenti sono oracoli, non concorrenti.
- **`ClienteRepository` è grande** (1271 righe, 20 metodi). Si converte per gruppi, non in un colpo.
- **Due repository separati** che devono restare allineati: ogni funzione nuova va documentata in
  `Documents/Funzioni_DB.md` prima che Flask la usi, perché è l'unico contratto condiviso.
- **Fino alla consegna, PROD gira con MAUI 1.35**, che non conosce i nuovi vincoli: per questo gli
  script restano fuori da PROD fino al go-live (già deciso).

## Deciso il 2026-08-20

- Email obbligatoria **per i piloti**, facoltativa per gli accompagnatori.
- Unicità dell'email: **avviso**, non vincolo — condividere la casella è prassi legittima.
- Documento scaduto: **avviso**.
- Consenso e lingua **dentro** il CRUD; consenso raccolto **per ciascun partecipante** anche dal sito.
- Le `fn_wizard_*` sovrapposte si **eliminano**: Flask chiama le canoniche.
