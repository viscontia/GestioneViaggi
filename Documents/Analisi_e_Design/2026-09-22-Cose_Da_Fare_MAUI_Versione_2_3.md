# Cose da fare su MAUI — versione 2.3

> **USO INTERNO.** Aperto il 2026-09-22, dopo la consegna della 2.2.
> Raccoglie le idee nate lavorando, con il **perché** di ognuna: senza quello, fra tre mesi
> resta solo un elenco di funzioni che nessuno sa più valutare.

---

## Il filo che le tiene insieme

Antonio passa **quasi tutte le giornate in viaggio con i clienti**. Quando è a casa prepara i
nuovi viaggi, tiene i conti, fa le fatture, scarica foto e filmati — e in mezzo a tutto questo
deve anche trovare il tempo per il gestionale.

⭐️ Le tre voci qui sotto nascono tutte dalla stessa constatazione: **il programma non deve
aspettare che uno si ricordi di fare una cosa.** Deve dirgliela lui, nel momento in cui apre, e
portarcelo con un clic.

---

## 1. Il promemoria all'apertura ⭐️ *(la più importante)*

**Cosa.** All'avvio del gestionale compare una finestra con una **tabella delle cose rimaste in
sospeso**. Ogni riga ha un bottone che porta **dritto alla funzione** che la risolve.

**Le righe, per cominciare:**

| Cosa segnala | Perché è in sospeso | Dove porta il bottone |
|---|---|---|
| Viaggi **già passati** e non segnati come effettuati | Falsa i conti e le statistiche, e resta lì per sempre | Anagrafica Viaggi e Date, su quella partenza |
| Partenze future **senza scheda web** | Senza scheda il tour **non esiste** per il sito | Viaggio → Contenuti Web |
| Partenze future **con scheda in bozza** | Pronta ma invisibile: è il caso più frustrante | Viaggio → Contenuti Web |
| Partenze future **senza newsletter** | Un viaggio che nessuno sa che esiste non si riempie | Newsletter → nuova, già agganciata a quella partenza |
| Viaggi **senza capienza o senza soglia** | Il sito non può scrivere «rimangono N posti» | Viaggio → Dati Generali |
| Schede web **senza fotografie** | Non sono pubblicabili: diventerebbero caselle grigie | Viaggio → Contenuti Web → Galleria |
| Clienti con **scheda incompleta** | Bloccano l'iscrizione e la schedina alloggiati | Anagrafica Clienti, su quel cliente |
| Documenti **scaduti o in scadenza** per partenze vicine | Si scopre all'imbarco, ed è tardi | Partecipanti della partenza |

⚠️ **Vincoli, dalle lezioni già imparate:**
- la finestra **non si chiude cliccando fuori, né con Esc, né con la rotella** — vale la regola
  introdotta nella 2.2, e qui a maggior ragione: è la prima cosa che si vede;
- deve avere un **«non mostrarmelo più oggi»**, o alla terza volta diventa un fastidio da
  chiudere a occhi chiusi — ed è così che i promemoria smettono di funzionare;
- **se non c'è niente in sospeso, non deve comparire affatto.** Una finestra che dice «tutto a
  posto» è una finestra che insegna a chiuderla senza leggerla.

**Perché.** È insieme un promemoria e una lista di cose da fare, costruita su quello che il
database **già sa**. Nessuna di queste domande richiede un dato nuovo: sono tutte interrogazioni
su ciò che c'è.

ℹ️ **Nota di progetto:** ogni riga è una funzione di database che risponde «quanti e quali».
Così la stessa lista potrà un giorno comparire anche altrove (una mail del lunedì mattina, per
dire) senza riscrivere niente.

---

## 2. Dopo una data nuova, la scheda web

**Cosa.** Quando si salva una **data viaggio nuova**, compare una domanda: *«Vuoi preparare
subito la scheda web di questa partenza?»*. Rispondendo **sì** si finisce direttamente nella
schermata dei contenuti web, sulla partenza appena creata.

**Perché.** È il momento in cui si ha in testa il viaggio — le date, il percorso, cosa lo rende
diverso dagli altri. Tornarci tre settimane dopo significa ricostruire tutto da capo, e infatti
oggi **otto schede su otto sono rimaste in bozza**.

⚠️ La domanda va fatta **solo per le partenze future**: su una data passata inserita per
storico sarebbe rumore.

---

## 3. Calendario: scegliere quanto guardare avanti

**Cosa.** Nel calendario delle partenze, una tendina per l'**arco temporale**: 3 mesi · 6 mesi ·
1 anno (oltre al mese singolo di oggi).

**Perché.** Il mese da solo risponde a «cosa c'è adesso», ma le domande vere di un tour
operator sono altre: *dove sono i buchi da riempire?* e *dove si accavallano due partenze?*.
Sono domande che si vedono solo su un arco lungo.

ℹ️ La scelta va **ricordata**: chi ragiona a sei mesi ci ragiona sempre. C'è già
`sys_utente_preferenze` per questo.

ℹ️ Su un anno intero le partenze diventano tante: probabilmente serve una vista più compatta
(una barra per partenza invece della casella piena). Da guardare quando ci si mette mano.

---

## Ordine consigliato

1. **Il promemoria all'apertura** — è quello che cambia la giornata di lavoro, e riusa cose che
   ci sono già.
2. **La domanda dopo la data nuova** — piccola, e attacca il problema delle schede in bozza
   alla radice invece che a valle.
3. **L'arco del calendario** — comoda, ma nessuno è bloccato senza.

*(Le idee messe da parte durante i test restano in `2026-09-05-Prossime_Funzioni.md`; questo
documento raccoglie solo quelle nate dopo la 2.2.)*

---

## Già nel codice, da portare con la 2.3

⚠️ Al rilascio `ApplicationDisplayVersion` passa da **2.2 a 2.3** (`GestioneViaggi.csproj`).

| Cosa | Dove |
|---|---|
| **Foto HEIC dell'iPhone**: ImageSharp non le leggeva («Image cannot be loaded. Available decoders…», Antonio, 2026-09-26). Ora si convertono con Magick.NET su Windows e ImageIO sul Mac; un formato illeggibile dice «Salva la foto come JPEG o PNG». ⏳ Da provare dentro il gestionale su Windows (il pacchetto si installa solo lì) | `WebImageProcessor.cs`, commit `d8513f2` |

---

## Legato al sito pubblico

Il sito pubblico (**Fuori Traccia Travel**, `fuoritracciatravel.com`) ha il suo elenco gemello:
`../../../../Sito Web SFT/Documenti/2026-09-25-Cose_Da_Fare_Sito.md`. Le voci che toccano tutti
e due i progetti hanno lo **stesso codice** in entrambi i documenti. ⛔️ Quando una si chiude, si
chiude in tutti e due. Il dettaglio sta dove vive la cosa, l'altro documento lo riassume e rimanda.

| Codice | Cosa, in una riga | Dettaglio |
|---|---|---|
| **L1** | I titoli dei tour arrivano al sito in MAIUSCOLO (`viaggio_descrizione_breve`, forzato in maiuscolo). ✅ Deciso il 2026-09-25: **nessuna modifica al gestionale**, li converte il codice del sito | Sito |
| **L2** | Il promemoria all'apertura: quattro righe servono al sito (bozza, senza scheda, senza foto, senza capienza) | Qui, §1 |
| **L3** | La scheda web proposta dopo una data nuova | Qui, §2 |
| **L4** | Dati personali nel sito Flask: ✅ rubinetto in produzione dal 2026-09-21 (script 651). ✅ Disegno nuovo approvato il 2026-09-25: chi è riconosciuto usa la sua scheda senza ricompilarla, completa solo i campi mancanti, OTP solo per modificare. Gli script SQL (`660` e seguenti) nascono qui. ✅ Fatto in locale il 2026-09-26 (script 660–663, gruppo H del piano di test); ⏳ in produzione con L13: 660 → 661 → 662 → 663 → 666, poi il sito aggiornato, poi (a prova fatta) 667 | `Iscrizione-Viaggi-Offroad PostgreSQL/docs/plans/2026-09-25-cliente-riconosciuto-otp-design.md` |
| **L5** | Indirizzo del sito scritto nel codice Flask: con il dominio nuovo va nella configurazione azienda | `Prossime_Funzioni` §2-bis |
| **L6** | Chiave dello Storage dentro il gestionale | `Prossime_Funzioni` §11 |
| **L7** | Pagina pubblica di iscrizione alla newsletter | `Prossime_Funzioni` §3 |
| **L8** | Import dei 2.523 iscritti dal Drupal, al go-live | `Prossime_Funzioni` §4 |
| **L9** | PDF della scheda dal sito | `Prossime_Funzioni` §12 |
| **L10** | ✅ Fatto il 2026-09-25 (`SqlScripts/659`): nessuna funzione nostra eseguibile da `PUBLIC`, le nuove nascono chiuse; `anon` esegue solo le 8 letture pubbliche | `Funzioni_DB.md` §0.2 |
| **L11** | Dati personali nei log del sito Flask: il testo degli errori di database (DETAIL con la riga di `ana_clienti`) finisce nei log in molti punti; chiuso nel salvataggio del cliente, restano `/finalizza` e altri | Sito |
| **L12** | Azione «email confermata» nella scheda cliente: su un'email agganciata dal sito (script 662) il codice usa e getta resta bloccato finché l'email non cambia; se Antonio verifica che è quella giusta deve poterlo dire (una funzione SQL che cancella la riga in `web_email_agganciate` + un bottone) | Qui (schermata cliente) |
| **L12-bis** | Correzioni proposte dal cliente sul sito (per cominciare il documento), quando non può ricevere il codice: il sito le salva come **proposta**, Antonio le approva o scarta dalla scheda cliente, e solo allora la scheda cambia. Tabella delle proposte e funzioni SQL qui, schermata di approvazione qui, invio dal wizard nel sito. Da fare con L12 (prova M8, 2026-09-26) | Qui (schermata cliente) + Sito |
| **L13** | 🔴 Il sito Flask consegnava dati di clienti a caso (nomi, date di nascita, intolleranze, anche di altre aziende) mettendo id arbitrari in sessione: corretta sul ramo Flask e nello script **663** (le `fn_wizard_get_*` ora filtrano per azienda e le firme vecchie sono tolte: 663 e sito aggiornato vanno rilasciati **insieme**). In produzione con L4, per decisione di Adriano | Sito |
| **L14** | `/api/cliente/verifica-registrazione-viaggio` del sito Flask risponde senza limite di frequenza con id, cognome e nome dall'email (e scrive la scheda intera nel log DEBUG). Preesistente, fuori da L4 | Sito |
| **L15** | Mail di conferma del sito Flask: anche il passeggero legge «(e quella degli eventuali passeggeri)», che vale solo per il pilota. ✅ Fatto in locale il 2026-09-26, in PROD con L4 | Sito |
| **L16** | Due rifiniture del wizard Flask rimandabili a dopo L4: il messaggio sul documento scaduto con la modifica già aperta, e un bottone «Riprova» dopo un caricamento del profilo non riuscito | Sito |

ℹ️ **Al go-live del sito**, in PROD: `web_indirizzi` «SITO INTERNET» e il sito web dell'azienda
nelle newsletter passano a `fuoritracciatravel.com`. Non prima: le newsletter porterebbero su un
dominio senza sito.
