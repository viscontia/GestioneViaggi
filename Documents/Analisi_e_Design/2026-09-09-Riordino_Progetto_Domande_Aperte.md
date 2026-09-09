# Riordino della cartella di progetto — cosa ho fatto e cosa devo chiederti

**2026-09-09.** Prima parte eseguita e committata (`ffe80b9`). Qui restano le decisioni che
**non** posso prendere io, ognuna con la misura che serve per deciderla.

---

## Parte già fatta, senza bisogno di chiedere

| Cosa | Quanto |
|---|---|
| Log di build in radice (`*.log`, `maui_syslog.txt`) | 11 file, 428 KB — erano già fuori da git |
| `.DS_Store` sparsi | 10 |
| Istantanee vecchie di graphify | 39 su 42 — **424 MB → 117 MB** |
| Cartelle vuote (`Setup Windows/`, `Backup_DB/`) | 2 |
| Documenti sparsi in 8 posti → `Documents/` con 9 sottocartelle | 45 spostamenti, storia git conservata |
| Riferimenti ai vecchi percorsi aggiornati | 65 file, ⚠️ **inclusi i due script che scrivono dentro `Funzioni_DB.md`** |
| Regola del versionamento | `overview.md` §3.6 (breve) e §15 (tabella completa) |

✅ Build verde su maccatalyst dopo tutti gli spostamenti.

---

## Le domande

### 1. ⭐️ I 90 script SQL senza numero — la domanda che pesa di più

`SqlScripts/` ha **455 file**: 365 numerati (la sequenza di deploy, `001`→`636`) e **90 senza
numero**, dell'era precedente alla numerazione. Sono contabilità, valute, fornitori, IVA: nomi come
`Fix_SQL_Ambiguity_Final.sql`, `Fix_SQL_Ambiguity_Unambiguous.sql`, `Fix_SQL_Final_Casted.sql` —
tre tentativi dello stesso problema, e non si capisce quale sia quello buono.

⚠️ **28 dei 90 sono citati da documenti**, quindi cancellarli lascerebbe rimandi ciechi.

⛔️ Uno di essi crea `ana_fornitori`, tabella che poi è stata **eliminata** (c'è il
`09_elimina_ana_fornitori.sql` che lo dice): quello script oggi è attivamente fuorviante.

**Cosa propongo:** spostarli in `SqlScripts/Storico_Pre_Numerazione/` e aggiornare i 28
riferimenti. Non cancellarli: sono già stati eseguiti in produzione anni fa, e dicono *perché* il
database è fatto così.

**Domanda:** archiviare in sottocartella (proposta), oppure cancellarli davvero visto che la loro
storia resta comunque in git?

---

### 2. `Manuali_Utente/` resta in radice?

Due giorni fa mi hai chiesto tu di crearla **sotto la radice**, e l'ho lasciata lì apposta: non
volevo disfare una tua decisione recente durante un riordino.

⚠️ È però l'unica cartella di documenti rimasta fuori da `Documents/`, e la regola che ho appena
scritto dice «tutti i documenti sotto `Documents/`». O sposto (diventerebbe
`Documents/Manuali_Utente/`), o **scrivo l'eccezione nella regola** — perché i manuali non sono
documenti interni: sono un prodotto che si consegna, e averli in vista ha senso.

**Domanda:** lasciare in radice (e io scrivo l'eccezione), o spostare sotto `Documents/`?

---

### 3. 6,5 GB di compilato — `bin/` e `obj/`

`obj/` 3,6 GB e `bin/` 2,9 GB. Si rigenerano da soli, non sono su git, e **non servono a nulla**
se non a far ripartire una compilazione più in fretta.

ℹ️ Cancellandoli, la prima compilazione successiva dura qualche minuto in più. Poi tutto uguale.

**Domanda:** faccio `dotnet clean` e li cancello? È il 90% del peso del progetto.

---

### 4. `Gallerie Foto Web/` — 81 MB

- `4x4 EST SARDEGNA/` — 5 MB, 22 foto di viaggio: sembra materiale sorgente per le gallerie del sito
- `Foto di iCloud/` — **76 MB**, coppie JPEG+MOV (foto live dell'iPhone). ⚠️ I `.MOV` sono la parte
  pesante e **non servono a un sito web**

**Domanda:** i `.MOV` si possono cancellare? E le foto sono già state caricate su Supabase Storage,
o questa è l'unica copia?

---

### 5. Otto file di lavoro rimasti in radice

| File | Ultimo commit | Cos'è |
|---|---|---|
| `TestSmtpConnection.cs` | 2026-06-27 | Programma a sé per provare l'SMTP. ⓘ Escluso dalla compilazione da `<Compile Remove="Test*.cs">` |
| `TestAziende.cs` | 2026-09-01 | idem |
| `verification.sql` | 2026-01-15 | verifiche una tantum |
| `debug_login_flow.sql` | 2026-01-15 | idem |
| `update_dialog_options.py` | 2025-12-23 | script di modifica di massa, già eseguito |
| `inspect_headers.py` | 2026-01-06 | idem |
| `missing_funcs_src.txt` | 2026-01-11 | 120 KB di elenco funzioni mancanti, di gennaio |
| `run_maui.sh` | 2026-07-28 | ⭐️ questo **serve**: lancia l'app in locale |

⚠️ `deploy_sql.sh` e `generate_db_functions_doc.sh` restano dove sono: sono vivi e usati.

**Proposta:** `run_maui.sh`, `deploy_sql.sh`, `generate_db_functions_doc.sh` restano in radice; gli
altri sei vanno in `Scripts/Storico/` (non cancellati: `TestSmtpConnection.cs` potrebbe tornare
utile il giorno che la posta fa i capricci).

**Domanda:** va bene, o preferisci cancellare quelli di gennaio?

---

### 6. `Scripts/Migrazione_Contabile/` — migrazione chiusa?

Nove script numerati `01`→`09` che trasformano `ana_fornitori` in `ana_controparti`, più il
`README_ELIMINAZIONE_ANA_FORNITORI.md`. L'ultimo elimina la tabella vecchia.

**Domanda:** la migrazione è stata completata anche in produzione? Se sì, la cartella va in
`Documents/Storico/` (il README) + `SqlScripts/Storico_Pre_Numerazione/` (gli script).

---

### 7. `Unit_Tests/` — fermi da marzo

Ultimo commit **2026-03-23**. ⛔️ Non si possono nemmeno lanciare da riga di comando: il progetto
di test riferisce quello principale che è solo-maccatalyst, e `dotnet test` fallisce con `NU1201`.

Ci sono tre file di test veri (`ClienteRepositoryIntegrationTests`, `VatValidationTests`,
`UnitTest1`).

**Domanda:** vale la pena rimetterli in piedi (servirebbe estrarre la logica pura in un progetto
separato), o si archiviano dichiarando che il collaudo qui si fa a mano con i Piani_Test?

---

### 8. Due cose piccole

- **`Documents/PDF_Oracle/`** — due PDF di gennaio 2026: elenco partecipanti e rooming list del
  Capodanno 2025-2026. Sono **stampe di esempio** o servono come riferimento?
- **`GPX/`** — un solo file, «Colle - Follonica G1 Definitiva.GPX», 700 KB, fuori da git. Traccia di
  prova per la funzione mappe, o un dato vero?

---

## Cosa NON ho toccato, per tua indicazione

- `inp_Excel/` — i sette file Excel della migrazione Oracle: hai detto di lasciarli
- `Migrazione_Dati_Oracle/` — ⭐️ hai deciso oggi che **l'import va tolto dal software**: è
  registrato come punto **10** in `2026-09-05-Prossime_Funzioni.md`, con l'avvertenza che i due
  servizi Excel non sono Oracle e vanno guardati a parte
