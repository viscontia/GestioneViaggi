# Il promemoria all'apertura — disegno (L2)

> **Approvato da Adriano il 2026-09-27.** Voce **L2** delle due liste gemelle; §1 di
> `../../Analisi_e_Design/2026-09-27-Cose_Da_Fare_MAUI_Versione_2_4.md`, che spiega il perché.
> Decisioni di Adriano: newsletter solo per le partenze **dei prossimi 90 giorni**; i casi in
> **una tabella** (possono essere tre o trecento); la soglia è un **parametro dell'azienda** nella
> linguetta «Funzioni Web»; la **mail del lunedì** è una voce a parte, dopo.

---

## 1. Cosa fa

All'avvio, se c'è qualcosa in sospeso, compare una finestra con **una tabella dei casi**. Ogni riga
ha un bottone **Apri** che porta dritto dove il caso si risolve. Se non c'è niente, la finestra
**non compare**.

Misurato il 2026-09-27 sui dati dell'azienda 2: 8 partenze passate non segnate effettuate, 4
partenze future senza scheda, 6 schede in bozza, 10 viaggi senza capienza o soglia, 5 schede senza
foto; zero clienti incompleti, documenti o proposte (le voci ci sono lo stesso: oggi zero non vuol
dire domani zero).

## 2. Le voci

| Codice | Cosa | Regola | Apri porta a |
|---|---|---|---|
| `PARTENZA_NON_EFFETTUATA` | Partenza passata non segnata come effettuata | fine < oggi e `data_viaggio_effettuato_sino <> 'Y'` | Scheda viaggio → Date e Costi |
| `SENZA_SCHEDA_WEB` | Partenza futura senza scheda web | inizio ≥ oggi, nessuna riga in `web_tour_contenuti` per quella partenza | Scheda viaggio → Contenuti Web |
| `SCHEDA_IN_BOZZA` | Partenza futura con la scheda in bozza | come sopra, `stato_pubblicazione = 'bozza'` | Scheda viaggio → Contenuti Web |
| `SCHEDA_SENZA_FOTO` | Scheda web di una partenza futura senza foto | nessuna riga in `web_tour_immagini` | Scheda viaggio → Contenuti Web |
| `SENZA_CAPIENZA` | Viaggio con partenze future senza capienza o soglia | `viaggio_capienza_max` o `viaggio_capienza_alert` vuoti | Scheda viaggio → Dati Generali |
| `SENZA_NEWSLETTER` | Partenza nei prossimi **N giorni** senza newsletter inviata | nessun blocco con quella partenza in una newsletter con stato `inviata` o `in_invio` (le bozze e i modelli non contano); N dal parametro (§4) | Pagina Newsletter |
| `CLIENTE_INCOMPLETO` | Iscritto a una partenza futura che non potrebbe iscriversi | `fn_cliente_iscrivibile(cliente, azienda, guida)` con gravità ERRORE; `guida` = è pilota | Scheda cliente |
| `DOCUMENTO` | Iscritto con documento scaduto o in scadenza | `fn_documento_esito_per_partenza` con gravità ERRORE o AVVISO | Partecipanti della partenza |
| `PROPOSTA_DAL_SITO` | Correzione dal sito da approvare (L12-bis) | `fn_web_proposte_in_attesa(azienda)` | Scheda cliente (riquadro Approva/Scarta) |

⛔️ Le regole dei clienti e dei documenti sono **le stesse** del sito e dell'iscrizione: si
chiamano le funzioni che già esistono, non se ne scrive una copia.

## 3. Dove vivono le regole

⛔️ Nel database (`SqlScripts/671` e seguenti). Il programma disegna, non ricalcola.

`fn_promemoria_apertura(p_azienda_id integer)` restituisce una riga per caso:

| Colonna | Cosa |
|---|---|
| `voce` | il codice della tabella qui sopra |
| `voce_titolo` | «Scheda web in bozza» |
| `perche` | «Pronta ma invisibile sul sito» |
| `oggetto` | «SARDEGNA SELVAGGIA · 12/10/2026» oppure «ROSSI MARIO» |
| `urgenza` | intero per l'ordinamento: prima ciò che blocca il sito o una partenza vicina |
| `data_rif` | la data di partenza, per ordinare dentro la stessa urgenza |
| `viaggio_id`, `data_viaggio_id`, `cliente_id` | cosa aprire (quelli che servono, gli altri NULL) |

Una funzione sola, fatta di un blocco per voce: la **mail del lunedì** la richiamerà così com'è.

## 4. Il parametro: linguetta «Funzioni Web» dell'azienda

Si usa la struttura che esiste già (`web_aziende_funzioni`, come per le recensioni): una funzione
nuova **`promemoria`**, con l'interruttore (acceso = il promemoria compare) e `parametri`
`{"giorni_newsletter": 90}`. Quando è acceso, sotto compare il campo **«Giorni di anticipo per la
newsletter»** con Salva.

- Riga assente o parametro vuoto → **90** (deciso nella funzione SQL, non nel C#).
- Lo script crea la riga `promemoria` attiva con 90 per ogni azienda.

## 5. La finestra

- **Filtro a bottoni** in alto, uno per voce presente, con il conteggio: «Scheda in bozza (6)»; più
  «Tutte». **Ricerca** testuale. Tabella con colonne *Cosa · Su che cosa · Perché conta · Apri*,
  ordinata per urgenza; **paginazione** oltre 25 righe.
- **Apri** apre la scheda sopra il promemoria; chiusa la scheda, la tabella si **rilegge**.
- ⛔️ Non si chiude cliccando fuori, con Esc o con la rotella (regola della 2.2). In basso **«Non
  mostrarmelo più oggi»** e **Chiudi**.
- «Non mostrarmelo più oggi» si salva in `sys_utente_preferenze` (chiave `promemoria_nascosto_il`,
  valore la data): vale per quell'utente e per quel giorno.
- Voce di menu **«Promemoria»** con il conteggio, per riaprirla quando si vuole (anche se nascosta
  per oggi).
- Compare dopo il login, una volta per avvio, se il promemoria è acceso per l'azienda, non è
  nascosto per oggi e ci sono righe.

## 6. Prove

- SQL (`Test_671_…`): un caso costruito per ogni voce compare, e sparisce dopo averlo risolto; il
  parametro cambia la finestra della newsletter; un'altra azienda non vede niente; senza riga
  `promemoria` vale 90.
- Gestionale: nessuna riga → nessuna finestra; «Non mostrarmelo più oggi» vale per un solo utente
  e un solo giorno; ogni «Apri» porta al posto giusto; il caso risolto sparisce alla rilettura.

## 7. Fuori da qui

- **La mail del lunedì**: voce a parte nella lista 2.4, dopo il promemoria; userà
  `fn_promemoria_apertura` com'è.
- Segnare «effettuata» direttamente dal promemoria: si fa dalla scheda, come oggi.
