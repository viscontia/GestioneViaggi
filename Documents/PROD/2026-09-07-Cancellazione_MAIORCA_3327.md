# PROD — cancellata `ana_clienti` 3327 (MAIORCA MARIA doppia)

**Eseguita il 2026-09-07**, su autorizzazione esplicita di Adriano: «possiamo cancellare il
guscio vuoto 3327 sei autorizzato, tanto non ha mai viaggiato».

## Perché

MAIORCA MARIA esisteva **due volte** in azienda 2, stessa data di nascita (1961-08-15).
È uno dei due gruppi di PROD che violano la regola d'identità del progetto
(`fn_ana_clienti_verifica_duplicato`: cognome + nome + data di nascita).

⚠️ Non era un «guscio vuoto», come detto in un primo momento: aveva documento, indirizzo e
comune di nascita. Ma il confronto campo per campo mostra che **non aveva nulla che alla 3324
mancasse** — solo versioni peggiori:

| Campo | 3324 (tenuta) | 3327 (cancellata) |
|---|---|---|
| Codice fiscale | MRCMRA61M55I754V | assente |
| Email | mariamaio1@hotmail.it | assente |
| Telefono | +39 3498225108 | assente |
| Documento | AX**8396**386 | AX**9386**386 |
| Rilasciato da | COMUNE DI MASSA | COMUNE MASSA |
| Creata il | 2025-06-07 | 2025-06-08 |
| Iscrizioni / camere | 2 / 2 | 0 / 0 |

Data e comune di nascita, residenza, indirizzo, date del documento, titolo e sesso: identici.
Il numero del documento è **lo stesso con due cifre invertite** (8396 ↔ 9386): un reinserimento
a mano il giorno dopo, con un refuso. La 3324 è quella comunicata agli alberghi per la legge
alloggiati.

## Verifiche fatte PRIMA di cancellare

Tutte e **otto** le colonne che riferiscono `ana_clienti` (FK trovate in `pg_constraint`, tutte
`ON DELETE RESTRICT`) contavano **0** righe per la 3327:

`mov_clienti_viaggi.cliente_id_fk`, `mov_clienti_viaggi.cliente_pilota_id_fk`,
`mov_clienti_alloggi.cliente_id1_fk` … `cliente_id6_fk`.

⚠️ `cliente_pilota_id_fk` non era nelle due che avevo controllato all'inizio: le FK vanno
enumerate dal catalogo, non ricordate.

## La riga cancellata, per intero

```json
{"created":"2025-06-08T16:13:25+00:00","updated":"2026-04-07T14:40:32.958983+00:00",
 "azienda_fk":2,"cliente_id":3327,"created_by":"segreteria@sardegnafuoritraccia.it",
 "updated_by":"","cliente_nome":"MARIA","cliente_cognome":"MAIORCA","cliente_sesso":"F",
 "cliente_titolo":"SRA","cliente_email":null,"cliente_telefono":null,"cliente_preftelint":null,
 "cliente_codicefiscale":null,"cliente_data_nascita":"1961-08-15",
 "cliente_comune_nascita_fk":72707,"cliente_comune_residenza_fk":69720,
 "cliente_indirizzo_residenza":"LARGO QUERCIOLI 3","cliente_documento_numero":"AX9386386",
 "cliente_tipodoc_identita":"CID","cliente_documento_rilasciato_da":"COMUNE MASSA",
 "cliente_documento_rilasciato_data":"2017-01-26",
 "cliente_documento_rilasciato_scadenza":"2027-08-15",
 "cliente_iban":null,"cliente_note":null,"cliente_intolleranza":null,
 "cliente_carta_identita":null,"cliente_foto":null}
```

## Verifica DOPO la cancellazione

| Controllo | Esito |
|---|---|
| MAIORCA in anagrafica | **1** (era 2) |
| La 3327 esiste ancora? | **no** |
| La 3324: iscrizioni / camere | **2 / 2**, intatte |
| Clienti azienda 2 | 206 → **205** |

## Resta aperto

Il **secondo** gruppo in violazione su PROD non è stato toccato: va guardato con lo stesso
metodo, riga per riga, prima di decidere.

E la lezione generale: una UNIQUE sull'email **non avrebbe impedito questo doppione**, perché la
3327 non aveva email. Il vincolo che l'avrebbe fermato è quello sull'identità
(cognome + nome + data di nascita), che è la regola già scritta nel progetto.
