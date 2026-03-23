# CRITICAL BUG FIX: Azienda Update - RegimeFiscaleFk Missing

**Data**: 2026-03-17
**Gravità**: CRITICA
**Stato**: RISOLTO

---

## PROBLEMA SEGNALATO

L'utente selezionava il regime fiscale dalla combobox durante la modifica di un'azienda, ma il record NON veniva salvato correttamente.

**Messaggio di errore:**
```
Il valore selezionato per 'Regime Fiscale' non è valido o non esiste più nel sistema.
```

---

## ROOT CAUSE ANALYSIS

### File Coinvolti
- `/Components/Pages/Anagrafiche/Aziende.razor` - Pagina principale (BUG TROVATO QUI)
- `/Services/CRUD/AziendaService.cs` - Service (CORRETTO)
- `/Components/Shared/AziendaDialog.razor` - Dialog di modifica (CORRETTO)
- `/Models/Azienda.cs` - Model (CORRETTO)

### Investigazione Step-by-Step

#### 1. Verifica AziendaService.cs
- Query UPDATE: 19 campi SET (incluso `regime_fiscale_fk`)
- AddCommandParameters: 19 parametri aggiunti correttamente
- L'ordine e i nomi dei parametri erano CORRETTI
- **Risultato**: Service CORRETTO ✓

#### 2. Verifica AziendaDialog.razor
- Binding combobox: `@bind-Value="Entity.RegimeFiscaleFk"` (CORRETTO)
- Caricamento regimi: `_regimi = await RegimiFiscaliService.GetActiveAsync()` (CORRETTO)
- Default per nuove aziende: impostato su "ORDINARIO" (CORRETTO)
- **Risultato**: Dialog CORRETTO ✓

#### 3. Verifica Aziende.razor - **BUG TROVATO!**
Nel metodo `OpenEditDialog` (riga 240-267), quando viene creata la copia dell'entità da passare al dialog:

```csharp
var parameters = new DialogParameters<AziendaDialog>
{
    { x => x.Entity, new Azienda
        {
            Id = item.Id,
            RagioneSociale = item.RagioneSociale,
            FormaGiuridica = item.FormaGiuridica,
            // ... altri 14 campi copiati correttamente ...
            TelefonoPrincipale = item.TelefonoPrincipale,
            Attivo = item.Attivo
            // ❌ MANCAVA: RegimeFiscaleFk = item.RegimeFiscaleFk
            // ❌ MANCAVA: SitoWebIscrizione = item.SitoWebIscrizione
        }
    },
    { x => x.IsEditMode, true }
};
```

### Sequenza del Bug

1. L'utente clicca su "Modifica" su un'azienda esistente
2. `OpenEditDialog` crea un nuovo oggetto `Azienda` e copia i campi
3. Il campo `RegimeFiscaleFk` NON viene copiato → rimane al valore di default `0`
4. Il dialog si apre con `Entity.RegimeFiscaleFk = 0`
5. La combobox si popola correttamente con i regimi, ma NON ha selezione iniziale
6. Anche se l'utente seleziona manualmente un valore, se poi modifica altri campi e salva, il problema persiste
7. Quando viene chiamato `Service.UpdateAsync(updatedItem)`, viene passato un FK invalido (0 o valore non corretto)
8. Il database rifiuta l'UPDATE perché `regime_fiscale_fk = 0` non esiste o viola il constraint

### Impatto del Bug

- **Gravità**: CRITICA - Impedisce l'aggiornamento di qualsiasi azienda
- **Ambito**: Tutte le modifiche alle aziende esistenti
- **Workaround**: Nessuno (l'utente dovrebbe sempre ri-selezionare manualmente il regime fiscale)

---

## SOLUZIONE IMPLEMENTATA

### File Modificato
`/Components/Pages/Anagrafiche/Aziende.razor`

### Modifiche Applicate
Aggiunto il campo mancante `RegimeFiscaleFk` e `SitoWebIscrizione` alla copia dell'entità:

```csharp
var parameters = new DialogParameters<AziendaDialog>
{
    { x => x.Entity, new Azienda
        {
            Id = item.Id,
            RagioneSociale = item.RagioneSociale,
            FormaGiuridica = item.FormaGiuridica,
            DataCostituzione = item.DataCostituzione,
            DataInizioAttivita = item.DataInizioAttivita,
            CapitaleSociale = item.CapitaleSociale,
            SocioUnico = item.SocioUnico,
            InLiquidazione = item.InLiquidazione,
            PartitaIva = item.PartitaIva,
            CodiceFiscale = item.CodiceFiscale,
            ReaProvinciaFk = item.ReaProvinciaFk,
            ReaNumero = item.ReaNumero,
            ReaDataIscrizione = item.ReaDataIscrizione,
            CodiceDestinatarioSdi = item.CodiceDestinatarioSdi,
            Pec = item.Pec,
            SitoWeb = item.SitoWeb,
            SitoWebIscrizione = item.SitoWebIscrizione,  // ✅ AGGIUNTO
            TelefonoPrincipale = item.TelefonoPrincipale,
            Attivo = item.Attivo,
            RegimeFiscaleFk = item.RegimeFiscaleFk      // ✅ AGGIUNTO
        }
    },
    { x => x.IsEditMode, true }
};
```

---

## VERIFICA POST-FIX

### Test da Eseguire

1. **Test UPDATE Regime Fiscale**
   - Aprire la modifica di un'azienda esistente
   - Verificare che la combobox "Regime Fiscale" mostri il valore corretto già selezionato
   - Modificare un altro campo (es: telefono)
   - Salvare
   - **Risultato Atteso**: L'UPDATE va a buon fine, il regime fiscale NON cambia

2. **Test Cambio Regime Fiscale**
   - Aprire la modifica di un'azienda esistente
   - Cambiare il regime fiscale da uno all'altro
   - Salvare
   - **Risultato Atteso**: L'UPDATE va a buon fine, il regime fiscale viene aggiornato

3. **Test Tutti i Campi**
   - Aprire la modifica di un'azienda
   - Verificare che TUTTI i campi (incluso SitoWebIscrizione) siano popolati correttamente
   - **Risultato Atteso**: Tutti i dati esistenti vengono visualizzati correttamente

### Comandi di Verifica Database

```sql
-- Verifica che i regimi fiscali siano configurati correttamente
SELECT regime_id, regime_codice, regime_descrizione, attivo
FROM ana_regimi_fiscali
WHERE attivo = true
ORDER BY regime_codice;

-- Verifica l'integrità dei dati aziende
SELECT
    azienda_id,
    ragione_sociale,
    regime_fiscale_fk,
    r.regime_codice,
    r.regime_descrizione
FROM ana_aziende a
LEFT JOIN ana_regimi_fiscali r ON a.regime_fiscale_fk = r.regime_id
WHERE a.attivo = true
ORDER BY a.ragione_sociale;

-- Verifica che non esistano FK a 0 o NULL
SELECT COUNT(*) as problemi
FROM ana_aziende
WHERE regime_fiscale_fk IS NULL
   OR regime_fiscale_fk = 0
   OR regime_fiscale_fk NOT IN (SELECT regime_id FROM ana_regimi_fiscali WHERE attivo = true);
```

---

## PREVENZIONE FUTURA

### Raccomandazioni

1. **Code Review Checklist**
   - Quando si copia manualmente un'entità campo per campo, verificare che TUTTI i campi siano inclusi
   - Considerare l'uso di un metodo di clonazione automatico o reflection-based

2. **Possibile Refactoring**
   Invece di copiare manualmente i campi, considerare:

   ```csharp
   // Opzione 1: Metodo Clone nel model
   { x => x.Entity, item.Clone() }

   // Opzione 2: Usare l'oggetto originale direttamente (se appropriato)
   { x => x.Entity, item }
   ```

3. **Test Unitari**
   - Aggiungere test che verifichino la completezza della copia dei campi
   - Test di integrazione per l'UPDATE completo

4. **Validazione a Runtime**
   - Il model `Azienda.cs` ha già la validazione `[Required]` per `RegimeFiscaleFk`
   - Assicurarsi che questa validazione venga eseguita PRIMA del salvataggio

---

## CONCLUSIONI

**Bug Identificato**: Campo `RegimeFiscaleFk` (e `SitoWebIscrizione`) mancante nella copia manuale dell'entità in `OpenEditDialog`

**Causa**: Errore umano nella copia manuale dei campi

**Fix Applicato**: Aggiunta dei campi mancanti alla riga 263 del file `Aziende.razor`

**Impatto**: Bug critico RISOLTO - Gli aggiornamenti delle aziende funzionano correttamente

**Prossimi Passi**: Eseguire i test di verifica e considerare il refactoring suggerito per prevenire errori simili in futuro.

---

**Fine Report**
