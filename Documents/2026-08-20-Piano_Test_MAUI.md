# Piano di test — Gestionale MAUI (`ana_clienti` centralizzato)

**Aggiornato:** 2026-08-21
**Ambiente:** DB locale Docker (`gestione_viaggi`), script `538`–`562` applicati
**Chi lo esegue:** Adriano — richiede l'app in esecuzione, non è automatizzabile da CLI

---

## Perché questo piano esiste separato

Copre **solo il gestionale**. Il sito di iscrizione ha il suo piano
(`2026-08-20-Piano_Test_Flask.md`), e la prova incrociata fra i due è in fondo a quello.

Non è qui ciò che è già stato verificato a livello di database: il motore del codice fiscale, gli
esiti di `fn_ana_clienti_valida`, l'avviso nome/sesso come funzione. Quelli sono passati. Qui resta
ciò che si vede **solo aprendo l'applicazione** — e soprattutto ciò che, se si fosse rotto, non
darebbe alcun errore.

---

## Prima di iniziare

| # | Cosa | Atteso |
|---|---|---|
| P1 | `docker ps` | Il container `postgres_db` è in piedi |
| P2 | `./run_maui.sh` | Build verde, e nel log **`Master key segreti: caricata`** |
| P3 | Accedi come utente dell'**azienda 2** | La pagina Clienti si apre |

**Dati di riferimento**, servono per quasi tutte le prove sotto:

| Cosa | Valore |
|---|---|
| Titolo `SIG.` | **6** |
| Titolo `SIG.RA` | **8** |
| Comune ORISTANO | **70582** |
| Tipo partecipante *pilota mezzo proprio* | **4** |
| Tipo partecipante *passeggero* | **6** |
| Codice fiscale di prova coerente | `TLONTN77M24G113N` → TOLU ANTONIO, M, 24/08/1977, ORISTANO |

> Usa cognomi che iniziano per **`ZZ`** per tutti i clienti di prova: la query di pulizia in fondo
> li trova così.

---

## A — Le letture, ora nel database

Con gli script `558`–`560` **`ClienteRepository.cs` non contiene più una sola SELECT**. Le funzioni
esistevano dal marzo 2026 e nessuno le chiamava: sono state completate e collegate.

È il gruppo col rischio più alto di tutto il lavoro, per un motivo preciso: **un campo che sparisce
da una form non dà errore**. Non c'è, e se ne accorge solo chi guarda. Il modo giusto di fare
questi test è **confrontare**, non ispezionare: apri una scheda che conosci e verifica che ci sia
tutto quello che c'era ieri.

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| A1 | Apri l'**elenco clienti** | Ci sono tutti. Comune di nascita e di residenza **con la provincia**, non vuoti |
| A2 | Nell'elenco guarda le colonne **viaggi fatti / da fare** | Valorizzate come prima |
| A3 | Dalla **dashboard** clicca il riquadro dei clienti di un anno | Si apre l'elenco filtrato, con il banner «Filtro Attivo: Anno Creazione», e «Mostra Tutto» lo azzera. Nella pagina Clienti non c'è (e non c'è mai stata) una tendina degli anni: il filtro arriva solo di lì, ed è sull'anno di **creazione della scheda** |
| A4 | **Cerca** per cognome, poi per email, poi per codice fiscale | Trova in tutti e tre i casi; i comuni sono valorizzati anche nei risultati |
| A5 | Apri un cliente **con foto e documento** | Si vedono entrambi. È il caso più a rischio: viaggiano in base64 e **solo** nel dettaglio |
| A6 | Apri un cliente e controlla **titolo, lingua e consenso** | Il titolo è quello giusto nella tendina, non vuoto |
| A7 | Apri un cliente, **salva senza modificare**, riaprilo | Titolo, lingua e consenso **invariati**. Se il titolo tornasse vuoto o il consenso si spegnesse, la lettura non porta la chiave |
| A8 | Da un cliente apri le **statistiche viaggi** | Si apre. Prima della correzione andava in eccezione: leggeva colonne che la vecchia funzione non restituiva |
| A9 | Cancella un cliente con iscrizioni, poi uno con alloggio assegnato | Rifiutato in entrambi i casi |
| A10 | Cancella un cliente `ZZ` **senza** iscrizioni né alloggi | Si cancella |
| A11 | Accedi come utente di **un'altra azienda** e cerca un cliente della prima | Non lo trova |

> **Da guardare una volta sola.** La ricerca per email ora ordina per `cliente_id` e restituisce la
> scheda più vecchia. Prima non ordinava affatto: con le tre coppie che condividono la casella,
> quale delle due tornasse era arbitrario e poteva cambiare fra due esecuzioni identiche.

---

## B — Formati e vincoli

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| B1 | Clienti → Nuovo | Compila un cliente valido e salva | Si salva. Il **sesso non è digitabile**: lo mostra derivato dal titolo |
| B2 | Nuovo cliente | Email `pippo@` (senza dominio) | Errore sul campo **mentre scrivi** |
| B3 | Nuovo cliente | Cognome `A` (un carattere) | Rifiutato: «Il cognome deve avere almeno 2 caratteri» |
| B4 | Nuovo cliente | IBAN `XX123` | Rifiutato con la ragione (15-34 caratteri, due lettere iniziali) e **campo in rosso**. È il caso di riferimento del meccanismo: nessun controllo locale lo intercetta, quindi prova davvero il giro completo fino al database |
| B5 | Nuovo cliente | Telefono valorizzato, **prefisso vuoto** | **Rifiutato sul campo.** Il database lo classifica `CONFERMA`, il gestionale lo blocca prima: divergenza nota e accettata (2026-08-31), perché un numero senza prefisso è inutilizzabile. Il sito resta più permissivo |
| B6 | Nuovo cliente | Documento con rilascio **domani** | Rifiutato: la data di rilascio è nel futuro |
| B7 | Nuovo cliente | Documento con scadenza **passata** | **Avviso**, non blocco |
| B8 | Nuovo cliente **estero** (comune di residenza fuori Italia, così il CF non è richiesto) | Data di nascita **domani** | Rifiutato, con la **data di nascita in rosso**. Su un cliente italiano il caso non è isolabile: il codice fiscale codifica la data di nascita, quindi non può esistere un CF valido per una nascita futura |
| B9 | Nuovo cliente | Lascia l'**email vuota** | Passa. L'obbligo dipende dal ruolo, e si applica all'iscrizione (gruppo G) |

| B12 | Nuovo cliente | Metti una **data di rilascio precedente alla data di nascita**, poi correggi la data di nascita | L'errore sulla data di rilascio **sparisce** senza doverla ritoccare: le tre date si giudicano a vicenda e si ricalcolano insieme |
| B13 | Nuovo cliente | Scrivi un IBAN sbagliato ed **esci dal campo** senza premere Salva | L'errore compare subito. Le regole del database non aspettano più il salvataggio |

> Gli errori che arrivano dal database (cognome corto, IBAN, date nel futuro, codice fiscale)
> **illuminano il campo**, non solo la barra dei messaggi: se vedi il messaggio ma nessuna
> cornice rossa, la mappa `CampoPerEsito` in `ClienteDialog` non conosce quell'esito.
>
> I messaggi devono essere in italiano leggibile. Se ne vedi uno che contiene `CONTEXT:` o il nome
> di una funzione PL/pgSQL, è un difetto: significa che l'errore grezzo del database è arrivato a
> video con dentro la riga, dati personali compresi.

---

## C — Il codice fiscale

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| C1 | Nuovo cliente | Cognome `ZZTOLU`, nome `ANTONIO`, titolo `SIG.`, nato il **24/08/1977** a **ORISTANO**, CF `TLONTN77M24G113N` | Nessuna segnalazione: **corrisponde** |
| C2 | Stesso caso | Cambia la data di nascita in **24/07/1977** | ⚠️ Chiede conferma: il codice non corrisponde, e dice quale risulterebbe |
| C3 | Nuovo cliente | Metti `ANTONIO` nel **cognome** e `ZZTOLU` nel **nome**, stesso CF | ⚠️ Chiede conferma: «Nome e cognome sembrano invertiti…», con la proposta di scambio |
| C4 | Stesso caso | **Conferma** | Si salva. È il caso raro del codice emesso invertito, che deve restare registrabile |
| C5 | Nuovo cliente | CF `TLONTN77M24G113A` (ultimo carattere alterato) | Rifiutato: non supera il controllo dell'ultimo carattere |
| C6 | Nuovo cliente | CF `ABC` | Rifiutato: forma non valida |
| C7 | Cliente **nato all'estero** (comune senza codice catastale) | Inserisci un CF formalmente valido | **Passa**: il confronto con l'anagrafica non è possibile, e non è colpa di chi compila |

---

## D — Duplicati e omonimi

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| D1 | Nuovo cliente | Usa il CF di un cliente esistente su un'altra anagrafica | Rifiutato, e dice **chi** ce l'ha già |
| D2 | Nuovo cliente | Stessi cognome, nome, **data e comune di nascita** di un esistente, **senza** CF | Rifiutato: esiste già un cliente con questi dati |
| D3 | Nuovo cliente | Solo **cognome e nome** uguali a un esistente, data diversa | **Avviso**, non blocco: gli omonimi esistono davvero |
| D4 | ⭐ **Il caso che prima era cieco** | Come D3, ma **senza codice fiscale e senza data di nascita** | **Avviso lo stesso.** Il vecchio controllo qui non vedeva nulla: girava solo sulle schede complete, cioè era cieco sul 42% dei clienti |
| D5 | Nuovo cliente | Email già usata da un altro cliente | **Avviso**, non blocco — condividere la casella è prassi legittima fra coniugi. ⚠️ Prima diceva «impossibile proseguire» |
| D6 | **Modifica** di un cliente esistente | Salva senza cambiare nulla | **Nessuna segnalazione**: non deve accusare sé stesso |
| D7 | Utente di **un'altra azienda** | Crea un cliente col CF di un cliente dell'azienda 2 | **Nessun blocco**: i silos restano silos |

---

## E — L'avviso nome/sesso, che ora vive nel database

La regola stava solo in C#. Ora sta in `fn_nome_sesso_avviso` e nella tabella
`ana_nomi_maschili_in_a`, ed è **la stessa che vede il sito**. Il validatore C# è stato eliminato:
non erano due copie da tenere allineate, era una copia in più.

Cambia anche **quando** compare: prima a ogni tasto, ora quando si sceglie il titolo e quando si
lascia il campo Nome. È un giro al database, e il momento utile è quando il nome è finito.

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| E1 | Titolo **SIG.**, nome **FRANCESCA**, esci dal campo | Compare l'avviso giallo «sembra un nome femminile…» |
| E2 | Cambia il titolo in **SIG.RA** | L'avviso **sparisce** subito |
| E3 | Titolo **SIG.**, nome **ANDREA** | Nessun avviso (è in lista) |
| E4 | Titolo **SIG.**, nome **GIANLUCA** | Nessun avviso |
| E5 | Titolo **SIG.**, nome **GIUSEPPE MARIA** | Nessun avviso: MARIA come secondo nome è maschile |
| E6 | Titolo **SIG.**, nome **MARIA** da solo | Avviso presente |
| E7 | Titolo **SIG.RA**, nome **MARCO** | Avviso «sembra un nome maschile…» |
| E8 | Con l'avviso a video, **salva** | Il salvataggio **riesce**: è un avviso, non un divieto |
| E9 | Nessun titolo scelto, scrivi un nome | Nessun avviso: senza titolo non c'è un sesso da contraddire |

---

## F — Consenso e lingua: le trappole

Il consenso non è un flag qualunque: le tre colonne (`consenso_marketing`, `_data`, `_fonte`)
esistono per **dimostrare** che è stato dato. Un aggiornamento che le azzera non perde una
preferenza, perde una prova — e non è recuperabile con un backfill.

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| F1 | Nuovo cliente | Spunta il consenso e salva | A DB: consenso vero, **data valorizzata** e una fonte |
| F2 | Cliente **con** consenso | Riapri, cambia **solo il telefono**, salva | Consenso, data e fonte **invariati**. È la trappola vera: un aggiornamento qualsiasi non deve toccarli |
| F3 | Cliente con consenso | Togli la spunta e salva | Consenso spento, ma **data e fonte restano**: servono a dimostrare che un tempo c'era |
| F4 | Cliente **senza** consenso | Accendilo | **Nuova** data e nuova fonte |
| F5 | Qualsiasi cliente | Cambia la **lingua**, salva, riapri | Il valore è quello scelto. Non passa più da una chiamata separata dopo il salvataggio: è dentro il CRUD |

---

## G — Iscrizione al viaggio

Fino al 2026-08-21 il gestionale chiamava ancora la vecchia `sp_mov_clienti_viaggi_create`, che
**non controllava nulla**: le regole degli script `551` e `553` le applicava soltanto il sito. Cioè
lo strumento usato tutti i giorni era quello scoperto — ed è così che si sono iscritti 11 piloti
senza email. Ora entrambe le form passano da `fn_mov_clienti_viaggi_insert`.

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| G1 | Iscrivi come **pilota** una persona senza email | Si apre il popup **«Manca l'email»** col nome della persona |
| G2 | Nel popup lascia vuoto o premi **Annulla iscrizione** | L'iscrizione **non** avviene; nessuna riga a database |
| G3 | Nel popup scrivi un'email **malformata** | «Salva e prosegui» resta disabilitato |
| G4 | Nel popup scrivi un'email valida e conferma | L'email finisce **in anagrafica** (riaprendo la scheda c'è) e l'iscrizione prosegue |
| G5 | Riapri il popup | Il fuoco parte dal campo email |
| G6 | Iscrivi la stessa persona senza email come **accompagnatore** | Consentito, nessun popup |
| G7 | Ruolo che richiede i **dati del mezzo**, lasciali vuoti | Rifiutato, e il messaggio dice **quali** mancano (marca, modello, targa) |
| G8 | Stesso caso, compila **marca e modello**, lascia solo la targa | Il messaggio nomina **solo la targa** |
| G9 | Iscrivi due volte la stessa persona allo stesso viaggio e data | Rifiutato |
| G10 | Ripeti G1 e G7 dal **tab Partecipanti**, non dall'inserimento rapido | Stesso comportamento: le due form condividono lo stesso codice |
| G11 | **Modifica** un partecipante cambiandogli ruolo in pilota, se non ha email | Stesso popup |

> Il popup non è una scorciatoia per aggirare il controllo: l'email inserita passa dal salvataggio
> normale dell'anagrafica, quindi dagli stessi controlli di sempre. Se fosse duplicata o
> incoerente, il salvataggio lo direbbe e l'iscrizione non proseguirebbe.

---

## H — Non regressione

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| H1 | Apri **dieci clienti storici** a caso | Chi è incompleto lo dichiara **all'apertura**, con un avviso giallo in cima e i campi mancanti in rosso — al 2026-08-31 sono 578 su 742, quindi capiterà quasi sempre. Salvare senza completare è **rifiutato**: è la regola dei documenti obbligatori (script 563), non un difetto |
| H1b | Completa il documento di uno di quei clienti e salva | Si salva, e riaprendolo l'avviso non c'è più |
| H2 | Griglia clienti: ricerca, ordinamento, paginazione | Invariati |
| H3 | **Export Excel** dei clienti | La colonna **Titolo** è valorizzata |
| H4 | Stampa una **rooming list** e una **scheda viaggio** | Invariate |
| H5 | Invia una **newsletter di prova** | Destinatari e telefoni come prima (il prefisso ha ancora lo spazio: `+39 333…`) |
| H6 | Tabelle → **Titoli persone**: elenco, inserimento, modifica, cancellazione | Funzionano. Cancellare un titolo **in uso** è impedito |
| H7 | Tabulazione e focus nelle form toccate (cliente, newsletter) | Il focus parte dal primo campo, il TAB segue l'ordine |

---

## Pulizia finale

```sql
SELECT cliente_id, cliente_cognome, cliente_nome FROM ana_clienti WHERE cliente_cognome LIKE 'ZZ%';
-- e le eventuali iscrizioni collegate, prima di cancellarli
```

---

## Cosa questo piano NON copre

- **PROD.** Nulla si prova là: gli script non ci sono ancora.
- **Il sito di iscrizione** — ha il suo piano, e con esso la prova incrociata.
- **La consegna coordinata**: script → sito → eseguibile, in quest'ordine (§3.7 della Checklist Go-Live).
- **I test xUnit**: in questo progetto non girano da CLI (`NU1201`). La verifica è build + prova nell'app.
