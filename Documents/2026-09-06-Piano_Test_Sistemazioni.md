# Piano di test — Generi di sistemazione e coerenza col viaggio

**Scritto il 2026-09-06**, dopo l'implementazione su MAUI. Copre il gestionale; la parte
sul sito arriverà quando il passo 5 sarà riscritto.

Riferimenti: `Estensione Progetto WEB/Documenti/2026-09-05-Analisi_Scelta_Camere_Step5.md`,
`SqlScripts/599`–`601`.

⚠️ **Segnala solo ciò che non funziona.** Dove serve un dato da cercare, chiedi.

---

## Prima di cominciare

Il database locale deve avere gli script fino al **601** applicati. Verifica:

```sql
SELECT count(*) FROM ana_alloggio_generi;                 -- atteso: 3
SELECT count(*) FROM ana_tipo_alloggio WHERE genere_fk IS NULL;  -- atteso: 0
SELECT count(*) FROM ana_tipo_pernottamento_generi;       -- atteso: 4
```

---

## A — La pagina dei Generi di Sistemazione

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| A1 | Menu → **Generi di Sistemazione** | La voce c'è, accanto a «Tipologie Alloggi». Si apre con tre righe: ALBERGO, TENDA, NESSUNA |
| A2 | **Nuovo** → descrizione «BUNGALOW», codice «BUNGALOW», ordine 3 | Si crea. ⚠️ Descrizione e codice diventano MAIUSCOLI da soli |
| A3 | Scrivi nel codice «CASA MOBILE» (con lo spazio) | Lo spazio diventa `_`: `CASA_MOBILE`. Il codice lo usa il programma, non può avere spazi |
| A4 | **Modifica** il bungalow appena creato | ⚠️ Il campo **codice è disabilitato**: è il nome con cui il programma riconosce il genere, e cambiarlo su una riga già usata romperebbe le regole in silenzio |
| A5 | Togli la spunta **Attivo** al bungalow e salva | Resta in elenco con la spunta vuota |
| A6 | Vai in **Tipologie Alloggi** → Nuovo → apri la tendina Genere | ⚠️ Il bungalow **non compare**: disattivato non si può più scegliere |
| A7 | Rimetti Attivo al bungalow, poi prova a **eliminarlo** | Si elimina: nessun tipo lo usa |
| A8 | Prova a eliminare **ALBERGO** | ⚠️ Rifiutato, e il messaggio dice **quanti** tipi lo usano («è il genere di 10 tipi di sistemazione») — non un generico «impossibile» |
| A9 | **Nuovo** lasciando la descrizione vuota | Il salvataggio non parte, il campo si segna in rosso |
| A10 | Cerca «tenda» nella barra di ricerca | Trova TENDA per codice o descrizione |

---

## B — Il genere sui tipi di sistemazione

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| B1 | Menu → **Tipologie Alloggi** | C'è la colonna **Genere**, popolata su tutte le 15 righe |
| B2 | Cerca «tenda» | Trova le 4 tende. ⚠️ Le trova **anche per genere**, non solo per descrizione |
| B3 | **Modifica** CAMERA MATRIMONIALE | Il campo Genere mostra «Camera in struttura ricettiva», con la spiegazione sotto |
| B4 | **Nuovo** → descrizione e occupanti, ma **non** scegliere il genere → Crea | ⚠️ Rifiutato: il genere è obbligatorio |
| B5 | Crea «CAMERA QUINTUPLA», 5 posti, genere ALBERGO | Si crea, e in elenco **compare subito il genere** (non una cella vuota) |
| B6 | Modifica quella riga: cambia solo la descrizione e salva | Il genere **resta** quello scelto, non si azzera |
| B7 | Elimina «CAMERA QUINTUPLA» | Si elimina |

---

## C — Le sistemazioni previste da un pernottamento

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| C1 | Menu → **Tipologie Pernottamento** | C'è la colonna **Sistemazioni previste**: ALBERGO per «ALBERGO», «Camera… · Tenda…» per il misto, «Tenda…» per SOLO CAMPI TENDATI, **«nessuna»** per NESSUNO |
| C2 | **Modifica** «ALBERGO» | ⚠️ La spunta «Con Albergo» **non c'è più**. Ci sono le spunte delle sistemazioni previste, con ALBERGO spuntato |
| C3 | Spunta anche TENDA e salva | In elenco la riga mostra entrambe |
| C4 | Guarda la colonna «Con Albergo» | ⚠️ È ancora `Y`, **senza che tu l'abbia toccata**: ora è una conseguenza dei generi, non una scelta |
| C5 | Modifica «SOLO CAMPI TENDATI»: **togli** TENDA, **metti** ALBERGO, salva | La colonna «Con Albergo» passa da vuota a spuntata **da sola** |
| C6 | Rimetti TENDA e togli ALBERGO | «Con Albergo» torna vuota |
| C7 | Modifica «NESSUNO»: prova a spuntare qualcosa e poi togli tutto | Salva con «nessuna»: un elenco vuoto è legittimo |
| C8 | In una qualunque scheda, cerca la voce «Nessuna sistemazione» fra le spunte | ⚠️ **Non c'è**, ed è giusto: vale sempre, su qualunque viaggio, e non si configura |

---

## D — Quel che si può assegnare dipende dal viaggio

⚠️ Serve un viaggio in albergo e uno in campo tendato. Chiedi se non li trovi.

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| D1 | Apri un viaggio **in ALBERGO** → tab Partecipanti → gestione alloggi → nuova camera | Nella tendina dei tipi ci sono **le camere e «nessuna camera»**, ⚠️ **nessuna tenda** |
| D2 | Apri un viaggio **SOLO CAMPI TENDATI** → stessa strada | Ci sono **le tende e «nessuna camera»**, ⚠️ **nessuna camera d'albergo** |
| D3 | Apri un viaggio con pernottamento **NESSUNO** | ⚠️ L'unica voce è **«nessuna camera»** |
| D4 | **Iscrizione veloce**: scegli un viaggio in albergo e una data, poi guarda la tendina della sistemazione | Solo camere |
| D5 | Sempre in iscrizione veloce, **cambia la data** scegliendo una partenza di un viaggio in tenda | ⚠️ La tendina si **ricarica** e mostra le tende |
| D6 | In iscrizione veloce: scegli una camera, poi **cambia data** verso un viaggio in tenda | ⚠️ La sistemazione scelta **si azzera**: su quella partenza non è più ammessa |

---

## E — La validazione al salvataggio

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| E1 | Su un viaggio in albergo, crea una **camera matrimoniale** con **due** occupanti | Si salva |
| E2 | Crea una **matrimoniale** con **un solo** occupante | ⚠️ Rifiutato: «ospita 2 persone, ne è stata indicata 1». Una doppia con uno solo si chiama «doppia uso singola» ed è un tipo suo |
| E3 | Crea una **camera singola** con 1 occupante | Si salva |
| E4 | Metti la **stessa persona** in due camere | ⚠️ Rifiutato: «una stessa persona risulta assegnata a più di una sistemazione» |
| E5 | Guarda il messaggio di errore | Una riga per rilievo, leggibile — non un errore tecnico del database |

---

## F — Il suggerimento del tipo

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| F1 | Componi una camera per **2 persone** su un viaggio in albergo | Propone un tipo da **2 posti esatti**, preferendo quello **senza supplemento** |
| F2 | Componi per **1 persona** | Propone un tipo da **1 posto** (singola, non una doppia) |
| F3 | Componi per **2 persone** su un viaggio **in tenda** | ⚠️ Propone una **tenda** da 2 posti. Prima cercava «MATRIMONIALE» nel nome e non avrebbe trovato niente |
| F4 | Su un viaggio in tenda, guarda quale tenda propone fra «di proprietà» e «noleggiata» | Quella **di proprietà**: non ha supplemento |

---

## G — Che le due strade dicano la stessa cosa

⚠️ È il gruppo che conta: le regole stanno a database e valgono per chiunque scriva.

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| G1 | Prova a scrivere **a mano nel database** una camera d'albergo su un viaggio in tenda | ⚠️ **Rifiutata dal database** (`SqlScripts/602`), con un messaggio che dice il tipo, il pernottamento del viaggio e quali generi sarebbero ammessi |
| G1b | Scrivi a mano una **tenda** sullo stesso viaggio | Passa |
| G1c | Scrivi a mano «nessuna camera» sullo stesso viaggio | Passa: vale sempre |
| G1d | Prendi una riga valida e **modificale il tipo** verso uno non ammesso | Rifiutata: il vincolo vale anche in modifica, non solo in inserimento |
| G1e | Scrivi a mano una **doppia con un occupante solo** | ⚠️ **Passa**, ed è voluto: quando l'albergo non ha singole è una situazione reale. La capienza resta un rilievo della validazione, che blocca l'interfaccia ma non la mano di chi sa cosa sta facendo |
| G2 | Sulla partenza PIRENEI, chiedi la validazione dell'assegnazione vuota | Elenca **tutti** i partecipanti senza sistemazione |

```sql
-- G2, da eseguire sul database locale
SELECT gravita, esito, messaggio
FROM fn_alloggi_assegnazione_valida(
       (SELECT d.data_viaggio_id FROM ana_date_viaggi d
        JOIN ana_viaggi v ON v.viaggio_id = d.viaggio_id_fk
        WHERE v.viaggio_descrizione_breve ILIKE '%PIRENEI%' LIMIT 1),
       '[]'::jsonb);
```

---

## Cosa questo piano NON copre

- **Il sito di iscrizione**: il passo 5 non è ancora stato riscritto. Finché non lo è, sui
  viaggi in tenda continua a saltarlo.
- **Le combinazioni** (`fn_alloggi_combinazioni`): la funzione c'è ed è verificata, ma
  nessuna interfaccia la usa ancora. Servirà al sito.
- **Il caso misto** — albergo e tende nello stesso viaggio, notte per notte: dichiarato
  fuori portata nell'analisi, il modello lega la sistemazione alla partenza.
- **I dati storici incoerenti**: le 17 assegnazioni già in produzione non vengono corrette
  da nulla. Il nuovo controllo impedisce che se ne creino altre.
