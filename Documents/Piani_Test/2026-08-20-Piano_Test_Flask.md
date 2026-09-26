# Piano di test — Sito di iscrizione (Flask + React)

**Data:** 2026-08-20
**Repository:** `Iscrizione-Viaggi-Offroad PostgreSQL`, ramo `feature/controlli-centralizzati`
**Ambiente:** `./avvia-locale.sh` (DB Docker locale), script `538`–`576` applicati
**Chi lo esegue:** Adriano — **serve un browser**, e questi test non sono automatizzabili da qui

---

## Cosa è già stato verificato (e quindi NON è in questo piano)

Eseguito il 2026-08-20 chiamando direttamente le API contro il database locale. **Tutto passato.**
Non va rifatto: se qualcosa qui sotto fallisse nel browser, il problema è nell'interfaccia, non
nella logica.

| Verificato | Esito |
|---|---|
| `/api/static/titoli_cliente` restituisce la lookup, `SIG.` prima di `SIG.RA`, ciascuno col suo sesso | ✅ |
| Salvataggio di un cliente nuovo: il sito **non invia il sesso**, lo deriva il trigger dal titolo | ✅ |
| Consenso salvato con **data e fonte `SITO_ISCRIZIONE`** | ✅ |
| Codice fiscale corretto / di un'altra persona / malformato, su cliente esistente | ✅ tre esiti distinti |
| Codice fiscale con **cognome e nome invertiti** su cliente **nuovo** | ✅ `CONFERMA`, propone lo scambio |
| Codice fiscale già usato da un altro cliente | ✅ rifiutato, indica quale email usare |
| Email malformata e cognome di un carattere | ✅ messaggio pulito, **senza** lo stack PL/pgSQL |
| `/api/cliente/valida` restituisce l'avviso nome/sesso | ✅ |
| Lettura SMTP: senza chiave, con chiave sbagliata, con configurazione valida | ✅ tre comportamenti corretti |

---

## 📋 Censimento del 2026-09-02: quali regole il sito anticipa e quali no

Fatto per non scoprirle una alla volta durante le prove. Il database può emettere **34 esiti**
(`fn_ana_clienti_valida` e le funzioni che chiama). Rispetto a ciascuno il sito sta così:

| Stato | Esiti |
| :--- | :--- |
| **Anticipati mentre si compila** | nome/sesso, cognome e nome minimi, formato email, consenso senza email, i quattro del codice fiscale, data di nascita futura, data di rilascio futura |
| **Non anticipabili, e va bene** | i quattro su duplicati e omonimi: richiedono comunque il database, il sito li mostra al salvataggio |
| **Non applicabili** | `IBAN_FORMATO`: il sito l'IBAN non lo raccoglie |
| 🔴 **Non anticipati** | i tredici **`MANCA_*`** per il **passeggero** e in **modifica** |

L'ultima riga non si chiude con una correzione: ogni validatore contiene tre rami
(`mode === 'passenger'`, `isExistingClient`, `isEditingEnabled`) che si intrecciano, in trenta
funzioni quasi identiche. È il perimetro del riordino, ed è ciò che **C10** e **C11** vanno a
documentare — non a riparare.

---

## 🔴 L'inserimento di una nuova anagrafica va in errore — **ma solo su PROD**

Segnalato il **2026-08-31**. Verificato il **2026-09-01**: in locale, sul ramo
`feature/controlli-centralizzati` con il DB Docker, **l'inserimento funziona** (nuovo passeggero
creato e ritrovato a database). Quindi non è un difetto del codice del sito: è qualcosa che esiste
**solo in produzione**.

**L'ipotesi da verificare per prima** è già scritta nella Checklist Go-Live (§1, nota sullo stato di
PROD): su PROD sono state applicate le funzioni `543`→`555` **ma non** gli script `538`–`542`.
Il database di produzione ha quindi **23 funzioni nuove senza lo schema che presuppongono** —
mancano `ana_titolo_persone` e `ana_clienti.cliente_titolo_fk`. Se il sito in produzione chiama
anche una sola di quelle funzioni, fallisce lì e soltanto lì.

Da raccogliere sul server di produzione: il messaggio a video, la risposta dell'endpoint nella
console di rete e la riga nel log di Flask. **L'errore atteso in questo scenario nomina un oggetto
mancante** (`relation "ana_titolo_persone" does not exist`, o una colonna sconosciuta): se è così,
l'ipotesi è confermata e la cura è il go-live stesso, che applica gli script in ordine.

⚠️ Non applicare `538`–`542` a PROD da soli per "sistemare": la regola della checklist è che a PROD
non si applica nulla fuori dalla sequenza.

Da raccogliere alla riproduzione: il messaggio a video, la risposta di `/api/cliente/salva`
(o dell'endpoint effettivo) nella console di rete, e la riga corrispondente nel log di Flask.

---

## 🔧 Questo piano non basta: il sito va anche riletto e riordinato

> **Primi due interventi fatti il 2026-09-02**, mentre si correggeva il consenso che non
> tornava:
> - rimosse **116 righe morte** (`populateFormStates`): popolava il form da un cliente esistente,
>   non la chiamava nessuno, ed era un doppione **incompleto** di `populateStateWithData` — non
>   impostava il consenso. Chi l'avesse collegata credendola equivalente avrebbe rimesso in piedi
>   il difetto appena chiuso;
> - `/api/cliente/dati` non ricopia più la risposta **chiave per chiave**: parte da ciò che il DAO
>   restituisce e trasforma solo le tre cose che deve (rinomina, date in ISO, descrizione del
>   prefisso). Era lì che `consenso_marketing` e `titolo_fk` si perdevano, pur essendo restituiti
>   dal database.
>
> Il resto del riordino resta da pianificare: sono interventi mirati, non la revisione.


Deciso il **2026-08-31**. Il codice del sito è più vecchio del resto e cresciuto per aggiunte
successive: `Step2Content.jsx` è un unico form da 3.187 righe che serve pilota e passeggero
attraverso un parametro `mode`, con i controlli replicati campo per campo e tre rami diversi
(`mode === 'passenger'`, `isExistingClient`, `isEditingEnabled`) che si intrecciano dentro ogni
singolo validatore. È così che nascono i buchi trovati oggi:

- per il passeggero **nessun campo è obbligatorio**, perché ogni validatore comincia con
  `if (mode === 'passenger' && !value) return '';`
- un cliente già riconosciuto **non viene validato affatto**: `triggerValidation()` esce subito
  con `isValid: true` se non si preme «Modifica Anagrafica»
- premendo «Modifica Anagrafica» i validatori restituiscono comunque vuoto, rimandando a un
  controllo «al tentativo di salvataggio» **che non è mai stato scritto**

Quindi le prove di questo piano vanno affiancate da una revisione del codice e da una
riorganizzazione: i controlli non devono stare in trenta `useCallback` quasi identici, ma
appoggiarsi alle funzioni del database come fa ora il gestionale. Da pianificare come lavoro a sé,
non da infilare fra un test e l'altro.

---

## 🔄 Cambiato sotto il sito il 2026-09-01: leggere prima di eseguire

Il sito non è stato toccato, ma **le regole che eredita dal database sì**, sei volte in un giorno
(script `563`–`569`, decisi collaudando il gestionale). Il sito le riceve tutte, perché passa dalle
stesse funzioni. Tre prove di questo piano sono diventate **sbagliate** e vanno eseguite nella
versione nuova; altre sono da aggiungere.

| Cosa è cambiato | Effetto sul sito |
| :--- | :--- |
| `563` **Documento obbligatorio per tutti** | I cinque campi del documento, più data e comune di nascita, comune e indirizzo di residenza, sono ora obbligatori **per ogni persona** — pilota *e* passeggero. Il sito lato suo non li pretende (per il passeggero non pretende nulla), quindi il rifiuto arriverà **dal server** al salvataggio |
| `564` `565` **Codice fiscale: niente più conferme** | Un codice in disaccordo con i dati è ora un **errore**, nomi invertiti compresi. La richiesta di conferma con la proposta di scambio **non esiste più** |
| `566` `567` `569` **I duplicati non fanno nomi** | Codice fiscale o email già registrati non rivelano più chi li possiede: il messaggio dice cosa è successo e basta |
| `568` **Consenso vuole un'email** | Spuntare il consenso senza indirizzo è rifiutato |

> ⚠️ **Cosa aspettarsi davvero.** Il sito ha i controlli lato client **disallineati** da questi
> (vedi la sezione sul riordino): per il passeggero non chiede nulla, e un cliente già riconosciuto
> non lo valida affatto. Quindi molte di queste regole si manifesteranno come **errori restituiti dal
> server dopo aver premuto avanti**, non come campi rossi mentre si compila. Non è un difetto nuovo
> da segnalare ogni volta: è la misura di quanto il sito sia rimasto indietro, ed è esattamente ciò
> che il riordino deve chiudere. Va segnalato invece **come** l'errore si presenta: se è leggibile,
> se dice quale campo, e se il sito resta utilizzabile.

---

## ⚠️ Prerequisito: `GV_SECRET_KEY`

Il sito legge la configurazione SMTP dell'azienda dal database chiamando
`fn_get_smtp_config_for_email` — **la stessa funzione del gestionale**. La password è cifrata, e
serve la chiave.

**In locale è già a posto e verificato** (2026-08-20): nel repository Flask c'è un **symlink** al
file della chiave del gestionale (`.gv_secret_key.local.sh`), quindi il segreto resta in un posto
solo, e `avvia-locale.sh` lo carica da sé. Provato: la configurazione dell'azienda 2 viene letta e
la password decifrata, e all'avvio compare

```
[FLASK FACTORY] DEBUG - Flask-Mail inizializzato da DB (Server=mail.sardegnafuoritraccia.it, Porta=465, Security=ssl).
```

Se invece leggi `GV_SECRET_KEY non impostata`, stai lanciando il sito da una shell non interattiva
e senza lo script: `~/.zshrc` non viene letto in quel caso. Usa `./avvia-locale.sh`.

**Non** mettere la chiave in `.env`: quel file viene sovrascritto da `avvia-locale.sh` e
`avvia-supabase.sh`. Per la produzione, i passi sono nella Checklist Go-Live (§ variabili d'ambiente).

---

## A — Il titolo comanda il sesso

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| A1 | Apri l'iscrizione, arriva ai dati anagrafici | La tendina **Titolo** mostra `SIG.` per primo, poi `SIG.RA`, poi gli altri. ✅ **Passato** il 2026-09-04 |
| A2 | Scegli **SIG.RA** | Il campo **Sesso** passa a F **da solo**. ✅ **Passato** il 2026-09-04 |
| A3 | Prova a modificare il campo Sesso a mano | **Non si può**: è disabilitato. ✅ **Passato** il 2026-09-04 |
| A4 | Scegli **SIG.**, poi cambia in **DOTT.SSA** | Il sesso segue: M, poi F. ✅ **Passato** il 2026-09-04 |
| A5 | Riprendi l'iscrizione con l'email di un cliente **già esistente** | Il suo titolo viene **ritrovato e selezionato**, non resta vuoto. ✅ **Passato** il 2026-09-04 |

---

## B — Il consenso email

È il punto che ha motivato tutta la revisione: il consenso **non è recuperabile con un backfill**,
o si raccoglie alla fonte o è perso.

> ⚠️ **Nota del 2026-09-01: la spunta del consenso ESISTE.** A fine agosto era stata data per
> mancante, e l'avevo scritto qui senza aprire il codice: è in `Step2Content.jsx`,
> `id="consensoMarketing"`, con l'etichetta «Desidero ricevere comunicazioni sui prossimi viaggi a
> questo indirizzo». Il gruppo B è quindi **eseguibile**, e va eseguito davvero — non dato per
> buono. Il §2.8.1 della Checklist Go-Live va riletto con questa informazione, perché descrive la
> raccolta del consenso come interamente da fare.

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| B1 | Guarda il modulo anagrafico | C'è una spunta per il consenso all'invio di comunicazioni. ✅ **Passato** il 2026-09-04 |
| B2 | Osservala all'apertura | **Non è pre-spuntata**. ✅ **Passato** il 2026-09-04 |
| B3 | Verifica che il consenso alle comunicazioni **non sia mescolato** con l'accettazione dell'informativa | La spunta del modulo riguarda **solo** le comunicazioni. L'informativa privacy si accetta a parte, nel riepilogo finale, con la formula «inviando questo modulo dichiaro di aver letto…» — che è un **testo**, non una seconda spunta. ⚠️ **La prova era scritta male** (2026-09-04): cercava «due spunte distinte», ma la seconda non esiste e non deve esistere. Il trattamento dei dati **per eseguire l'iscrizione** non si basa sul consenso — si basa sul contratto — quindi non va chiesto un permesso che non serve: serve l'**informativa**, che c'è ed è collegata. La sostanza del controllo resta: i due piani non devono confondersi, e con una sola spunta, che parla solo di comunicazioni, non possono. ✅ **Verificato nel codice** il 2026-09-04: l'informativa (`static/informativa_privacy.html`) **non nomina** marketing o newsletter, quindi accettarla non tira dentro il consenso commerciale |
| B4 | Compila **senza** spuntarla e salva | Si salva; a database `consenso_marketing` resta `false`. ✅ **Passato** il 2026-09-04, verificato anche sul gestionale |
| B5 | Spuntala e salva | A database: `true`, con **data** e **fonte `SITO_ISCRIZIONE`**. ✅ **Passato** il 2026-09-04 (cliente PIPPONE PIPPO: `true`, fonte `SITO_ISCRIZIONE`, con data) |
| B6 | Aggiungi un **passeggero** e guarda il suo modulo | Ha **la sua** spunta: il consenso è personale, non del capogruppo. ✅ **Passato** il 2026-09-04 (passeggero PIPPONA PIPPA) |
| B7 | Riapri un cliente esistente che **aveva già** dato il consenso e salva senza toccare la spunta | Il consenso **resta acceso**. Se si spegnesse, si starebbe falsificando un dato. ✅ **Passato** il 2026-09-04 |
| B8 | Completa un'iscrizione **senza** spuntare il consenso | A DB consenso falso, e **nessuna data, nessuna fonte**: non c'è nulla da dimostrare. ✅ **Passato** il 2026-09-04 |
| B9 | Entra con l'email di un cliente **esistente** | Titolo **ritrovato** nella tendina e spunta del consenso **com'era**. ⚠️ Sono le due regressioni chiuse col `557`: senza, il titolo restava vuoto e il consenso si sarebbe spento da solo al primo salvataggio. ✅ **Passato** il 2026-09-04 |
| B9b | Riprendi con un cliente che **ha il consenso** e apri «Modifica Anagrafica» | La spunta è **segnata**. ⚠️ Fino al 2026-09-02 arrivava sempre spenta: l'endpoint `/api/cliente/dati` costruisce la risposta a mano, chiave per chiave, e `consenso_marketing` non era fra quelle ricopiate — pur essendo restituito dal database e dal DAO (`SqlScripts/557`). Salvando si sarebbe spento un consenso che nessuno aveva revocato. ✅ **Passato** il 2026-09-04 |

---

## C — I controlli, gli stessi del gestionale

Il sito chiama `/api/cliente/valida`, che è `fn_ana_clienti_valida`: **la stessa funzione** che il
gestionale invoca da `ValidaAsync`. Qui si verifica che i messaggi arrivino davvero all'utente.

> **(aggiornato il 2026-09-26: cliente riconosciuto)** Dal ramo `feature/cliente-riconosciuto`
> chi è già in archivio **non vede più il modulo**: vede il riquadro «ti abbiamo riconosciuto» e,
> al più, i soli campi che mancano. «Modifica Anagrafica» non esiste più: al suo posto
> **«Modifica i miei dati»**, che manda un codice usa e getta alla casella in archivio. Quindi, in
> tutte le prove qui sotto, **«in modifica» su una scheda in archivio vuol dire dopo il codice**
> (gruppo H, H6); in alternativa si usa una scheda **creata in questa sessione** e si torna al
> passo 2 (H8), che si riapre in modifica senza codice. Le prove su un cliente **nuovo** non cambiano.

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| C1 | Titolo **SIG.**, nome **FRANCESCA**, **scheda completa**, prosegui | Compare l'avviso giallo nome/sesso, e **si può andare avanti** |
| C1b | Lo stesso, ma con la **scheda incompleta** (solo titolo e nome) | Compaiono **sia** l'avviso giallo **sia** l'elenco dei dati mancanti — in **un solo** messaggio, non nove sovrapposti. ⚠️ Corretto il 2026-09-01: gli avvisi venivano scartati appena c'era un errore, e da quando i documenti sono obbligatori una scheda in compilazione un errore ce l'ha quasi sempre. L'avviso nome/sesso era quindi diventato invisibile |
| C2 | Titolo **SIG.**, nome **ANDREA** | Nessun avviso |
| C3 | Inserisci un'**email scritta male** e salva | Messaggio rosso leggibile in italiano. **Non** deve comparire «Esiste già una anagrafica con questo Codice Fiscale», né testo tipo `CONTEXT: PL/pgSQL function…` |
| C3b | Con l'email scritta male, guarda la spunta del **consenso** | **Non si accende**, e lo dice: «Serve prima un indirizzo email valido». Un consenso dato su un indirizzo malformato è una riga che al primo invio risulta irraggiungibile. Resta però sempre **spegnibile** anche con l'email non valida: una revoca non si nega mai |
| C3c | Riprendi l'iscrizione con un cliente **che ha già il consenso** e cambiagli l'email | Stesso avviso del gestionale, accanto alla spunta. Il consenso resta acceso e la sua data non cambia. **(aggiornato il 2026-09-26: cliente riconosciuto)** Cambiare l'email di una scheda in archivio è una *modifica*: si può solo **dopo il codice** («Modifica i miei dati»). Senza codice il riquadro non mostra il campo email, e un'email diversa mandata a mano a `/api/cliente/save` viene ignorata (H23) |
| C4 | Inserisci un **cognome di un carattere** ed esci dal campo | «Il cognome deve avere almeno 2 caratteri.», **subito sul campo**. ⚠️ Fino al 2026-09-02 il sito non conosceva quella regola — il suo controllo guardava solo che il campo non fosse vuoto — e lasciava proseguire fino al modale «Vuoi salvare le modifiche?», con il rifiuto che arrivava **dopo** la conferma |
| C4b | Stessa cosa con un **nome** di un carattere | Stesso comportamento |
| C5b | Metti una **data di rilascio del documento nel futuro** | «La data di rilascio non può essere nel futuro», subito sul campo. ⚠️ Fino al 2026-09-02 il ramo di controllo per le date del documento era **vuoto** — solo commenti — e il rifiuto arrivava dal database al salvataggio |
| C5c | Metti una **scadenza già passata** | **Passa** (un documento scaduto va registrato lo stesso, semmai rinnovato), e accanto agli «Anni residui di validità» compare in rosso «**Documento scaduto il gg/mm/aaaa**». ⚠️ Fino al 2026-09-02 quel campo diventava rosso **senza una parola di spiegazione** |
| C5d | Metti una scadenza **fra sei mesi** | Il campo si colora, e il testo dice «**Scade il gg/mm/aaaa, fra meno di un anno**». ⚠️ Prima scaduto e in-scadenza erano identici: `calcolaAnniResiduiDocumento` restituisce `'0'` in entrambi i casi, quindi lo stesso rosso per due situazioni molto diverse |
| C5 | Digita il codice fiscale mettendo **cognome e nome invertiti** | **Rifiutato** (dal 2026-09-01, script `565`): «Nome e cognome sembrano invertiti: il codice corrisponde leggendo X come cognome e Y come nome. **Scambia i due campi prima di proseguire**». Non c'è più nessuna conferma da accettare, e nessuno scambio automatico da attendersi |
| C6 | **Scambia davvero** i due campi come dice il messaggio | Il salvataggio va a buon fine. ⚠️ Fino al 2026-08-31 questa prova chiedeva di *confermare* l'incongruenza e salvarla: non è più possibile, per nessuna via |
| C7 | Usa il codice fiscale di una persona **già iscritta** | Bloccato con «Questo codice fiscale risulta già registrato». ⚠️ Il messaggio **non dice più di chi sia** (`566`, `569`): verifica che il sito continui a indicare da sé **l'email con cui riprendere** l'iscrizione, perché quell'indicazione è sua e non del database. **(aggiornato il 2026-09-26: cliente riconosciuto)** L'email indicata ora è **mascherata** (`m***@dominio`): per intero rivelerebbe la casella di un altro a chi ne conosce il codice fiscale. Se la scheda già registrata **non ha email**, non c'è blocco: il sito le aggancia quella digitata e la **completa soltanto**, senza sovrascrivere nulla (H33) |
| C8 | Verifica quanto restano a video i messaggi | Errori e avvisi restano **8 secondi**, non un lampo |
| C9 | Ripeti C1, C3 e C5 **su un passeggero** (Step 3) | Stessi comportamenti: un passeggero non è un cliente di serie B. **(aggiornato il 2026-09-26: cliente riconosciuto)** Vale per un passeggero **nuovo**, o dopo il **suo** codice: un passeggero già in archivio non vede il modulo ma il riquadro «è già in archivio: useremo i suoi dati» (H12) |
| C10 | ⭐ Iscrivi un **passeggero** lasciando vuoti i dati del documento | **Rifiutato** (`563`): i documenti servono a ogni occupante della stanza, per legge, e il sito oggi al passeggero non chiede niente. Guarda **come** arriva il rifiuto: leggibile? dice quali campi? |
| C11 | Prosegui con un **cliente già riconosciuto** la cui scheda è incompleta, senza premere «Modifica Anagrafica» | **Rifiutato subito**, con l'elenco di ciò che manca — non alla fine del wizard. ⚠️ Eseguito il 2026-09-04 con **BATTISTELLA NICOLA** (`nicolabattistella93@gmail.com`, mancano tutti e cinque i campi del documento): **falliva**, il sito lo lasciava passare senza dire niente. Corretto in tre passi lo stesso giorno (difetti 51, 52, 53). ✅ **Passato** il 2026-09-04. **(aggiornato il 2026-09-26: cliente riconosciuto)** Ora il riquadro dice «Per iscriverti ci mancano: …» e mostra **solo quei campi**, vuoti: «Avanti» non passa finché mancano, e compilati si salvano **senza codice** (completamento). Da rifare con questo comportamento; la stessa cosa, con una scheda di prova, è H2 |
| C11b | Ripeti C11 con **ARRIGONI ANDREA** (`arrigoni.andrea10@gmail.com`), cui manca **solo** l'indirizzo di residenza | Rifiutato lo stesso. È la prova che conta di più: la scheda che sembra a posto. ✅ **Passato** il 2026-09-04. **(aggiornato il 2026-09-26: cliente riconosciuto)** Deve comparire **solo** il campo dell'indirizzo; compilato, si salva senza codice e al titolare arriva la mail «Abbiamo completato la tua scheda» |
| C11c | Riprendi un'iscrizione mentre il database è **irraggiungibile** (ferma il container, o rinomina temporaneamente `fn_ana_clienti_valida`) | **Non si prosegue**, e compare «Non è stato possibile verificare i dati anagrafici». Nasce dal difetto 53: prima un controllo che falliva rispondeva «nessun problema» con HTTP 200. ⚠️ Nel percorso di **salvataggio** invece si prosegue di proposito: lì la validazione viene riapplicata a valle dall'insert. **Eseguito il 2026-09-04 fermando il container** mentre si era già nello Step 2: **fallito cinque volte di seguito**, facendo emergere i difetti **55, 57, 58, 59, 60 e 61** — fino alla causa sotto tutte le altre, cioè che le richieste non fallivano affatto ma restavano appese. ✅ **Passato** alla sesta. **(aggiornato il 2026-09-26: cliente riconosciuto)** Da rifare anche **al riconoscimento**: se il database è fermo quando il passo 2 legge il profilo (503), il pilota **non** diventa un cliente nuovo — niente modulo vuoto, compare il messaggio del database irraggiungibile e «Avanti» resta fermo (commit `dea093ca`). È H11b |
| C11c-bis | Ferma il container **fra Step 1 e Step 2**, poi prova ad andare avanti | **Non si passa allo step successivo**: compare «Il database non è raggiungibile: non è possibile proseguire». ⚠️ Provato il 2026-09-04: il wizard **arrivava in fondo lo stesso**, saltando ogni controllo (difetto 57). Al posto dello spinner muto ora c'è un messaggio. Il pulsante «Avanti» si spegne entro cinque secondi. ✅ **Passato** il 2026-09-04 |
| C11c-ter | Col container fermo, premi «Avanti» **due o tre volte di seguito** | Sempre lo **stesso messaggio**, l'icona **rossa già dalla prima**, e non si passa mai allo step successivo. Il pulsante **«Avanti» è spento**, quindi la seconda pressione non parte nemmeno e non c'è nessuno spinner. ⚠️ Prima: primo tentativo messaggio + icona verde, secondo tentativo spinner muto + passaggio allo step 3 (difetti 58 e 59). ✅ **Passato** il 2026-09-04 |
| C11d | Ripeti fermando il container e **guarda l'indicatore di stato del database** | Diventa **rosso alla prima chiamata che fallisce**, non al giro successivo del controllo periodico (difetto 56). Il messaggio del tooltip dice «Database non raggiungibile». ✅ **Passato** il 2026-09-04 |
| C11e | Riavvia il container e continua a usare il sito | L'icona **torna verde** alla prima chiamata riuscita, senza aspettare i 30 secondi. ✅ **Passato** il 2026-09-04: il pulsante «Avanti» torna cliccabile da sé |
| C11f | Con il database **attivo**, provoca un errore applicativo qualsiasi (es. un codice fiscale duplicato) | L'icona **resta verde**: 404, 409 e 500 applicativi non sono problemi di connessione, e farla lampeggiare a ogni rifiuto la renderebbe inutile. ✅ **Passato** il 2026-09-04 |
| C13 | Apri l'anagrafica **in modifica** e svuota un campo obbligatorio (es. il comune di residenza), poi esci dal campo | L'errore compare **subito, accanto al campo**. Prima le segnalazioni erano spente in modifica e arrivavano tutte insieme al salvataggio (difetto 62). ✅ **Passato** il 2026-09-04. **(aggiornato il 2026-09-26: cliente riconosciuto)** «In modifica» ora vuol dire **dopo il codice** (o scheda creata in questa sessione, H8): vale per C13, C13a, C13a-bis, C13e, C13f e C13g. Da rifare così |
| C13a | In modifica, **attraversa col tabulatore** i campi Comune di nascita e Comune di residenza senza toccarli | Il valore **resta**. ⚠️ Prima veniva cancellato dal solo passaggio del fuoco (difetto 63), in silenzio. ✅ **Passato** il 2026-09-04, alla quarta correzione |
| C13a-bis | Cancella un comune **di proposito** con la «x» del selettore, poi esci dal campo | Resta cancellato, e il campo va in errore: la cancellazione voluta non viene annullata dal ripristino. ⚠️ La «x» **non c'era** ed è stata aggiunta il 2026-09-04 (difetto 68): prima l'unico modo di svuotare il campo era cancellare il testo a mano. ✅ **Passato** il 2026-09-04 |
| C13e | In modifica, **apri e richiudi** la tendina del tipo documento senza cambiare voce | Numero, ente e date del documento **restano**. ⚠️ Prima bastava aprirla per perderli (difetto 79) |
| C13f | Cambia **davvero** il tipo documento (es. da Carta d'identità a Passaporto) | I campi collegati si azzerano: il numero della carta non è quello del passaporto |
| C13g | In modifica, **apri e richiudi** la tendina del **prefisso internazionale** senza cambiare voce | Il **numero di telefono resta**. ✅ Verificato nel codice il 2026-09-05: quel gestore non azzera niente — il prefisso non ha campi dipendenti, e cambiarlo non cambia il numero. La prova sta qui perché il dubbio è legittimo dopo il difetto 79 |
| C13d | Apri l'anagrafica di **VISCONTI ADRIANO** (`visconti.adriano@gmail.com`, scheda SFT) e guarda il **prefisso internazionale** | Mostra **+27**. ⚠️ Prima il campo era vuoto: l'elenco del sito ha dieci prefissi europei e +27 non c'è (difetto 64). Nota: di questa email esistono **due** schede, in aziende diverse — la 22 (azienda 6, +39) e la 3870 (azienda 2 = SFT, +27). Il sito lavora sulla seconda. ✅ **Passato** il 2026-09-04. **(aggiornato il 2026-09-26: cliente riconosciuto)** Senza codice il prefisso **non si vede più**: compare nel modulo compilato che si apre dopo il codice (`/api/cliente/scheda` restituisce `pref_tel_int_codice`, corretto in `9f308650`). Con una scheda di prova il prefisso e le allergie arrivano compilati (H6 ✅ 2026-09-26); con la 3870 va rifatta col codice vero (M1) |
| C13b | Compila un **passeggero** (Step 3) lasciando vuoti comune di nascita, residenza e i campi del documento | Ogni campo si segnala **mentre compili**. Il telefono e il prefisso invece **non** sono obbligatori per un passeggero: quella è la regola, non una svista. ✅ **Passato** il 2026-09-04 |
| C13c | Nella scheda di un **pilota** in modifica, cancella il telefono | Segnalato: chi guida deve restare raggiungibile anche quando modifica la propria scheda. ✅ **Passato** il 2026-09-04. **(aggiornato il 2026-09-26: cliente riconosciuto)** Per un pilota in archivio si arriva in modifica solo dopo il codice. Il caso vicino, telefono **mancante** in archivio, oggi fa comparire nel riquadro solo prefisso e telefono (H2 ✅ 2026-09-26) |
| C12 | Spunta il consenso lasciando **vuota l'email** | ✅ **Passato** il 2026-09-04. Rifiutato (`568`). Sul sito l'email è la chiave d'ingresso, quindi potrebbe non essere raggiungibile: se non riesci a produrre il caso, annotalo e passa oltre. ✅ **Passato** il 2026-09-04: l'errore viene dato e non si procede |

---

## D — Iscrizione al viaggio

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| D1 | Verifica che sul sito **non si possa** iscrivere un pilota senza email | **Non è eseguibile, ed è la risposta giusta**: l'email è la chiave d'ingresso dello Step 1, quindi senza non si arriva nemmeno all'anagrafica. La regola `PILOTA_SENZA_EMAIL` esiste comunque nel database ed è collaudata dal **gestionale** (prova D1 del piano MAUI), dove un pilota senza email si può creare davvero. ⚠️ **La prova era scritta male** (corretta il 2026-09-04): chiedeva di produrre una situazione che il sito rende impossibile per costruzione |
| D2 | Iscrivi un **passeggero** lasciando vuota la sua email | **Consentito**: l'email è obbligatoria solo per chi guida (`SqlScripts/563`), perché è a lui che vanno convocazione e variazioni di programma. Un passeggero che non lascia il proprio indirizzo sta esercitando una scelta legittima. ⚠️ **La prova era scritta male**: diceva «iscrivi la stessa persona come accompagnatore», ma pilota e passeggero **sono due persone diverse** — non si può essere entrambi |
| D3 | Tipo partecipante che richiede i **dati del mezzo**, lasciali vuoti | Rifiutato. ✅ **Passato** il 2026-09-04 |
| D4 | Iscriviti a un viaggio **a cui sei già iscritto** | Rifiutato. ⚠️ Prima il sito non lo controllava affatto. ✅ **Passato** il 2026-09-04 |
| D6 | Iscrivi a un viaggio **in Italia** una persona col documento scaduto | **Avviso**, non blocco (script `576`). Nuovo dal 2026-09-02: prima nessuno guardava la scadenza. ✅ **Passato** il 2026-09-04. **(aggiornato il 2026-09-26: cliente riconosciuto)** Per una persona **in archivio** l'avviso compare già nel riquadro del passo 2 («In albergo i documenti di tutti gli occupanti si presentano per legge»), e «Avanti» passa. ✅ **Passato** il 2026-09-26 (H5b, scheda di prova, AUTUNNO IN GALLURA) |
| D7 | Iscrivi a un viaggio **all'estero** una persona col documento scaduto | **Rifiutato al secondo passo**, appena compilata l'anagrafica: «Il viaggio è all'estero: senza documento valido non si parte». ⚠️ Eseguito il 2026-09-04: **fallito due volte**. Il messaggio era *«Hai già inviato una prenotazione»* (difetto 71), e il rifiuto arrivava **alla conferma finale**, dopo aver compilato mezzi e passeggeri (difetto 72). Da rifare. **(aggiornato il 2026-09-26: cliente riconosciuto)** Per una persona **in archivio** il rifiuto arriva **prima ancora di compilare**: il riquadro del passo 2 mostra in rosso il messaggio del database, il bottone «Modifica i miei dati» è in evidenza e «Avanti» si ferma con lo stesso testo e l'invito al codice. Il documento si aggiorna **solo col codice** (è una modifica). ✅ **Passato** il 2026-09-26 per la persona in archivio (H5, scheda di prova, ANDALUCIA); per un cliente **nuovo** resta da rifare come scritto sopra |
| D7b | Ripeti su un viaggio **in Italia** | **Avviso**, e si prosegue: in Italia il documento scaduto non impedisce di partire, ma l'albergo può rifiutare la registrazione. **(aggiornato il 2026-09-26: cliente riconosciuto)** Per la persona in archivio: avviso nel riquadro, «Avanti» passa. ✅ **Passato** il 2026-09-26 (H5b) |
| D7c | Iscriviti a un viaggio all'estero con un documento **valido** | Nessuna segnalazione: non si disturba chi è a posto. **(aggiornato il 2026-09-26: cliente riconosciuto)** Per la persona in archivio: riquadro pulito, «Useremo i dati che abbiamo già». ✅ **Passato** il 2026-09-26 (H1, ANDALUCIA) |
| D7d | Premi **«Avanti» tre volte** su una scheda che produce un avviso | **Un solo messaggio**, non tre copie impilate (difetto 73). ⚠️ Vale ovunque, non solo qui: se trovi un messaggio che si duplica in un altro punto, è una regressione di quella correzione |
| D8 | Iscrivi qualcuno il cui documento scade **durante** il viaggio | Segnalato lo stesso: non conta se è valido oggi, conta se arriva al rientro. ✅ **Passato** il 2026-09-04. **(aggiornato il 2026-09-26: cliente riconosciuto)** Per una persona in archivio la segnalazione compare nel riquadro del passo 2, con la stessa regola di D7/D7b: da rifare con una scheda in archivio |
| D9 | Prova a iscriverti a una partenza **già conclusa** | **Non è eseguibile dall'interfaccia, ed è la risposta giusta**: l'elenco del primo passo propone solo partenze aperte, quindi una conclusa non si può nemmeno scegliere. La regola nel database resta necessaria come rete — la partenza può concludersi *mentre* qualcuno compila — e come tale è collaudata dal **gestionale** (prova J1 del piano MAUI) |
| D10 | Verifica che il sito **non mostri** partenze concluse fra quelle prenotabili | Non ne mostra. ⚠️ **Fino al 2026-09-04 il filtro era sbagliato** (difetto 75): escludeva le partenze con `effettuato_sino != 'S'`, ma **`'S'` non esiste** — il vincolo ammette solo `Y`, `N`, `P` — quindi non escludeva nulla. Una partenza futura marcata come effettuata (un viaggio annullato, per dire) sarebbe stata proposta e poi rifiutata dopo che la persona aveva compilato tutto. ✅ **Passato** il 2026-09-04 |
| D10b | Nel gestionale marca **effettuata** una partenza **già iniziata**, poi ricarica l'elenco del sito | Quel viaggio **sparisce** dalle proposte, se non ha altre partenze aperte. È la prova che il sito e il database usano la stessa definizione di «iscrivibile». ⚠️ **La prova era scritta male**: diceva di marcare effettuata una partenza *futura*, cosa che dal 2026-09-04 **non è più possibile** — la casella è spenta e il database la rifiuta (difetto 76). Va usata una partenza già cominciata, dove la spunta è legittima. ✅ **Passato** il 2026-09-04 |
| D10c | Guarda se il sito propone una partenza **in corso** (iniziata ieri, finisce domani) | **Non la propone**: a un viaggio già partito non ci si iscrive. ⚠️ Per un giorno lo ha fatto (difetto 75 corretto male), finché non è stato chiarito che il criterio è «non è cominciata», non «non è finita». ✅ **Passato** il 2026-09-04 |
| D5 | Completa un'iscrizione **dall'inizio alla fine** | Arriva a database: cliente, iscrizione, alloggio. ✅ **Passato** il 2026-09-04. **(aggiornato il 2026-09-26: cliente riconosciuto)** Da rifare **con un cliente in archivio e scheda completa**: si arriva in fondo **senza ricompilare nulla** (nessuna chiamata a `/api/cliente/save` al passo 2). Il 2026-09-26 è stato verificato fino al passo 4 (H1, H12); la conferma finale e le mail sono M5 |

---

## E — La posta

La chiave in locale c'è già (vedi il prerequisito): questo gruppo si può eseguire subito.

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| E1 | Riavvia il sito e guarda il log | `Flask-Mail inizializzato da DB (Server=…, Porta=…, Security=…)` |
| E2 | Completa un'iscrizione | Arriva l'email di conferma |
| E3 | Guarda **il mittente** | È il `from_email` dell'azienda con il suo `from_name` — non l'utenza SMTP. Prima queste due colonne erano ignorate |
| E4 | Ripeti con l'altra azienda (`AZIENDA_ID`) | Parte dalla **sua** configurazione: host, porta e mittente diversi |

> Se i test SMTP falliscono per timeout: **spegni la VPN**. Il server di posta blocca gli
> intervalli di indirizzi dei datacenter sulle porte 465/587/993.

---

## F — La prova che conta: i due software concordano

> Dal 2026-09-02 fra le cose da confrontare c'è anche il **documento valido per la partenza**:
> la regola sta in `fn_documento_stato_per_viaggio` e la applicano tutti e due. Iscrivendo dal sito
> e dal gestionale la stessa persona con documento scaduto allo stesso viaggio, la risposta deve
> essere identica — errore all'estero, avviso in Italia.

È il gruppo più importante di entrambi i piani, e va fatto **per ultimo**, con il gestionale e il
sito aperti insieme sullo stesso database.

Per ciascuna riga: inserisci **la stessa anagrafica sbagliata** da tutte e due le parti.

> **(aggiornato il 2026-09-26: cliente riconosciuto)** Sul sito una scheda **in archivio** non si riscrive più senza codice: chi è riconosciuto e
> non modifica non inserisce nulla, quindi non c'è niente da rifiutare. Le righe si eseguono sul
> sito con un **cliente nuovo**, oppure su una scheda in archivio **dopo il codice** («Modifica i
> miei dati»). Senza codice, un dato sbagliato mandato su un campo già pieno viene **ignorato**, non
> rifiutato (H23): non è una differenza col gestionale, è la regola nuova.

| # | Il dato sbagliato | Deve essere rifiutato da entrambi, **con lo stesso messaggio** |
|---|---|---|
| F1 | Email `pippo@` | ✅ / ✅ |
| F2 | Cognome `Z` | ✅ / ✅ |
| F3 | Codice fiscale di una persona già presente | ✅ / ✅. **(aggiornato il 2026-09-26: cliente riconosciuto)** Il sito indica l'email con cui riprendere **mascherata**; se la scheda trovata non ha email, il sito non rifiuta: aggancia l'email e completa soltanto (H33). Il gestionale non ha quel ramo: la differenza è voluta |
| F4 | Cognome e nome invertiti rispetto al codice fiscale | Entrambi chiedono conferma proponendo lo scambio |
| F5 | Titolo `SIG.` con nome `FRANCESCA` | Entrambi mostrano l'avviso, **nessuno dei due blocca** |
| F6 | Documento scaduto | Avviso in entrambi. **(aggiornato il 2026-09-26: cliente riconosciuto)** Vale in Italia; all'estero è un **errore** in entrambi (vedi la nota in cima al gruppo). Per una persona in archivio il sito lo dice già nel riquadro del passo 2 (H5, H5b) |
| F7 | Pilota senza email | Rifiutato in entrambi |
| F8 | Codice fiscale con **carattere di controllo errato** | Rifiutato in entrambi |
| F9 | Iscrizione **doppia** allo stesso viaggio e data | Rifiutata in entrambi |

**Se una riga si comporta diversamente nei due software, è un difetto**, non una differenza
accettabile: dopo questo lavoro le regole sono le stesse righe di codice.

---

## G — Il consenso alla newsletter chiesto durante l'iscrizione (nuovo, 2026-09-04)

Nasce da una decisione commerciale: la newsletter esiste, ma **737 clienti su 744 non
hanno il consenso e nessuno gliel'ha mai chiesto**. L'iscrizione è il momento naturale
per porre la domanda — a patto di porla bene.

> **Le tre cose da guardare in ogni prova**: il popup non deve essere pre-spuntato, non
> deve condizionare l'iscrizione, e non deve ricomparire a chi ha già risposto.

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| G1 | Iscrivi un cliente **già conosciuto** che non ha mai risposto | Superati i controlli della scheda, compare il popup: «Vuoi restare aggiornato?». Nessuna risposta è preselezionata |
| G2 | Rispondi **No, grazie** | L'iscrizione **prosegue identica**. In `ana_clienti` il consenso resta `false`, ma `consenso_marketing_chiesto_data` e `_fonte` sono valorizzate |
| G3 | Rifai l'iscrizione con lo **stesso cliente** | Il popup **non compare più**. È la regola decisa: a chi ha rifiutato non si richiede |
| G4 | Iscrivi un altro cliente e rispondi **Sì** | Consenso `true`, con data e fonte `iscrizione_web`. Il popup non ricompare |
| G5 | Iscrivi un cliente che ha **già** il consenso | Nessun popup: non si chiede ciò che è già stato dato |
| G6 | Iscrivi un cliente che aveva dato il consenso e poi l'ha **revocato** | Nessun popup. ⚠️ È il caso insidioso: per lui la colonna «chiesto» è vuota, ma una risposta l'ha data eccome |
| G7 | Iscrivi un **passeggero** | **Nessun popup**, mai. Il consenso lo deve dare la persona interessata, non il pilota che la sta iscrivendo |
| G7b | Dopo aver iscritto un passeggero, guarda la sua scheda a database | `consenso_marketing_chiesto_data` **vuota**: a lui non ha chiesto nessuno. ⚠️ Fino al 2026-09-04 veniva segnato come già interpellato (difetto 70), e iscrivendosi in prima persona non gli sarebbe più stato chiesto niente |
| G8 | Iscrivi un **cliente nuovo** lasciando la spunta del consenso **vuota** | L'iscrizione va a buon fine, e alla **seconda** iscrizione il popup non compare: la sua risposta era già stata registrata |
| G9 | Iscrivi un cliente nuovo **spuntando** il consenso | Consenso `true` con fonte `iscrizione_web` |
| G10 | Ferma il database e prova a iscriverti | Il popup non compare e **l'iscrizione non si blocca per causa sua**: un consenso non raccolto è un peccato, un'iscrizione persa per un popup è un danno |

## H — Protezione dei dati e cliente riconosciuto (nuovo, 2026-09-26)

Nasce dal disegno `docs/plans/2026-09-25-cliente-riconosciuto-otp-design.md` (repository Flask,
ramo `feature/cliente-riconosciuto`, script `660`–`663`). Una scheda in archivio si tocca in tre
modi: si **usa** (basta essere riconosciuti dall'email), si **completa** (solo i campi vuoti, senza
codice, con una mail di avviso al titolare), si **modifica** (solo dopo un codice usa e getta
mandato alla casella in archivio). Le regole stanno nel database e nel server: le prove «a mano»
con `curl` verificano che valgano anche per chi salta l'interfaccia.

> **Come è stato eseguito il 2026-09-26.** Sito in locale (`npm run build`, `python3 app.py`) sul
> database locale, **senza finti**: Chrome senza finestra pilotato da Playwright per l'interfaccia,
> `curl` con il cookie di sessione per le chiamate a mano. Le schede usate sono **copie usa e getta**
> della 3870 (cognome `PROVAHCOLLAUDO`, email `provah-…@example.invalid`, allergie sostituite da un
> testo sentinella per riconoscerle nelle risposte), con un campo svuotato secondo il caso;
> cancellate alla fine insieme ai loro codici, agli agganci e agli eventi del log (vedi *Pulizia
> finale*). La 3870 non è stata toccata.
>
> ⚠️ **Il codice non è stato letto dalla posta.** Dove serviva un codice giusto, lo ha generato la
> vera `fn_web_otp_genera` chiamata con `psql`, e nel browser la sola richiesta a
> `/api/cliente/otp/richiedi` è stata intercettata e servita con la risposta che dà il server. La
> **verifica**, la scheda, il salvataggio sono tutti reali. Il tratto «la mail parte e arriva» resta
> scoperto, ed è nelle prove M, **da eseguire a mano**.
>
> ⚠️ Con `MAIL_DIROTTA_A` attivo le mail arrivano alla casella di chi collauda, ma l'avviso di
> completamento ha il `reply_to` sull'email **vera** dell'azienda: **non rispondere** a quelle mail.

### H.1 — L'interfaccia: pilota e passeggero

In ogni prova si guardano anche le risposte di rete (`/api/*`): prima del codice nessuna deve
contenere `cf_atteso`, la data di nascita, il codice fiscale o le allergie (H10).

| # | Cosa fai | Cosa deve succedere | Esito |
|---|---|---|---|
| H1 | Passo 1 con l'email di una scheda **completa**, documento valido per la partenza, «Avanti» | Riquadro «Ciao …, ti abbiamo riconosciuto. Useremo i dati che abbiamo già», **nessun campo**. «Avanti» passa al passo 3 (dopo il popup del consenso, se dovuto). **Nessuna** chiamata a `validate-cf`, `/api/cliente/scheda` o `/api/cliente/save` | ✅ 2026-09-26 (scheda di prova 4744, ANDALUCIA) |
| H2 | Scheda cui mancano **solo telefono e prefisso** | Il riquadro dice «Per iscriverti ci mancano: il prefisso internazionale, il numero di telefono» e mostra **solo quei due campi**. Compilati, «Avanti»: il browser manda solo `cliente_id`, `email`, prefisso e telefono, il server risponde `{"completato": true}` (mai *quali* campi), il database li ha. Al titolare parte la mail «Abbiamo completato la tua scheda». Tornando al passo 2 il riquadro è **pulito** («Useremo i dati che abbiamo già») | ✅ 2026-09-26 (4745). La mail è partita (dirottata): il contenuto va guardato a mano, M6 |
| H3a | Scheda senza **data di nascita** ma con il codice fiscale in archivio: scrivi la data e un codice fiscale **sbagliato** | Compaiono data di nascita, età e «Codice Fiscale (facoltativo)» con la nota «serve anche il tuo codice fiscale». Il salvataggio risponde `{"completato": false}`, nulla è scritto, e compare «Non siamo riusciti ad aggiungere la data di nascita. Per aggiornare la scheda usa «Modifica i miei dati»: ti mandiamo un codice per email.» | ✅ 2026-09-26 (4746) |
| H3b | Stessa scheda, codice fiscale **giusto** | `{"completato": true}`, «Abbiamo aggiunto i dati che mancavano alla tua scheda.», si passa al passo 3, la data è a database | ✅ 2026-09-26 (4746) |
| H3c | Scheda senza data di nascita **e** senza codice fiscale, residente **all'estero**: scrivi solo la data | Non si completa (senza codice fiscale la data non ha prova), compare lo stesso invito e il bottone «Modifica i miei dati» passa **in evidenza**: la persona non resta in un vicolo cieco | ✅ 2026-09-26 (4747) |
| H4 | Scheda **completa senza codice fiscale**, pilota residente in Italia | Il riquadro dice «Per iscriverti come pilota manca il codice fiscale… Scrivilo qui sotto» e mostra **solo** il codice fiscale. Compilato giusto, si completa senza codice | ✅ 2026-09-26 (4748) |
| H5 | Documento **scaduto prima della partenza**, viaggio all'estero | Messaggio in rosso nel riquadro, bottone «Modifica i miei dati» **pieno** (non contornato), «Avanti» si **ferma** con lo stesso testo e l'invito al codice | ✅ 2026-09-26 (4749, ANDALUCIA). ⚠️ Osservazione: il testo del database è «**Il cliente documento scaduto il** 15/01/2026, prima della partenza…», sgrammaticato; e mostra la **data di scadenza del documento** a chiunque conosca l'email. Da decidere se va bene |
| H5b | Stessa scheda, viaggio **in Italia** | Avviso nel riquadro (documenti in albergo), «Avanti» passa | ✅ 2026-09-26 (4749, AUTUNNO IN GALLURA) |
| H6 | «Modifica i miei dati» → «Mandami il codice» → codice **sbagliato** → codice **scaduto** → «Mandane un altro» → codice giusto | «Codice mandato a p\*\*\*@…», «Sono 8 cifre e il codice vale 5 minuti»; poi «Codice sbagliato. Controlla e riprova.»; poi «Il codice è scaduto: chiedine uno nuovo.»; col nuovo codice la finestra si chiude e si apre il **modulo compilato**, con **prefisso** e **allergie** | ✅ 2026-09-26 (4744), con il codice preso dal database (vedi nota sopra). Col codice vero: M1 |
| H6b | Scheda la cui email l'ha **agganciata il sito** (script 662): «Modifica i miei dati» → «Mandami il codice» | `409`, la finestra dice «Per questa scheda il codice non si può mandare: per modificare i dati contatta l'organizzazione.» e il bottone «Mandami il codice» **sparisce** (resta «Chiudi»). Nessun codice generato a database | ✅ 2026-09-26 (4750). Nota: il bottone «Modifica i miei dati» del riquadro resta, e riaprendolo si rifà la stessa richiesta con lo stesso esito |
| H7 | Dopo il codice modifica un campo, ma con il permesso **scaduto** (30 minuti) | Il salvataggio risponde `{"completato": false}` e non scrive nulla; avviso «Il permesso di modificare la scheda è scaduto e le correzioni non sono state salvate: chiedi un nuovo codice…», la finestra del codice **si riapre**, la correzione **resta a video** | ✅ 2026-09-26 (4744): l'età del permesso è stata portata a 31 minuti riscrivendo il cookie di sessione con la chiave del `.env` locale. Con l'attesa vera: M3 |
| H8 | Cliente **nuovo**: compila il passo 2, «Avanti», poi «Indietro» | Il modulo torna **compilato e modificabile**, **senza** riquadro; `/api/cliente/scheda` risponde 200 (scheda creata in questa sessione) | ✅ 2026-09-26 (scheda creata dal test, poi cancellata) |
| H9 | Con il passo 2 aperto su una scheda riconosciuta, in un'**altra scheda del browser** cambia l'email al passo 1; poi nella prima premi «Avanti» | `403` dal salvataggio, «Non ti riconosciamo più in questa sessione: ricominciamo dal primo passo…», ritorno al passo 1, niente scritto | ✅ 2026-09-26 (4747). Nella **stessa** scheda del browser, «Indietro», cambio email e «Avanti» il passo 2 si ricarica sulla nuova persona: nessun 403 serve, ed è giusto |
| H10 | In tutte le prove sopra, prima del codice, cerca nelle risposte `cf_atteso`, data di nascita, codice fiscale, allergie | Nessuna risposta li contiene | ✅ 2026-09-26 |
| H11 | Esaurisci le ricerche (più di 20 in un minuto dallo stesso indirizzo), poi passo 1 → «Avanti» | Il pilota **non** diventa un cliente nuovo: niente modulo vuoto, compare «Troppe ricerche in questa sessione: riprova fra poco.», «Avanti» si ferma **con quel messaggio** | ❌ 2026-09-26, **difetto minore**: tutto giusto tranne il messaggio di «Avanti», che è «❌ Per procedere devi compilare tutti i campi obbligatori (contrassegnati con \*)» — su una pagina dove campi non ce ne sono. Il wizard chiama `triggerValidation()` (StepWizard, verso riga 567) **prima** di `handleSaveCliente`, che è dove sta il messaggio di `caricamentoFallito` (Step2Content, verso riga 2446). Probabile lo stesso col database fermo (H11b) |
| H11b | Come H11, ma col **database fermo** al momento del riconoscimento (503) | Come H11, con il messaggio del database irraggiungibile | **Da eseguire a mano**: il container locale è condiviso, non è stato fermato |
| H12 | Passo 3, un passeggero **in archivio** con scheda completa: «Verifica», poi «Avanti» senza aprirlo, poi «Apri Anagrafica» | La riga dice «In archivio»; «Avanti» si ferma: «Il passeggero 1 è in archivio ma non è ancora confermato…». La finestra dice «… è già in archivio: useremo i suoi dati. Non serve ricompilare niente», nessun campo; «Usa i dati in archivio» → «Avanti» porta al passo 4, in sessione c'è il suo id | ✅ 2026-09-26 (4751) |
| H13 | Passeggero con scheda **incompleta** (manca la data di nascita) | Testi in terza persona («Per il viaggio di … ci mancano: la data di nascita»), solo data e codice fiscale facoltativo, bottone «Aggiungi i dati mancanti» | ✅ 2026-09-26 (4747), solo la visualizzazione: il salvataggio è lo stesso endpoint di H2–H4 e non è stato ripetuto per non mandare un'altra mail |
| H14 | Passeggero con documento **scaduto**, viaggio all'estero: «Usa i dati in archivio» | La finestra **non si chiude**; avviso col messaggio del documento e «Per aggiornare la scheda usa «Modifica i dati di …»: mandiamo un codice alla sua email.» | ✅ 2026-09-26 (4749) |
| H15 | Passeggero: «Modifica i dati di …» | «Per sicurezza mandiamo un codice alla casella email di …: chiediglielo e inseriscilo qui.» | ✅ 2026-09-26 (testo). Il codice vero alla casella del passeggero: M2 |

### H.2 — Le chiamate a mano (`curl`)

Si prepara una sessione come farebbe il browser (viaggio, data, email al passo 1, profilo del
pilota), poi si chiama l'endpoint con il cookie. Esempio:

```bash
curl -s -c j -b j -X POST http://127.0.0.1:5001/api/cliente/save -H 'Content-Type: application/json' \
     -d '{"cliente_id": <id NON riconosciuto in questa sessione>, "indirizzo_residenza": "X"}'
# atteso: 403 «Scheda non riconosciuta in questa sessione.»
```

Per dire «non cambia nulla» si confronta l'impronta della riga prima e dopo:
`SELECT md5(row(c.*)::text) FROM ana_clienti c WHERE cliente_id = …`.

| # | Cosa fai | Cosa deve succedere | Esito |
|---|---|---|---|
| H20 | `POST /api/session/pilota` con l'id di una scheda **non** riconosciuta | `403` «Scheda non riconosciuta in questa sessione.»; con l'id riconosciuto `200` | ✅ 2026-09-26 |
| H21 | `POST /api/session/passeggero` con un id qualunque | `403` | ✅ 2026-09-26 |
| H22 | `POST /api/cliente/save` con il `cliente_id` di **un altro** e dati diversi | `403`; impronta della riga invariata | ✅ 2026-09-26 |
| H23 | `POST /api/cliente/save` con l'id **riconosciuto**, **senza codice**, indirizzo e telefono diversi da quelli (pieni) in archivio | `200 {"completato": false}`: **nessun campo pieno sovrascritto**, impronta invariata | ✅ 2026-09-26 |
| H24 | `GET /api/cliente/scheda` senza codice; poi con il codice verificato per **un altro** cliente della stessa sessione; poi con il suo | `403` «Per vedere la scheda serve il codice.», `403`, `200` | ✅ 2026-09-26 |
| H25 | `POST /api/validate-cf` con `client_id` riconosciuto ma non sbloccato; con uno non riconosciuto | `403` in entrambi i casi, nessun `cf_atteso` | ✅ 2026-09-26 |
| H26 | `GET /api/cliente/consenso/da-chiedere` e `POST /api/cliente/consenso/risposta` con un id non riconosciuto | `403` | ✅ 2026-09-26 |
| H27 | `POST /api/cliente/otp/richiedi` e `/verifica` con un id non riconosciuto | `403` | ✅ 2026-09-26 |
| H28 | Pilota e passeggero riconosciuti **non sbloccati**: `GET /api/session/summary`, `/api/final-summary`, `/api/partecipanti`, `/api/session/all` | Solo id, cognome e nome: **nessuna** email altrui, data di nascita, codice fiscale, telefono, numero di documento, allergia | ✅ 2026-09-26 |
| H29 | Come H28, poi codice verificato per il **pilota** | `/api/final-summary` mostra le allergie **del pilota** e non quelle del passeggero (che non ha sbloccato niente); `/api/session/summary` nessuna. Nelle mail di conferma ognuno vede **solo le sue** | ✅ 2026-09-26 la parte del riepilogo. Le mail: coperte da `tests/test_intolleranze.py`; a mano con M5 |
| H30 | Scheda con email **agganciata dal sito** (`web_email_agganciate`): `POST /api/cliente/otp/richiedi` | `409` con `email_non_verificata: true`, nessun codice generato, nessuna mail | ✅ 2026-09-26 |
| H31 | Il codice (generato con `fn_web_otp_genera`, verificato con `/api/cliente/otp/verifica`) | **8 cifre**; scadenza a **5 minuti** dalla creazione; giusto → `OK`; **riusato** → `NESSUN_CODICE`; due sbagliati → `ERRATO`, il **terzo** → `TENTATIVI_ESAURITI`, e dopo anche quello giusto è rifiutato; oltre la scadenza → `SCADUTO` | ✅ 2026-09-26 |
| H32 | I tetti: tre richieste negli ultimi 15 minuti, poi `POST /otp/richiedi`; dieci richieste nella giornata (nessuna negli ultimi 15 minuti), poi di nuovo | `429` «Hai già chiesto diversi codici: riprova più tardi.» in **entrambi** i casi, con lo stesso testo (non dice quale tetto); nessuna mail | ✅ 2026-09-26 |
| H33 | Scheda **senza email** in archivio: al passo 2 salva come cliente nuovo gli stessi dati anagrafici, più telefono (vuoto in archivio) e un'email | Il controllo sui doppioni la ritrova, le **aggancia** l'email e la **completa** soltanto (`completato: true`, `scheda_ritrovata: true`, scritta da `sito:completa`). Poi `/api/cliente/scheda` → `403` e la richiesta del codice → `409` (email non verificata): **completare sì, vedere e modificare no**. Un secondo salvataggio con un indirizzo diverso non lo sovrascrive | ✅ 2026-09-26 (scheda 4752). Nota: il disegno (§5) diceva «l'OTP sblocca il completare»; con lo script 662 il completare non chiede codice e il codice su un'email agganciata non parte. Il risultato che conta — non si vede e non si modifica — è quello |
| H34 | Codice verificato, poi `POST /api/cliente/save` con un indirizzo diverso | `200 {"success": true}` e l'indirizzo **cambia** a database: col codice si modifica | ✅ 2026-09-26 |

### H.3 — Da eseguire a mano (serve un codice vero, o la posta)

Le mail vanno alla casella di `MAIL_DIROTTA_A`. Si può usare la propria scheda **3870** (azienda 2,
ha email): **annotare prima** i valori che si cambiano e rimetterli dopo, dal gestionale o col
codice. Aprire i DevTools, pannello Network.

| # | Cosa fai | Cosa deve succedere | Esito |
|---|---|---|---|
| M1 | Passo 1 con l'email della 3870 → «Modifica i miei dati» → «Mandami il codice». Leggi la mail, scrivi il codice, «Verifica». Cambia un campo (es. l'indirizzo), «Avanti» → «Salva Modifiche». Poi rimetti il valore com'era, allo stesso modo | Arriva **una** mail «Il tuo codice per l'iscrizione» con **8 cifre**; nella finestra «Codice mandato a v\*\*\*@…». Dopo la verifica il modulo è **compilato**, prefisso (**+27**, prova C13d) e allergie compresi. Il salvataggio risponde `{"success": true}` **senza** `completato`, e il gestionale mostra il campo cambiato | Da eseguire a mano |
| M2 | Passo 3, passeggero con una **sua** email in archivio → «Apri Anagrafica» → «Modifica i dati di …» → «Mandami il codice» | La mail parte verso la casella **del passeggero** (col dirottamento arriva a te: nel log di Flask la riga `[MAIL] DIROTTATA` nomina come destinatario originale l'email del passeggero, non quella del pilota). Col codice il modulo del passeggero si apre compilato | Da eseguire a mano |
| M3 | Come M1, ma dopo la verifica **aspetta più di 30 minuti**, poi cambia un campo e «Avanti» | Come H7: avviso «Il permesso di modificare la scheda è scaduto…», finestra del codice riaperta, correzione a video, niente scritto | Da eseguire a mano |
| M4 | Chiedi un codice, **aspetta 6 minuti**, scrivilo. Poi «Mandane un altro» due volte, poi una terza | Prima «Il codice è scaduto: chiedine uno nuovo.»; ogni «Mandane un altro» fa arrivare una mail nuova e **solo l'ultimo codice vale**; la **quarta** richiesta nel quarto d'ora dà «Hai già chiesto diversi codici: riprova più tardi.» e **nessuna** mail | Da eseguire a mano |
| M5 | Iscrizione completa, fino alla conferma, con un pilota in archivio a scheda completa e un passeggero in archivio, **senza modificare** nulla; il pilota con un'allergia e il passeggero con un'altra | L'iscrizione va a buon fine senza aver ricompilato nulla (D5). Nelle mail di conferma **ognuno vede solo la sua** allergia; nel riepilogo finale a video, prima del codice, nessuna allergia. Poi annullare l'iscrizione dal gestionale | Da eseguire a mano |
| M6 | Nella casella di collaudo, le mail «**Abbiamo completato la tua scheda**» del 2026-09-26 alle 09:17, 09:20, 09:22 e 09:23 (le hanno mandate H33, H2, H3b e H4) | Ognuna elenca **quali campi** sono stati aggiunti, **senza i valori**: prefisso e telefono (09:17 e 09:20), data di nascita (09:22), codice fiscale (09:23). Il mittente è l'utenza SMTP del sito; «Rispondi» va all'email principale dell'azienda. ⛔️ Quindi **non rispondere**: arriverebbe all'azienda vera | Da eseguire a mano |
| M7 | H11b: database fermo quando il passo 2 legge il profilo | Vedi H11b | Da eseguire a mano |


---

## Pulizia finale

```sql
SELECT cliente_id, cliente_cognome, cliente_nome FROM ana_clienti WHERE cliente_cognome LIKE 'ZZ%';
```

Dopo il gruppo H (le schede di prova hanno cognome `PROVAHCOLLAUDO`; eseguito il 2026-09-26, al
termine tutte le query sotto davano zero righe):

```sql
BEGIN;
SELECT set_config('my.app_user', 'test:collaudo-H', true);
DELETE FROM web_otp_codici       WHERE cliente_id IN (SELECT cliente_id FROM ana_clienti WHERE cliente_cognome = 'PROVAHCOLLAUDO');
DELETE FROM web_email_agganciate WHERE cliente_id IN (SELECT cliente_id FROM ana_clienti WHERE cliente_cognome = 'PROVAHCOLLAUDO');
-- gli eventi CLIENTE_CREATED/DELETED che i trigger scrivono per queste schede
DELETE FROM ana_business_events  WHERE entity_table = 'ana_clienti'
   AND entity_id IN (SELECT cliente_id FROM ana_clienti WHERE cliente_cognome = 'PROVAHCOLLAUDO');
DELETE FROM ana_clienti          WHERE cliente_cognome = 'PROVAHCOLLAUDO';
COMMIT;
-- e poi gli eventi CLIENTE_DELETED appena scritti dalla cancellazione:
DELETE FROM ana_business_events WHERE entity_table = 'ana_clienti' AND description LIKE '%PROVAHCOLLAUDO%';
```

---

## Una questione aperta, che non è un test

**Chi spunta il consenso per un passeggero è chi compila l'iscrizione, non il passeggero stesso.**

La spunta c'è per ciascun partecipante, come deciso, e i test del gruppo B lo verificano. Ma resta
un problema di sostanza che nessun test può chiudere: un consenso dato da altri vale poco. Se il
passeggero ha un'email propria, la strada pulita è chiederlo a lui — un doppio opt-in, o una
richiesta separata dopo l'iscrizione.

Va deciso, non collaudato. È annotato qui perché è emerso proprio scrivendo le prove sul consenso,
ed è il tipo di cosa che si perde se resta in una conversazione.

---

## Cosa questo piano NON copre

- **PROD.** Il sito non va puntato là finché gli script non sono applicati: scriverebbe su uno
  schema che non rispetta, e quei dati non si sistemano più.
- **`Step2Content copy.jsx`**: file morto, non collegato a nulla. Non è stato toccato — va
  eliminato, ma è una decisione separata.
- **Il ricalcolo dei prezzi e la parte pagamenti**, estranei a questo lavoro.
