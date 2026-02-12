# Eliminazione Tabella `ana_fornitori`

## Contesto

Dopo la migrazione da `ana_fornitori` a `ana_controparti`, la vecchia tabella `ana_fornitori` non è più necessaria poiché:

1. ✅ È stata creata la nuova tabella `ana_controparti` con supporto sia per fornitori che clienti
2. ✅ I dati sono stati migrati completamente
3. ✅ Le foreign key sono state aggiornate (da `transazione_fornitore_id` a `transazione_controparte_id`)
4. ✅ Il codice C# è stato aggiornato per usare la nuova struttura

## ⚠️ Procedura di Eliminazione Sicura

### Prerequisiti

- [ ] Backup completo del database eseguito
- [ ] Tutti gli script di migrazione (01-07) sono stati eseguiti con successo
- [ ] L'applicazione funziona correttamente con la nuova struttura

### Step 1: Verifica Foreign Keys

Esegui lo script di verifica per controllare se ci sono ancora foreign key attive:

```bash
psql -U tuo_utente -d tuo_database -f 08_verifica_fk_ana_fornitori.sql
```

**Output atteso:**
```
✓ La tabella ana_fornitori ESISTE ancora
✓ Nessuna FK punta a ana_fornitori - SAFE TO DELETE
✓ Migrazione completa
```

Se vedi messaggi di errore (✗), **NON procedere** con l'eliminazione finché non hai risolto i problemi.

### Step 2: Eliminazione Tabella

**SOLO se lo Step 1 ha dato esito positivo**, procedi con l'eliminazione:

```bash
psql -U tuo_utente -d tuo_database -f 09_elimina_ana_fornitori.sql
```

Lo script:
1. Crea automaticamente un backup di sicurezza (`ana_fornitori_backup_before_delete`)
2. Verifica una ultima volta l'assenza di FK attive
3. Elimina la tabella `ana_fornitori`
4. Conferma l'eliminazione

### Step 3: Test Post-Eliminazione

Dopo l'eliminazione, verifica che l'applicazione funzioni correttamente:

- [ ] Accedi all'applicazione
- [ ] Naviga in "Anagrafica Controparti"
- [ ] Verifica che tutti i fornitori siano visibili
- [ ] Crea una nuova transazione contabile
- [ ] Verifica che il dropdown controparti funzioni
- [ ] Controlla i report contabili

### Step 4: Pulizia Backup (Opzionale)

Dopo **alcuni giorni** di utilizzo senza problemi, puoi eliminare il backup temporaneo:

```sql
DROP TABLE IF EXISTS ana_fornitori_backup_before_delete;
```

## 🔄 Rollback (in caso di emergenza)

Se dopo l'eliminazione scopri che serve ripristinare `ana_fornitori`:

```sql
-- Ripristina dalla tabella di backup
CREATE TABLE ana_fornitori AS
SELECT * FROM ana_fornitori_backup_before_delete;

-- Ricrea gli indici (vedi SqlScripts/Create_AnaFornitori.sql per dettagli)
-- ...

-- Ricrea le foreign key necessarie
-- ...
```

## 📊 Checklist Finale

Prima di considerare completata la migrazione:

- [ ] Script 08 eseguito con successo (nessuna FK attiva)
- [ ] Backup database completo eseguito
- [ ] Script 09 eseguito (tabella eliminata)
- [ ] Applicazione testata completamente
- [ ] Nessun errore nei log per almeno 48 ore
- [ ] Backup temporaneo `ana_fornitori_backup_before_delete` eliminato

## 🆘 Supporto

In caso di problemi:
- Consulta il documento: [Implementazione_Contabile.md](../../Documents/Implementazione_Contabile.md)
- Verifica i log PostgreSQL: `/var/log/postgresql/`
- Controlla i log applicazione

---

**Ultima modifica**: 12/02/2026
