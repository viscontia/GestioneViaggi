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
| 1 | Email obbligatoria? | **Sì, sempre — anche in modifica.** Chi riapre un'anagrafica senza email non salva finché non la inserisce |
| 2 | Email univoca? | **`UNIQUE (azienda_fk, email)`**. Fra aziende diverse la stessa email resta lecita: i silos sono indipendenti |
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
