# Importazione Dati da Excel

Documento che descrive l'ordine corretto di importazione dei file Excel nel database `gestione_viaggi`, necessario per evitare violazioni di chiavi esterne e dati orfani.

---

## Ordine di Importazione

| # | File Excel | Tabella Target | Dipendenze |
|---|-----------|---------------|-----------|
| 1 | `ana_mezzi.xlsx` | `ana_mezzi` | Nessuna |
| 2 | `ana_mezzi_modelli.xlsx` | `ana_mezzi_modelli` | `ana_mezzi` |
| 3 | `ana_viaggi.xlsx` | `ana_viaggi` | Solo lookup opzionali |
| 4 | `ana_date_viaggi.xlsx` | `ana_date_viaggi` | `ana_viaggi` |
| 5 | `ana_clienti.xlsx` | `ana_clienti` | Solo lookup opzionali |
| 6 | `mov_clienti_viaggi.xlsx` | `mov_clienti_viaggi` | `ana_viaggi`, `ana_date_viaggi`, `ana_clienti`, `ana_mezzi`, `ana_mezzi_modelli` |
| 7 | `mov_clienti_alloggi.xlsx` | `mov_clienti_alloggi` | `ana_viaggi`, `ana_date_viaggi`, `ana_clienti`, `ana_tipo_alloggio` |

---

## Motivazioni

### 1. `ana_mezzi` — Prima di tutto

`ana_mezzi` è una tabella base senza dipendenze da altre anagrafiche importate. Deve essere caricata per prima perché `ana_mezzi_modelli` la referenzia tramite la FK `mezzo_modello_mezzo_fk`.

### 2. `ana_mezzi_modelli` — Subito dopo i mezzi

I modelli di mezzo appartengono a un mezzo (`mezzo_modello_mezzo_fk → ana_mezzi`). Il record del mezzo padre deve già esistere al momento dell'inserimento del modello. L'indice univoco è su `(mezzo_modello_descrizione, mezzo_modello_mezzo_fk)`.

### 3. `ana_viaggi` — Base per tutti i movimenti

I viaggi non dipendono da altre anagrafiche importate: le FK verso `ana_tipo_avvicinamento`, `ana_tipo_viaggio`, `ana_tipo_trattamento`, `nazioni`, `ana_tipo_pernottamento` sono tutte opzionali e puntano a tabelle di lookup già presenti nel DB prima dell'importazione. Deve però precedere date e movimenti che la referenziano.

### 4. `ana_date_viaggi` — Dipende dai viaggi

Ogni data di viaggio appartiene a un viaggio (`viaggio_id_fk → ana_viaggi`). Senza i viaggi già caricati, nessuna data potrebbe essere inserita. I movimenti (passi 6 e 7) referenziano sia il viaggio che la data specifica, quindi `ana_date_viaggi` deve precedere entrambi.

### 5. `ana_clienti` — Indipendente dai viaggi, necessaria per i movimenti

I clienti non dipendono da viaggi né da date, quindi possono essere caricati in parallelo con i passi 3 e 4 (in pratica dopo il passo 3, per semplicità). Le FK verso `comuni` e `azienda` sono opzionali o puntano a tabelle già esistenti. I clienti devono però esistere prima dei movimenti (passi 6 e 7) che li referenziano.

### 6. `mov_clienti_viaggi` — Solo dopo tutti gli anagrafici

Questo movimento è il più vincolato: referenzia `ana_viaggi`, `ana_date_viaggi`, `ana_clienti`, `ana_mezzi` e `ana_mezzi_modelli`. La chiave primaria è composita su `(viaggio_id_fk, data_viaggio_id_fk, cliente_id_fk)`. Tutti i record padre devono esistere prima di questo passo.

### 7. `mov_clienti_alloggi` — Ultimo

Gli alloggi referenziano `ana_viaggi`, `ana_date_viaggi`, fino a 6 clienti (`cliente_id[1-6]_fk`) e la tabella di lookup `ana_tipo_alloggio` (già presente nel DB). Viene caricato per ultimo perché dipende sia dai viaggi/date che dai clienti.

---

## Note Operative

- I passi **3** (`ana_viaggi`) e **5** (`ana_clienti`) sono reciprocamente indipendenti: si potrebbero invertire senza conseguenze.
- La tabella `ana_tipo_alloggio` è un lookup preesistente nel DB e **non** va importata da Excel.
- Tutti i servizi di importazione si trovano in `Migrazione_Dati_Oracle/` e usano `ON CONFLICT` (UPSERT): una re-importazione è sicura e idempotente.
- Il servizio `OracleViaggiImportService` disabilita i trigger durante l'import per prestazioni; lo stesso vale per `OracleMovClientiViaggiImportService`.
