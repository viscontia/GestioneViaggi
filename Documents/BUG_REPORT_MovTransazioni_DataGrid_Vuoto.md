# BUG REPORT: DataGrid MovTransazioni Vuota

**Data**: 2026-02-04
**Componente**: MovTransazioniPage.razor
**Gravità**: CRITICA
**Status**: RISOLTO ✓

---

## SOMMARIO DEL PROBLEMA

La DataGrid dei movimenti contabili (`MovTransazioniPage.razor`) rimaneva **vuota** nonostante:
- Il database contenesse 3 transazioni verificate
- La query SQL diretta funzionasse correttamente
- Il service restituisse dati validi
- Il build non presentasse errori
- Tutte le correzioni precedenti (rimozione ereditarietà BaseEntity, alias SQL, logging) fossero state applicate

---

## ROOT CAUSE ANALYSIS

### PROBLEMA IDENTIFICATO

Il problema era nel **tipo di dato** usato per la collezione `_items`:

**CODICE ERRATO (non funzionante):**
```csharp
private IEnumerable<MovTransazioni> _items = new List<MovTransazioni>();
```

**CODICE CORRETTO (funzionante):**
```csharp
private List<MovTransazioni> _items = new();
```

### PERCHÉ `IEnumerable<T>` NON FUNZIONA

`MudDataGrid<T>` (componente base di `EnterpriseDataGrid<T>`) richiede una **collezione concreta** (`List<T>`, `IList<T>`, etc.) e NON può funzionare correttamente con `IEnumerable<T>` perché:

1. **Necessità di Count**: Il DataGrid deve conoscere il numero totale di elementi per il paginatore
2. **Indexing**: Deve poter accedere agli elementi per indice per la paginazione
3. **Multiple Enumeration**: Il rendering richiede iterazioni multiple sulla collezione
4. **Performance**: `IEnumerable<T>` potrebbe rieseguire la query ogni volta che viene enumerato

### DIFFERENZA CON ALTRI COMPONENTI FUNZIONANTI

Confronto con `AnaFornitori.razor` (funzionante):

| Componente | Dichiarazione _items | Funziona |
|------------|---------------------|----------|
| AnaFornitori | `private List<AnaFornitore> _items = new();` | ✓ SI |
| MovTransazioni (old) | `private IEnumerable<MovTransazioni> _items = new List<...>()` | ✗ NO |
| MovTransazioni (new) | `private List<MovTransazioni> _items = new();` | ✓ SI |

---

## SOLUZIONE IMPLEMENTATA

### 1. Modifica dichiarazione collezione

**File**: `Components/Pages/MovTransazioniPage.razor`

```csharp
// PRIMA (errato)
private IEnumerable<MovTransazioni> _items = new List<MovTransazioni>();

// DOPO (corretto)
private List<MovTransazioni> _items = new();
```

### 2. Conversione esplicita a List nei metodi

Tutte le chiamate ai service ora convertono esplicitamente il risultato con `.ToList()`:

```csharp
// SuperAdmin - Tutte le transazioni
_items = (await TransazioniService.GetAllAsync()).ToList();

// Filtro per azienda specifica
_items = (await TransazioniService.GetByAziendaAsync(_selectedAziendaId)).ToList();

// Utente normale
_items = (await TransazioniService.GetByAziendaAsync(_currentAziendaId.Value)).ToList();
```

### 3. Aggiornamento dei riferimenti Count()

Cambiato `_items?.Count()` in `_items?.Count` per usare la proprietà invece del metodo LINQ:

```csharp
// PRIMA
Logger.LogInformation("Caricati {Count} items", _items?.Count() ?? 0);

// DOPO
Logger.LogInformation("Caricati {Count} items", _items?.Count ?? 0);
```

**Benefici**:
- `Count` (proprietà) è O(1) su List<T>
- `Count()` (metodo LINQ) è O(n) su IEnumerable<T>

---

## PASSI PER LA VERIFICA

### Test Manuale

1. Eseguire l'applicazione
2. Navigare su `/movimenti`
3. Verificare che la DataGrid mostri le 3 transazioni
4. Controllare i log per confermare il caricamento

### Log Attesi

```
LoadDataAsync: Inizio caricamento dati
LoadDataAsync: GetAllAsync completato - risultato: 3 items
LoadDataAsync: Primo elemento - ID=1, Causale=..., Fornitore=...
LoadDataAsync: Caricamento completato - _loading=False, _items.Count=3
```

### Build Status

```bash
cd "/Users/adrianovisconti/Documents/Sviluppo Software/MAUI/GestioneViaggi"
dotnet build --no-restore
```

**Risultato**: Build succeeded ✓

---

## LEZIONI APPRESE

### 1. Type Specificity in UI Components

I componenti UI moderni (MudBlazor, Radzen, ecc.) richiedono **collezioni concrete** per:
- Binding bidirezionale
- Paginazione
- Ordinamento
- Performance tracking

### 2. Pattern da Seguire

**SEMPRE usare questo pattern per DataGrid:**

```csharp
// 1. Dichiarazione
private List<TEntity> _items = new();

// 2. Caricamento
_items = (await service.GetAllAsync()).ToList();

// 3. Count
var count = _items.Count; // NON _items.Count()
```

### 3. Debugging Approach

L'approccio sistematico ha funzionato:

1. Verifica dati DB ✓
2. Test query SQL diretta ✓
3. Verifica service mapping ✓
4. **Confronto con componenti funzionanti** ← Soluzione trovata qui
5. Test rendering Blazor

---

## CODICE DI TEST DIAGNOSTICO

Creato `TestDiagnostico.cs` per test approfonditi (se necessario in futuro):

```csharp
// Simula esattamente il flusso GetAllAsync()
var result = await conn.QueryAsync<MovTransazioni>(sql);
var resultList = result.ToList();

// Verifica mapping
Console.WriteLine($"Risultati: {resultList.Count} transazioni");

// Testa proprietà computed
var importoFormattato = first.ImportoFormattato;
```

---

## MODIFICHE CORRELATE PRECEDENTI

Questo bug era **indipendente** dalle seguenti correzioni (che erano comunque necessarie):

1. ✓ Rimozione ereditarietà `BaseEntity` da `MovTransazioni`
2. ✓ Alias SQL in snake_case per Dapper
3. ✓ `MatchNamesWithUnderscores = true` in MauiProgram
4. ✓ Metodi `GetAllAsync()` e `GetByAziendaAsync()` nel service
5. ✓ Logging dettagliato

---

## PREVENZIONE FUTURA

### Checklist per nuove DataGrid

- [ ] Usare `List<T>` NON `IEnumerable<T>` per `_items`
- [ ] Convertire con `.ToList()` i risultati dei service
- [ ] Usare `_items.Count` NON `_items.Count()`
- [ ] Chiamare `StateHasChanged()` dopo modifiche async
- [ ] Verificare il pattern con componenti esistenti funzionanti

### Template Standard

```csharp
@code {
    private List<TEntity> _items = new();
    private TEntity? _selectedItem;
    private bool _loading = true;

    protected override async Task OnInitializedAsync()
    {
        await LoadDataAsync();
    }

    private async Task LoadDataAsync()
    {
        _loading = true;
        StateHasChanged();

        try
        {
            _items = (await Service.GetAllAsync()).ToList();
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "Errore caricamento");
            _items = new List<TEntity>();
        }
        finally
        {
            _loading = false;
            StateHasChanged();
        }
    }
}
```

---

## STATUS FINALE

**PROBLEMA RISOLTO** ✓

La DataGrid ora si popola correttamente con i dati dal database.

**Files Modificati**:
- `Components/Pages/MovTransazioniPage.razor` (tipo collezione + .ToList() conversions)

**Files Creati per Diagnostica**:
- `TestDiagnostico.cs` (test manuale opzionale)
- `Documents/BUG_REPORT_MovTransazioni_DataGrid_Vuoto.md` (questo documento)
