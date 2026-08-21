# Piano di test — Sito di iscrizione (Flask + React)

**Data:** 2026-08-20
**Repository:** `Iscrizione-Viaggi-Offroad PostgreSQL`, ramo `feature/controlli-centralizzati`
**Ambiente:** `./avvia-locale.sh` (DB Docker locale), script `538`–`562` applicati
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

---

## C — I controlli, gli stessi del gestionale

Il sito chiama `/api/cliente/valida`, che è `fn_ana_clienti_valida`: **la stessa funzione** che il
gestionale invoca da `ValidaAsync`. Qui si verifica che i messaggi arrivino davvero all'utente.

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| C1 | Titolo **SIG.**, nome **FRANCESCA**, prosegui | Compare l'avviso giallo nome/sesso, e **si può andare avanti** |
| C2 | Titolo **SIG.**, nome **ANDREA** | Nessun avviso |
| C3 | Inserisci un'**email scritta male** e salva | Messaggio rosso leggibile in italiano. **Non** deve comparire «Esiste già una anagrafica con questo Codice Fiscale», né testo tipo `CONTEXT: PL/pgSQL function…` |
| C4 | Inserisci un **cognome di un carattere** | «Il cognome deve avere almeno 2 caratteri.» |
| C5 | Digita il codice fiscale mettendo **cognome e nome invertiti** | Compare la richiesta di conferma che propone lo scambio; rifiutando **non** si prosegue |
| C6 | Accetta la conferma del punto C5 | Il salvataggio va a buon fine |
| C7 | Usa il codice fiscale di una persona **già iscritta** | Bloccato, con l'indicazione dell'email da usare |
| C8 | Verifica quanto restano a video i messaggi | Errori e avvisi restano **8 secondi**, non un lampo |
| C9 | Ripeti C1, C3 e C5 **su un passeggero** (Step 3) | Stessi comportamenti: un passeggero non è un cliente di serie B |

---

## D — Iscrizione al viaggio

| # | Cosa fai | Cosa deve succedere |
|---|---|---|
| D1 | Iscrivi come **pilota** una persona senza email | Rifiutato, con il nome di chi correggere |
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
