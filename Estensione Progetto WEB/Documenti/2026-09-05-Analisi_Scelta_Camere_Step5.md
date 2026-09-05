# La scelta delle camere: prima la domanda, poi solo ciò che è possibile

**Analisi del 2026-09-05.** Documento operativo per rifare il passo 5 del sito di
iscrizione. La direzione è già decisa — *«la domanda potrebbe essere fatta PRIMA»* — qui
c'è il disegno, l'elenco completo delle combinazioni e cosa serve a database.

---

## 1. Cosa succede oggi

Per un'iscrizione con **1 o 2 persone** (Modalità A) il sito mostra una fila di card di
tipi camera **per ciascun partecipante**. Una coppia deve quindi scegliere «CAMERA
MATRIMONIALE» **due volte**. Solo *dopo*, e solo se le due scelte coincidono, compare la
domanda: **«dormite nella stessa camera?»**

Con **3 o più persone** (Modalità B) l'interazione cambia del tutto: un mini-wizard che
compone una camera alla volta.

### I tre difetti, in ordine di gravità

1. **La domanda che dovrebbe guidare arriva alla fine.** Si chiede alla persona di
   esprimere due volte una scelta che è una sola, e poi le si chiede se intendeva davvero
   quello che ha appena fatto.
2. **Rispondendo «no» si viene respinti.** Il sito rifiuta — *«Non puoi assegnare una
   camera da più posti a una sola persona»* — e fa ricominciare. L'assegnazione sbagliata
   non viene registrata, ed è già qualcosa: ma la persona ha compiuto tre scelte, ne ha
   sbagliata una che non sapeva di poter sbagliare, e deve rifare tutto.
3. **Due percorsi diversi per la stessa cosa**, a seconda di quanti si è: due da mantenere,
   due da collaudare. Se una via regge quattro persone, regge anche due.

### Un quarto difetto, tecnico

`fn_wizard_get_all_tipi_alloggio` restituisce **tutti** i tipi senza filtro, compresi
`NESSUNA CAMERA` (capienza **0**), le varianti `DISABILI` e le tende. Il front-end poi
filtra con «capienza ≤ persone da assegnare»: ⚠️ con capienza 0 la condizione è sempre
vera, quindi **`NESSUNA CAMERA` compare fra le card selezionabili** — e sceglierla porta
dritti al rifiuto del punto 2.

---

## 2. La misura: come SFT usa davvero le camere

Su PROD, azienda 2:

| Tipo | Capienza | Volte usata | ⚠️ Sotto capienza |
|---|---|---|---|
| CAMERA MATRIMONIALE | 2 | **59** | 1 |
| CAMERA SINGOLA | 1 | **30** | 0 |
| CAMERA DOPPIA LETTI SINGOLI | 2 | **20** | **6** |
| CAMERA DOPPIA USO SINGOLA | 1 | **15** | 0 |
| CAMERA TRIPLA (matrimoniale + singolo) | 3 | 5 | 0 |
| NESSUNA CAMERA | 0 | **2** | 0 |

Tre cose che questa tabella dice, e che il disegno deve rispettare:

- **Il caso dominante è la coppia in matrimoniale** (59 su 131). È il percorso da rendere
  più breve, non quello da far passare per tre schermate.
- ⚠️ **`NESSUNA CAMERA` esiste ed è usata.** Qualcuno dorme altrove — camper, casa propria,
  amici. Il disegno deve prevederlo come **scelta di prima classe**, non come un'anomalia.
- ⚠️ **Sei «doppie letti singoli» risultano occupate da una persona sola**, cioè
  esattamente ciò che il sito rifiuta. Vengono dal gestionale, che non ha quel controllo.
  Sono dati da guardare: o sono errori, o è una prassi (una doppia pagata a uso singolo
  registrata come doppia) e allora il modello va capito prima di irrigidirlo.

---

## 3. Il principio

> **Prima si chiede come si vuole dormire. Poi si offrono solo le combinazioni che
> esistono davvero.**

Chi si iscrive non deve poter comporre una sistemazione impossibile e scoprirlo dopo: le
combinazioni impossibili **non gli vengono mostrate**. Il numero di persone e le capienze
delle camere sono noti al server; la risposta alla prima domanda è l'unico dato che manca,
e una volta ottenuta la lista delle soluzioni valide è breve e si può mostrare intera.

---

## 4. Il modello dei dati regge già: la capienza è esatta

Nella tabella dei tipi, **`CAMERA DOPPIA USO SINGOLA` ha `numero_occupanti = 1`**, non 2.
Cioè il modello codifica già «doppia pagata da uno solo» come una camera da **una** persona
con supplemento.

⚠️ Questo semplifica tutto: la regola non è «capienza ≥ persone», è **capienza = persone**.
Un gruppo di 1 prende un tipo di capienza 1 (SINGOLA, DOPPIA USO SINGOLA); un gruppo di 2
un tipo di capienza 2; e così via. Nessuna aritmetica di supplementi da inventare nel
codice: il supplemento è già un attributo del tipo scelto.

Le sei righe «sotto capienza» del capitolo 2 sono l'unica cosa che contraddice il modello,
e vanno chiarite prima.

---

## 5. L'elenco completo delle combinazioni

Con i tipi oggi a catalogo:

| Capienza | Tipi disponibili |
|---|---|
| 0 | NESSUNA CAMERA |
| 1 | CAMERA SINGOLA · CAMERA DOPPIA USO SINGOLA ⚠️ · CAMERA SINGOLA DISABILI |
| 2 | CAMERA MATRIMONIALE · CAMERA DOPPIA LETTI SINGOLI · CAMERA MATRIMONIALE DISABILI · TENDA 2 POSTI ⚠️ |
| 3 | CAMERA TRIPLA (matrimoniale + letto singolo) · CAMERA TRIPLA (tre letti singoli) |
| 4 | CAMERA QUADRUPLA (4P) · TENDA 4 POSTI ⚠️ |
| 5 | CAMERA QUADRUPLA (5P) |

⚠️ = comporta supplemento.

### 1 persona — 1 combinazione

| # | Forma | Camere |
|---|---|---|
| 1 | sola | 1 camera da 1 |
| — | *nessuna camera* | (opzione sempre disponibile) |

### 2 persone — 2 combinazioni

| # | Forma | Camere | Nota |
|---|---|---|---|
| 1 | **insieme** | 1 camera da 2 | ⭐ il caso dominante (59 su 131) |
| 2 | **separati** | 2 camere da 1 | ⚠️ due supplementi se sono doppie uso singola |

### 3 persone — 3 combinazioni

| # | Forma | Camere |
|---|---|---|
| 1 | tutti insieme | 1 camera da 3 |
| 2 | due insieme + uno solo | 1 camera da 2 + 1 camera da 1 |
| 3 | tutti separati | 3 camere da 1 |

### 4 persone — 5 combinazioni

| # | Forma | Camere |
|---|---|---|
| 1 | tutti insieme | 1 camera da 4 |
| 2 | tre insieme + uno solo | 1 camera da 3 + 1 camera da 1 |
| 3 | due coppie | 2 camere da 2 |
| 4 | una coppia + due soli | 1 camera da 2 + 2 camere da 1 |
| 5 | tutti separati | 4 camere da 1 |

### Oltre le 4 persone

Le combinazioni crescono in fretta — **5 persone: 7 forme; 6 persone: 11**. Mostrarle tutte
smette di aiutare e comincia a confondere.

⚠️ **Decisione di disegno da prendere**: fino a 4 si mostrano le soluzioni complete; da 5 in
su si torna a comporre una camera alla volta — ma come *continuazione della stessa
domanda*, non come un secondo percorso con un'altra faccia. Il limite di 4 non è arbitrario:
è dove l'elenco resta leggibile, ed è anche la dimensione oltre la quale nei dati reali non
si va mai (la camera più grande a catalogo tiene 5, e `mov_clienti_alloggi` 6 per riga).

### Chi sta con chi

Una volta scelta la **forma**, serve sapere **chi** va dove — ma solo quando è ambiguo:

| Forma | Serve chiedere chi? |
|---|---|
| tutti insieme | **no** |
| tutti separati | **no** |
| gruppi tutti uguali (es. due coppie) | **sì** |
| gruppi diversi (es. 2 + 1) | **sì** |

⚠️ Con 2 persone non si chiede **mai**: le due forme sono «insieme» e «separati», e in
entrambe la domanda di chi-con-chi non ha risposte alternative. È il motivo per cui il caso
più frequente diventa **una schermata sola**.

### La scelta del tipo

Ultimo passo, e solo dove c'è più di un tipo per quella capienza: matrimoniale o due letti
singoli? tripla con matrimoniale o tre singoli? ⚠️ Le varianti **DISABILI** e le **TENDE**
vanno mostrate solo se ha senso — vedi le decisioni aperte.

---

## 6. Cosa serve a database

Nessuna di queste regole deve stare nel JavaScript: la stessa scelta la farà un domani il
gestionale, e le capienze cambiano aggiungendo una riga a `ana_tipo_alloggio`.

| Funzione | Cosa risponde |
|---|---|
| `fn_alloggi_combinazioni(p_data_viaggio_id, p_persone)` | Le forme possibili per quel numero di persone: per ciascuna, l'elenco dei gruppi con la loro dimensione. È il cuore: **la lista delle combinazioni non si calcola nel browser** |
| `fn_alloggi_tipi_per_capienza(p_capienza)` | I tipi che ospitano esattamente quel numero di persone, con descrizione e supplemento. Sostituisce il filtro fatto oggi nel front-end |
| `fn_alloggi_assegnazione_valida(p_data_viaggio_id, p_assegnazioni)` | ⚠️ Il controllo finale: che ogni persona compaia una volta sola, che ogni gruppo stia in un tipo di capienza pari alla sua dimensione, che nessuno resti fuori. **Deve esistere anche se l'interfaccia impedisce già di sbagliare**: è la regola, e l'interfaccia è solo il modo comodo di rispettarla |

⚠️ `fn_wizard_get_all_tipi_alloggio` va **filtrata**: niente capienza 0 nell'elenco delle
camere (`NESSUNA CAMERA` è una scelta a parte, non un tipo di stanza).

---

## 7. Cosa si pulisce nel codice

| Dove | Cosa sparisce |
|---|---|
| `Step5Content.jsx` | Le due modalità A e B diventano **una**. Spariscono `sameCameraChoice`, `modeABothSameType`, `modeAAllSelected` e il ramo che rifiuta la scelta incoerente: non serve rifiutare ciò che non si può più comporre |
| `Step5Content.jsx` | Il filtro delle capienze fatto in JavaScript: lo fa la funzione a database |
| `handleModeAConfirm` | Il messaggio *«Non puoi assegnare una camera da più posti a una sola persona»*: quella situazione non è più raggiungibile |

---

## 8. Casi limite e decisioni aperte

### Decise il 2026-09-05

**2 — Le varianti DISABILI si mostrano SEMPRE.** ⚠️ Non dietro una domanda preliminare del
tipo «ti serve una camera accessibile?»: per rispetto verso chi la userà, e per non
obbligare nessuno a **dichiararsi disabile** per vedere un'opzione. Stanno in elenco come
tutte le altre.

**3 — Il tipo di pernottamento del viaggio esiste già, e basta collegarlo.** Non serve
inventare un legame tipo↔viaggio: `ana_viaggi.viaggio_tipo_pernottamento_fk` c'è, e la
tabella `ana_tipo_pernottamento` contiene esattamente le categorie descritte dall'utente:

| Tipo | Con albergo | Viaggi SFT |
|---|---|---|
| ALBERGO | Y | **18** |
| ALBERGO CON QUALCHE CAMPO TENDATO | Y | 0 |
| SOLO CAMPI TENDATI | N | **2** |
| NESSUNO | N | 0 |

Il sito già usa il flag `con_albergo`: `StepWizard.jsx` **salta il passo 5** quando vale
`N`. ⚠️ Ma è un interruttore acceso/spento — non filtra i **tipi di camera** offerti.
Il collegamento che manca è quello: un viaggio in albergo non deve proporre tende, uno con
solo campi tendati non deve proporre matrimoniali. Il dato per farlo c'è già.

⚠️ Nota da verificare prima: il caso **ALBERGO CON QUALCHE CAMPO TENDATO** ha `con_albergo = Y`
ma non è mai stato usato. Con il misto, la sistemazione può cambiare **da una notte
all'altra** — e il modello attuale associa una camera alla *partenza*, non alla singola
notte. È il limite da conoscere prima di promettere il misto.

**4 — Le sei doppie con un occupante: NON sono un caso di prassi da modellare.** L'elenco
mostra che si tratta di **motociclisti soli** iscritti a MAXI ENDURO TOUR GPX e GRAN TOUR
ENDURO FEBBRAIO, più due casi isolati: gente che viaggia da sola e a cui è stata assegnata
una doppia. Tutte inserite **dal gestionale** (`segreteria@`), che non ha il controllo del
sito. La lettura più semplice è che sia una **doppia pagata a uso singolo registrata come
doppia** invece che con il tipo apposito, che esiste (`CAMERA DOPPIA USO SINGOLA`,
capienza 1, con supplemento). ☐ **Da confermare con Antonio**: se è così sono dati da
normalizzare, e «capienza = persone» resta la regola giusta.

**5 — «Passiamo dalla casa di mia zia e quella sera dormo da lei»: fuori dal software.** Si
gestisce a mano — la persona lo scrive nelle note o telefona per prendere accordi. ⚠️ Non
per pigrizia: *«molto spesso queste richieste hanno solo lo scopo di farsi abbassare il
costo del viaggio»*, quindi vanno negoziate da una persona, non concesse da un modulo. Il
caso esiste ed è reale, ma è raro, e modellarlo significherebbe legare la sistemazione alla
singola notte per servire l'eccezione.

### Ancora da decidere

| # | Caso | Da decidere |
|---|---|---|
| 1 | **`NESSUNA CAMERA`** | Come si offre? Una spunta «non mi serve la camera» per singola persona, prima delle forme — non come un tipo di stanza fra gli altri. ⚠️ Diverso dal caso 5: qui si tratta di chi **dorme nel proprio mezzo**, non di chi si sposta a casa di parenti |
| 2 | **Gruppi misti** | Un genitore con un minore: chi sta con chi non è deducibile dai dati, va chiesto — e l'ordine delle domande deve renderlo naturale |
| 3 | **Il costo** | Le camere con supplemento costano di più. ⚠️ La combinazione scelta dovrebbe mostrare **quanto cambia**, altrimenti si sceglie al buio e il preventivo arriva dopo |
| 4 | **Modifica successiva** | Se una persona viene aggiunta o tolta dall'iscrizione, la combinazione scelta può diventare invalida. Va ricalcolata, e la persona avvisata |

---

## 9. Impatto sui test

| Gruppo del piano Flask | Da rifare? |
|---|---|
| A, B, C, G | no |
| D — iscrizione al viaggio | **sì**, la parte sulla sistemazione |
| E — la posta | no |
| F — i due software concordano | **sì**, se il gestionale userà le stesse funzioni |
| **Nuovo gruppo** — combinazioni camere | **sì**: una prova per ciascuna forma di 1, 2, 3 e 4 persone, più `NESSUNA CAMERA`, più il ricalcolo quando cambia il numero di partecipanti |

⚠️ Si somma al giro già previsto per la protezione dei dati personali
(`2026-09-05-Analisi_Protezione_Dati_Personali_Sito.md`). **Entrambi toccano il passo 5 e
il passo 2**: conviene farli e collaudarli insieme, non uno dopo l'altro.

---

## 10. La frase da ricordare

Oggi il sito **lascia comporre una sistemazione impossibile e poi la rifiuta**. Il disegno
nuovo non aggiunge controlli: toglie la possibilità di sbagliare. ⚠️ È la stessa differenza
fra un modulo che ti dice «data non valida» e un calendario da cui scegli — e costa meno
codice, non di più, perché il ramo che rifiuta sparisce insieme al caso che rifiutava.
