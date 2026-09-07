# PROD — TACCA ALESSANDRO: il doppione risolto **spostando** il dato, non cancellandolo

**Eseguita il 2026-09-07**, su autorizzazione di Adriano — che ha approvato l'operazione
corretta, non quella che avevo proposto per prima.

## ⚠️ Avevo descritto male il caso

Lo avevo annunciato come «il caso facile, come MAIORCA: la 4377 non ha iscrizioni». Era vero
ma **insufficiente**. Il confronto campo per campo diceva un'altra cosa:

| Campo | **4377** (che avrei cancellato) | **4381** (che ha viaggiato) |
|---|---|---|
| **Codice fiscale** | **TCCLSN73D14L013K** | ⛔️ **assente** |
| Documento | PATENTE U1902N621N (Motorizzazione Torino, scad. 2031) | Carta d'identità CA84869QE (scad. 2033) |
| Email | promidea**.sa**@gmail.com | promidea**.ta**@gmail.com |
| Creata il | 2026-06-29 | 2026-07-01 |
| Iscrizioni | 0 | **1** |

Cancellando come avevo proposto si sarebbe **perso l'unico codice fiscale**, e la riga
superstite — quella che ha viaggiato — sarebbe rimasta senza. ⚠️ Con la regola scritta lo
stesso giorno (script `634`) **non avrebbe più potuto iscriversi come pilota**.

Nella MAIORCA la riga in più non aveva nulla di suo. Qui aveva il dato più importante.
Il metodo che ha salvato la situazione è lo stesso: **confrontare campo per campo prima di
cancellare**, invece di fidarsi di «tanto non ha iscrizioni».

## ⚠️ E l'ordine dei due passi non era quello previsto

Il primo tentativo — copiare il codice fiscale e poi cancellare — è stato **rifiutato dal
database**:

```
duplicate key value violates unique constraint "ana_clienti_idx06_scoped"
Key (azienda_fk, upper(cognome), upper(nome), data_nascita, upper(codice_fiscale)) already exists
```

Copiando il codice fiscale sulla 4381 le due righe sarebbero diventate identiche. I passi sono
stati quindi invertiti: **prima la cancellazione, poi la copia** — con il codice fiscale già
messo al sicuro qui sotto.

## La scoperta che vale piu' dell'operazione

**Un vincolo di unicità sull'identità ESISTE GIA'**, e non lo sapevamo:

```sql
CREATE UNIQUE INDEX ana_clienti_idx06_scoped ON public.ana_clienti
  USING btree (azienda_fk, upper(cliente_cognome), upper(cliente_nome),
               cliente_data_nascita, upper(cliente_codicefiscale));
```

⚠️ **Include il codice fiscale, ed è esattamente per questo che i doppioni passano**: chi non
ha il codice fiscale produce una chiave diversa da chi ce l'ha, e le due righe convivono. È il
caso di TACCA (uno col codice, uno senza) e sarebbe stato quello di MAIORCA.

Non manca un vincolo: ce n'è uno **fatto in modo che non impedisce il caso che conta**. Va
tenuto presente nell'analisi sull'unicità dell'anagrafica.

## La riga cancellata, per intero

```json
{"created":"2026-06-29T07:57:40.538939+00:00","updated":"2026-08-20T08:51:51.29246+00:00",
 "azienda_fk":2,"cliente_id":4377,"created_by":"WIZARD","updated_by":"",
 "cliente_cognome":"TACCA","cliente_nome":"ALESSANDRO","cliente_sesso":"M","cliente_titolo":"SIG",
 "cliente_email":"promidea.sa@gmail.com","cliente_telefono":"3477690843","cliente_preftelint":"+39",
 "cliente_data_nascita":"1973-04-14","cliente_codicefiscale":"TCCLSN73D14L013K",
 "cliente_comune_nascita_fk":72915,"cliente_comune_residenza_fk":66211,
 "cliente_indirizzo_residenza":"VIA DEI TESTA 19","cliente_documento_numero":"U1902N621N",
 "cliente_tipodoc_identita":"PAT","cliente_documento_rilasciato_da":"MOTORIZZAZIONE DI TORINO",
 "cliente_documento_rilasciato_data":"2026-06-04","cliente_documento_rilasciato_scadenza":"2031-06-03",
 "cliente_intolleranza":"","cliente_iban":null,"cliente_note":null,"cliente_foto":null}
```

⚠️ **Non trasferita: la patente** (U1902N621N, scad. 2031). La 4381 conserva la carta d'identità,
che scade più tardi (2033). Se un domani servisse la patente, il numero è qui.

## Verifiche

**Prima:** tutte e otto le colonne che riferiscono `ana_clienti` a **0** per la 4377; la 4381
col codice fiscale davvero vuoto; il codice fiscale non appartenente a nessun altro cliente.

**Dopo:**

| Controllo | Esito |
|---|---|
| TACCA in anagrafica | **1** (era 2) |
| La 4377 esiste ancora? | **no** |
| La 4381: codice fiscale | **TCCLSN73D14L013K** |
| La 4381: iscrizioni | **1**, intatta |
| Clienti azienda 2 | 205 → **204** |
| Gruppi in violazione (cognome+nome+data nascita) | **0** — non ce ne sono più |

Con la MAIORCA del mattino, PROD è ora **pulita da doppioni anagrafici**.
