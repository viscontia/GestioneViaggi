# Note di rilascio — Versione 1.35

Questa versione introduce correzioni e miglioramenti all'esperienza d'uso
quotidiana dell'applicazione. Le modifiche descritte di seguito sono già
attive e non richiedono alcuna azione da parte tua.

---

## Correzioni

### Nomi dei file delle stampe relative ai viaggi

**Problema**

Quando veniva generata una stampa relativa a un viaggio — come la Scheda
Viaggio, la Scheda Dettagliata o la Rooming List — il file PDF salvato
riportava nel nome la parola generica "Viaggio" al posto del nome effettivo
del viaggio. Ad esempio, una stampa del viaggio Ichnusa veniva salvata come:

```
SchedaViaggio_Viaggio_Dal_25-04-2026_al_01-05-2026.pdf
```

Questo rendeva difficile riconoscere e ritrovare il file in un secondo momento,
specialmente quando erano presenti più stampe relative a viaggi diversi.

**Come funziona adesso**

Il nome del file include ora il nome del viaggio correttamente. Tutte le stampe
relative ai viaggi seguono questo formato:

| Tipo di stampa      | Esempio nome file                                        |
|---------------------|----------------------------------------------------------|
| Scheda Sintetica    | `SchedaViaggio_ICHNUSA_Dal_25-04-2026_al_01-05-2026.pdf` |
| Scheda Dettagliata  | `SchedaViaggioDettaglio_ICHNUSA_Dal_25-04-2026_al_01-05-2026.pdf` |
| Rooming List        | `RoomingList_ICHNUSA_Dal_25-04-2026_al_01-05-2026.pdf`  |

Il nome del file conterrà sempre il nome del viaggio e le date di inizio e fine,
rendendo ogni stampa immediatamente identificabile anche a distanza di tempo.

---

### Indirizzo email ridondante rimosso dall'invio mail

**Problema**

Quando veniva inviata un'email ai partecipanti di un viaggio (o qualsiasi altra
email tramite il pannello di invio), i destinatari ricevevano il messaggio
correttamente in BCC, ma nell'intestazione della mail erano visibili due
indirizzi aggiuntivi: l'indirizzo principale dell'azienda e, in CC,
l'indirizzo email associato al profilo dell'utente che aveva effettuato
l'invio. Per l'azienda 2 ciò si traduceva nella presenza di
`segreteria@sardegnafuoritraccia.it` e `info@sardegnafuoritraccia.it`
in ogni messaggio inviato, con quest'ultimo del tutto ridondante.

**Come funziona adesso**

L'indirizzo email dell'utente loggato non viene più aggiunto automaticamente
in CC. Il campo `To` continua a riportare l'indirizzo mittente configurato
nell'account SMTP aziendale (`segreteria@sardegnafuoritraccia.it`), che
funge già da copia per la mailbox aziendale. I partecipanti vedranno
nell'intestazione un solo indirizzo aggiuntivo anziché due.

---

### Ordinamento e visualizzazione camere nella sezione Alloggi

**Problema**

Nella scheda Alloggi del dialog di gestione partecipanti, le camere all'interno
di ogni tipologia (ad esempio "Camera Matrimoniale") venivano mostrate in un
ordine non prevedibile. Inoltre, all'interno di ogni camera i nomi degli
occupanti erano elencati casualmente, senza distinguere visivamente il pilota
dagli altri passeggeri.

**Come funziona adesso**

Le camere sono ora ordinate per cognome del pilota all'interno di ogni
tipologia, rendendo immediato il confronto tra le diverse camere dello stesso
tipo. All'interno di ogni camera il pilota appare sempre per primo, seguito dai
passeggeri in ordine alfabetico per cognome e nome. Il nome del pilota è
visualizzato in **grassetto** per distinguerlo a colpo d'occhio dagli altri
occupanti.

---

### Cartella di salvataggio delle stampe PDF su Windows

**Problema**

Su Windows, le stampe PDF generate dall'applicazione (schede viaggio, rooming
list, ecc.) venivano salvate direttamente nella cartella **Downloads**
dell'utente. Di conseguenza, il menu "Posizione delle stampe PDF" apriva la
cartella Downloads anziché una cartella dedicata all'applicazione, mescolando
i file generati da GestioneViaggi con tutto il resto del contenuto di quella
cartella.

**Come funziona adesso**

Le stampe PDF vengono ora salvate nella cartella dedicata dell'applicazione su
tutte le piattaforme. Su Windows corrisponde alla cartella dati locale dell'app
(`%LOCALAPPDATA%`), coerentemente con il comportamento già in uso su macOS.
Il menu "Posizione delle stampe PDF" apre ora sempre la cartella corretta,
separata dal filesystem utente.

---

### Errore nella cancellazione di un partecipante senza camera assegnata

**Problema**

Quando si tentava di rimuovere un partecipante da un viaggio che non aveva
nessuna camera assegnata nella sezione Alloggi, l'applicazione mostrava un
messaggio di errore:

```
Errore: Column 'room_id' is null.
```

La cancellazione non veniva eseguita e il partecipante rimaneva nell'elenco,
costringendo a riprovare senza possibilità di riuscita.

**Come funziona adesso**

La rimozione di un partecipante senza camera assegnata viene completata
correttamente. Il messaggio di conferma viene mostrato e l'elenco dei
partecipanti si aggiorna subito dopo l'operazione.
