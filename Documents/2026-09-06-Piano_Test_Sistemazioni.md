# Piano di test — Generi di sistemazione e coerenza col viaggio

**Scritto il 2026-09-06**, dopo l'implementazione su MAUI. Copre il gestionale; la parte
sul sito arriverà quando il passo 5 sarà riscritto.

Riferimenti: `Estensione Progetto WEB/Documenti/2026-09-05-Analisi_Scelta_Camere_Step5.md`,
`SqlScripts/599`–`601`.

⚠️ **Segnala solo ciò che non funziona.** Dove serve un dato da cercare, chiedi.

### Stato

| Gruppo | Esito |
|---|---|
| **A** — La pagina dei Generi di Sistemazione | ✅ **superato** (2026-09-06) |
| **B** — Il genere sui tipi di sistemazione | ✅ **superato** (2026-09-06) |
| **C** — Le sistemazioni previste da un pernottamento | ✅ **superato** (2026-09-06), dopo gli script `607`→`609` e la correzione dei messaggi |
| **D** — Quel che si può assegnare dipende dal viaggio | ✅ **superato** (2026-09-06), dopo `610`, `611`, la tendina unica e la correzione del blocco |
| **E** — La validazione al salvataggio | ☐ da fare |
| **F** — Il suggerimento del tipo | ☐ da fare — ⚠️ **riscritto**: prima collaudava una funzione che non esisteva |
| **G** — Che le due strade dicano la stessa cosa | ☐ da fare |

I difetti trovati durante A–C e corretti: la domanda di conferma al posto del rifiuto
(`609`), «NESSUNO» modificabile (`609`), le descrizioni minuscole (`603`), le guardie
incomplete sui generi (`606`), e ⚠️ **il messaggio del database sostituito da una frase
generica** (`DatabaseExceptionHelper`) — che riguardava tutte le guardie, non solo C12.

---

## Prima di cominciare

Il database locale deve avere gli script fino al **611** applicati.

⚠️ **Dal 2026-09-06 la tendina delle sistemazioni è UN componente solo**
(`TipoAlloggioSelect`), usato da tutte e tre le schede. Prima erano tre copie: se una prova
di D o E fallisce in una scheda sola, è un difetto del componente o di come quella scheda lo
usa — non più «una delle tre copie è rimasta indietro». Verifica:

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
| B8 | Modifica CAMERA MATRIMONIALE e prova a portarne il genere a **Tenda** | ⚠️ **Rifiutato**: «con questo genere 219 assegnazioni già registrate diventerebbero incoerenti, su: …». Cambiare il genere di un tipo in uso invaliderebbe la storia in silenzio |
| B9 | Modifica CAMERA MATRIMONIALE cambiando **solo la descrizione** | Passa: il controllo guarda il genere, non ogni modifica |
| B10 | Cambia il genere di **TENDA 4 POSTI NOLEGGIATA** (mai usata) verso Albergo | ⚠️ **Passa**, ed è voluto: nessuna assegnazione ne resta invalidata, e vietarlo impedirebbe di correggere una classificazione sbagliata |

---

## C — Le sistemazioni previste da un pernottamento

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| C1 | Menu → **Tipologie Pernottamento** | C'è la colonna **Sistemazioni previste**: ALBERGO per «ALBERGO», «Camera… · Tenda…» per il misto, «Tenda…» per SOLO CAMPI TENDATI, **NESSUNA** per NESSUNO. Accanto a «NESSUNO» c'è un **lucchetto** |
| C2 | **Modifica** «ALBERGO» | ⚠️ La spunta «Con Albergo» **non c'è più**. Ci sono le spunte delle sistemazioni previste, con ALBERGO spuntato |
| C3 | Spunta anche TENDA e salva | In elenco la riga mostra entrambe |
| C4 | Guarda la colonna «Con Albergo» | ⚠️ È ancora `Y`, **senza che tu l'abbia toccata**: ora è una conseguenza dei generi, non una scelta |
| C5 | Modifica «SOLO CAMPI TENDATI»: **togli** TENDA, **metti** ALBERGO, salva | La colonna «Con Albergo» passa da vuota a spuntata **da sola** |
| C6 | Rimetti TENDA e togli ALBERGO | «Con Albergo» torna vuota |
| C7 | Prova a **modificare** «NESSUNO» | ⚠️ **Non si apre nemmeno**: «è una configurazione di sistema… non si può modificare né cancellare». Non è più possibile spuntargli dei generi — ed era proprio quel gesto a creare la trappola da cui non si tornava indietro |
| C7b | Prova a **eliminare** «NESSUNO» | ⚠️ Stesso avviso, stesso rifiuto |
| C8 | In una qualunque scheda, cerca la voce «Nessuna sistemazione» fra le spunte | ⚠️ **Non c'è**, ed è giusto: vale sempre, su qualunque viaggio, e non si configura |
| C9 | Modifica «ALBERGO» e prova a **togliere** la spunta ALBERGO | ⛔️ **RIFIUTATO**, senza domande: «Non si può: 414 assegnazioni oggi valide non lo sarebbero più, su: …. Vanno cambiate prima quelle assegnazioni». Non c'è nessun «Procedi»: un clic non deve poter rompere 414 righe |
| C9b | Riapri «ALBERGO» e **risalva senza cambiare niente** | Salva, **senza avvisi**: se non si rompe nulla non si dice nulla. ⚠️ È la prova che il controllo non è rumoroso — un avviso che compare quando non serve insegna a ignorarlo |
| C9c | Modifica «ALBERGO CON QUALCHE CAMPO TENDATO» togliendo TENDA (che nessuna assegnazione usa) | Salva, **senza avvisi**: togliere un genere che nessuno sta usando non rompe niente |
| C10 | Modifica «ALBERGO» **aggiungendo** TENDA senza togliere nulla | Passa: aggiungere non scopre niente |
| C11 | Prova a **eliminare** il pernottamento «ALBERGO» | ⚠️ Rifiutato, con il conto di ciò che è collegato: viaggi, date e prenotazioni |
| C12 | Apri un **viaggio in albergo** con camere assegnate e cambiane il pernottamento a «SOLO CAMPI TENDATI» | ⚠️ **Rifiutato**, con il messaggio **per esteso**: «Con il pernottamento «SOLO CAMPI TENDATI» 37 sistemazioni già assegnate su questo viaggio non sarebbero più ammesse. Vanno cambiate prima». ⚠️ Il numero dev'esserci: un rifiuto generico («un valore non rispetta le regole di validità») non dice cosa fare |

---

## D — Quel che si può assegnare dipende dal viaggio

⚠️ Serve un viaggio in albergo e uno in campo tendato. Chiedi se non li trovi.

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| D1 | Apri un viaggio **in ALBERGO** → tab Partecipanti → gestione alloggi → nuova camera | Nella tendina dei tipi ci sono **le camere e «nessuna camera»**, ⚠️ **nessuna tenda** |
| D2 | Apri un viaggio **SOLO CAMPI TENDATI** (PIRENEI IN FUORISTRADA) → stessa strada | Ci sono **le tende e «nessuna camera»**, ⚠️ **nessuna camera d'albergo**. ⚠️ Provalo dalla scheda **Partecipanti** assegnando un passeggero: è la strada che sbagliava (`SqlScripts/610`), e le altre già funzionavano |
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

> **Scritto il 2026-09-06**, dopo aver accertato che non esisteva: c'erano due copie del
> calcolo, già divergenti fra loro, e ⚠️ **nessuna delle due veniva mai chiamata**. Ora la
> regola è una sola (`TipoAlloggioService.Suggerisci`) e la applica `TipoAlloggioSelect`.
>
> **La regola:** capienza **uguale** al gruppo (non «almeno»: una doppia con uno solo è una
> «doppia uso singola», tipo suo con supplemento suo); a parità, quello **senza
> supplemento**; a parità anche di quello, il più vecchio.
>
> È una **proposta**, non una decisione: si può sempre cambiare, e appena scegli a mano il
> programma non ci torna più sopra.

| # | Cosa fare | Cosa deve succedere |
|---|---|---|
| F1 | Viaggio in **albergo**, componi una camera e aggiungi **1** occupante | Propone **CAMERA SINGOLA** |
| F2 | Aggiungi il **secondo** occupante | ⚠️ La proposta si **aggiorna** a CAMERA MATRIMONIALE: finché non hai scelto tu, segue il gruppo |
| F3 | Aggiungi il **terzo**, poi il **quarto** | CAMERA TRIPLA (TRE LETTI SINGOLI), poi CAMERA QUADRUPLA (…4P) |
| F4 | Con 2 occupanti, **cambia a mano** in CAMERA DOPPIA LETTI SINGOLI, poi aggiungi il terzo | ⚠️ **Resta quella che hai scelto tu**: la proposta non sovrascrive una scelta. La capienza sbagliata la segnala la validazione (E2) |
| F5 | Viaggio **in tenda**, gruppo di **2** | Propone **TENDA 2 POSTI DI PROPRIETA'** — non quella noleggiata, che ha supplemento |
| F6 | Stesso viaggio, gruppo di **3** | ⚠️ **Nessuna proposta**: ci sono tende da 1, 2 e 4 posti, non da 3. Meglio non proporre che proporre una capienza che poi il salvataggio rifiuta |
| F6b | Viaggio **in tenda**, gruppo di **1** | Propone **TENDA 1 POSTO DI PROPRIETA'** — non la noleggiata, che ha supplemento. ⚠️ Prima non c'era nessuna tenda da uno: a chi partiva da solo il programma non proponeva niente e non aveva niente da scegliere |
| F7 | **Iscrizione Veloce**: scegli un viaggio in albergo, una data, e chiedi la sistemazione | Propone CAMERA SINGOLA: lì si iscrive una persona per volta |
| F8 | Scheda **Partecipanti**: apri un **pilota con 2 passeggeri** e chiedi la sistemazione | Propone un tipo da **3 posti**: il pilota porta con sé i suoi passeggeri |
| F9 | Stessa scheda, apri un **passeggero** | Propone un tipo da **1 posto**: un passeggero sta per conto suo |

| F13 | Iscrivi un **pilota** con una CAMERA SINGOLA, poi aggiungi una **passeggera** abbinata a lui e chiedi «aggiungi a camera esistente» | ⚠️ Non c'è nessuna camera libera, ed è giusto. Ma il messaggio ora **nomina la situazione**: «X ha una CAMERA SINGOLA, già al completo. Se devono stare insieme, cambia quella camera con la matita — creandone una seconda si pagano due sistemazioni» |
| F14 | Dalla matita sulla camera del pilota, cambiala in **MATRIMONIALE** e aggiungi la passeggera | Si salva: due occupanti su due posti |
| F15 | In alternativa, crea per lei una **seconda singola** e salva | ⚠️ **Passa, ed è voluto**: due singole con un occupante ciascuna sono valide quanto una matrimoniale, e a volte è proprio quello che si vuole. Il programma non lo vieta — avvisa, e la scelta resta di chi lavora |
| F10 | Viaggio in albergo, gruppo di **1**: apri la tendina e guarda l'elenco | ⚠️ **CAMERA SINGOLA DISABILI c'è**, si può scegliere — ma **non è quella proposta**: esce CAMERA SINGOLA |
| F11 | Menu → **Tipologie Alloggi**: guarda la colonna «Mai proposta» | Il segno c'è sulle due righe DISABILI e su nessun'altra |
| F12 | Modifica una sistemazione qualunque e spunta «Non proporre mai d'ufficio», poi rifai F1 | Sparisce dalle proposte ma **resta in elenco**. ⚠️ È una scelta dell'operatore, non una cosa che posso cambiare solo io con una UPDATE a mano |

⚠️ **Perché serviva una colonna** (`SqlScripts/611`). Per una persona sola in albergo
esistono tre tipi da 1 posto, tutti con supplemento: CAMERA SINGOLA, CAMERA DOPPIA USO
SINGOLA e **CAMERA SINGOLA DISABILI**. Fino al 6 settembre usciva CAMERA SINGOLA solo perché
era la più vecchia delle tre — **per fortuna, non per regola**: bastava creare una riga
nuova per far proporre a caso una camera attrezzata a chi non l'aveva chiesta. Ora lo dice il
dato (`tipo_alloggio_mai_proposta`). ⛔️ Riconoscerla dal nome non si fa: è il difetto tolto
dai generi.

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
