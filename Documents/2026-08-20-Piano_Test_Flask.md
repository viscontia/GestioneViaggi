# Piano di test — Sito di iscrizione (Flask + React)

**Data:** 2026-08-20
**Repository:** `Iscrizione-Viaggi-Offroad PostgreSQL`, ramo `feature/controlli-centralizzati`
**Ambiente:** `./avvia-locale.sh` (DB Docker locale), script `538`–`569` applicati
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
| A1 | Apri l'iscrizione, arriva ai dati anagrafici | La tendina **Titolo** mostra `SIG.` per primo, poi `SIG.RA`, poi gli altri |
| A2 | Scegli **SIG.RA** | Il campo **Sesso** passa a F **da solo** |
| A3 | Prova a modificare il campo Sesso a mano | **Non si può**: è disabilitato |
| A4 | Scegli **SIG.**, poi cambia in **DOTT.SSA** | Il sesso segue: M, poi F |
| A5 | Riprendi l'iscrizione con l'email di un cliente **già esistente** | Il suo titolo viene **ritrovato e selezionato**, non resta vuoto |

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
| B1 | Guarda il modulo anagrafico | C'è una spunta per il consenso all'invio di comunicazioni |
| B2 | Osservala all'apertura | **Non è pre-spuntata** |
| B3 | Confrontala con l'accettazione delle condizioni | Sono **due spunte distinte**: sono due consensi diversi |
| B4 | Compila **senza** spuntarla e salva | Si salva; a database `consenso_marketing` resta `false` |
| B5 | Spuntala e salva | A database: `true`, con **data** e **fonte `SITO_ISCRIZIONE`** |
| B6 | Aggiungi un **passeggero** e guarda il suo modulo | Ha **la sua** spunta: il consenso è personale, non del capogruppo |
| B7 | Riapri un cliente esistente che **aveva già** dato il consenso e salva senza toccare la spunta | Il consenso **resta acceso**. Se si spegnesse, si starebbe falsificando un dato |
| B8 | Completa un'iscrizione **senza** spuntare il consenso | A DB consenso falso, e **nessuna data, nessuna fonte**: non c'è nulla da dimostrare |
| B9 | Entra con l'email di un cliente **esistente** | Titolo **ritrovato** nella tendina e spunta del consenso **com'era**. ⚠️ Sono le due regressioni chiuse col `557`: senza, il titolo restava vuoto e il consenso si sarebbe spento da solo al primo salvataggio |
| B9b | Riprendi con un cliente che **ha il consenso** e apri «Modifica Anagrafica» | La spunta è **segnata**. ⚠️ Fino al 2026-09-02 arrivava sempre spenta: l'endpoint `/api/cliente/dati` costruisce la risposta a mano, chiave per chiave, e `consenso_marketing` non era fra quelle ricopiate — pur essendo restituito dal database e dal DAO (`SqlScripts/557`). Salvando si sarebbe spento un consenso che nessuno aveva revocato |

---

## C — I controlli, gli stessi del gestionale

Il sito chiama `/api/cliente/valida`, che è `fn_ana_clienti_valida`: **la stessa funzione** che il
gestionale invoca da `ValidaAsync`. Qui si verifica che i messaggi arrivino davvero all'utente.

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| C1 | Titolo **SIG.**, nome **FRANCESCA**, **scheda completa**, prosegui | Compare l'avviso giallo nome/sesso, e **si può andare avanti** |
| C1b | Lo stesso, ma con la **scheda incompleta** (solo titolo e nome) | Compaiono **sia** l'avviso giallo **sia** l'elenco dei dati mancanti — in **un solo** messaggio, non nove sovrapposti. ⚠️ Corretto il 2026-09-01: gli avvisi venivano scartati appena c'era un errore, e da quando i documenti sono obbligatori una scheda in compilazione un errore ce l'ha quasi sempre. L'avviso nome/sesso era quindi diventato invisibile |
| C2 | Titolo **SIG.**, nome **ANDREA** | Nessun avviso |
| C3 | Inserisci un'**email scritta male** e salva | Messaggio rosso leggibile in italiano. **Non** deve comparire «Esiste già una anagrafica con questo Codice Fiscale», né testo tipo `CONTEXT: PL/pgSQL function…` |
| C3b | Con l'email scritta male, guarda la spunta del **consenso** | **Non si accende**, e lo dice: «Serve prima un indirizzo email valido». Un consenso dato su un indirizzo malformato è una riga che al primo invio risulta irraggiungibile. Resta però sempre **spegnibile** anche con l'email non valida: una revoca non si nega mai |
| C3c | Riprendi l'iscrizione con un cliente **che ha già il consenso** e cambiagli l'email | Stesso avviso del gestionale, accanto alla spunta. Il consenso resta acceso e la sua data non cambia |
| C4 | Inserisci un **cognome di un carattere** ed esci dal campo | «Il cognome deve avere almeno 2 caratteri.», **subito sul campo**. ⚠️ Fino al 2026-09-02 il sito non conosceva quella regola — il suo controllo guardava solo che il campo non fosse vuoto — e lasciava proseguire fino al modale «Vuoi salvare le modifiche?», con il rifiuto che arrivava **dopo** la conferma |
| C4b | Stessa cosa con un **nome** di un carattere | Stesso comportamento |
| C5b | Metti una **data di rilascio del documento nel futuro** | «La data di rilascio non può essere nel futuro», subito sul campo. ⚠️ Fino al 2026-09-02 il ramo di controllo per le date del documento era **vuoto** — solo commenti — e il rifiuto arrivava dal database al salvataggio |
| C5c | Metti una **scadenza già passata** | **Passa** (un documento scaduto va registrato lo stesso, semmai rinnovato), e accanto agli «Anni residui di validità» compare in rosso «**Documento scaduto il gg/mm/aaaa**». ⚠️ Fino al 2026-09-02 quel campo diventava rosso **senza una parola di spiegazione** |
| C5d | Metti una scadenza **fra sei mesi** | Il campo si colora, e il testo dice «**Scade il gg/mm/aaaa, fra meno di un anno**». ⚠️ Prima scaduto e in-scadenza erano identici: `calcolaAnniResiduiDocumento` restituisce `'0'` in entrambi i casi, quindi lo stesso rosso per due situazioni molto diverse |
| C5 | Digita il codice fiscale mettendo **cognome e nome invertiti** | **Rifiutato** (dal 2026-09-01, script `565`): «Nome e cognome sembrano invertiti: il codice corrisponde leggendo X come cognome e Y come nome. **Scambia i due campi prima di proseguire**». Non c'è più nessuna conferma da accettare, e nessuno scambio automatico da attendersi |
| C6 | **Scambia davvero** i due campi come dice il messaggio | Il salvataggio va a buon fine. ⚠️ Fino al 2026-08-31 questa prova chiedeva di *confermare* l'incongruenza e salvarla: non è più possibile, per nessuna via |
| C7 | Usa il codice fiscale di una persona **già iscritta** | Bloccato con «Questo codice fiscale risulta già registrato». ⚠️ Il messaggio **non dice più di chi sia** (`566`, `569`): verifica che il sito continui a indicare da sé **l'email con cui riprendere** l'iscrizione, perché quell'indicazione è sua e non del database |
| C8 | Verifica quanto restano a video i messaggi | Errori e avvisi restano **8 secondi**, non un lampo |
| C9 | Ripeti C1, C3 e C5 **su un passeggero** (Step 3) | Stessi comportamenti: un passeggero non è un cliente di serie B |
| C10 | ⭐ Iscrivi un **passeggero** lasciando vuoti i dati del documento | **Rifiutato** (`563`): i documenti servono a ogni occupante della stanza, per legge, e il sito oggi al passeggero non chiede niente. Guarda **come** arriva il rifiuto: leggibile? dice quali campi? |
| C11 | Prosegui con un **cliente già riconosciuto** la cui scheda è incompleta, senza premere «Modifica Anagrafica» | **Rifiutato** all'iscrizione. È il caso che il sito non guarda affatto: `triggerValidation()` esce subito con `isValid: true` |
| C12 | Spunta il consenso lasciando **vuota l'email** | Rifiutato (`568`). Sul sito l'email è la chiave d'ingresso, quindi potrebbe non essere raggiungibile: se non riesci a produrre il caso, annotalo e passa oltre |

---

## D — Iscrizione al viaggio

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| D1 | Iscrivi come **pilota** una persona senza email | Rifiutato, con il nome di chi correggere. ⚠️ Qui il nome **resta** di proposito: è la persona che stai iscrivendo tu, non un estraneo, e senza quel nome non sapresti di chi si parla iscrivendone più d'uno |
| D2 | Iscrivi la stessa persona come **accompagnatore** | Consentito |
| D3 | Tipo partecipante che richiede i **dati del mezzo**, lasciali vuoti | Rifiutato |
| D4 | Iscriviti a un viaggio **a cui sei già iscritto** | Rifiutato. ⚠️ Prima il sito non lo controllava affatto |
| D5 | Completa un'iscrizione **dall'inizio alla fine** | Arriva a database: cliente, iscrizione, alloggio |

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

È il gruppo più importante di entrambi i piani, e va fatto **per ultimo**, con il gestionale e il
sito aperti insieme sullo stesso database.

Per ciascuna riga: inserisci **la stessa anagrafica sbagliata** da tutte e due le parti.

| # | Il dato sbagliato | Deve essere rifiutato da entrambi, **con lo stesso messaggio** |
|---|---|---|
| F1 | Email `pippo@` | ✅ / ✅ |
| F2 | Cognome `Z` | ✅ / ✅ |
| F3 | Codice fiscale di una persona già presente | ✅ / ✅ |
| F4 | Cognome e nome invertiti rispetto al codice fiscale | Entrambi chiedono conferma proponendo lo scambio |
| F5 | Titolo `SIG.` con nome `FRANCESCA` | Entrambi mostrano l'avviso, **nessuno dei due blocca** |
| F6 | Documento scaduto | Avviso in entrambi |
| F7 | Pilota senza email | Rifiutato in entrambi |
| F8 | Codice fiscale con **carattere di controllo errato** | Rifiutato in entrambi |
| F9 | Iscrizione **doppia** allo stesso viaggio e data | Rifiutata in entrambi |

**Se una riga si comporta diversamente nei due software, è un difetto**, non una differenza
accettabile: dopo questo lavoro le regole sono le stesse righe di codice.

---

## Pulizia finale

```sql
SELECT cliente_id, cliente_cognome, cliente_nome FROM ana_clienti WHERE cliente_cognome LIKE 'ZZ%';
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
