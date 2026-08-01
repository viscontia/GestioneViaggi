# Note di Rilascio — Versione 2.0

> Salto maggiore **1.35 → 2.0**: introduzione dell'**Estensione CMS per il Web** nel gestionale, più una serie di bug pre-esistenti individuati e risolti durante i test di pre-rilascio.
> Data: 2026-07-19 · ultimo aggiornamento 2026-08-01. Stato: in preparazione (documento vivo fino al go-live).

---

## Sezione 1 — Nuove funzionalità: Estensione CMS per il Web

Il gestionale diventa l'**unico motore di contenuti** per il nuovo sito pubblico: i contenuti web sono redatti e gestiti dal gestionale (nessun CMS separato) e pubblicati verso il sito.

> **Criterio di inserimento:** in questa sezione entrano **solo le funzionalità verificate a runtime**. Le altre restano nell'elenco "In attesa di verifica" finché non sono collaudate, e vengono promosse a funzionalità rilasciata una volta testate.

### Funzionalità verificate

- **Lingua del cliente (anagrafica)** — nuovo campo *lingua preferita* in anagrafica cliente, usato dalla newsletter per l'invio multilingua. Il campo non è mai vuoto: se l'operatore non lo specifica, la lingua viene **auto-derivata dalla nazione di residenza** (fallback italiano) e memorizzata; la newsletter la legge senza dover ragionare. *(Verificato a runtime: 2026-07-19.)*
- **Tipi viaggio globali + descrizioni web** — lookup condivisa fra le aziende, con mappatura tipo → descrizione web e relative traduzioni. *(Verificato a runtime: 2026-07-25.)*
- **Schede web dei tour per edizione (viaggio + data)** — un contenuto per singola partenza, con creazione dalla scheda viaggio e **anteprima** di come apparirà sul sito; l'anteprima riporta le **prossime partenze in programma** e può essere visualizzata **in lingua** quando le traduzioni sono complete e approvate. *(Verificato a runtime: 2026-07-31.)*
- **Itinerario giorno per giorno** — giornate e passi con riordino; ogni giornata mostra la **data reale derivata dalla partenza**, che si aggiorna da sola se la giornata viene spostata. *(Verificato a runtime: 2026-07-31.)*
- **Galleria immagini del tour** — caricamento con conversione WebP e archiviazione su Supabase Storage, copertina, riordino, protezione delle foto usate nell'itinerario. *(Verificato a runtime: 2026-07-31.)*
- **Mappe statiche da traccia GPX** — **più mappe per edizione**: una dell'intero viaggio e una per giornata dell'itinerario, con descrizione tradotta, blocco dei file duplicati e tracciato volutamente generalizzato perché non sia replicabile. *(Verificato a runtime: 2026-07-29.)*
- **Traduzioni assistite multilingua (Claude)** — traduzione di ciò che manca o è obsoleto, revisione con editor visuale (mai HTML a vista), **approvazione in blocco** dopo un controllo a campione per lingua, e **gating**: non si pubblica finché le traduzioni non sono revisionate. Include il **registro dei consumi** con soglia di spesa facoltativa e avviso. *(Verificato a runtime: 2026-07-31.)*
- **Incluso / Escluso per tour** — campi a livello viaggio, condivisi fra le edizioni e tradotti insieme al resto della scheda. *(Verificato a runtime: 2026-07-31.)*
- **Cifratura dei segreti (`pgcrypto`)** — chiavi salvate cifrate e rilette in chiaro solo con la master key d'ambiente. *(Verificato a runtime sulla chiave Claude: 2026-07-28. Il percorso SMTP usa lo stesso meccanismo ma non è stato riesercitato in questo ciclo.)*

### In attesa di verifica runtime (non ancora documentate come rilasciate)

Implementate ma da collaudare prima di promuoverle sopra. Le voci qui sotto **non sono state esercitate** nel ciclo di test 2026-07-25 → 08-01: per alcune manca il dato di prova, per altre serve il sito pubblico (Fase 3).

- [ ] **Clonazione** di una scheda web su un'altra edizione (creazione e anteprima già verificate)
- [ ] **Clonazione fra partenze di durata diversa**: se l'edizione di destinazione dura meno di quella di origine, il programma se ne accorge e chiede se rinunciare o clonare solo le prime giornate, avvertendo che l'ultima va rivista a mano
- [ ] **Eliminazione di una scheda web** (solo bozza o archiviata), con conferma che elenca giornate, foto, mappe e traduzioni che spariscono. Serve anche a sbloccare la cancellazione di una partenza futura
- [ ] **Il sito non mostra partenze già iniziate**: filtro sulla data di inizio in lettura — verificabile solo con il frontend pubblico (Fase 3)
- [ ] Capienza e "posti rimasti" per tour — la capienza si imposta dal gestionale, ma *posti rimasti* è un dato che espone il **sito pubblico**: verificabile solo con il frontend (Fase 3)
- [ ] Tour brevi / giornalieri — nessun tipo viaggio ancora marcato come breve
- [ ] Newsletter multilingua (invio, iscrizione/disiscrizione, destinatari) — nessun invio né iscritto sul database di prova
- [ ] Configurazione funzioni web per azienda — nessuna funzione ancora configurata
- [ ] Recensioni Google / TripAdvisor — dipende dalla configurazione funzioni web, non ancora impostata
- [ ] SMTP: test connessione con diagnostica (firewall/VPN, DNS, TLS…), messaggi errore centralizzati, mostra/nascondi password

> Nota architetturale: logica dati **DB-first** (funzioni PostgreSQL), componenti UI **condivisi**, contenuti web **per-azienda** (silos multi-tenant); solo tipi-viaggio e relative descrizioni sono globali.

---

## Sezione 2 — Bug pre-esistenti individuati e risolti

Bug non legati all'estensione web, emersi durante i test di pre-rilascio e corretti in questa versione.

| # | Area | Problema | Soluzione |
|---|------|----------|-----------|
| 1 | **Anagrafica Cliente — validazione** | I campi **obbligatori su tab non visitati** (es. "Documenti") **non bloccavano il salvataggio** (insert e update): `MudForm` valida solo i campi renderizzati e `MudTabs` renderizzava solo il pannello attivo, quindi i `Required` sugli altri tab non venivano registrati. | `KeepPanelsAlive="true"` sui `MudTabs`: tutti i pannelli renderizzati → tutti i campi validati. (Stesso schema già corretto in passato su `AziendaDialog`/`AnaViaggiDialog`; mancava su `ClienteDialog`.) |
| 2 | **Anagrafica Cliente — lingua (salvataggio)** | Il cast `@L::char` (= `char(1)`) in `ClienteLinguaService.SetAsync` **troncava** il codice lingua (`IT`→`I`) prima della funzione DB → al rientro il campo mostrava il codice grezzo. | Cast corretto a `::varchar`; script di **repair dati** per le righe già troncate (rimappa 1 carattere → ISO a 2 lettere). |
| 3 | **Anagrafica Cliente — lingua (NULL)** | Svuotando il campo lingua si salvava **NULL** in `cliente_lingua`, delegando alla newsletter la derivazione. | La funzione `fn_ana_clienti_set_lingua` **auto-deriva** la lingua dalla nazione di residenza quando il campo è vuoto (fallback `IT`); colonna resa `NOT NULL DEFAULT 'IT'`. La newsletter legge il valore senza dover ragionare. |
| 4 | **Anagrafica Cliente — layout** | La form del dialog aveva **altezza fissa (800px)** → grande spazio vuoto verticale e barra di scorrimento inutile; spaziatura eccessiva tra i campi. | Altezza resa **adattiva** (`max-height: 80vh`) e spaziatura dei tab compattata. |
| 5 | **SMTP — lettura password** | Il recupero della password SMTP in chiaro leggeva `password_enc->>'value'` (JSONB) su una colonna diventata `bytea` (pgcrypto) → errore silenzioso, il test dava sempre "password non recuperabile" anche con password salvata. | Nuova funzione DB `fn_ana_aziende_smtp_secrets_get` (decifra via `pgp_sym_decrypt`); C# aggiornato per usarla. |
| 6 | **Date viaggio — stato "effettuato"** | La colonna **EFFETT.** dell'elenco date mostrava un pallino **verde/rosso senza tooltip**: nessuna spiegazione di cosa indicasse, e il **rosso su "non effettuato"** faceva sembrare un errore quella che per una partenza futura è la situazione **normale**. Il flag inoltre veniva letto **da solo**, mentre il suo significato dipende anche dal calendario: una partenza conclusa e non spuntata è un dato da correggere, una futura e non spuntata è corretta. | Nuovo componente condiviso **`StatoPartenzaChip`** (regole e testi in `StatoPartenzaRules`) che **incrocia il flag con la data di fine** e distingue quattro casi: conclusa e registrata, **conclusa ma non registrata** (anomalia), in programma (normale), **spuntata ma non ancora conclusa** (anomalia). Tooltip sempre presente, che spiega il caso e **dove si corregge**. Adottato sia nell'elenco date sia nelle schede web, così la stessa icona significa la stessa cosa ovunque. |
| 7 | **Partecipanti — titolo del dialogo** | Aprendo i **partecipanti** di una partenza, l'intestazione restava **"Caricamento..."** anche a elenco completamente caricato. Il dato era corretto (`fn_get_viaggio_partecipanti_init_data` restituiva il titolo giusto): il titolo era disegnato con `<TitleContent>`, che il contenitore del dialogo rende **una volta sola** e non rilegge quando il componente termina il caricamento asincrono. | Titolo impostato con **`IMudDialogInstance.SetTitleAsync`**, l'API prevista per i titoli che dipendono da un valore interno al dialogo. ⚠️ Ha effetto **solo** se `<TitleContent>` viene rimosso, quindi il blocco è stato eliminato e non affiancato. Verificati gli altri dialoghi con titolo dinamico: non hanno il problema (titolo da parametro o proprietà calcolata, disponibili già al primo render). |
| 8 | **Date viaggio — cancellazione di una partenza** | Una partenza **già avvenuta** era **cancellabile senza alcuna domanda**: non esisteva nessun controllo né sulle date né sul flag "effettuato". *(Verificato: partenza di 400 giorni fa, segnata come effettuata, eliminata senza avvisi.)* L'unica protezione era **accidentale** — di norma quelle partenze hanno prenotazioni, e quelle bloccavano — quindi non valeva quando i partecipanti non erano mai stati registrati o erano stati rimossi: spariva storico aziendale in modo irreversibile. In più, una partenza con **scheda web** era sì bloccata, ma dal vincolo del database anziché da un controllo: l'utente vedeva un messaggio generico ("utilizzato in altre parti del sistema") in **rosso**, mentre il caso prenotazioni — identico come natura — dava un avviso **giallo**. | Guardie esplicite in `sp_ana_date_viaggi_delete`: si elimina **solo una partenza che deve ancora iniziare** e non segnata come effettuata (stesso confine già usato per la pubblicabilità sul web). Le partenze con una scheda di contenuti web vengono rifiutate con un messaggio che **distingue bozza da pubblicato** e dice cosa fare. Tutti i rifiuti tornano come **avviso giallo**, non come errore. ⚠️ Chi inserisce per sbaglio una data nel passato la corregge e poi la elimina: è deliberatamente un passaggio in due mosse. |

### Note operative emerse dai test
- Il nuovo controllo del punto 6 fa emergere **anomalie già presenti nei dati**: sul database di sviluppo ha segnalato **9 partenze concluse ma non spuntate come effettuate**. Non è un difetto del programma: sono dati di anagrafica da verificare caso per caso (o il viaggio è stato fatto e manca la spunta, o non è stato realizzato). La correzione si fa nella scheda **Date del viaggio**.
- I **test SMTP** (test connessione, invio) vanno eseguiti con **VPN disattivata**: molti server di posta bloccano gli IP di VPN/datacenter sulle porte mail pur lasciando aperte quelle web. Il messaggio d'errore ora lo segnala esplicitamente.

---

*Documento da completare/rivedere fino al go-live. Per la sequenza tecnica di deploy in produzione vedi `Estensione Progetto WEB/Documenti/2026-07-10-Checklist_Go_Live_PROD.md`.*
