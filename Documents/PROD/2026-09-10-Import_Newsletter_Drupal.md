# Import della newsletter dal vecchio sito — eseguito il 2026-09-10

⭐️ **Fatto su produzione.** Da 0 a **2.484 iscritti** in una transazione sola.

---

## Da dove vengono

Dal CMS **Drupal** del vecchio sito SFT, modulo **Simplenews**, che aveva già una funzione
«Esporta» in `/admin/people/simplenews/export`. ⓘ Non è servito né il fornitore uscente né
l'accesso al database: Adriano ha aperto il pannello, il resto è stato guidato da lì.

⚠️ **Quattro liste, non una** — `Sardegna Fuori Traccia newsletter`, `Newsletter Test SFT`,
`SFT Moto`, `Nuovi Clienti 12-2024` — esportate tutte e unite, per decisione di Adriano.

## I numeri, misurati

| | |
|---|---|
| Iscritti attivi estratti | 2.523 |
| ⚠️ Iscritti a una lista e disiscritti da un'altra | 39 → **messi fra i soppressi** |
| **Iscritti importati** | **2.484** |
| **Soppressioni** | **643** |
| Collegati a una scheda cliente | **78** |
| Scartati perché soppressi · malformati | 0 · 0 |
| Non confermati (double opt-in mai chiuso) | ✅ zero |

### Verifiche dopo il COMMIT

| | |
|---|---|
| Righe iscritti · soppressi | 2.484 · 643 ✅ |
| ⛔️ Soppressi finiti fra gli attivi | **0** |
| Token di disiscrizione tutti diversi | 2.484 su 2.484 ✅ |
| Contattabili da una newsletter oggi | 2.484 |

## Il confronto che dà la misura del salto

**In anagrafica SFT ci sono 227 clienti. Qui ne sono entrati 2.484**: la lista del vecchio sito è
**undici volte** l'anagrafica del gestionale, e fino a ieri era interamente fuori.

⚠️ **Il rovescio, che si vede solo incrociando i due elenchi: 131 clienti SFT con email NON sono
nella newsletter.** Non si erano mai iscritti al sito, e l'import non li tocca. Restano loro il
gruppo a cui va posta la domanda del consenso — con una mail sola, scritta con cura.

## Le decisioni prese, e perché

⛔️ **I 39 contesi fra i soppressi.** Disiscriversi è un atto esplicito; l'iscrizione all'altra
lista può essere vecchia. Costa l'1,5% dei contatti e toglie il rischio di scrivere a chi ha
detto di no.

⭐️ **Casella condivisa → la mail va a chi guida.** «Al passeggero non interessa» (Adriano). Il
pilota si riconosce dal flag `tipo_partecipante_pilota` sulle iscrizioni passate. ⚠️ Su
`lulu.sciascia@gmail.com` il collegamento è andato al **marito** COLOMBO GIANCARLO benché
l'indirizzo porti il nome di lei: è voluto, ma sorprende chi non lo sa.

⛔️ **I 259 clienti dell'azienda 6 NON sono stati collegati.** Verificato invece che supposto:
**nessuno di loro ha mai viaggiato con SFT** — conteggio zero su tutte le iscrizioni. Sono i
clienti storici di Offroad Adventures, finiti nella lista perché il sito era lo stesso. Entrano
come iscritti senza `cliente_fk`.

## Cosa è cambiato nello schema

`consenso_fonte` e `motivo` da **`VARCHAR(20)` a `VARCHAR(120)`** (script `637`). Venti caratteri
non bastavano a scrivere da dove viene il consenso — la frase usata ne occupa 46 — e comprimerla
in una sigla l'avrebbe resa illeggibile fra due anni, cioè inutile proprio quando serve.

ℹ️ **Nessuna nuova build dell'app**: `ConsensoFonte` è una `string?` senza limiti e il cast è
`::varchar` generico. Il gestionale legge le righe nuove così com'è.

## Dove sono i file

⛔️ **Fuori dal repository**, perché contengono dati personali di migliaia di persone:
`~/Documents/Backup_GoLive/newsletter_drupal/` — gli estratti grezzi, i due CSV e
`IMPORT_ESEGUI.sql`, che è rimasto con `ROLLBACK` in coda: rilanciarlo per sbaglio non fa danni.

⚠️ **Lo script è rigiocabile**: una seconda esecuzione non raddoppia nulla.
