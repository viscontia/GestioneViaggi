# Database Migration Checklist

## Scopo
Questa checklist previene errori comuni durante le migrazioni del database, come il disallineamento tra schema SQL e codice C#.

## Checklist Pre-Migration

- [ ] **Backup del database**: Creare un backup completo prima di eseguire qualsiasi migrazione
- [ ] **Review dello script SQL**: Verificare che lo script SQL sia corretto e non contenga errori di sintassi
- [ ] **Test in ambiente di sviluppo**: Eseguire prima la migrazione in un database di test

## Checklist Durante Migration

- [ ] **Eseguire script in ordine**: Se ci sono più script, eseguirli nell'ordine corretto (verificare i numeri/date nei nomi)
- [ ] **Verificare successo esecuzione**: Controllare che non ci siano errori nell'output
- [ ] **Verificare schema aggiornato**: Controllare che le modifiche siano effettivamente applicate

## Checklist Post-Migration

### 1. Verifica Schema Database
```sql
-- Verifica struttura tabella
\d+ table_name

-- Verifica funzioni
\df+ function_name

-- Verifica procedure
\df+ procedure_name
```

### 2. Verifica Allineamento Codice C#

Quando si aggiunge/modifica una colonna:

- [ ] **Model C# aggiornato**: La proprietà esiste nel modello C#?
- [ ] **Service aggiornato**: Il service legge/scrive la nuova colonna?
- [ ] **UI aggiornata**: I componenti Blazor usano la nuova proprietà?
- [ ] **Stored Procedures aggiornate**: Tutte le SP che leggono/scrivono quella tabella sono aggiornate?
- [ ] **Functions aggiornate**: Tutte le function che restituiscono quella tabella sono aggiornate?

### 3. Test Funzionalità

- [ ] **Build completo**: `dotnet build` senza errori
- [ ] **Test CRUD base**: Creare, leggere, aggiornare, eliminare record
- [ ] **Test UI**: Verificare che tutti i dialoghi/form si aprano correttamente
- [ ] **Test validazione**: Verificare che le validazioni funzionino

### 4. Verifica Log

- [ ] **Console logs**: Controllare la console dell'app per errori
- [ ] **Database logs**: Verificare i log del database PostgreSQL
- [ ] **Application logs**: Verificare i log dell'applicazione

## Common Issues & Solutions

### Issue: "An unhandled error has occurred" all'apertura di un dialogo

**Causa**: Disallineamento tra colonne restituite da una SQL function e colonne lette dal C# Service

**Soluzione**:
1. Verificare che la function SQL restituisca TUTTE le colonne richieste
2. Verificare che il codice C# non cerchi di leggere colonne inesistenti
3. Aggiungere try-catch più specifici per identificare la colonna problematica

**Debug**:
```csharp
try {
    var ordinal = reader.GetOrdinal("column_name");
    // Se questa riga fallisce, la colonna non esiste nel result set
} catch (IndexOutOfRangeException ex) {
    _logger.LogError("Column 'column_name' not found in result set");
}
```

### Issue: Foreign Key Violation

**Causa**: Tentativo di inserire/aggiornare con riferimento a un ID che non esiste

**Soluzione**:
1. Verificare che i dati di riferimento esistano
2. Controllare l'ordine di esecuzione delle operazioni
3. Considerare l'uso di transazioni

### Issue: NOT NULL Constraint Violation

**Causa**: Tentativo di inserire NULL in una colonna NOT NULL

**Soluzione**:
1. Fornire valori di default nel codice C#
2. Fornire valori di default nella stored procedure
3. Se necessario, modificare lo schema per permettere NULL

## Migration Script Template

```sql
-- =============================================
-- Migration: [DESCRIZIONE BREVE]
-- Data: YYYY-MM-DD
-- Autore: [NOME]
-- Descrizione: [DESCRIZIONE DETTAGLIATA]
-- =============================================

-- Backup point
BEGIN;

-- 1. Schema changes
-- ALTER TABLE ...

-- 2. Data migration
-- UPDATE ...

-- 3. Update stored procedures
-- CREATE OR REPLACE PROCEDURE ...

-- 4. Update functions
-- CREATE OR REPLACE FUNCTION ...

-- Verification queries
-- SELECT * FROM ...

COMMIT;
-- ROLLBACK; -- Decommentare in caso di problemi
```

## Rollback Procedure

In caso di problemi:

1. **Immediate rollback**: Se la migration è in una transazione, eseguire `ROLLBACK;`
2. **Restore da backup**: Se la migration è già committata, ripristinare dal backup
3. **Reverse script**: Creare uno script che inverte le modifiche

## Tools

- **pgAdmin**: GUI per PostgreSQL
- **DBeaver**: Multi-database GUI
- **psql**: CLI PostgreSQL
- **pg_dump**: Backup utility
- **pg_restore**: Restore utility

## Riferimenti

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Npgsql Documentation](https://www.npgsql.org/doc/)
- Cartella progetto: `/SqlScripts/`
