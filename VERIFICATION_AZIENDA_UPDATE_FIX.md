# Verifica Fix: Errore "Non è possibile eliminare" durante UPDATE di Azienda

## Problema Identificato

Quando l'utente modificava un'azienda e selezionava un valore non valido per:
- **Regime Fiscale** (`regime_fiscale_fk`)
- **Provincia REA** (`rea_provincia_fk`)

PostgreSQL generava un errore **23503 (foreign_key_violation)** perché il valore selezionato non esisteva nelle tabelle di riferimento.

Il `DatabaseExceptionHelper` traduceva **TUTTI** gli errori 23503 come:
```
"Non è possibile eliminare l'ana_aziende perché è utilizzato in altre parti del sistema"
```

Questo messaggio era **SBAGLIATO** per due motivi:
1. L'operazione era un **UPDATE**, non un DELETE
2. Il problema non era "l'azienda è usata altrove", ma "il valore selezionato non esiste"

## Root Cause Analysis

Il codice originale in `DatabaseExceptionHelper.cs` (linea 29-39) NON distingueva tra:

### Scenario 1: DELETE che fallisce (messaggio corretto)
```
DELETE FROM ana_regimi_fiscali WHERE regime_id = 1;
-- Errore: "Non è possibile eliminare il regime fiscale perché è utilizzato in altre parti del sistema"
-- Dettaglio PostgreSQL: "Key (regime_id)=(1) is still referenced from table "ana_aziende"."
```

### Scenario 2: UPDATE che fallisce (messaggio ERRATO)
```
UPDATE ana_aziende SET regime_fiscale_fk = 999 WHERE azienda_id = 1;
-- Errore VECCHIO: "Non è possibile eliminare l'ana_aziende perché è utilizzato in altre parti del sistema"
-- Errore CORRETTO: "Il valore selezionato per 'Regime Fiscale' non è valido o non esiste più nel sistema."
-- Dettaglio PostgreSQL: "insert or update on table "ana_aziende" violates foreign key constraint..."
```

## Soluzione Implementata

### File Modificato
`/Users/adrianovisconti/Documents/Sviluppo Software/MAUI/GestioneViaggi/Helpers/DatabaseExceptionHelper.cs`

### Cambiamenti

1. **Distinzione tra DELETE e INSERT/UPDATE** (linea 30-31)
   ```csharp
   bool isDeleteOperation = ex.Detail?.Contains("is still referenced from table") == true;
   ```

2. **Messaggio DELETE** (linea 33-43) - INVARIATO
   ```csharp
   if (isDeleteOperation)
   {
       message = $"Non è possibile eliminare {prefix}{label} perché è utilizzato in altre parti del sistema...";
   }
   ```

3. **Messaggio INSERT/UPDATE** (linea 45-60) - NUOVO
   ```csharp
   else
   {
       string constraintName = ExtractConstraintNameFromMessage(ex.MessageText);
       string fieldName = ExtractFieldNameFromConstraint(constraintName);

       if (!string.IsNullOrEmpty(fieldName))
       {
           message = $"Il valore selezionato per '{fieldName}' non è valido o non esiste più nel sistema.";
       }
       else
       {
           message = $"Uno dei valori selezionati per {prefix}{label} non è valido o non esiste più nel sistema.";
       }
   }
   ```

4. **Nuove Funzioni Helper** (linea 97-140)
   - `ExtractConstraintNameFromMessage()`: Estrae il nome del constraint dal messaggio di errore
   - `ExtractFieldNameFromConstraint()`: Mappa il constraint a un nome campo user-friendly

### Mapping Constraint → Nome Campo
```csharp
{ "regime_fiscale_fk", "Regime Fiscale" }
{ "rea_provincia_fk", "Provincia REA" }
{ "azienda_fk", "Azienda" }
{ "causale_fk", "Causale" }
{ "valuta_fk", "Valuta" }
{ "aliquota_iva_fk", "Aliquota IVA" }
{ "paese_fk", "Paese" }
{ "provincia_fk", "Provincia" }
{ "comune_fk", "Comune" }
{ "reparto_fk", "Reparto" }
```

## Test di Verifica

### Prerequisiti
1. Assicurarsi di avere almeno un'azienda nel database
2. Conoscere un ID di regime fiscale che NON esiste (es. 999)
3. Avere accesso alla UI di modifica azienda

### Test Case 1: UPDATE con FK non valida

**Passi:**
1. Aprire la schermata Anagrafiche → Aziende
2. Selezionare un'azienda esistente e cliccare "Modifica"
3. Modificare il campo "Regime Fiscale" selezionando un valore
4. MANUALMENTE modificare il valore nel database prima del salvataggio:
   ```sql
   -- Simulare un regime fiscale eliminato
   DELETE FROM ana_regimi_fiscali WHERE regime_id = [ID_SELEZIONATO];
   ```
5. Cliccare "Salva" nella UI

**Risultato Atteso:**
```
Errore: Il valore selezionato per 'Regime Fiscale' non è valido o non esiste più nel sistema.
```

**Risultato PRECEDENTE (ERRATO):**
```
Errore: Non è possibile eliminare l'ana_aziende perché è utilizzato in altre parti del sistema.
```

### Test Case 2: DELETE di Regime Fiscale usato

**Passi:**
1. Aprire la schermata Anagrafiche → Regimi Fiscali
2. Tentare di eliminare un regime fiscale usato da almeno un'azienda

**Risultato Atteso (INVARIATO):**
```
Errore: Non è possibile eliminare il regime fiscale perché è utilizzato in altre parti del sistema (es. azienda).
```

### Test Case 3: UPDATE con Provincia REA non valida

**Passi:**
1. Modificare un'azienda
2. Selezionare una Provincia REA
3. Eliminarla dal database prima del salvataggio
4. Salvare

**Risultato Atteso:**
```
Errore: Il valore selezionato per 'Provincia REA' non è valido o non esiste più nel sistema.
```

## Verifica Build

```bash
cd "/Users/adrianovisconti/Documents/Sviluppo Software/MAUI/GestioneViaggi"
dotnet build --no-restore
```

**Risultato:**
- Build completata con successo
- 0 errori
- 1 warning (MT0182 - non rilevante, riguarda OpenGLES su MacCatalyst)

## Impatto

### Tabelle/Entità Beneficiarie
Questa fix migliora i messaggi di errore per TUTTE le entità che hanno foreign key, tra cui:
- `ana_aziende` (regime_fiscale_fk, rea_provincia_fk)
- `mov_transazioni` (azienda_fk, causale_fk, valuta_fk, aliquota_iva_fk)
- `ana_clienti` (paese_fk, provincia_fk, comune_fk)
- `ana_fornitori` (azienda_fk)
- Tutte le altre 20+ tabelle che usano il `DatabaseExceptionHelper`

### Servizi Impattati
Tutti i servizi che usano `DatabaseExceptionHelper.WrapException()`:
- AziendaService
- ClienteService
- MovTransazioniService
- AnaViaggiService
- E tutti gli altri 20+ servizi CRUD

## Note Tecniche

### Differenza nei Detail di PostgreSQL

**DELETE che fallisce per FK:**
```
Detail: "Key (regime_id)=(1) is still referenced from table \"ana_aziende\"."
MessageText: "update or delete on table \"ana_regimi_fiscali\" violates foreign key constraint..."
```

**UPDATE con FK non valida:**
```
Detail: "Key (regime_fiscale_fk)=(999) is not present in table \"ana_regimi_fiscali\"."
MessageText: "insert or update on table \"ana_aziende\" violates foreign key constraint \"ana_aziende_regime_fiscale_fk_fkey\""
```

La fix usa la presenza di `"is still referenced from table"` nel `Detail` per distinguere i due casi.

## Prossimi Passi Consigliati

1. **Test Manuale**: Eseguire i test case sopra descritti
2. **Test Automatizzato**: Creare unit test per `DatabaseExceptionHelper` (opzionale)
3. **Monitoring**: Verificare i log dopo il deploy per vedere se i nuovi messaggi sono più chiari
4. **Documentazione**: Aggiornare la documentazione utente con i nuovi messaggi di errore

## Checklist di Verifica

- [x] Codice modificato e compilato con successo
- [ ] Test Case 1 eseguito e passato
- [ ] Test Case 2 eseguito e passato (regressione)
- [ ] Test Case 3 eseguito e passato
- [ ] Utenti informati del cambio messaggi di errore
- [ ] Documentazione aggiornata (se necessario)

## Autore e Data
- **Data Fix**: 2026-03-17
- **File Modificato**: `Helpers/DatabaseExceptionHelper.cs`
- **Linee Modificate**: 22-140 (aggiunte 3 nuove funzioni, modificata logica case 23503)
- **Backward Compatibility**: SI (i messaggi DELETE rimangono identici)
