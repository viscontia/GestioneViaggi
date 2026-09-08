# PROD — COLOMBO ROBERTA: due schede fuse in una (2026-09-08)

**Autorizzato da Adriano il 2026-09-08:** «Colombo Roberta ha una scheda con CF e una senza. Va
mantenuta quella con CF e il viaggio dell'altra scheda spostato su quella con CF».

Terzo e ultimo doppione anagrafico di produzione, dopo MAIORCA (3327) e TACCA (4377). ⚠️ A
differenza degli altri due **non era una cancellazione**: entrambe le schede avevano iscrizioni.

## Le due schede

| | 3027 (eliminata) | 3889 (mantenuta) |
|---|---|---|
| Codice fiscale | *(nessuno)* | `CLMRRT64E65A794E` |
| Data di nascita | 1964-05-**20** | 1964-05-**25** |
| Email | *(nessuna)* | colombor0525@gmail.com |
| Telefono | *(nessuno)* | +39 3386190437 |
| Residenza | VIA VOLTURNO 1, comune 66434 | *identica* |
| Comune di nascita | 66434 | *identico* |
| Iscrizioni | 2 | 1 |
| Creata | 2024-10-18, segreteria | 2026-01-09, segreteria |

⚠️ **La data giusta è quella della 3889.** Nel codice fiscale `CLMRRT64E65A794E` il gruppo `E65`
codifica il **25 maggio** per una donna (giorno + 40): la 3027 aveva un refuso di cinque giorni.
È anche il motivo per cui l'indice di unicità dello script `636` **non** avrebbe fermato questo
caso — le due date differiscono davvero.

## ⚠️ Quello che si è scoperto solo guardando i movimenti

Le due schede **erano iscritte alla stessa partenza**: viaggio 861, partenza 1823 (10/04/2026),
entrambe come passeggero (ruolo 6) del pilota 3026. Quindi non c'era «il viaggio da spostare»,
ce n'erano due situazioni diverse:

- viaggio **541 / partenza 1503** (29/10/2024): solo della 3027 → **spostato** sulla 3889;
- viaggio **861 / partenza 1823** (10/04/2026): su **entrambe** → la riga della 3027 **eliminata**,
  perché la 3889 era già iscritta.

E la conseguenza peggiore, che nessuno aveva visto: sulla partenza 1823 il pilota **3026 risultava
in DUE camere matrimoniali** — una con 3027, una con 3889. Due matrimoniali per due persone.
⛔️ Se qualcuno avesse stampato la rooming list, l'albergo avrebbe ricevuto una camera in più.

Le due righe di iscrizione su 1823 erano **identiche in ogni campo** (stesso ruolo, stesso pilota,
nessun mezzo, nessuna nota): non si è perso nulla eliminando quella della 3027.

## Cosa è stato eseguito

Tutto in un unico blocco atomico, preceduto da una **prova a secco annullata in coda** per
verificare che nessuna guardia rifiutasse (nessuna lo ha fatto). Con `my.app_user` valorizzato,
così l'audit registra chi ha scritto.

1. `mov_clienti_viaggi`: iscrizione a 541/1503 spostata da 3027 a **3889**
2. `mov_clienti_alloggi` pk **3404** (camera di quella partenza): `cliente_id2_fk` 3027 → **3889**
3. `mov_clienti_alloggi` pk **4362** eliminata — la matrimoniale doppia su 1823
4. `mov_clienti_viaggi`: iscrizione doppia a 861/1823 della 3027 eliminata
5. `ana_clienti` **3027** eliminata

Ogni passo con `GET DIAGNOSTICS` e rifiuto se le righe toccate non erano esattamente una.

## Verifiche dopo l'operazione

| Controllo | Esito |
|---|---|
| Schede COLOMBO ROBERTA rimaste | **1** |
| Viaggi della 3889 | **2** (nessuno perso) |
| Camere della 3889 | **2** |
| Riferimenti residui alla 3027 | **0** |
| Camere di 3026 sulla partenza 1823 | **1** (era 2) |
| Clienti azienda 2 | 204 → **203** |
| Gruppi in violazione di identità, tutte le aziende | **0** |

✅ **PROD non ha più doppioni anagrafici riconoscibili** su cognome + nome + data di nascita.

## Cosa resta, e non è risolvibile qui

⚠️ Due clienti SFT **senza data di nascita** — GENDUSO FRANCESCA e FORNO RAFFAELLA — restano fuori
dalla portata sia del vincolo che del riconoscimento automatico. Adriano, 2026-09-08: «non ho
soluzioni, se non quella di scrivere o telefonare: lo farà Antonio».
