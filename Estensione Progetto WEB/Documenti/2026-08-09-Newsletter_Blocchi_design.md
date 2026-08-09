# Newsletter a blocchi — design

**Creato:** 2026-08-09 · **Stato:** proposta, da approvare prima di implementare
**Origine:** collaudo newsletter del 2026-08-09 (`RISULTATI TEST NEWSLETTER 9 Agosto 2026.pdf`)

---

## 1. Il problema

La newsletter che SFT manda davvero — quella del vecchio CMS Drupal allegata al collaudo — è un
**documento composto**: immagine di testata con titolo, blocchi di testo, riquadri tour con
copertina e pulsante "Vai alla pagina del Tour", blocco informazioni (chi può partecipare, costi,
adesioni), footer societario.

Quello che abbiamo costruito è **una casella di testo formattato** dentro un template fisso.
Non è la stessa cosa, e la differenza non si colma aggiungendo un pulsante.

### Cosa manca, in concreto

| | Stato |
|---|---|
| Immagini nel corpo | **Impossibili**: la toolbar Quill non ha il pulsante immagine (`NewsletterPage.razor:53-59`) |
| Logo | C'è, ma incorporato come `data:` URI → **Outlook per Windows non lo renderizza** |
| Copertine dei tour | Non riutilizzabili: la galleria produce **WebP**, che Outlook non supporta |
| Bozza | `stato='bozza'` è **già ammesso dal CHECK** e non lo scrive nessuno |
| Anteprima | Assente |
| Clonazione | Assente — ma le newsletter sono quasi sempre varianti della precedente |
| Invio reale a un solo indirizzo | Assente (l'"invio di prova" forza `[TEST]` e l'italiano) |
| `CompanyEmailTemplate` | Classe statica C# con l'HTML inline: invisibile e non modificabile dall'utente |

### Cosa invece c'è già e va riusato

- **Supabase Storage + `IWebMediaStorage.BuildPublicUrl`** → URL pubblici https, che è esattamente
  ciò che vogliono le immagini nelle email.
- **I dati dei tour**: copertina, titolo, slug. Il grosso di una newsletter SFT è "ecco i nuovi
  tour, clicca qui" — dati che il gestionale ha già e che oggi andrebbero ricopiati a mano.
- **`web_traduzioni`** polimorfica (`entita` + `entita_id`) e il motore Claude.
- **`fn_web_tour_contenuti_clona`** come modello per la clonazione.

---

## 2. Decisioni di progetto

### 2.1 — Blocchi in tabella, non in JSONB

`web_newsletter_blocchi`, figlia di `web_newsletter_invii`, sul modello di `web_tour_itinerario`.

**Perché non JSONB:** le traduzioni. `web_traduzioni` indirizza `(entita, entita_id, campo, lingua)`
e ha bisogno di **identificatori stabili** per ogni testo traducibile. Con un JSONB si dovrebbe
inventare un indirizzamento per posizione, che si rompe al primo riordino dei blocchi. Con una
tabella ogni blocco ha una PK e la traduzione ci si aggancia come già fa per le giornate
dell'itinerario. In più il riordino ha già un pattern collaudato (`fn_web_tour_itinerario_reorder`).

### 2.2 — Tipi di blocco

Derivati **dalla newsletter reale**, non inventati:

| Tipo | Contenuto | Traducibile |
|---|---|---|
| `testata` | immagine di sfondo + titolo + sottotitolo | titolo, sottotitolo |
| `testo` | HTML ricco (Quill senza immagini) | corpo |
| `tour` | riferimento a un'edizione → copertina, titolo, testo, link | testo introduttivo, etichetta pulsante |
| `immagine` | immagine + testo alternativo + link opzionale | alt |
| `pulsante` | etichetta + URL | etichetta |
| `separatore` | spazio o linea | — |

**Il footer societario NON è un blocco.** È parte del template, come l'intestazione col logo:
deve esserci sempre e non deve essere cancellabile per errore — sono i dati di legge del mittente.

### 2.3 — Il blocco `tour` si compila da solo

L'operatore sceglie un'**edizione** (viaggio + data) fra quelle pubblicate; il sistema prende
copertina, titolo e costruisce il link dallo slug. L'operatore può sovrascrivere il testo, non i
dati strutturali. È il blocco che fa risparmiare più tempo e che oggi non esiste.

### 2.4 — Immagini compatibili con l'email

Regola: **niente `data:` URI, niente WebP.** Ogni immagine usata in una newsletter deve essere
raggiungibile via URL pubblico https e in formato **JPEG o PNG**.

Conseguenze:
- serve una **resa JPEG** delle immagini usate nella newsletter. Le copertine dei tour sono WebP:
  al momento dell'inserimento nel blocco si genera (una volta) un derivato JPEG in Storage sotto
  `newsletter/`, e si usa quello;
- **il logo passa da base64 a URL pubblico**, con caricamento in Storage. È un cambio a
  `CompanyEmailTemplate` che sistema anche il logo delle email non-newsletter, oggi probabilmente
  invisibile in Outlook;
- l'HTML generato è **tabellare, larghezza fissa 600px, stili inline**. Niente flex, niente grid,
  niente `<style>` in `<head>`: sono le regole che Outlook impone.

### 2.5 — Bozza: si finisce ciò che è già previsto

La riga di `web_newsletter_invii` viene creata **quando si crea la newsletter**, con
`stato='bozza'`, non al momento dell'invio. Da lì: si modifica, si vede in anteprima, si clona, si
invia. `corpo_html` conserva l'**HTML renderizzato al momento dell'invio**, come istantanea di ciò
che è davvero partito (serve allo storico, non alla modifica).

### 2.6 — Traduzione per campo, non del blob

Oggi l'intero HTML passa dentro Claude. Con i blocchi si traducono **solo i campi di testo**:
meno token, e soprattutto le immagini e la struttura non possono più tornare indietro rovinate.

---

## 3. Cosa cambia per l'utente

1. **Newsletter** diventa un elenco: bozze e inviate, con *Nuova*, *Duplica*, *Modifica*, *Anteprima*, *Invia*.
2. La composizione è un elenco di blocchi con aggiungi / riordina / elimina.
3. **Anteprima** mostra la newsletter come la vedrà il destinatario, nella lingua scelta.
4. **"Invia a me"** manda il rendering **reale** a un solo indirizzo: nessun `[TEST]`, lingua a scelta.
5. **Duplica** crea una bozza identica da modificare — il caso più frequente.

---

## 4. Piano di lavoro

| Fase | Contenuto | Dipendenze |
|---|---|---|
| **1. DB** | `web_newsletter_blocchi` + CRUD + reorder + `fn_web_newsletter_clona`; bozza | — |
| **2. Rendering** | `NewsletterHtmlRenderer` (blocchi → HTML tabellare); resa JPEG; logo via URL | 1 |
| **3. UI** | elenco newsletter, composizione a blocchi, anteprima, duplica | 1, 2 |
| **4. Traduzioni** | per campo invece che sul blob | 1, 3 |
| **5. Invio** | "invia a me" reale, invio campagna sul rendering | 2, 3 |

Ogni fase si chiude con build verde e le righe di test corrispondenti nel Piano di Test §8.

---

## 5. Punti da confermare prima di partire

1. **I sei tipi di blocco** di §2.2 coprono ciò che serve? Ne manca qualcuno che usava Drupal?
2. **Il footer come parte fissa del template** (non cancellabile) va bene?
3. **Anteprima solo nell'applicazione**, o serve anche il "vedi nel browser" che molte newsletter
   mettono in cima? *(Il secondo richiede una pagina pubblica → Fase 3 del sito.)*
4. Le newsletter vecchie di Drupal vanno **importate**, o si riparte da zero clonando la prima
   fatta a mano?
