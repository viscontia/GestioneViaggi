# Configurazione Campi Data in MudBlazor

## Guida alla Digitazione Rapida dei Campi Data

Questo documento descrive la configurazione corretta dei componenti `MudDatePicker` per consentire la **digitazione rapida da tastiera** nelle form gestionali.

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

### 3. **DateFormat="dd/MM/yyyy"**
Deve corrispondere al formato della maschera per garantire coerenza.

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
⚠️ **Attenzione:** In Blazor Server con alta latenza, la combinazione `Editable="true"` + `Mask` può causare problemi di cursore (bug MudBlazor #6796). Questo NON si applica a MAUI Blazor Hybrid.

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

---

## Riferimenti

- **MudBlazor Documentation:** [MudDatePicker](https://mudblazor.com/components/datepicker)
- **File di Esempio:**
  - `/Components/Shared/ClienteDialog.razor` (linee 63-70, 156-178)
  - `/Components/Shared/AziendaDialog.razor` (linee 89-128, 209-245)

---

**Ultima modifica:** 2026-01-02
**Autore:** Adriano Visconti
**Versione:** 1.0
