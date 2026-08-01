# Configurazione Campi Data in MudBlazor

## Guida alla Digitazione Rapida dei Campi Data

Questo documento descrive la configurazione corretta dei componenti `MudDatePicker` per consentire la **digitazione rapida da tastiera** nelle form gestionali.

> ⚠️ **Leggere prima la sezione "Un anno sbagliato passa senza avvisi"** in fondo. La maschera da sola
> **non** protegge dai refusi sull'anno: un solo tasto fuori posto produce una data assurda che nessun
> controllo formale intercetta. Ogni campo data operativo deve avere anche una validazione di plausibilità.

---

## Configurazione Standard

Per abilitare la digitazione rapida nei campi data, utilizzare la seguente configurazione:

```razor
<MudDatePicker @bind-Date="Entity.PropertyName"
    For="@(() => Entity.PropertyName)"
    Label="Etichetta Campo"
    Variant="Variant.Outlined"
    Class="mb-3"
    DateFormat="dd/MM/yyyy"
    Editable="true"
    Mask="@(new DateMask("dd/MM/yyyy"))"
    Placeholder="gg/mm/aaaa"
    HelperText="Digitare la data (es: 15031990) o selezionare dal calendario" />
```

---

## Parametri Essenziali

### 1. **Editable="true"**
Abilita la digitazione manuale nel campo.

### 2. **Mask="@(new DateMask("dd/MM/yyyy"))"**
Applica la maschera di input che formatta automaticamente la data durante la digitazione.

**IMPORTANTE:**
- Utilizzare `DateMask` con il formato `"dd/MM/yyyy"` (NON usare pattern numerici come `"00/00/0000"`)
- La sintassi corretta è: `new DateMask("dd/MM/yyyy")`

### 3. **DateFormat="dd/MM/yyyy"** — obbligatorio, non cosmetico
Deve corrispondere al formato della maschera.

⚠️ **Se manca**, il campo non usa `dd/MM/yyyy`: usa il formato breve della **lingua del sistema operativo**
(`CultureInfo.CurrentCulture.ShortDatePattern`). L'applicazione **non imposta** la cultura da nessuna parte,
quindi eredita quella del PC. Su una macchina configurata in inglese lo short pattern è `M/d/yyyy`: la
maschera scrive `01/12/2026` (1° dicembre) e il campo lo rilegge come **12 gennaio**. Giorno e mese si
scambiano in silenzio, senza errori. Sul Mac di sviluppo non si vede perché la regione è italiana — è
esattamente il tipo di guasto che compare solo sulla macchina del cliente.

### 4. **Placeholder="gg/mm/aaaa"**
Fornisce un suggerimento visivo all'utente sul formato atteso.

### 5. **HelperText**
Testo di aiuto che spiega come inserire la data.

---

## Comportamento Atteso

### Digitazione Rapida
- L'utente digita: `15031990`
- Il campo formatta automaticamente: `15/03/1990`
- **Nessun separatore `/` da digitare manualmente**

### Funzionalità Supportate
✅ Digitazione continua senza slash
✅ Formattazione automatica durante la digitazione
✅ Backspace/Delete funzionano correttamente
✅ Calendario alternativo tramite icona
✅ Validazione date (se configurata)

---

## Validazione (Opzionale)

Per aggiungere validazione personalizzata:

```razor
<MudDatePicker @bind-Date="Entity.DataInizioAttivita"
    For="@(() => Entity.DataInizioAttivita)"
    Validation="@(new Func<DateTime?, IEnumerable<string>>(ValidateDataInizioAttivita))"
    DateFormat="dd/MM/yyyy"
    Editable="true"
    Mask="@(new DateMask("dd/MM/yyyy"))"
    Placeholder="gg/mm/aaaa"
    HelperText="La data deve essere >= Data Costituzione" />
```

Nel code-behind:

```csharp
private IEnumerable<string> ValidateDataInizioAttivita(DateTime? value)
{
    if (value.HasValue && Entity.DataCostituzione.HasValue)
    {
        if (value.Value < Entity.DataCostituzione.Value)
        {
            yield return "Data Inizio Attività deve essere >= Data Costituzione";
        }
    }
}
```

---

## Esempi di Implementazione

### Campo Data Obbligatorio

```razor
<MudDatePicker @bind-Date="Entity.DataNascita"
    For="@(() => Entity.DataNascita)"
    Label="Data di Nascita"
    Required="true"
    RequiredError="La data di nascita è obbligatoria"
    Variant="Variant.Outlined"
    DateFormat="dd/MM/yyyy"
    Editable="true"
    Mask="@(new DateMask("dd/MM/yyyy"))"
    Placeholder="gg/mm/aaaa"
    Adornment="Adornment.End"
    AdornmentText="*"
    AdornmentColor="Color.Error"
    HelperText="Digitare la data (es: 15031990) o selezionare dal calendario" />
```

### Campo Data Opzionale

```razor
<MudDatePicker @bind-Date="Entity.DataCostituzione"
    For="@(() => Entity.DataCostituzione)"
    Label="Data Costituzione (opzionale)"
    Variant="Variant.Outlined"
    DateFormat="dd/MM/yyyy"
    Editable="true"
    Mask="@(new DateMask("dd/MM/yyyy"))"
    Placeholder="gg/mm/aaaa"
    HelperText="Digitare la data (es: 15031990) o selezionare dal calendario" />
```

### Campo Data con Validazione Cross-Field

```razor
<MudDatePicker @bind-Date="Entity.DocumentoRilasciatoScadenza"
    For="@(() => Entity.DocumentoRilasciatoScadenza)"
    Label="Data Scadenza Documento"
    Validation="@(new Func<DateTime?, IEnumerable<string>>(ValidateDataScadenza))"
    Variant="Variant.Outlined"
    DateFormat="dd/MM/yyyy"
    Editable="true"
    Mask="@(new DateMask("dd/MM/yyyy"))"
    Placeholder="gg/mm/aaaa"
    HelperText="Scadenza deve essere > Data Rilascio" />
```

---

## Note Tecniche

### Architettura: MAUI Blazor Hybrid
Questa configurazione funziona perfettamente in **MAUI Blazor Hybrid** perché:
- Rendering client-side (come Blazor WebAssembly)
- Nessun round-trip verso il server
- Nessuna latenza che causa problemi di cursore

### Differenze con Blazor Server
In Blazor Server con alta latenza, la combinazione `Editable="true"` + `Mask` può causare problemi di cursore
(bug MudBlazor #6796).

⚠️ **Questa nota diceva che il problema "NON si applica a MAUI Blazor Hybrid": è un'assunzione troppo
ottimistica.** Nel 2026-08 è stata salvata una data con anno **262** da un operatore certo di aver digitato
2026, e il valore osservato (`0262`) è esattamente quello che si ottiene se **una sola** battuta finisce in
posizione sbagliata. Non è stato possibile provare il meccanismo dentro la WebView, ma l'assunzione va
considerata non verificata. La difesa non è sperare che il cursore si comporti bene: è **validare il valore**.

### Model Binding
Il campo del modello deve essere di tipo `DateTime?` (nullable):

```csharp
public class Cliente : BaseEntity
{
    public DateTime? DataNascita { get; set; }
    public DateTime? DocumentoRilasciatoData { get; set; }
    public DateTime? DocumentoRilasciatoScadenza { get; set; }
}
```

---

## Un anno sbagliato passa senza avvisi

Caso reale (2026-08): partenza salvata con date **01/12/0262 – 06/12/0262**. Nessun messaggio, nessun
campo in errore. Riproducendo la maschera fuori dall'applicazione (`DateMask` + `DefaultConverter<DateTime?>`,
MudBlazor 8.15.0) è emerso questo:

| digitazione | testo prodotto dalla maschera | valore interpretato |
|---|---|---|
| `0 1 1 2 2 0 2 6` (corretta) | `01/12/2026` | 2026-12-01 ✔ |
| `0 1 1 2 0 2 2 6` (**una sola inversione**) | `01/12/0226` | **0226-12-01** |
| `0 1 1 2 0 2 6 2` | `01/12/0262` | **0262-12-01** ← il caso osservato |
| `0 1 1 2 0 2 6` (una battuta persa) | `01/12/026` | *rifiutato*, campo vuoto |

Due fatti da tenere a mente quando si fa un campo data:

1. **Il blocco anno accetta uno zero iniziale.** `0262` è un anno di 4 cifre formalmente valido: la maschera
   lo accetta e il converter lo interpreta senza obiezioni. Solo un anno **incompleto** (meno di 4 cifre)
   viene rifiutato — ed è il caso *fortunato*, perché almeno si vede.
2. **Un anno assurdo supera tutti i controlli relativi.** Su `ana_date_viaggi` esistevano già "fine ≥ inizio"
   e "durata = numero giorni dell'anagrafica": un refuso sull'anno sposta **entrambe** le date insieme, quindi
   ordine e durata restano perfetti. Serve un controllo **assoluto** sull'anno, che prima non esisteva da
   nessuna parte — né nella form, né nel database.

### Cosa usare

Controlli centralizzati in `Validation/Semantic/DateValidator.cs`, messaggi in `Validation/Core/ValidationMessages.cs`:

```csharp
// Blocca: anno fuori da 2000-2100 (pavimento di plausibilità, non regola commerciale)
var esito = DateValidator.CheckAnnoPlausibile(Entity.DataInizio, "Data Inizio");
if (!esito.IsValid) { Snackbar.Add(esito.ErrorMessage, Severity.Error); return; }

// Chiede conferma (non vieta): anno precedente a quello in corso, oppure oltre 5 anni nel futuro
if (DateValidator.MotivoDaConfermare(Entity.DataInizio) is { } motivo) { /* MessageBox */ }
```

Più `MinDate="@DateValidator.DataMinima"` / `MaxDate="@DateValidator.DataMassima"` sul picker — che però
limitano **solo il calendario**, non il testo digitato: la validazione in `Submit()` resta indispensabile.

Sul database la stessa soglia è il vincolo `chk_data_viaggio_anno_plausibile` (`SqlScripts/509`). Le due
soglie vanno tenute allineate.

**Perché la conferma sull'anno passato e non un divieto:** una partenza non si programma nell'anno scorso,
ma una data storica può servire per registrare l'esistente. E soprattutto: nessun intervallo, per quanto
stretto, intercetta il refuso realistico (2027 invece di 2026). La conferma sì.

### Due tolleranze diverse, non una sola

L'anno passato non pesa uguale ovunque, quindi `MotivoDaConfermare` prende `anniIndietroAmmessi`:

| ambito | valore | perché |
|---|---|---|
| **Viaggi** (`ViaggioDateDialog`) | `0` (default) | una partenza non si programma nell'anno scorso: si conferma **sempre** |
| **Contabilità** (`MovTransazioniEditDialog`, `PagaOraDialog`) | `DateValidator.AnniIndietroContabilita` = `1` | a inizio anno si chiude legittimamente l'esercizio precedente: chiedere conferma su ogni registrazione sarebbe solo un fastidio |

In entrambi i casi si conferma da **due** anni indietro in su, e oltre **5** anni nel futuro.

### Due pavimenti, non uno solo

⚠️ **Il pavimento 2000 vale solo per le date operative.** Applicarlo a una data di nascita o alla
costituzione di una società sarebbe sbagliato: chi è nato nel 1960 o un'azienda fondata nel 1975 sono
dati del tutto normali.

| tipo di data | pavimento | metodo |
|---|---|---|
| **operative** — partenze, transazioni, pagamenti | `AnnoMinimo` = **2000** | `CheckAnnoPlausibile(...)` |
| **storiche** — nascita, costituzione, inizio attività, REA, rilascio documento | `AnnoMinimoStorico` = **1900** | `CheckDataStorica(...)` |

`CheckDataStorica` fa i due controlli assoluti che servono sempre insieme — anno entro 1900–2100 **e**
data non futura — con `ammetteFutura: true` per i casi che possono legittimamente stare avanti (la
scadenza di un documento). Per le storiche la conferma non è "l'anno è passato" (sarebbe la norma) ma
`MotivoDaConfermareStorica`: oltre **100 anni** indietro.

### Stato dei campi data nell'applicazione

Tutti i `MudDatePicker` hanno `DateFormat="dd/MM/yyyy"` (allineamento del 2026-08-01: ne mancava in
**16** campi) e i limiti di calendario `MinDate`/`MaxDate`. La validazione di plausibilità è nelle form
che **registrano** dati — partenze, transazioni, pagamento immediato, clienti, aziende — mentre i
dialoghi di stampa hanno solo il formato, perché i loro campi sono filtri e non finiscono su nessuna
tabella.

---

## Checklist Implementazione

Quando si implementa un nuovo campo data, verificare:

- [ ] `Editable="true"` presente
- [ ] `Mask="@(new DateMask("dd/MM/yyyy"))"` configurata correttamente
- [ ] `DateFormat="dd/MM/yyyy"` corrisponde alla maschera
- [ ] `Placeholder="gg/mm/aaaa"` presente
- [ ] `HelperText` spiega il formato (es: 15031990)
- [ ] Proprietà del modello è `DateTime?` (nullable)
- [ ] `@bind-Date` utilizza la proprietà corretta
- [ ] `For="@(() => Entity.Property)"` configurato per validazione
- [ ] Testato: digitare 8 cifre senza slash funziona
- [ ] Testato: calendario alternativo funziona
- [ ] **`DateFormat` presente** (senza, il campo segue la lingua del PC e può scambiare giorno e mese)
- [ ] **Validazione di plausibilità dell'anno** con `DateValidator.CheckAnnoPlausibile` nel salvataggio
- [ ] **Conferma sulle date insolite** con `DateValidator.MotivoDaConfermare`, se il campo è operativo
- [ ] Testato: digitare un anno che inizia per zero (es. `01120262`) viene rifiutato

---

## Riferimenti

- **MudBlazor Documentation:** [MudDatePicker](https://mudblazor.com/components/datepicker)
- **File di Esempio:**
  - `/Components/Shared/ClienteDialog.razor` (linee 63-70, 156-178)
  - `/Components/Shared/AziendaDialog.razor` (linee 89-128, 209-245)

---

**Ultima modifica:** 2026-08-01
**Autore:** Adriano Visconti
**Versione:** 1.1
