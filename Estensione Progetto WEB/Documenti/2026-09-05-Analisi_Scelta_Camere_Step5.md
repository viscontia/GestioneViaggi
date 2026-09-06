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

## 4. ⚠️ Il sito non deve far scegliere il tipo di camera

**Questa sezione sostituisce quella precedente**, che dava per buona la regola «capienza =
persone». È caduta il 2026-09-05, e l'ha smontata un fatto di mestiere.

### Cosa è successo davvero con le sei doppie a un occupante

Antonio, interpellato a suo tempo: **quell'albergo non offriva camere singole** — e succede
spesso. L'unica opzione era la doppia. Quindi non ha sbagliato tipo: ha registrato **la
verità fisica**. Il motociclista ha avuto una doppia a due letti, da solo, e non era un
«uso singola» perché la singola in quella struttura **non esiste**.

### Il catalogo mescola due assi

| Tipo | Cos'è |
|---|---|
| `CAMERA DOPPIA USO SINGOLA` (capienza 1, suppl. Y) | un **prodotto commerciale**: una doppia venduta a una persona, col supplemento |
| `CAMERA DOPPIA LETTI SINGOLI` (capienza 2, suppl. N) | una **stanza fisica** |

Sono la stessa stanza con due trattamenti diversi. Finché stanno nello stesso elenco come
alternative pari, il modello non può esprimere «doppia occupata da uno perché non c'erano
singole».

E il modello è più debole di così:

- `tipo_alloggio_supplemento` è un **Y/N sul tipo**, non un importo e non per partenza:
  ⚠️ **l'importo del supplemento non esiste da nessuna parte** nel sistema;
- i costi della partenza sono per **categoria di persona** — pilota, passeggero, bambini —
  mai per tipo di camera;
- **nessuna tabella lega un alloggio a un viaggio o a una partenza**: non esistono
  disponibilità né prezzi per struttura;
- `ana_tipo_alloggio.tipo_alloggio_fk` è un riferimento a se stessa **mai valorizzato** —
  sembra nato proprio per dire «questa è una variante di quella», che è la relazione
  mancante fra doppia e doppia-uso-singola.

### La conseguenza, che semplifica il passo 5

**Quale stanza tocchi dipende dall'albergo — che SFT conosce e chi si iscrive no.** Nessuno
che prenota può sapere se quella struttura ha le singole. Quindi il sito **non deve far
scegliere il tipo**: deve raccogliere l'**intenzione**.

| Il sito chiede | SFT decide dopo |
|---|---|
| dormite insieme o separati? | matrimoniale o due letti singoli |
| chi con chi (solo quando serve, vedi §5) | tripla con matrimoniale o tre singoli |
| a qualcuno non serve la camera perché dorme nel proprio mezzo? | doppia uso singola oppure doppia, secondo cosa offre l'albergo |

Il passo 5 passa da **tredici tipi da interpretare** a **una domanda sola** — che è anche
l'unica cosa a cui chi si iscrive sa rispondere con certezza.

⚠️ **Una cosa va detta in chiaro nell'interfaccia**: chi vuole dormire da solo non può
ricevere una promessa di prezzo. La formulazione onesta è *«camera per te solo — a seconda
della struttura può comportare un supplemento»*. Non è un peggioramento: **oggi il
supplemento non è calcolato comunque**, perché l'importo non esiste nel sistema. Cambia
solo che lo si dice, invece di lasciarlo scoprire dopo.

### Il legame tipo ↔ struttura ↔ partenza: **scartato**, non rimandato

Sarebbe ciò che permetterebbe di dire a chi prenota quanto costa dormire da solo. **Non si
fa**, deciso dall'utente il 2026-09-05, e la ragione è di mestiere più che tecnica:

> comporterebbe l'anagrafica degli **alberghi**, i **tipi di camera** che ciascuno offre e i
> **prezzi aggiornati** — ⚠️ e i supplementi «possono cambiare quando vogliono e non
> comunicarlo».

Un dato che il fornitore cambia senza avvisare non si può tenere allineato: il sistema
direbbe una cifra e l'albergo ne farebbe un'altra, il che è peggio che non dire niente.

**Conseguenza da accettare consapevolmente**: il supplemento resta un `Y/N` senza importo, e
chi si iscrive non saprà mai dal sito quanto costa dormire da solo. L'interfaccia deve dirlo
onestamente — *«può comportare un supplemento»* — e la cifra la fa SFT, che parla con
l'albergo.

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

**La regola esatta:** si chiede **solo se almeno un gruppo ha 2 o più persone E i gruppi
sono più di uno.** In tutti gli altri casi la risposta è una sola e chiederla è un
passaggio a vuoto.

| Persone | Forma | Serve chiedere chi? |
|---|---|---|
| 1 | sola | no |
| 2 | insieme | **no** — un gruppo solo |
| 2 | separati | **no** — due gruppi da uno: chi va dove non cambia niente |
| 3 | tutti insieme | no |
| 3 | **due insieme + uno solo** | **SÌ** — quali due? |
| 3 | tutti separati | no |
| 4 | tutti insieme | no |
| 4 | **tre insieme + uno solo** | **SÌ** — chi resta solo? |
| 4 | **due coppie** | **SÌ** — chi con chi? |
| 4 | **una coppia + due soli** | **SÌ** — quali due stanno insieme? |
| 4 | tutti separati | no |

⚠️ **Con 2 persone non si chiede mai.** Ed è il caso dominante — 59 su 131 — quindi la
coppia in matrimoniale diventa **una schermata sola**: una domanda, una risposta, avanti.

⚠️ **Precisazione su una intuizione dell'utente**, che è giusta al 90%: non è vero che la
domanda resta solo con 4 persone. Sopravvive anche con **3 in forma 2+1** — una coppia più
un amico, e bisogna sapere quali due sono la coppia. Sono in tutto **4 forme su 11**: una
di tre e tre di quattro.

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

## 8-bis. ⚠️ Anche le tende vanno composte — da discutere il 2026-09-06

**Sollevato dall'utente il 2026-09-05**, e i dati gli danno ragione:

> *«Anche nei campeggi vogliono la composizione della tenda, come se fosse una camera.
> Quindi anche un viaggio in tenda come i Pirenei obbliga a indicare le "camere", ovvero le
> tende.»*

### Cosa dicono i dati (PROD, azienda 2)

| Viaggio | Pernottamento | Righe di alloggio | Tipi usati |
|---|---|---|---|
| **PIRENEI IN FUORISTRADA** | SOLO CAMPI TENDATI | **1** | ⚠️ `NESSUNA CAMERA` |
| BARBAGIA WILD TOUR | SOLO CAMPI TENDATI | 0 | — |
| MAXI ENDURO TOUR DEI 2 MARI | ALBERGO | 7 | fra cui `NESSUNA CAMERA` |

Tre fatti che si incastrano:

1. **Il sito salta del tutto il passo 5** quando `con_albergo = 'N'` (`StepWizard.jsx`).
   Per i viaggi in tenda, quindi, **nessuno compone niente**.
2. Sui Pirenei però una riga c'è, ed è `NESSUNA CAMERA`: qualcuno **aveva bisogno di
   registrare qualcosa** e ha usato l'unica cosa disponibile. È il segno che il bisogno
   esiste e che manca lo strumento.
3. ⚠️ **`TENDA 2 POSTI NOLEGGIATA` e `TENDA 4 POSTI NOLEGGIATA` esistono in anagrafica e non
   sono state usate mai.** Ci sono, ma il flusso non le offre a nessuno.

### Il difetto di fondo: `con_albergo` risponde alla domanda sbagliata

`ana_tipo_pernottamento_con_albergo` significa **«è un albergo?»**, ma viene usato per
decidere **«c'è qualcosa da comporre?»**. Per i campi tendati le due risposte divergono: non
è un albergo, **ma i posti letto vanno assegnati lo stesso** — e li vuole il campeggio,
esattamente come l'albergo vuole i documenti.

### La proposta dell'utente, e come la vedo

> *«Credo ci manchi un flag in `ana_tipo_alloggio` che indichi se è una camera d'albergo o
> una tenda, in combinata con `ana_tipo_pernottamento`.»*

È giusta, e diventano **due assi indipendenti**:

| | Valori | Sta su |
|---|---|---|
| **Che pernottamento prevede il viaggio** | albergo · tende · misto · nessuno | `ana_tipo_pernottamento` (c'è già) |
| **Che tipo di unità è** | camera · tenda · nessuna | ⚠️ **manca** — il flag nuovo su `ana_tipo_alloggio` |

E la regola diventa una sola: **si offrono le unità del genere che il viaggio prevede** — il
misto le offre entrambe. Il passo 5 non si salta più per i viaggi in tenda: si salta solo
per `NESSUNO`.

### ⚠️ La misura che dice quanto costa oggi

Verificato su PROD il 2026-09-06, partenza **PIRENEI IN FUORISTRADA del 19/08/2026**:

| | |
|---|---|
| Iscritti | **12** |
| Righe di alloggio | **1** (`NESSUNA CAMERA`) |

**Undici persone su dodici non hanno alcuna sistemazione registrata**, su un viaggio dove il
campeggio la composizione la chiede. L'utente conferma: **le tende sono state assegnate
fuori dal sistema** — su carta, a voce, in un messaggio.

⚠️ Non è un dato mancante per distrazione: è il software che non ha mai offerto il posto
dove metterlo. Il sito salta il passo 5 perché `con_albergo = 'N'`, e il gestionale non ha
un percorso che chieda la composizione delle tende. Il lavoro descritto qui sopra serve
esattamente a questo, e **il caso è già successo**.

E c'è una conseguenza sui dati che nessuno vede finché non serve: alla partenza, chi ha in
mano l'elenco degli occupanti per il campeggio? Nessun documento stampato dal gestionale può
contenerlo, perché il dato non c'è.

### Il disegno proposto: due assi, e un controllo che oggi non esiste

**Domanda dell'utente (2026-09-06):** *«Manca un flag in `ana_tipo_alloggio` che indichi se
è una camera d'albergo o una tenda, oppure può reggere anche così? Al momento non abbiamo
nessun controllo incrociato fra la definizione di un viaggio "solo tende" e la coerenza col
tipo di alloggio.»*

**Non regge, e non è un rischio teorico.** Misurato su PROD il 2026-09-06: esistono già
**17 assegnazioni incoerenti**, tutte camere d'albergo su viaggi con pernottamento
`NESSUNO` — 10 matrimoniali, 4 singole, 2 doppie, 1 quadrupla. Nessuno se n'è accorto,
perché **non c'è niente che guardi**. Il controllo incrociato non manca solo per le tende:
manca del tutto.

#### Perché serve un flag e non basta il nome

Senza, l'unico modo di sapere se un tipo è una tenda sarebbe leggere la descrizione
(`ILIKE '%TENDA%'`) o cablare gli identificativi `30, 32, 34, 36`. ⚠️ Entrambe sono la
forma di difetto tolta quattro volte il 2026-09-05. E il catalogo **è modificabile dal
gestionale** (`TipoAlloggioPage`): la classificazione dipenderebbe da come qualcuno scrive
un'etichetta — si chiama una riga «CASA MOBILE» o «IGLOO» e il controllo smette di
funzionare, in silenzio. È lo stesso ceppo dei tipi documento, dove cinque codici scritti a
mano descrivevano tre documenti.

#### I due assi

⚠️ **Un flag solo non basta**: anche il lato viaggio è povero. `ana_tipo_pernottamento` ha
solo `con_albergo` Y/N, che **non sa esprimere il misto** — `ALBERGO CON QUALCHE CAMPO
TENDATO` ha `con_albergo = 'Y'`, quindi un controllo che si fidasse di quel flag
escluderebbe le tende **proprio sul viaggio che le prevede entrambe**.

⚠️ **E i valori non si scrivono nel codice.** Domanda posta all'utente il 2026-09-06 —
*«tre valori bastano?»* — e risposta: *«no, un domani potrebbero esserci condizioni di
alloggio totalmente diverse che oggi non sono state prese in considerazione»*. Bungalow,
case mobili, rifugi, barche. Un elenco fisso a tre voci andrebbe riaperto ogni volta, e con
lui tutti i controlli che nel frattempo ci si appoggiano.

Quindi **il genere è una tabella, non un enumerato**, e il legame col pernottamento è una
tabella di associazione:

| Oggetto | Cosa contiene |
|---|---|
| `ana_alloggio_generi` | i generi: `ALBERGO`, `TENDA`, `NESSUNA` — e domani quello che serve. Codice, descrizione, ordine, attivo |
| `ana_tipo_alloggio.genere_fk` | di che genere è questo tipo di sistemazione |
| `ana_tipo_pernottamento_generi` | quali generi ammette ciascun tipo di pernottamento — **molti a molti** |

Costa una tabella in più di quanto sembri necessario oggi, e la ragione è precisa:
⚠️ **l'alternativa — un booleano per genere — è esattamente ciò che ha già fallito.**
`con_albergo` è nato così, e il giorno in cui sono comparse le tende non ha saputo dire
niente: si sarebbe dovuto aggiungere `con_tenda`, poi `con_bungalow`, ognuno con il suo
controllo da scrivere. Con l'associazione, aggiungere un genere è **una riga in una tabella
e nessuna riga di codice**.

Il pernottamento oggi si tradurrebbe così:

| Pernottamento | Generi ammessi |
|---|---|
| ALBERGO | ALBERGO |
| ALBERGO CON QUALCHE CAMPO TENDATO | ALBERGO, TENDA |
| SOLO CAMPI TENDATI | TENDA |
| NESSUNO | *(nessuno)* |

**La regola diventa una riga:** un tipo si può assegnare se il suo genere è fra quelli
ammessi dal viaggio. ⚠️ E **`NESSUNA` vale sempre**, su qualunque viaggio, senza comparire
nell'associazione: «non mi serve una sistemazione» è legittimo ovunque — chi dorme nel
proprio mezzo, chi si ferma da parenti. Nei dati è già usato sia su ALBERGO sia su SOLO
CAMPI TENDATI, coerente in entrambi.

⚠️ **Cosa fare di `con_albergo`.** Oggi il sito lo usa per una cosa sola: saltare il passo 5
(`StepWizard.jsx`). Con questo modello quella decisione si **deduce** — si salta il passo 5
se il viaggio non ammette alcun genere — e il flag può sparire invece di essere mantenuto
accanto a un'informazione più ricca che lo contraddirebbe.

Da qui discendono tre cose che oggi non ci sono: il sito offre solo i tipi giusti, il passo
5 si salta solo quando davvero non c'è nulla da comporre, e una funzione di validazione
rifiuta l'incoerenza invece di lasciarla passare diciassette volte.

#### ⚠️ Il caso misto resta scoperto, e va detto

I due booleani **sanno descrivere** il viaggio misto — albergo e tende insieme, più
`NESSUNA` che vale sempre. Ma descriverlo non è servirlo: **la sistemazione è legata alla
PARTENZA, non alla singola notte.** Un viaggio che dorme tre notti in albergo e due in
tenda non ha modo di dire chi sta dove **in quale notte**: la riga di `mov_clienti_alloggi`
è una sola per tutta la partenza.

Non a caso `ALBERGO CON QUALCHE CAMPO TENDATO` **non è mai stato usato**: il modello non lo
regge, e chi inserisce lo evita.

Quindi il disegno qui proposto:

- ✅ **risolve** albergo puro, tende pure, e chi non ha bisogno di sistemazione;
- ✅ **rende impossibili** le incoerenze come le 17 trovate;
- ⚠️ **non risolve** il misto vero, che richiede di legare la sistemazione alla notte — un
  lavoro molto più grande, dello stesso ordine di quello scartato per i prezzi.

Il misto va quindi **dichiarato fuori portata per ora**, non lasciato ambiguo: se un domani
serve davvero, si affronta il modello per notte. Nel frattempo un viaggio misto si gestisce
scegliendo il pernottamento prevalente e annotando il resto — che è ciò che si fa già.

### Le due cose da decidere domani

1. ~~**La tenda propria** serve come tipo nuovo~~ — ✅ **esiste già su PROD**, verificato il
   2026-09-06: `TENDA 2 POSTI DI PROPRIETA'` (id 34) e `TENDA 4 POSTI DI PROPRIETA'` (id 36),
   entrambe con supplemento `N`. ⚠️ **Mancavano al database di sviluppo**, che aveva 13 tipi
   contro i 15 di produzione: l'affermazione «a catalogo ci sono solo tende noleggiate» era
   vera in locale e falsa in produzione. Allineato con `SqlScripts/597`, che porta la tabella **intera** con le chiavi di produzione (⚠️ un trigger `BEFORE INSERT` sovrascrive gli identificativi e rende inutile ogni `ON CONFLICT`: vedi difetto 97). **Non c'è niente da
   progettare qui: il modello è già giusto, manca solo il flusso che lo usa.**
2. **La riga `NESSUNA CAMERA` sui Pirenei.** Una volta che le tende si possono comporre,
   quella riga descrive ancora la realtà o va corretta? Domanda per Antonio.

### Perché conviene farlo insieme al resto

Tocca le stesse cose: la funzione che offre i tipi, il salto del passo 5, e l'interfaccia
della composizione. ⚠️ Farlo dopo significherebbe **riaprire il passo 5 una terza volta** —
e rifarne i test una terza volta.

---

## 8-ter. Il lavoro riguarda ENTRAMBI i software — deciso il 2026-09-06

> *«Dobbiamo anche fare questa parte su MAUI. Non vedo altre possibilità, quindi bisogna
> assolutamente procedere anche su MAUI, e le tabelle nuove devono essere anche a menu,
> cioè devono avere la loro interfaccia di gestione.»*

⚠️ Non è un'estensione del lavoro: è la condizione perché funzioni. Le regole stanno a
database e valgono per chiunque scriva — ma se il gestionale continua a offrire tutti i
tipi senza guardare il pernottamento, **le incoerenze continuano a nascere da lì**, ed è
esattamente da lì che sono nate le 17 già trovate.

### Cosa serve nel gestionale

| Dove | Cosa |
|---|---|
| **Nuova pagina** `ana_alloggio_generi` | CRUD dei generi, sul modello di `TipoAlloggioPage`. ⚠️ **Con voce di menu**: una tabella che si può cambiare solo con una `INSERT` a mano è una tabella che nessuno cambierà |
| `TipoAlloggioPage` | nuovo campo **genere** in elenco e nella scheda |
| `TipoPernottamentoPage` | i **generi ammessi** da ciascun pernottamento. ⚠️ Non una pagina a sé: l'associazione si gestisce **dentro** la scheda del pernottamento, con una selezione multipla — è lì che uno la cerca |
| `ViaggioAlloggiAdvancedDialog`, `ViaggioAlloggiEditDialog`, `QuickAddParticipantDialog` | offrono solo i tipi ammessi dal viaggio, invece dell'elenco intero |
| Composizione delle camere | le stesse combinazioni del sito: **una regola sola, due interfacce** |

Il menu è in `Components/Shared/NavMenu.razor`, dove le tabelle di appoggio stanno già in
gruppo (`/tabelle/tipologie-alloggi`, `/tabelle/tipologie-partecipanti`, …): la voce nuova
va accanto a quelle, non altrove.

### Il principio che tiene insieme le due parti

⚠️ **Le regole non si scrivono due volte.** `fn_alloggi_tipi_ammessi(partenza)`,
`fn_alloggi_combinazioni(partenza, persone)` e `fn_alloggi_assegnazione_valida(...)` stanno
a database e le chiamano **entrambi** i software — è la stessa scelta che ha fatto
funzionare il consenso, i documenti obbligatori e i controlli sull'anagrafica.

Il sito e il gestionale possono avere interfacce diverse — il primo guida chi si iscrive,
il secondo serve chi lavora e deve poter correggere — ma **non possono avere idee diverse su
cosa sia valido**. È il difetto che abbiamo passato due giorni a togliere in quattro forme
diverse.

### Cosa questo aggiunge al lavoro

- Una pagina CRUD nuova e due esistenti da estendere.
- Tre dialoghi del gestionale da allineare.
- ⚠️ **Il gruppo di test del gestionale sulle camere va rifatto**, non solo quello del sito:
  è un'interfaccia diversa sulle stesse regole, e le prove che contano sono quelle
  incrociate — la stessa combinazione deve essere accettata o rifiutata **allo stesso modo**
  dai due software.

---

## 9. Impatto sui test

| Gruppo del piano Flask | Da rifare? |
|---|---|
| A, B, C, G | no |
| D — iscrizione al viaggio | **sì**, la parte sulla sistemazione |
| E — la posta | no |
| F — i due software concordano | **sì**, se il gestionale userà le stesse funzioni |
| **Nuovo gruppo** — combinazioni camere | **sì**: una prova per ciascuna forma di 1, 2, 3 e 4 persone, più `NESSUNA CAMERA`, più il ricalcolo quando cambia il numero di partecipanti |
| **Gruppo camere del piano MAUI** | **sì** — vedi §8-ter: il gestionale usa le stesse regole con un'altra interfaccia, e le prove che contano sono quelle **incrociate** |

⚠️ Si somma al giro già previsto per la protezione dei dati personali
(`2026-09-05-Analisi_Protezione_Dati_Personali_Sito.md`). **Entrambi toccano il passo 5 e
il passo 2**: conviene farli e collaudarli insieme, non uno dopo l'altro.

---

## 10. La frase da ricordare

Oggi il sito **lascia comporre una sistemazione impossibile e poi la rifiuta**. Il disegno
nuovo non aggiunge controlli: toglie la possibilità di sbagliare. ⚠️ È la stessa differenza
fra un modulo che ti dice «data non valida» e un calendario da cui scegli — e costa meno
codice, non di più, perché il ramo che rifiuta sparisce insieme al caso che rifiutava.
