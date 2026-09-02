# Piano di test — Gestionale MAUI (`ana_clienti` centralizzato)

**Aggiornato:** 2026-08-21
**Ambiente:** DB locale Docker (`gestione_viaggi`), script `538`–`562` applicati
**Chi lo esegue:** Adriano — richiede l'app in esecuzione, non è automatizzabile da CLI
**Esito:** gruppi A–H eseguiti integralmente il **2026-08-31 / 2026-09-01**, tutti passati, comprese le undici prove nate durante l'esecuzione (A4b, B12, B13, C1b, F1b–F1d, G12, G13, H1b, H7b, H7c). I difetti emersi durante l'esecuzione — dieci — sono documentati nelle Note di Rilascio 2.0 (punti 11–20); le prove che il piano descriveva in modo sbagliato sono state corrette qui (A3, B4, B5, B8, C2, C3, C4, D1, D2, D3, D4, H1).
**Da rifare il 2026-09-02**: il gruppo **I** (nuovo, documenti validi per la partenza) e le prove **F1c**, **F1d** sul consenso

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
| Codice fiscale di prova coerente | `ZZTNTN77M24G113N` → **ZZTOLU** ANTONIO, M, 24/08/1977, ORISTANO |

> ⚠️ **Non usare `TLONTN77M24G113N`**, che questo piano indicava fino al 2026-08-31: è il codice
> fiscale di **TOLU ANTONIO, cliente 3071 dell'azienda 2**, una persona vera. Il controllo sui
> duplicati scatta per primo («già registrato su un altro cliente») e nasconde tutto il resto,
> quindi nessuna prova del gruppo C era eseguibile. Il codice qui sopra è calcolato con
> `fn_cf_calcola` sugli stessi dati ma con cognome `ZZTOLU`, e non appartiene a nessuno.

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
| A4b | **Cerca** un cliente, poi **aprilo** dal risultato | La scheda è completa: documento, IBAN, note, comuni. ⚠️ Nessun avviso «scheda incompleta» se i dati ci sono. Il 2026-09-01 la ricerca restituiva sedici campi in meno, e aprendo da lì si sarebbero potuti azzerare salvando |
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
| C1 | Nuovo cliente | Cognome `ZZTOLU`, nome `ANTONIO`, titolo `SIG.`, nato il **24/08/1977** a **ORISTANO**, CF `ZZTNTN77M24G113N` | Nessuna segnalazione: **corrisponde** |
| C2 | Stesso caso | Cambia la data di nascita in **24/07/1977** | **Rifiutato** (dal 2026-08-31 è un errore, non una domanda): il codice non corrisponde ai dati, e il messaggio dice quale risulterebbe. Se il codice non torna, uno dei due dati è sbagliato e va corretto |
| C3 | Nuovo cliente, **ripartendo dai dati di C1** (data 24/08/1977) | Metti `ANTONIO` nel **cognome** e `ZZTOLU` nel **nome**, stesso CF | **Rifiutato**: «Nome e cognome sembrano invertiti: il codice corrisponde leggendo ZZTOLU come cognome e ANTONIO come nome. **Scambia i due campi prima di proseguire**». Nessuna proposta di scambio automatico: non esiste, e il messaggio non deve prometterla. ⚠️ Se ti porti dietro la data sbagliata di C2 dirà «non corrisponde» invece che «invertiti», ed è giusto: con due dati sbagliati lo scambio da solo non fa tornare il codice |
| C4 | Stesso caso | Scambia davvero i due campi e salva | Si salva. **Dal 2026-08-31 non esiste più alcun modo di salvare un codice fiscale in disaccordo con l'anagrafica**: non si conferma, si corregge. La versione precedente di questa prova chiedeva di confermare l'incongruenza |
| C5 | Nuovo cliente | CF `ZZTNTN77M24G113A` (ultimo carattere alterato) | Rifiutato: non supera il controllo dell'ultimo carattere |
| C6 | Nuovo cliente | CF `ABC` | Rifiutato: forma non valida |
| C7 | Cliente **nato all'estero** (comune senza codice catastale) | Inserisci un CF formalmente valido | **Passa**: il confronto con l'anagrafica non è possibile, e non è colpa di chi compila |

---

## D — Duplicati e omonimi

| # | Da dove parti | Cosa fai | Cosa deve succedere |
|---|---|---|---|
| D1 | Nuovo cliente | Usa il CF di un cliente esistente su un'altra anagrafica | Rifiutato. **Non** dice di chi sia (deciso il 2026-09-01): chi digita un codice a caso non deve poter scoprire il nome di un cliente altrui. Dice invece come trovarla, quella scheda — cercandola per codice fiscale |
| D2 | Nuovo cliente | Stessi cognome, nome, **data e comune di nascita** di un esistente, **senza** CF | Rifiutato: «Esiste già un cliente con questi stessi dati anagrafici». Senza nomi, come tutte le segnalazioni sui duplicati (2026-09-01) |
| D3 | Nuovo cliente | Solo **cognome e nome** uguali a un esistente, data diversa | **Avviso**, non blocco: gli omonimi esistono davvero. Il messaggio non riporta il nome trovato |
| D4 | ⭐ **Il caso che prima era cieco** | Crea un cliente **completo** con cognome e nome uguali a una scheda **storica priva di data di nascita e di codice fiscale** (sul DB di prova: `FORNO RAFFAELLA` o `GENDUSO FRANCESCA`) | **Avviso di omonimia lo stesso.** È il caso su cui il vecchio controllo era cieco: pretendeva il codice fiscale fra i criteri, quindi le schede incomplete — su PROD il 42% — non le confrontava con nessuno. ⚠️ Dal 2026-08-31 **non si può più creare** un cliente senza data di nascita (script 563): l'incompletezza da provare è ora quella della scheda **già a database**, non di quella che stai inserendo |
| D5 | Nuovo cliente | Email già usata da un altro cliente | **Avviso**, non blocco — condividere la casella è prassi legittima fra coniugi. Anche qui **senza il nome** dell'altro cliente. ⚠️ Prima diceva «impossibile proseguire» |
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
| F1 | Nuovo cliente | Spunta il consenso e salva | A DB: consenso vero, **data valorizzata** e fonte **`GESTIONALE`** (non `NON_DICHIARATA`: la fonte dice dove il consenso è stato raccolto ed è metà della prova). ⚠️ Senza email la spunta **non si accende**, e lo dice: «Serve prima un indirizzo email» |
| F1b | Cliente **con** consenso e con email | Cancella l'email e salva | Rifiutato: «Il consenso alla newsletter richiede un indirizzo email». La spunta resta però sempre **spegnibile** anche senza email — una revoca non si nega mai |
| F1c | Nuovo cliente | Scrivi un'email **malformata** (`pippo@`) e guarda la spunta del consenso | **Non si accende**: dal 2026-09-01 non basta che l'email ci sia, deve anche essere valida. Prima `pippo@` bastava |
| F1d | Cliente **con consenso attivo** | Cambia il suo indirizzo email con un altro valido | Compare un avviso giallo: «Il consenso era stato dato all'indirizzo *vecchio*. Verifica che valga anche per quello nuovo». Il consenso **resta acceso** e data e fonte **non cambiano**: il consenso lo dà una persona, non una casella. L'avviso serve a intercettare l'errore di battitura, che manderebbe la newsletter a un estraneo |
| F2 | Cliente **con** consenso | Riapri, cambia **solo il telefono**, salva | Consenso, data e fonte **invariati**. È la trappola vera: un aggiornamento qualsiasi non deve toccarli |
| F3 | Cliente con consenso | Togli la spunta e salva | Consenso spento, ma **data e fonte restano**: servono a dimostrare che un tempo c'era. Riaprendo, la scheda dice «**Revocato. Era stato concesso il …**» — quella data è la concessione, non la revoca, che non è registrata da nessuna parte |
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

> ✅ **Corretto il 2026-08-31 — da verificare con G12/G13 qui sotto.** Nell'**Iscrizione Veloce**
> (`QuickAddParticipantDialog.razor`) i campi del mezzo — marca, modello, targa — **non esistono**.
> Scegliendo un ruolo da pilota il controllo li chiede, giustamente, e non c'è modo di compilarli:
> da quella form un pilota non si può iscrivere. Il tab Partecipanti invece li ha già, e li mostra
> solo quando il ruolo è da pilota (`ViaggioPartecipantiManagerDialog.razor:390`, `@if (IsPilot(…))`).
> Da correggere estraendo quel blocco in un componente condiviso e usandolo in entrambe le form:
> copiarlo sarebbe la stessa regola in due posti, cioè il difetto che stiamo togliendo da tutto il resto.

| G12 | **Iscrizione Veloce**: scegli un cliente e dagli un ruolo da **pilota** | Compaiono marca, modello e targa. Compilandoli, l'iscrizione va a buon fine |
| G13 | Nella stessa form riporta il ruolo a **passeggero** | I campi del mezzo spariscono, e l'iscrizione non li chiede più |

> Il popup non è una scorciatoia per aggirare il controllo: l'email inserita passa dal salvataggio
> normale dell'anagrafica, quindi dagli stessi controlli di sempre. Se fosse duplicata o
> incoerente, il salvataggio lo direbbe e l'iscrizione non proseguirebbe.

---

## I — Documenti validi per la partenza (nuovo, 2026-09-02)

Nessuno controllava che il documento di un partecipante fosse valido **alla data del viaggio**.
Non è un problema informatico: all'estero non si parte affatto, e in Italia l'albergo può
rifiutare la registrazione — dove i documenti di tutti gli occupanti si presentano per legge.

Due cose da tenere a mente eseguendo queste prove:

- **non conta «scaduto oggi», conta «scaduto alla fine del viaggio»**: un documento che scade il 20
  è validissimo adesso e inutile per una partenza che rientra il 24;
- **la severità dipende dalla destinazione**: all'estero è un errore, in Italia un avviso.

> **Dati di prova.** Sul DB locale molte schede storiche non hanno la data di scadenza, quindi le
> partenze vecchie mostreranno elenchi lunghi: è lo stato di quei dati, non un difetto. Su PROD le
> quattro partenze future hanno **zero** casi (misurato il 2026-09-02).

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| I1 | Iscrivi a un viaggio **in Italia** una persona col documento scaduto | **Avviso**, non blocco: «…in albergo i documenti di tutti gli occupanti si presentano per legge» |
| I2 | Iscrivi la stessa persona a un viaggio **all'estero** | **Rifiutato**: «Il viaggio è all'estero: senza documento valido non si parte» |
| I3 | Iscrivi qualcuno il cui documento scade **durante** il viaggio (fra partenza e rientro) | Segnalato lo stesso: al rientro quel documento non vale più |
| I4 | Apri i **partecipanti** di una partenza con qualcuno in queste condizioni | Le righe sono colorate: **rosso** chi non può partire (mancante o scaduto), **giallo** chi scade durante. L'icona ha un suggerimento che spiega quale dei due casi è |
| I5 | Lancia la **rooming list** di quella partenza | Prima della stampa compare l'elenco con **email e telefono** di chi va avvisato |
| I6 | Nel riquadro premi **Annulla la stampa** | La stampa non parte |
| I7 | Rilancia e premi **Ho letto, stampa** | Il PDF esce, e **in fondo** c'è la stessa nota in rosso |
| I7b | Fra i segnalati mettine uno **senza email né telefono** in anagrafica | Nella nota stampata, sotto la tabella, una riga in rosso lo nomina: «non c'è né email né telefono in anagrafica… va trovato un recapito prima della partenza». È il caso peggiore — non parte, e non si sa come dirglielo |
| I7c | Stampa una partenza con **più di dieci** persone da sistemare | La nota non si spezza a metà: la testata resta unita e la tabella prosegue **ripetendo l'intestazione**. Sotto le dieci resta tutta su una pagina |
| I8 | Ripeti I5–I7 con **Stampa Scheda Data Viaggio** e **Stampa Dettaglio Data Viaggio** | Stesso comportamento: sono le tre stampe che si usano prima di partire |
| I9 | Lancia una stampa **non** di partenza (registro IVA, scadenzario, fatture) | **Nessun avviso e nessuna nota**: non hanno niente a che vedere con chi parte |
| I10 | Apri una partenza in cui **tutti** hanno il documento valido e stampa | **Nessun riquadro**: chi lavora su partenze a posto non deve imparare a chiudere un dialogo per stampare |

---

## H — Non regressione

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| H1 | Apri **dieci clienti storici** a caso | Chi è incompleto lo dichiara **all'apertura**, con un avviso giallo in cima e i campi mancanti in rosso — capiterà spesso (sul DB **locale di prova** erano 578 su 742 al 2026-08-31; il numero vero è quello di PROD, non misurato). Salvare senza completare è **rifiutato**: è la regola dei documenti obbligatori (script 563), non un difetto |
| H1b | Completa il documento di uno di quei clienti e salva | Si salva, e riaprendolo l'avviso non c'è più |
| H2 | Griglia clienti: ricerca, ordinamento, paginazione | Invariati |
| H3 | **Export Excel** dei clienti | La colonna **Titolo** è valorizzata |
| H4 | Stampa una **rooming list** e una **scheda viaggio** | Invariate |
| H5 | Invia una **newsletter di prova** | Destinatari e telefoni come prima (il prefisso ha ancora lo spazio: `+39 333…`) |
| H6 | Tabelle → **Titoli persone**: elenco, inserimento, modifica, cancellazione | Funzionano. Cancellare un titolo **in uso** è impedito |
| H7 | Tabulazione e focus nelle form toccate (cliente, newsletter) | Il focus parte dal primo campo, il TAB segue l'ordine |
| H7b | Scegli il **titolo** dalla tendina | Il cursore va **da solo** sul Cognome |
| H7c | Clicca sulle schede **Residenza & Contatti**, **Documenti**, **Altro** | Il cursore si posiziona ogni volta sul primo campo in alto a sinistra: Comune di Residenza, Tipo Documento, Intolleranze. L'intera scheda si compila senza toccare il mouse |

---

## Un difetto rimasto senza spiegazione

Durante le prove il **Comune di Residenza** è andato in errore due volte pur essendo compilato, e
sempre in presenza di altri errori nella scheda. Non si è più ripresentato dal commit `0f794f9`
(che ha tolto una doppia validazione della form nel salvataggio), e una traccia lasciata in ascolto
per due ore di prove non ha registrato nemmeno un'anomalia.

Non è dichiarato risolto, perché **non è stato capito**: una correzione che non si sa spiegare non è
una diagnosi. Se ricompare, la traccia da rimettere è in `ComuneSelect` (vedi commit `c5031d8`),
e registra gli azzeramenti del valore e i disallineamenti fra identificativo e oggetto.

---

## Pulizia finale

**Deciso il 2026-09-01: i clienti di prova restano.** Non sono spazzatura da togliere, sono casi
già pronti per le prove successive — e ricostruirli costa più che tenerli.

| id | cliente | a cosa serve |
| :--- | :--- | :--- |
| 4383 | ALESSANDRA PIERO | scheda completa, buona come punto di partenza |
| 4384 | FORNO RAFFAELLA | **omonimo** di una scheda storica priva di data e codice fiscale: è il caso D4 |
| 4386 | PIPPO MARCO | ha attraversato tutto il ciclo del consenso (dato, revocato, ridato) |

Nessuno dei tre ha iscrizioni o alloggi collegati.

Da non toccare, benché somigli a un dato di prova: **MAIORCA MARIA** (3327) è un cliente storico,
ed è l'unico dell'azienda 2 con anagrafica completa e **senza email**. È il solo su cui si possano
provare i controlli sul pilota senza email (G10, G11) senza che scatti prima il blocco
sull'anagrafica incompleta. Se qualcuno gliela compila, quel caso di prova non esiste più.

### Se invece si vuole ripulire davvero



Il prefisso `ZZ` non basta: alcune prove — l'omonimia di D4, per dire — impongono di usare il
cognome di una scheda esistente, e altre volte capita di inventare un nome sul momento. La data di
creazione invece non si dimentica:

```sql
-- Tutto cio' che e' nato durante le prove, comunque si chiami
SELECT cliente_id, cliente_cognome, cliente_nome, created
FROM ana_clienti
WHERE created >= DATE '2026-08-31'      -- il giorno in cui sono cominciate
ORDER BY cliente_id;

-- Chi ha iscrizioni collegate va sciolto prima, o la cancellazione viene rifiutata
SELECT v.cliente_id_fk, COUNT(*)
FROM mov_clienti_viaggi v
WHERE v.cliente_id_fk IN (SELECT cliente_id FROM ana_clienti WHERE created >= DATE '2026-08-31')
GROUP BY 1;
```

⚠️ Da eseguire **sul DB locale di prova**, mai su PROD.

---

## Cosa questo piano NON copre

- **PROD.** Nulla si prova là: gli script non ci sono ancora.
- **Il sito di iscrizione** — ha il suo piano, e con esso la prova incrociata.
- **La consegna coordinata**: script → sito → eseguibile, in quest'ordine (§3.7 della Checklist Go-Live).
- **I test xUnit**: in questo progetto non girano da CLI (`NU1201`). La verifica è build + prova nell'app.
