# Preparare il gestionale per il nuovo sito — guida passo passo

**Per Antonio — 22 settembre 2026**

Il nuovo sito legge **direttamente dal gestionale**: quello che c'è scritto qui dentro compare
là fuori, e quello che manca qui non compare da nessuna parte. Questa guida elenca le sei cose
da fare perché il sito possa nascere. **Nessuna richiede competenze tecniche**: sono tutte
schermate che già conosci.

> ⏱️ **Tempo stimato: mezza giornata**, esclusa la scrittura delle schede dei tour enduro
> (capitolo 7), che dipende da quanto materiale hai già pronto.
>
> ⚠️ Finché questi punti non sono fatti, **il sito non può partire**: nascerebbe vuoto.

---

## Indice

1. [Creare le sezioni del sito](#1-creare-le-sezioni-del-sito)
2. [Dire a ogni tipo di viaggio in quale sezione va](#2-dire-a-ogni-tipo-di-viaggio-in-quale-sezione-va)
3. [Segnare i tour brevi](#3-segnare-i-tour-brevi)
4. [Accendere le funzioni web](#4-accendere-le-funzioni-web)
5. [Social e contatti del sito](#5-social-e-contatti-del-sito)
6. [Posti disponibili e soglia di allarme](#6-posti-disponibili-e-soglia-di-allarme)
7. [Pubblicare le schede dei tour](#7-pubblicare-le-schede-dei-tour)

---

## 1. Creare le sezioni del sito

**Dove:** menu **Tabelle → Tabelle Viaggi → Descrizioni WEB dei Tipi di Viaggio**

**Cosa fare:** crea una riga per ogni **pagina del sito** dedicata a un genere di viaggio.
Per ognuna servono tre cose:

| Campo | Cosa scriverci | Esempio |
|---|---|---|
| **Descrizione web** | Il nome come lo leggerà il visitatore | `Viaggi in 4x4` |
| **Slug** | Lo stesso nome in minuscolo, senza accenti né spazi (si usano i trattini) | `viaggi-in-4x4` |
| **Ordine** | In che posizione compare nel menu del sito (10, 20, 30…) | `10` |

**Perché serve:** ⛔️ **questa tabella oggi è completamente vuota**, e finché lo resta il sito
non ha nessuna sezione. È l'elenco delle pagine del catalogo.

ℹ️ **Consiglio sull'ordine:** usa 10, 20, 30 invece di 1, 2, 3. Così se un domani vuoi
infilare una sezione in mezzo, le dai 15 e non devi rinumerare tutto.

ℹ️ **Consiglio sullo slug:** è l'indirizzo della pagina su internet — diventerà
`sardegnafuoritraccia.it/tour/viaggi-in-4x4`. Scegli con calma: cambiarlo dopo che Google ha
indicizzato la pagina fa perdere posizioni.

**Per iniziare bastano due sezioni:** `Viaggi in 4x4` e `Enduro`.

---

## 2. Dire a ogni tipo di viaggio in quale sezione va

**Dove:** menu **Tabelle → Tabelle Viaggi → Tipologie Viaggio**

**Cosa fare:** apri ogni tipologia e scegli, nel campo della descrizione web, **a quale sezione
appartiene** fra quelle create al punto 1.

⭐️ **Più tipologie possono puntare alla stessa sezione, ed è voluto.** Per te «enduro
bicilindrici» e «enduro monocilindrici» sono due cose diverse, perché cambiano mezzo e
difficoltà. Per chi guarda il sito sono **una sezione sola, "Enduro"**: la differenza fra bi e
monocilindrico non gli dice niente, mentre quella fra un enduro e un 4x4 sì.

**Perché serve:** ⛔️ oggi **nessuna delle sette tipologie** ha questo collegamento. Senza, il
gestionale non sa in quale pagina del sito mettere un viaggio, e il viaggio non compare.

### Come funzionano le sezioni sul sito

Questa è la parte che ti farà risparmiare tempo negli anni: **le sezioni compaiono e spariscono
da sole.**

- Una sezione compare nel menu del sito **solo se contiene almeno un tour pubblicato con una
  partenza da domani in avanti**.
- Quando l'ultima partenza di quel genere è passata, **la sezione sparisce da sola**.
- Il giorno in cui farai il primo viaggio in e-bike, ti basterà creare la sezione (punto 1) e
  collegarla (punto 2): **comparirà da sola** quando metterai la prima data, e non dovrai
  chiedere a nessuno di modificare il sito.

---

## 3. Segnare i tour brevi

**Dove:** menu **Tabelle → Tabelle Viaggi → Tipologie Viaggio** (stessa schermata del punto 2)

**Cosa fare:** metti la spunta **tour breve** sulle tipologie che sono esperienze da **1 a 3
giorni**.

**Perché serve:** il sito ha una sezione «Tour giornalieri e weekend» pensata per chi arriva in
Sardegna con il volo diretto su Olbia e cerca un'avventura corta. Quella sezione compare **solo
se** esistono tour marcati così. ℹ️ Se oggi non ne hai, **lascia perdere questo punto**: lo
farai quando ne proporrai uno.

---

## 4. Accendere le funzioni web

**Dove:** menu **Anagrafiche → Anagrafica Aziende** → apri **SFT** → linguetta **Funzioni Web**

**Cosa fare:** attiva gli interruttori delle funzioni che vuoi sul sito (newsletter, recensioni,
mappe…).

**Perché serve:** ⛔️ oggi **non c'è nessuna riga**: il gestionale considera tutte le funzioni
web **spente**. Anche se i contenuti ci sono, il sito non li mostrerebbe.

---

## 5. Social e contatti del sito

**Dove:** menu **Tabelle → Tabelle web → Indirizzi web**

**Cosa fare:** inserisci gli indirizzi dei tuoi canali — Facebook, Instagram, YouTube, WhatsApp,
e il sito stesso.

**Perché serve:** ⛔️ oggi la tabella è **vuota**. Sono i collegamenti che compaiono in fondo a
ogni pagina del sito e dentro le newsletter. Senza, il piè di pagina resta spoglio.

---

## 6. Posti disponibili e soglia di allarme

**Dove:** menu **Anagrafiche → Anagrafica Viaggi e Date** → apri un viaggio → **Dati Generali**

**Cosa fare:** per ogni viaggio compila due numeri:

| Campo | Cosa significa | Esempio |
|---|---|---|
| **Capienza massima** | Quanti posti hai in tutto su quel viaggio | `12` |
| **Soglia di allarme** | Sotto questo numero il sito scrive «Rimangono solo N posti» | `4` |

**Perché serve:** è la spinta alla prenotazione — «Rimangono solo 2 posti» fa decidere chi è
indeciso. ⛔️ Oggi la **soglia non è impostata su nessun viaggio** (la capienza sì, su 6 viaggi
su 23), quindi quella scritta non comparirebbe mai.

ℹ️ Il conteggio dei posti rimasti è **automatico**: il gestionale sottrae gli iscritti e
aggiorna il sito da solo, in tempo reale. A zero posti compare **SOLD OUT**.

---

## 7. Pubblicare le schede dei tour

**Dove:** menu **Anagrafiche → Anagrafica Viaggi e Date** → apri un viaggio → linguetta
**Contenuti Web**

**Cosa fare:** due cose distinte.

### 7a. Pubblicare quelle che hai già

Hai **8 schede pronte, tutte ancora in bozza**. Rileggile e portale allo stato **pubblicato**.

**Perché serve:** ⛔️ una scheda in bozza **non esiste** per il sito. Con tutte in bozza il
catalogo sarebbe vuoto anche dopo aver fatto i punti 1-6.

Dentro la scheda trovi le linguette **Contenuti**, **Galleria**, **Itinerario**, **Mappa**,
**Traduzioni**: sono le sezioni della pagina che il visitatore vedrà.

⚠️ **Una scheda senza fotografie non va pubblicata.** Sul sito diventerebbe una casella grigia
in mezzo alle altre, e fa più danno che non esserci: abbiamo deciso che le sezioni senza foto
non si mostrano affatto.

### 7b. Le schede che mancano del tutto

⛔️ **Tutte e otto le schede che hai riguardano viaggi in 4x4.** I tour **enduro** hanno
partenze già in calendario (22 e 29 ottobre) ma **nessuna scheda web**: senza, la sezione
«Enduro» non comparirà, anche dopo aver fatto tutto il resto.

Servono almeno **una o due schede enduro** perché il sito nasca con più di una sezione.

---

## Riepilogo in una pagina

| # | Dove | Cosa | Quanto è urgente |
|---|---|---|---|
| 1 | Tabelle → Tabelle Viaggi → Descrizioni WEB | Creare le sezioni | ⛔️ **Bloccante** |
| 2 | Tabelle → Tabelle Viaggi → Tipologie Viaggio | Collegare i tipi alle sezioni | ⛔️ **Bloccante** |
| 3 | Tabelle → Tabelle Viaggi → Tipologie Viaggio | Spunta «tour breve» | Solo se ne hai |
| 4 | Anagrafiche → Aziende → Funzioni Web | Accendere le funzioni | ⛔️ **Bloccante** |
| 5 | Tabelle → Tabelle web → Indirizzi web | Social e contatti | Importante |
| 6 | Anagrafiche → Viaggi e Date → Dati Generali | Capienza e soglia | Importante |
| 7 | Anagrafiche → Viaggi e Date → Contenuti Web | Pubblicare le 8 schede + fare le enduro | ⛔️ **Bloccante** |

**Le quattro voci bloccanti sono quelle senza le quali il sito non può proprio nascere.**
Le altre due lo migliorano molto, ma si possono aggiungere subito dopo.

---

*Se qualcosa non torna o una schermata non è come descritta qui, fermati e chiedi: è più veloce
sistemare la guida che rifare il lavoro.*
