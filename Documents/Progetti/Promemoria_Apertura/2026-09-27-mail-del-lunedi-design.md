# La mail del lunedì — disegno

> **Approvato da Adriano il 2026-09-27.** Voce §1-bis di
> `../../Analisi_e_Design/2026-09-27-Cose_Da_Fare_MAUI_Versione_2_4.md`. Prosegue il promemoria
> all'apertura (L2, `2026-09-27-promemoria-apertura-design.md`, stessa cartella).
> Decisioni di Adriano: **un parametro per azienda** («magari qualcuno non la vuole»); per SFT il
> destinatario è **`segreteria@sardegnafuoritraccia.it`**, cioè l'email principale dell'azienda
> che il programma conosce già.

---

## 1. Cosa fa

Ogni **lunedì alle 7:30 (ora italiana)** parte una mail con le stesse righe del promemoria
all'apertura. Antonio la legge anche dal telefono, quando è in viaggio e il gestionale è spento.
**Se non c'è niente in sospeso, la mail non parte.**

## 2. Chi la spedisce

Il **server del sito di iscrizione** (Hetzner), sempre acceso. Il gestionale no: è un programma sul
PC, e il lunedì mattina può essere spento.

Il server sa già spedire con l'SMTP di ogni azienda (`AziendaDAO.get_smtp_config`, la stessa
configurazione del gestionale), conosce l'azienda del suo sito (`azienda_corrente()`) e ha la
deviazione della posta di prova (`_destinatari_effettivi`, `MAIL_DIROTTA_A`). Ogni installazione
del sito serve un'azienda: ogni installazione ha il suo timer.

- `promemoria_lunedi.py` nella radice del progetto Flask: apre il contesto dell'app, legge dal
  database destinatari e righe, spedisce. Esce con codice ≠ 0 se l'invio fallisce (resta nel
  giornale di systemd).
- `systemd`: `iscrizione-promemoria-2.service` (oneshot, stesso `EnvironmentFile` e stessa `.venv`
  del sito) e `iscrizione-promemoria-2.timer` con `OnCalendar=Mon *-*-* 07:30:00 Europe/Rome`
  (il server è in UTC: il fuso nel timer segue da solo l'ora legale).

## 3. Dove vivono le regole

⛔️ Nel database, `SqlScripts/673`:

| Cosa | Dove |
|---|---|
| Le righe | `fn_promemoria_apertura(azienda)` (671), **così com'è**: la mail e la finestra dicono la stessa cosa |
| Se partire e a chi | `fn_promemoria_mail_destinatari(azienda) → text[]`: vuoto se la funzione `mail_lunedi` è spenta o manca; altrimenti gli indirizzi del parametro `destinatari`, o in mancanza **l'email principale** dell'azienda (`ana_aziende_email.is_principale`) |

La riga `mail_lunedi` in `web_aziende_funzioni` nasce **spenta** per tutte le aziende: nessuno
riceve mail che non ha chiesto. Per SFT si accende al rilascio, con il via di Adriano.

## 4. Il parametro: linguetta «Funzioni Web»

Interruttore **«Mail del lunedì»** e, quando è acceso, il campo **«Destinatari»** (indirizzi
separati da virgola). Vuoto = l'email principale dell'azienda, che il campo mostra come
suggerimento. Gli indirizzi si controllano nel formato prima di salvare.

## 5. La mail

- Oggetto: «Cose in sospeso — lunedì 5 ottobre: 41».
- Un blocco per voce, nell'ordine di urgenza del database: titolo con il conteggio, il «perché» una
  volta sola, l'elenco dei casi («su che cosa»). Stile e logo delle altre mail del sito.
- In fondo: «Si risolvono dal promemoria all'apertura del gestionale (menu Promemoria)». Nessun
  link: dal telefono il gestionale non si apre.

## 6. Prove

- SQL (`Test_673`): spenta → nessun destinatario; accesa senza parametro → l'email principale;
  con parametro → quegli indirizzi; un'altra azienda non vede i destinatari di questa; chiusa ad
  `anon`.
- Flask (pytest): nessuna riga → nessuna mail; con righe → una mail, oggetto con il conteggio,
  blocchi nell'ordine ricevuto; nessun destinatario → nessuna mail; la deviazione vale anche qui.
- A mano, in locale con `MAIL_DIROTTA_A`: lo script lanciato a mano manda la mail alla casella di
  collaudo; poi il timer sul server, prima con una data di prova e la deviazione, poi vero.

## 7. Fuori da qui

- Giorno e ora diversi per azienda: tutti il lunedì alle 7:30 finché qualcuno non chiede altro.
- Un registro degli invii: il giornale di systemd basta per sapere se è partita.
