# Note di Rilascio — Versione 2.4

> ### 🛠️ In preparazione — aperta il 2026-09-27
> Versione precedente: **2.3** del 2026-09-27 (consegnata ad Antonio).
> Cosa entra: le voci di `../Analisi_e_Design/2026-09-27-Cose_Da_Fare_MAUI_Versione_2_4.md`, a
> cominciare dal **promemoria all'apertura** (L2). Ogni cosa finita va segnata qui e nella sezione
> «Già nel codice, da portare con la 2.4» di quella lista.

---

## In una riga

*(da scrivere al rilascio)*

---

## Sezione 1 — Novità

### ⭐️ 1.1 — Il promemoria all'apertura (L2)

All'avvio, se c'è qualcosa in sospeso, compare la finestra **«Cose in sospeso»**: una tabella con
una riga per caso, i bottoni-filtro per voce con il conteggio, la ricerca e le pagine da 25. Ogni
riga ha **Apri**, che porta dove il caso si risolve; chiusa la scheda, la tabella si rilegge.

Le voci: correzioni dal sito da approvare, documenti scaduti o in scadenza degli iscritti, iscritti
che oggi non potrebbero iscriversi, partenze future senza scheda web / in bozza / senza foto,
viaggi senza capienza o soglia, partenze entro N giorni senza newsletter inviata, partenze passate
non segnate come effettuate. Le decide tutte il database (`fn_promemoria_apertura`, script 671).

- Non si chiude cliccando fuori, con Esc o con la rotella; **«Non mostrarmelo più oggi»** vale per
  quell'utente e quel giorno. Se non c'è niente, non compare.
- Si riapre dal menu, voce **«Promemoria (N)»**.
- **Anagrafica Aziende → Funzioni Web**: interruttore «Promemoria all'apertura» e il campo
  **«Giorni di anticipo per la newsletter»** (90 se non impostato).
- La scheda del viaggio ora si può aprire direttamente sui **Contenuti Web** di una partenza.

Disegno e piano: `Documents/Progetti/Promemoria_Apertura/`.

### ⭐️ 1.2 — La mail del lunedì (L18)

Ogni lunedì alle 7:30 le stesse righe del promemoria arrivano per email, leggibili dal telefono.
In **Funzioni Web**: interruttore «Mail del lunedì» (spento di default) e «Destinatari» (vuoto =
email principale dell'azienda, per SFT `segreteria@`). Non parte se non c'è niente in sospeso.
La spedisce il server del sito (`promemoria_lunedi.py` + timer systemd), non il gestionale.

✅ **Già in produzione dal 2026-09-27**, prima della 2.4 (decisione di Adriano: la spedisce il
server, non dipende dall'eseguibile). Script 671 e 673 in PROD, sito pubblicato dal ramo
`feature/mail-lunedi` (solo i 6 file nuovi), timer `iscrizione-promemoria-2.timer` attivo, prova
dal server deviata ad Adriano arrivata, `mail_lunedi` accesa per SFT → prima mail vera lunedì
2026-09-28 alle 7:30 a `segreteria@`. Con la 2.4 arriva solo la schermata di Funzioni Web per
accenderla, spegnerla e cambiare i destinatari (fino ad allora: da database).

### 1.3 — Pubblicare non è vederlo subito sul sito (L23)

Salvando la scheda web di un tour, il messaggio dice **quando** il sito se ne accorge: il sito si
aggiorna al giro successivo della sua coda, non nell'istante del salvataggio (richiesta di Adriano,
2026-10-15; «1–2 minuti» per restare larghi):

- da bozza o archiviata a **pubblicata** → «Scheda pubblicata: comparirà sul sito entro 1–2 minuti.»
- una scheda **già pubblicata** → «Modifiche salvate: saranno sul sito entro 1–2 minuti.»
- da pubblicata a **bozza o archiviata** (anche quando la riporta a bozza il programma, perché manca
  qualcosa) → «Scheda tolta dal sito: sparirà entro 1–2 minuti.»
- una bozza che resta bozza → il messaggio di sempre.

Lo dice anche l'aiuto (icona ?) dello stato «Pubblicato».

### 1.4 — Il titolo del tour si traduce (sito, Tappa 3)

Nella linguetta **Traduzioni** della scheda web compare anche il **Titolo** del tour: il sito lo
mostra nella lingua del visitatore (prima restava in italiano). Si traduce la forma leggibile, non il
maiuscolo dell'anagrafica; cambiando il titolo del viaggio, le sue traduzioni diventano «obsolete»
come succede già per Incluso ed Escluso. I titoli delle 11 schede attuali sono già tradotti e
revisionati (script 685), quindi nessuna scheda cambia stato.

### 1.5 — Il cane nella rooming list

Nella stampa della rooming list, sotto le intolleranze, compare «** CANE AL SEGUITO **» per chi porta
il cane (prima usciva solo nella stampa del viaggio). Il dato è quello dell'iscrizione: se il cane è
segnato su tutti e due i componenti di una coppia, compare per tutti e due (scelta di Adriano: è il
dato dell'anagrafica). Script 674, in PROD dal 2026-10-10 (riallineato identico il 2026-10-16); con la
2.3 la stampa resta quella di prima, la riga esce con la 2.4.

### 1.6 — Via il «Link Documentazione» dall'anagrafica viaggio

Era un residuo del vecchio gestionale Oracle (il link alla pagina del vecchio sito): vuoto su tutti i
viaggi e non usato da nessuna parte. La pagina del tour, oggi, è la scheda web. Tolto dalla finestra
del viaggio; i valori vecchi erano già stati svuotati in PROD (script 665).

### ⭐️ 1.7 — La scheda «Sito web» dell'azienda (L28) e le garanzie del tour operator (L26)

Nell'anagrafica dell'azienda c'è una scheda nuova, **«Sito web»**: ciò che il sito pubblico mostra e
che decide il titolare. Per ora la sotto-scheda **Home**:
- la **foto d'apertura** (scelta dalla libreria immagini, con anteprima e un avviso se è troppo piccola),
  il **motto**, il **titolo** e il **sottotitolo** (facoltativo), tutti tradotti;
- l'**email che riceve i messaggi** del modulo Contatti del sito (vuota = l'email principale);
- il blocco **«In evidenza»**: un titolo e fino a 3 tour, scelti fra quelli che il sito mostra; un tour
  non più pubblicato sparisce da solo dal sito;
- il riquadro **«Lingue»** con «Traduci quello che manca» (se ci sono modifiche, prima le salva).

Nei **Dati generali**, il riquadro **«Garanzie del tour operator»**: polizza RC (compagnia, numero) e fondo
di garanzia (ente, estremi), mostrati nel piede del sito.

Si salva tutto con **«Aggiorna»**, che controlla anche le traduzioni del sito: se sono incomplete si può
**tradurre subito**, **chiudere comunque** o **tornare indietro**. Le modifiche della scheda non si
perdono cambiando scheda. Il sito si aggiorna da solo entro 1–2 minuti. Script 692, 693, 694, 695.

---

## Sezione 2 — Correzioni

### 2.1 — Le icone delle date viaggio sfalsate da una riga all'altra

Nella griglia «Date in Programma» l'ultima icona (stato della scheda web) è un **pulsante** quando la
scheda manca e un'**icona semplice** quando c'è: la seconda è più stretta, e la fila centrata
scivolava di lato (segnalato da Adriano il 2026-09-27, Capodanno in Ogliastra). Ora l'icona semplice
occupa lo stesso spazio di un pulsante (`StatoContenutoWebIcon`, parametro `IngombroPulsante`).

### 2.2 — Newsletter: titoli dei tour leggibili e periodo in buon italiano

Nelle newsletter i titoli dei tour non escono più in MAIUSCOLO come nell'anagrafica
(«Ponte dell'Immacolata in 4x4»), e il periodo usa le elisioni corrette («dall'8», «all'11») e «1°».
Lo decide il database (script 676 e 677), quindi è già attivo in PROD anche con la 2.3.

### 2.3 — Traduzioni: il marchio non si traduce, le sezioni sì

Nella linguetta Traduzioni si vedono i dati sistemati il 2026-10-16 (con l'autorizzazione di Adriano):
- in tre meta titoli il marchio era stato tradotto («Off Track Travel», «Hors Piste Travel»): ora è
  «Fuori Traccia Travel» (script 686);
- i nomi delle 5 sezioni del sito (Viaggi 4x4, in moto, in quad e SSV, Escursioni e-bike MTB,
  Esperienze) sono tradotti nelle 4 lingue (script 686), e lo sono anche i titoli delle 11 schede
  (script 685). Tutto revisionato; si cambia dal gestionale come ogni traduzione.

### 2.4 — Pilota senza codice fiscale: il messaggio dice perché

Quando si iscrive come pilota un cliente senza codice fiscale, il messaggio ora dice dove risulta
residente in anagrafica e cosa correggere: «… risulta residente in Italia (COMO): il codice fiscale
serve per emettere la fattura a chi guida. Se risiede all'estero, correggi il comune di residenza.»
La regola non cambia (chi risiede all'estero non deve avere il codice fiscale). Nato da un caso
reale del 2026-10-20: un cliente svizzero sembrava bloccato da un controllo sbagliato, invece in
anagrafica aveva Como come residenza. Script 697, già attivo in PROD anche con la 2.3.

---

## Sezione 3 — Documentazione

- **Registro degli script in PROD** (`Documents/PROD/Registro_Script_PROD.md`, 2026-10-16): una riga
  per ogni script dal 637, con lo stato in PROD **verificato** (impronte delle funzioni) e un controllo
  automatico degli script mancanti. Sostituisce, per gli script, la checklist del go-live
  dell'estensione web, ora chiusa (go-live eseguito il 2026-09-09).

---

## Sezione 4 — Database

| Script | Cosa | In PROD |
|---|---|---|
| `671_Promemoria_Apertura.sql` | `fn_promemoria_apertura`, `fn_promemoria_giorni_newsletter`, riga `promemoria` a 90 giorni per ogni azienda. Test `Test_671_…` | ✅ 2026-09-27 (anticipato per la mail del lunedì; la finestra arriva con l'eseguibile 2.4) |
| `673_Promemoria_Mail_Lunedi.sql` | `fn_promemoria_mail_destinatari`, riga `mail_lunedi` spenta per ogni azienda. Test `Test_673_…` | ✅ 2026-09-27; `mail_lunedi` **accesa per l'azienda 2** |
| `672_Elimina_Viaggio_Di_Test_2.sql` | Via il «VIAGGIO DI TEST 2» (903) con le sue 2 iscrizioni e 2 camere; anagrafiche intatte. Pulizia dati, non serve all'eseguibile | ✅ 2026-09-27 |
| `665_Viaggi_Svuota_Link_Documentazione.sql` | Svuota `ana_viaggi.viaggio_link` (link al vecchio sito), insieme al campo tolto dalla finestra (1.6) | ✅ (verificato il 2026-10-16: nessun valore rimasto) |
| `674_Rooming_List_Cane.sql` | `get_rooming_list_data` con `con_cane` (1.5) | ✅ 2026-10-10; riapplicato identico il 2026-10-16 |
| `676_Web_Newsletter_Titoli_Leggibili.sql`, `677_Web_Newsletter_Periodo_Elisioni.sql` | Titoli e periodo delle newsletter (2.2) | ✅ (verificati il 2026-10-16: funzioni identiche al locale) |
| `684_Web_Titolo_Sezioni_Tradotti.sql` | Il titolo del tour fra i campi da tradurre (1.4); titolo e sezione tradotti sul sito | ✅ **In PROD il 2026-10-17**, dopo il 685: semaforo Traduzioni confrontato prima e dopo, invariato per ogni scheda |
| `685_Web_Titoli_Tradotti.sql` | Titoli delle 11 schede tradotti e revisionati (2.3) | ✅ 2026-10-16 |
| `686_Web_Correzioni_Traduzioni.sql` | Marchio corretto in 3 meta titoli; nomi delle 5 sezioni tradotti (2.3) | ✅ 2026-10-16 |
| `689_Web_Andalucia_Durata_Tradotta.sql` | Durata di Andalucia tradotta nelle 4 lingue (era obsoleta): semaforo della scheda completo | ✅ 2026-10-17 |
| `690_Web_Mongolia_Gallura_Traduzioni.sql` | Mongolia: equipaggiamento tradotto; Gallura: durata e sottotitolo tradotti di nuovo. Tutte le schede pubblicate col semaforo completo | ✅ 2026-10-17 |
| `691_Web_Coda_Anagrafica_Traduzioni.sql` | Salvare nel gestionale l'anagrafica dell'azienda, una traduzione o il testo di una giornata mette in coda la rigenerazione del sito e dei PDF (prima no: il sito se ne accorgeva entro un'ora). Nessun cambiamento visibile nel gestionale | ✅ 2026-10-17 |
| `692_Web_Sito_Contenuti.sql` | Tabelle della scheda «Sito web» dell'azienda (home: foto, motto, frase, email dei messaggi del sito; «In evidenza»: fino a 3 tour) e garanzie del tour operator (polizza RC, fondo di garanzia) nell'anagrafica; ogni modifica aggiorna il sito (L24, L26, L28). La scheda nel gestionale arriva con l'eseguibile 2.4. Test `Test_692_…` | ✅ 2026-10-20 (anticipato: il sito lo usa già; la scheda arriva con l'eseguibile 2.4) |
| `693_Web_Sito_Letture.sql` | Le letture del sito per home, «In evidenza», piede e mappa delle zone (dati della scheda «Sito web» e dell'anagrafica, tradotti). Nessun cambiamento visibile nel gestionale. Test `Test_693_…` | ✅ 2026-10-20 |
| `694_Web_Utente_Sito_Posta.sql` | L'utente `sito_posta` del server del sito: legge solo la configurazione di posta e l'indirizzo che riceve i messaggi del modulo Contatti. Dopo lo script: login a mano (impronta SCRAM) e password nel `.env` del server. Test `Test_694_…` | ✅ 2026-10-20 (login non ancora dato) |
| `695_Web_Sito_Titolo_Sottotitolo.sql` | Home: titolo e sottotitolo al posto della frase d'apertura. Test `Test_695_…` | ✅ 2026-10-20 |
| `696_Web_Sito_Partenze.sql` | Le partenze della home del sito in ordine di data. Nessun cambiamento nel gestionale. Test `Test_696_…` | ✅ 2026-10-20 |
| `697_Messaggio_Pilota_Senza_CF.sql` | Pilota senza codice fiscale: il messaggio dice la residenza in anagrafica e cosa correggere (correzione 2.4). La regola non cambia. Test `Test_697_…` | ✅ 2026-10-20 |

⚠️ **Uno script che sta in `SqlScripts/` non è uno script applicato.** Ogni riga qui sopra si
chiude solo con la data dell'applicazione in PROD.

---

## Sezione 5 — Al momento del rilascio

La stessa sequenza della 2.3, con le lezioni imparate lì.

0. **Controlli preliminari su PROD** (procedura nelle note della 2.2, §7 passo 0):
   `SELECT * FROM fn_check_firme_duplicate();` deve rispondere zero righe, e ogni funzione chiamata
   dal codice deve esistere in PROD.
1. **Numero di versione a 2.4** in `Resources/Version/Versione.txt` (versione e data), nel
   `#define AppVersion` di `Scripts/windows/GestioneViaggi.iss`, in `ApplicationDisplayVersion`
   (build 40 → 41) e nell'intestazione e nel piè di pagina dei cinque manuali, più il nome
   `GestioneViaggi_Setup_2.4.exe` nel manuale di installazione. PDF rigenerati.
2. **Mac**: `dotnet build -f net9.0-maccatalyst -c Release`, poi sostituire
   `/Applications/GestioneViaggi.app` (quella nel Dock) con il bundle **universale**
   `bin/Release/net9.0-maccatalyst/GestioneViaggi.app`.
   ⛔️ Non quelli in `maccatalyst-arm64/` o `maccatalyst-x64/`: sono intermedi, senza icona e con
   la firma non valida (è successo con la 2.2 e con la 2.3). Prova: una mail a sé stessi
   dall'anagrafica clienti deve arrivare.
3. **Windows**, in PowerShell **dentro Parallels** (dal Terminale del Mac risponde `NETSDK1083`):
   ```powershell
   cd '\\Mac\Home\Documents\Sviluppo Software\MAUI\GestioneViaggi'
   dotnet publish -f net9.0-windows10.0.19041.0 -c Release -r win10-x64 --self-contained true
   ```
   Poi copia in `C:\GestioneViaggi-build` (svuotata prima) e Inno Setup, seguendo
   `Scripts/windows/COME_SI_GENERA_L_INSTALLER.md`. Controllare **x64** e versione **2.4.0.0**.
4. **Prova sulla VM**: installare sopra la 2.3 e provare le novità di questa versione.
5. **Consegna ad Antonio**: setup, `Novita_Versione_2_4.pdf` (da scrivere, voce aziendale) e i
   manuali; cancellare i setup vecchi. Segnare «consegnata» qui, nella lista della 2.4 e, per le
   voci `L*`, anche nella lista gemella del sito.
