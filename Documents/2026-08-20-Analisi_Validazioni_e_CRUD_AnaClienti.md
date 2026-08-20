# Analisi — Validazioni e CRUD di `ana_clienti`

> **USO INTERNO.** Rilevata il 2026-08-20. ⚠️ **I numeri di questo documento vengono da PROD**
> (Supabase, sola lettura). Il DB locale non è una copia di produzione: oltre all'import da Oracle
> porta la sporcizia di mesi di test, quindi non si usa per misurare — solo per far girare il codice
> e provare gli script.
> Prepara il lavoro deciso il 2026-08-19: centralizzare i controlli nel gestionale e **subito dopo**
> allineare il sito di iscrizione (§2.8 della Checklist Go-Live PROD). È un'analisi: propone, non decide.

---

## Sintesi

Tre cose, in ordine di gravità:

1. **Le regole non sono solo duplicate fra app e sito: si contraddicono dentro l'app stessa.**
   Email, telefono e documento sono dichiarati obbligatori in due strati su tre, e il terzo — quello
   che vince — li lascia vuoti. Non esiste oggi una risposta alla domanda «l'email è obbligatoria?».
2. **«Inserisci un cliente» è implementato tre volte**, e una delle tre non la chiama nessuno.
3. **Le regole del C# sono più severe dei dati veri.** Non si possono far scendere nel database così
   come sono: 297 clienti su 778 non hanno email, 572 non hanno documento. Metà delle regole non sono
   invarianti, sono politica di data-entry di una form.

Il punto 1 va risolto **prima** di scrivere qualsiasi codice: non si centralizza una regola che
nessuno sa quale sia.

---

## Parte A — Le regole vivono in tre strati, e non dicono la stessa cosa

| Strato | Dove | Cosa dice sull'email |
|---|---|---|
| Annotazione del model | `Models/Cliente.cs` | `[Required]` — «L'email è obbligatoria» |
| Validatore di business | `Validation/Business/ClienteValidator.ValidateEmail` | «L'email è obbligatoria» |
| **Delegato del dialog** | `ClienteDialog.razor.cs → ValidateEmailAsync` | **`if (string.IsNullOrWhiteSpace(email)) return [];`** — vuota va bene |

Nel markup il campo Email **non ha** `Required="true"`. MudBlazor, quando un campo espone un
delegato `Validation`, usa quello: quindi vince lo strato più nascosto dei tre, e l'email vuota passa.

**La prova sta nei dati:** 297 clienti su 778 non hanno email, e convivono da sempre con
un'annotazione che li dichiara impossibili. Stessa struttura per **telefono** (`ValidateTelefono` fa
`yield break` sul vuoto) e per i **campi del documento**, `[Required]` nel model e senza
`Required="true"` nel markup.

> **Conseguenza per il lavoro:** la prima domanda non è «dove mettiamo la regola», è **«qual è la
> regola»**. Finché tre strati dicono cose diverse, spostarli nel database significa scegliere a caso
> quale dei tre ha ragione.

---

## Parte B — Cosa impone davvero il database, oggi

Buona notizia, più di quanto sembrasse:

| Il DB impone già | Dettaglio |
|---|---|
| **Tutte le lunghezze massime** | `cliente_email` 100, `cognome`/`nome` 50, `indirizzo` 100, `telefono` 15, `preftelint` 5, `tipodoc` 10, `documento_numero` 50, `rilasciato_da` 100, `iban` 34, `codicefiscale` 16 — **coincidono esattamente** con i `MaxLength` dei validatori C# |
| **10 colonne `NOT NULL`** | `azienda_fk`, `cognome`, `nome`, `sesso`, `titolo_fk`, `comune_nascita_fk`, `comune_residenza_fk`, `lingua`, `consenso_marketing`, `cliente_id` |
| **1 solo `CHECK`** | `cliente_sesso IN ('M','F')` |
| Nessun `UNIQUE` | nemmeno sull'email |

Quindi le regole di **lunghezza** sono già centralizzate nel posto giusto: i `MaxLength` in C# sono
duplicati che servono solo a dare un messaggio migliore prima del round-trip. Non è debito, è
ridondanza accettabile — ma va saputo, per non «spostarle» credendo di guadagnare qualcosa.

Tutto il resto — formato, minimi, coerenza fra date, unicità — nel database **non esiste**.

---

## Parte C — Quali regole possono scendere nel DB, misurato sui dati veri

Conteggio delle righe che **oggi violerebbero** la regola, se diventasse un vincolo.
Locale (742 clienti) e PROD (778) danno lo stesso quadro; sotto sono i numeri di **PROD**.

### Gruppo 1 — Imponibili subito (zero violazioni)

| Regola | Viola |
|---|---|
| Email in formato valido *(se presente)* | 0 |
| Cognome ≥ 2 caratteri · Nome ≥ 2 caratteri | 0 |
| Data di rilascio non nel futuro | 0 |
| Data di rilascio successiva alla nascita | 0 |
| Data di scadenza successiva al rilascio | 0 |
| IBAN 15-34 caratteri e due lettere iniziali *(se presente)* | 0 |

Sono **invarianti veri**: nessun dato li viola, e nessun dato dovrebbe poterli violare. Diventano
`CHECK` senza bonifica e senza discussione. È il lavoro a costo zero da fare per primo.

### Gruppo 2 — Imponibili dopo una bonifica piccola

| Regola | Viola | Nota |
|---|---|---|
| Telefono con soli caratteri ammessi | 2 | due numeri con caratteri strani |
| Codice fiscale di 16 caratteri *(se presente)* | 4 | da guardare uno per uno |
| Documento non scaduto | 8 | ⚠️ **non è un invariante**: un documento scade da solo col tempo. Non può essere un `CHECK`, semmai un avviso |
| Indirizzo ≥ 5 caratteri *(se presente)* | 8 | |
| Email univoca per azienda | 3 | ⚠️ da decidere: è un vincolo o due persone possono condividere una casella? |

### Gruppo 3 — NON imponibili: le regole sono più severe della realtà

| Regola | Viola | su 778 |
|---|---|---|
| Ente di rilascio presente | **579** | 74% |
| Numero documento presente | **574** | 74% |
| Tipo documento presente | **572** | 74% |
| Prefisso telefonico presente | **298** | 38% |
| **Email presente** | **297** | 38% |
| Telefono presente | 292 | 38% |
| Indirizzo presente | 61 | 8% |

Qui sta il nodo del punto 1. Il C# dichiara obbligatori campi che **tre quarti dei clienti non
hanno** — l'eredità dell'import Oracle. Le strade sono tre, e la scelta è di prodotto, non tecnica:

- **(a) Non sono obbligatori.** Si allineano annotazioni e validatori al comportamento reale, e la
  contraddizione sparisce ammettendo che la regola non c'è mai stata.
- **(b) Obbligatori solo per i nuovi.** Il vincolo si applica agli inserimenti, non agli aggiornamenti
  di anagrafiche storiche. Si fa in una funzione DB, non con un `CHECK` (che guarda ogni riga).
- **(c) Obbligatori davvero, con bonifica.** Vuol dire recuperare l'email di 297 clienti reali. Non
  sembra realistico.

---

## Parte D — Il CRUD: tre implementazioni di «inserisci un cliente»

| # | Dove | Chi la usa | Come |
|---|---|---|---|
| 1 | `ClienteRepository.InsertAsync` / `UpdateAsync` / `DeleteAsync` | **il gestionale** | SQL inline in C# |
| 2 | `sp_ana_clienti_create` / `_update` / `_delete` | **nessuno** | PL/pgSQL |
| 3 | `fn_wizard_insert_cliente` / `fn_wizard_update_cliente` | **il sito di iscrizione** | PL/pgSQL |

La 2 esiste dal principio e non è mai stata collegata: un primo tentativo di DB-first abbandonato
quando è stato scritto il repository. Nessun file C# la nomina.

**Cosa scrive ciascuna** (colonne dell'`INSERT`):

| | repo C# | `sp_create` | wizard |
|---|---|---|---|
| Colonne scritte | 31 | 33 | **23** |
| `cliente_titolo_fk` | ✅ | ✗ (scrive il testo) | ✗ (scrive il testo) |
| Foto e documento (blob + metadati) | ✅ | ✅ | ✗ |
| IBAN, note | ✅ | ✅ | ✗ |
| `consenso_marketing`, `cliente_lingua` | ✗ | ✗ | ✗ |

Le ultime due righe contano: **nessuna delle tre** scrive consenso e lingua, che passano da funzioni
separate (`fn_ana_clienti_set_consenso`, `fn_ana_clienti_set_lingua`). Un CRUD unificato deve
decidere se assorbirle o lasciarle fuori — e per il consenso la risposta è probabilmente «dentro»,
visto che va raccolto **al momento dell'iscrizione** (§2.8.1 della checklist).

**Il resto del repository:** 20 metodi pubblici, 1271 righe, quasi tutti SQL inline. Usano una
funzione DB solo `GetDetailAsync` (`get_cliente_detail`) e i metodi sullo storico viaggi. Da
convertire: letture per id/email/CF/anagrafica, i tre `ExistsBy*`, `SearchAsync`, `CountAsync`,
`HasRelated*`.

---

## Parte E — Proposta di lavoro

1. **Decidere qual è la regola** per email, telefono, prefisso, indirizzo e documento (Parte C,
   gruppo 3). È l'unico passo che non posso fare io, e blocca tutti gli altri.
2. **Gruppo 1 → `CHECK` nel DB.** Sei regole, zero violazioni, nessuna bonifica: si fa subito e vale
   per app e sito insieme, dal primo minuto.
3. **Gruppo 2 → guardare le 17 righe** che violano, decidere caso per caso, poi vincolare.
4. **Un CRUD unico DB-first**: `fn_ana_clienti_insert` / `_update` / `_delete`, con dentro le regole
   decise al punto 1 e la copertura completa delle colonne (le 33 di `sp_create` + FK del titolo +
   consenso + lingua).
5. **Il repository chiama le funzioni nuove**; `sp_ana_clienti_*` si eliminano (mai usate).
6. **Il sito passa alle stesse funzioni**, e con questo il ponte di compatibilità del `539` e la
   colonna `cliente_titolo` si possono togliere (debito dichiarato in `Funzioni_DB.md` §8.3).
7. **In C# resta** l'immediatezza dell'interfaccia: messaggio inline, fuoco sul campo, avvisi non
   bloccanti come `CoerenzaNomeSessoValidator`. Le lunghezze massime restano duplicate: servono a
   dare il messaggio prima del round-trip.

### Decisioni prese il 2026-08-20

| # | Domanda | Decisione |
|---|---|---|
| 1 | Email obbligatoria? | ~~Sì, sempre~~ → **rivista**: obbligatoria per i **piloti**, facoltativa per gli accompagnatori. Vedi sotto |
| 2 | Email univoca? | ~~`UNIQUE (azienda_fk, email)`~~ → **rivista**: avviso, non vincolo. Vedi sotto |
| 3 | Documento scaduto | **Avviso, non blocco.** Importante ma non è un invariante: un documento scade da solo col tempo |
| 4 | Consenso e lingua nel CRUD | **Dentro**, e il consenso va raccolto **anche dal sito** per chi lascia lì la propria anagrafica |

**Conseguenze della 1, misurate su PROD.** I clienti senza email sono 297:

| Profilo | Clienti |
|---|---|
| Mai iscritti a un viaggio | 40 |
| **Attivi** — viaggio negli ultimi 3 anni | **82** |
| Solo viaggi più vecchi di 3 anni | 175 |

Con l'obbligo anche in modifica, ognuna di queste 297 schede diventa non salvabile finché non le si
aggiunge un'email. Sugli 82 attivi è una bonifica realistica — sono persone che viaggiano e a cui la
si può chiedere. Sui 175 storici e sui 40 mai partiti l'effetto pratico è che quelle schede non si
toccano più: chi le aprisse per correggere un telefono si troverebbe bloccato. **Scelta del
committente, presa con questi numeri sotto gli occhi.**

**Conseguenze della 2.** Vanno sanate **3 email duplicate dentro la stessa azienda** prima di poter
creare il vincolo. I **5 casi di stessa email su aziende diverse** non si toccano: sono leciti per
costruzione.

### Revisione delle decisioni 1 e 2 — dopo aver guardato i dati

Le prime due decisioni sono state **riviste lo stesso giorno**, perché i dati veri hanno mostrato che
le regole come formulate contraddicevano il modo in cui si lavora davvero.

#### Email: obbligatoria per i **piloti**, facoltativa per gli accompagnatori

L'obbligo indiscriminato produce dati falsi, non dati. Le tre coppie con email ripetuta lo
dimostrano: in ciascuna, **l'indirizzo appartiene a uno dei due** e l'altro se l'è fatto prestare —
`lulu.sciascia@` è di Sciascia, `massimo.fratantonio@` di Fratantonio, `s.biavati@` di Biavati. È la
firma di una form che pretende un'email da chi non vuole darla: la moglie che si iscrive col marito e
non lascia il proprio indirizzo per non ricevere posta che non le interessa.

Il criterio giusto lo detta il ruolo, ed è **già quello che il sito di iscrizione applica**. Misurato
su PROD il 2026-08-20:

| Ruolo | Iscrizioni | Senza email |
|---|---|---|
| **Piloti** (pilota mezzo proprio, guida, moto, quad, noleggiato) | **667** | **11** — 1,6% |
| **Non piloti** (passeggeri, guida in seconda) | **532** | **385** — 72% |

Chi guida lascia l'email quasi sempre; chi è trasportato quasi mai. La regola descrive la pratica
invece di combatterla, e **la bonifica passa da 297 righe a 11**.

> ⚠️ **Conseguenza architetturale, non banale.** Il ruolo pilota/passeggero **non sta sul cliente**:
> sta sull'iscrizione al viaggio (`mov_clienti_viaggi.tipo_partecipante_id_fk` →
> `ana_tipo_partecipante.tipo_partecipante_pilota`). La stessa persona è pilota in un viaggio e
> passeggero in un altro.
>
> Quindi la regola **non può essere** un `NOT NULL` né un `CHECK` su `ana_clienti`, e la form
> anagrafica da sola non può applicarla: non sa in che ruolo verrà iscritta quella persona. Va
> imposta **dove il ruolo si conosce** — al momento dell'iscrizione al viaggio. Sull'anagrafica
> l'email resta facoltativa.

#### Email univoca: avviso, non vincolo

Stessa causa. Se la moglie non lascia l'email e la form la pretende, si finisce per metterci quella
del marito: il vincolo di unicità non impedirebbe il dato sbagliato, lo renderebbe soltanto più
faticoso da inserire. Diventa un **avviso** — «questa email è già usata da un altro cliente di questa
azienda» — che intercetta la scheda duplicata per errore senza vietare la coppia. Coerente con la
scelta fatta per il documento scaduto.

Niente da sanare su PROD: le tre coppie restano legittime. La newsletter deduplica già per email
(`fn_web_destinatari_newsletter`), quindi una casella condivisa riceve un solo messaggio.

#### Perché il controllo anti-duplicato non ha fermato quelle tre coppie

Indagato il 2026-08-20. Il SQL di `ExistsByEmailAsync` è corretto: interrogato oggi vede tutte e tre
le coppie. Il dialog è l'**unico** percorso di creazione dell'app, e `HandleSubmit` rispetta
`_form.IsValid`. Le ipotesi degli spazi in coda e dell'azienda non propagata sono cadute — le email
non hanno spazi, e la segreteria è `azienda_admin` con azienda 2 correttamente valorizzata.

La spiegazione è più semplice: **il controllo è nato dopo**. Introdotto il 2026-01-02 (commit
`b079d2c`), mentre le coppie sono del **2025-09-11** e del **2025-11-05**.

**La coppia del 2026-01-25** è nata *dopo* il controllo, e su di lei l'indagine è proseguita.
Escluse con prove, in ordine: SQL sbagliato (oggi vede tutte e tre le coppie); spazi in coda nelle
email (zero); azienda non valorizzata (la segreteria è `azienda_admin` su azienda 2, e `Clienti.razor`
la imposta correttamente); scorciatoia del SuperAdmin che salta il controllo (non è SuperAdmin); un
secondo percorso di creazione (`ClienteDialog` è l'unico dell'app); `HandleSubmit` che ignora
`IsValid` (non lo ignora); campo Email non registrato nella form perché su un'altra scheda dei
`MudTabs` (`KeepPanelsAlive="true"`, resta registrato). L'audit non aiuta: gli eventi di quelle due
schede sono datati **2026-04-07**, entrambi allo stesso microsecondo e senza autore — un
ripopolamento a posteriori, non la traccia della creazione. Le due schede sono nate a **7 minuti**
di distanza e non sono **mai** state modificate: la seconda è stata creata con l'email già dentro.

> ✅ **Indagine chiusa il 2026-08-20: il controllo non ha mai fallito.**
> Le consegne a SFT sono state la **1.30 l'8 aprile 2026** e la **1.35 il 3 luglio 2026**. Il
> controllo è nel repository dal 2 gennaio, ma sulla macchina della segreteria è arrivato solo con la
> 1.30: il 25 gennaio girava una build più vecchia, che non lo aveva. Tutte e tre le coppie sono
> quindi anteriori all'arrivo del controllo, e non c'è nessun percorso di fallimento da inseguire.
>
> Conferma indipendente: il ripopolamento degli eventi di audit è datato **7 aprile 2026, ore 14:40**
> — il giorno prima della consegna della 1.30, coerente con la preparazione di un rilascio.
>
> *(La conclusione poggia sull'elenco delle consegne fornito dal committente: se fra il 2 e il 25
> gennaio ci fosse stata una consegna non ricordata, l'indagine andrebbe riaperta.)*

> ⚠️ **Difetto latente trovato durante l'indagine, indipendente da questo caso.**
> `DashboardAdmin.OpenNewClientDialog` apre il dialog con `AziendaFk = _currentUser?.AziendaId ?? 0`.
> Quel `?? 0` trasforma «azienda sconosciuta» in «azienda zero»: per un utente non SuperAdmin
> `aziendaCheck` vale 0, la ricerca gira su un'azienda inesistente, non trova nulla e **approva in
> silenzio**. Lo stesso schema vale per il controllo sul codice fiscale. Da chiudere a prescindere da
> come finisce l'indagine.

---

## Parte F — L'obbligo dell'email al pilota: dove vive la regola

**Il controllo all'iscrizione non esiste.** `MovClientiViaggiService` non ha **nessuna** validazione:
solo traduzione in italiano degli errori del database. Si può iscrivere come pilota una persona senza
email, e nulla lo impedisce.

**Quanto pesa l'obiezione «il ruolo cambia da viaggio a viaggio»** — misurato su PROD il 2026-08-20:

| Profilo | Clienti |
|---|---|
| Sempre e solo pilota | 347 |
| Sempre e solo passeggero | 333 |
| **Pilota in un viaggio, passeggero in un altro** | **7** (1%) |

Un flag memorizzato sull'anagrafica sarebbe giusto per il 99% e **falso in silenzio** su quei 7 — oltre
a essere la terza copia di un fatto che vive già sull'iscrizione.

**Decisione del 2026-08-20.** Due presidi, nessun dato duplicato:

1. **In anagrafica, una domanda non memorizzata** — «questa persona guiderà?» — che serve solo a
   decidere se pretendere l'email. Per chi risulta già pilota nello storico si risponde da sola.
2. **All'iscrizione al viaggio, il controllo autoritativo**: iscrivere qualcuno come pilota richiede
   che la sua anagrafica abbia un'email. È il punto in cui il ruolo si conosce con certezza, e prende
   automaticamente anche i 7 che cambiano ruolo.

Da sanare: gli **11 piloti senza email** già presenti (su 667 iscrizioni come pilota).

### Codice orfano rilevato (non rimosso: si decide col nuovo CRUD)

| Validatore | Perché è orfano |
|---|---|
| `ValidateTitolo`, `ValidateSesso` | superati dal re-model del `538`: il titolo è una FK, il sesso è derivato |
| `ValidatePassengerEmailDifferentFromPilot` | ⚠️ codifica l'assunto **opposto** a quello stabilito: vieta al passeggero l'email del pilota. Se qualcuno lo collegasse, vieterebbe le coppie che condividono la casella — cioè il caso reale |
| `ValidatePassengerEmailUnique` | stessa famiglia |

### Domande ancora aperte


- **Le 3 email duplicate su PROD**: come si sanano? Sono persone reali, va guardato caso per caso
  (stessa persona inserita due volte? oppure due persone che condividono una casella?). Query pronta
  in fondo a questo documento.
- **I 297 senza email**: bonifica pianificata o si accetta che quelle schede restino congelate?
- Il gruppo 2 della Parte C (17 righe fra telefoni, codici fiscali e indirizzi) va guardato prima di
  vincolare.

---

## Query per la bonifica (da eseguire su PROD, in sola lettura)

Le tre email duplicate dentro la stessa azienda — contiene dati personali, quindi va lanciata da te:

```sql
SELECT c.azienda_fk, c.cliente_id, c.cliente_cognome, c.cliente_nome, c.cliente_email
FROM ana_clienti c
JOIN (SELECT azienda_fk, lower(btrim(cliente_email)) AS e
      FROM ana_clienti
      WHERE cliente_email IS NOT NULL AND btrim(cliente_email) <> ''
      GROUP BY 1,2 HAVING count(*) > 1) d
  ON d.azienda_fk = c.azienda_fk AND d.e = lower(btrim(c.cliente_email))
ORDER BY c.azienda_fk, lower(btrim(c.cliente_email)), c.cliente_id;
```
