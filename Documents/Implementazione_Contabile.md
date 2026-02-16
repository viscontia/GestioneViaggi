# 📊 IMPLEMENTAZIONE SISTEMA CONTABILE - GESTIONE VIAGGI OFFROAD

**Progetto**: Gestione Viaggi Offroad
**Database**: PostgreSQL 17.5
**Data Creazione**: 12/02/2026
**Ultima Modifica**: 15/02/2026
**Versione**: 2.0 - Sistema Completo con Gestione IVA

---

# INDICE

## PARTE I: SISTEMA BASE
1. [Obiettivi e Architettura del Sistema](#parte-i-sistema-base)
2. [Roadmap di Implementazione Completa](#roadmap-di-implementazione-completa)
3. [Sistema Validazione Metadata-Driven](#sistema-di-validazione-metadata-driven)
4. [Sistema "Paga Ora"](#sistema-paga-ora---gestione-pagamenti-multipli)

## PARTE II: ESTENSIONE IVA
5. [IVA - Obiettivi e Scelte Architetturali](#parte-ii-estensione-iva)
6. [IVA - Implementazione Database (Step 1-4)](#step-1-database---tabella-ana_aliquote_iva)
7. [IVA - Implementazione Backend (Step 5-7)](#step-5-modelli-c---classi-dati)
8. [IVA - Implementazione UI Blazor (Step 8-9)](#step-8-ui-blazor---componente-aliquotaivaselectrazor)

## PARTE III: STRUTTURA DATI E REPORTISTICA
9. [Struttura Database Completa](#struttura-database---dettaglio)
10. [View di Reportistica](#view-di-reportistica)
11. [Trigger Automatici](#trigger-automatici)

## PARTE IV: MODIFICHE APPLICATIVE
12. [Modifiche UI Blazor](#modifiche-ui-blazor)
13. [Codice Backend](#codice-backend)

## PARTE V: TESTING E DEPLOYMENT
14. [Test di Validazione Completi](#test-di-validazione)
15. [Deployment e Rollback](#deployment-e-rollback)

## PARTE VI: RIFERIMENTI E GOVERNANCE
16. [Glossario Contabile](#glossario-contabile)
17. [Note Importanti](#note-importanti)
18. [Best Practices e Raccomandazioni](#best-practices-e-raccomandazioni)
19. [Benefici del Sistema](#benefici-del-sistema-implementato)
20. [Metriche di Qualità](#metriche-di-qualità)
21. [Roadmap Futura Unificata](#roadmap-futura)
22. [Supporto e Documentazione](#supporto-e-documentazione)

---

# PARTE I: SISTEMA BASE

## 🎯 Obiettivi e Architettura del Sistema

### Problema Iniziale
Il sistema attuale gestiva solo il **ciclo passivo** (fornitori), con una semantica del segno orientata esclusivamente ai debiti:
- `causale_segno = +1` → aumenta il debito verso fornitore
- `causale_segno = -1` → diminuisce il debito

Questa impostazione rendeva impossibile gestire il **ciclo attivo** (clienti) e calcolare correttamente il margine dei viaggi.

### Soluzione Implementata - Sistema Base

1. **Refactoring `ana_fornitori` → `ana_controparti`**
   - Supporto sia fornitori che clienti nella stessa tabella
   - Flag `is_fornitore` e `is_cliente` (possono essere entrambi TRUE)

2. **Aggiunta colonna `causale_ciclo`**
   - `ATTIVO`: ciclo clienti (fatture emesse, incassi)
   - `PASSIVO`: ciclo fornitori (fatture ricevute, pagamenti)

3. **Sistema Pagamenti con Transazioni PG/IN**
   - Pagamenti gestiti tramite transazioni PG (Pagamento) e IN (Incasso)
   - Link alle fatture originali tramite `transazione_fattura_fk`
   - Calcolo automatico del residuo da pagare/incassare

4. **View di reportistica**
   - Partitari fornitori/clienti con saldo progressivo
   - Margini viaggi (ricavi - costi)
   - Scadenzario pagamenti/incassi

5. **Sistema Metadata-Driven per Validazione**
   - Scadenze obbligatorie configurabili per causale
   - Auto-generazione scadenze con giorni default
   - Trigger di validazione senza hardcoding

### Architettura Esistente (Pre-IVA)

Il sistema contabile base era già strutturato con:

1. **Sistema Metadata-Driven**
   - Tabella `ana_tipi_causali` con metadati per validazione automatica
   - Trigger `fn_validate_transazione_metadata()` per scadenze, stati, ecc.
   - Zero hardcoding di codici causali nel codice

2. **Cicli Bilaterali (ATTIVO/PASSIVO)**
   - Colonna `causale_ciclo` distingue fornitori (PASSIVO) da clienti (ATTIVO)
   - Componente `ControparteSelect.razor` filtra automaticamente per ciclo
   - Service layer auto-determina `transazione_tipo_movimento`

3. **Gestione Multi-Valuta**
   - Tabella `ana_valute` con flag `valuta_is_base` (true solo per EUR)
   - Trigger `fn_calcola_importo_eur()` converte automaticamente in EUR
   - Service `ExchangeRateService` recupera tassi di cambio real-time

4. **Pagamenti Multipli**
   - Colonna `transazione_fattura_fk` collega pagamenti (PG/IN) a fatture (FT/FV)
   - Metodo `PagaOraAsync()` gestisce pagamenti parziali e calcolo stato
   - View `vw_partitario_*` mostra residui da pagare

5. **View Reportistica**
   - `vw_partitario_fornitori` / `vw_partitario_clienti`: Estratti conto
   - `vw_margini_viaggi`: Calcolo margine (ricavi - costi)
   - `vw_scadenzario`: Scadenze con priorità urgenza

---

## 📋 Roadmap di Implementazione Completa

### FASE 1: Schema Database
- [x] Creare tabella `ana_controparti`
- [x] Migrare dati da `ana_fornitori` a `ana_controparti`
- [x] Aggiungere colonna `causale_ciclo` a `ana_tipi_causali`
- [x] Creare causali per ciclo ATTIVO (FV, IN, NCA, NDA)
- [x] ~~Creare tabella `mov_pagamenti`~~ (creata poi rimossa - 13/02/2026)
- [x] Rinominare `transazione_fornitore_id` → `transazione_controparte_id`
- [x] Eliminare tabella `mov_pagamenti` (13/02/2026 - non utilizzata)

### FASE 2: View e Logica di Business
- [x] View `vw_partitario_fornitori`
- [x] View `vw_partitario_clienti`
- [x] View `vw_margini_viaggi`
- [x] View `vw_scadenzario`
- [x] Trigger aggiornamento automatico `transazione_stato`

### FASE 3: Codice C# Backend (85% COMPLETATA - 13/02/2026)
- [x] Refactoring modelli DTO (MovTransazioni, AnaControparte, AnaTipoCausale)
- [x] Adattamento servizi CRUD (ContropartiService, MovTransazioniService)
- [x] Aggiornamento validazioni (metadata-driven + trigger)
- [x] ~~AnaFornitoriService marcato come `[Obsolete]`~~ → **Eliminato completamente** (13/02/2026)
- [x] Rimossa registrazione `AnaFornitoriService` da MauiProgram.cs
- [ ] Unit test
- [ ] Deprecare componenti legacy (FornitoreSelect, AnaFornitori.razor)

### FASE 4: UI Frontend (Blazor) (70% COMPLETATA - 13/02/2026)
- [x] Componente `ControparteSelect.razor` con filtro dinamico `causale_ciclo`
- [x] Form MovTransazioni con selezione controparte filtrata per ciclo
- [x] Dialog `PagaOraDialog.razor` per pagamenti rapidi
- [x] Scadenza reattiva in MovTransazioniEditDialog
- [ ] Rinominare menu "Fornitori" → "Controparti" (menu NavBar)
- [ ] Deprecare componente `FornitoreSelect.razor`
- [ ] Nuove pagine per partitari clienti
- [ ] Dashboard margini viaggi

### FASE 5: Sistema Validazione e Pagamenti (COMPLETATA - 12/02/2026)
- [x] Sistema metadata-driven per validazione transazioni
- [x] Trigger auto-generazione scadenze
- [x] Funzionalità "Paga Ora" con gestione pagamenti multipli
- [x] Validazione coerenza stato/data pagamento
- [x] UI reattiva per scadenze obbligatorie

### FASE 6: Cleanup e Refactoring (COMPLETATA - 13/02/2026)
- [x] Eliminata tabella `mov_pagamenti` (non utilizzata)
- [x] Eliminato `AnaFornitoriService.cs` (sostituito da `ContropartiService`)
- [x] Rimossa registrazione servizio da `MauiProgram.cs`
- [x] Aggiornate VIEW reportistica per usare `transazione_fattura_fk`
- [x] Creato componente `ControparteSelect.razor` con filtraggio dinamico

**Componenti Legacy (da deprecare in futuro):**
- `FornitoreSelect.razor` - usato da `StampaMovimentiDialog` e altri componenti legacy
- `AnaFornitori.razor` - pagina non più accessibile da menu (route `/ana-fornitori`)
- `AnaFornitoriEditDialog.razor` - dialog legacy

### FASE 7: Gestione IVA (COMPLETATA - 14-15/02/2026)
- [x] Step 1: Tabella `ana_aliquote_iva` con aliquote multi-tenant
- [x] Step 2: Colonne IVA su `mov_transazioni` (imponibile, IVA, lordo, modalità)
- [x] Step 3: Metadati IVA su `ana_tipi_causali` (genera_iva, richiede_iva)
- [x] Step 4: Trigger calcolo IVA automatico con supporto correzioni manuali
- [x] Step 5-7: Backend C# (modelli, service layer, validazioni)
- [x] Step 8-9: UI Blazor (componenti IVA reattivi, griglia aggiornata)
- [x] Testing e validazione
- [x] Documentazione completa

---

## 🔒 Sistema di Validazione Metadata-Driven

### Problema Risolto
In precedenza, le regole di validazione erano hardcodate nel codice C# e nei constraint SQL, rendendo difficile:
- Personalizzare le regole per azienda
- Modificare requisiti senza deploy
- Gestire causali con caratteristiche diverse

### Soluzione Implementata

#### 1. Metadati Causali (`ana_tipi_causali`)

Aggiunte 3 nuove colonne per guidare dinamicamente la validazione:

```sql
causale_richiede_scadenza BOOLEAN NOT NULL DEFAULT FALSE
causale_giorni_scadenza_default INTEGER DEFAULT NULL
causale_genera_scadenza_auto BOOLEAN NOT NULL DEFAULT FALSE
```

**Configurazione Standard:**
| Causale | Richiede Scadenza | Giorni Default | Genera Auto |
|---------|-------------------|----------------|-------------|
| FT (Fattura Passiva) | ✓ | 30 | ✓ |
| ND (Nota Debito) | ✓ | 30 | ✓ |
| FV (Fattura Attiva) | ✓ | 30 | ✓ |
| NC (Nota Credito) | ✗ | NULL | ✗ |
| PG (Pagamento) | ✗ | NULL | ✗ |
| IN (Incasso) | ✗ | NULL | ✗ |

**Motivazione Contabile:**
- Le fatture (FT, FV, ND) richiedono sempre una scadenza per la gestione del cashflow
- I pagamenti (PG, IN) non hanno scadenza perché rappresentano movimenti finanziari già avvenuti
- Le note di credito (NC) possono non avere scadenza perché sono immediate

#### 2. Trigger di Validazione Dinamica

**File:** `Migration_Create_Validation_Trigger.sql`

Funzione: `fn_validate_transazione_metadata()`

**RULE 1 - Scadenza Obbligatoria (Metadata-Driven):**
```sql
IF v_causale.causale_richiede_scadenza = TRUE
   AND NEW.transazione_data_scadenza IS NULL THEN
    RAISE EXCEPTION 'La causale "%" richiede la Data Scadenza obbligatoria.'
```

**RULE 2 - Auto-Generazione Scadenza:**
```sql
IF v_causale.causale_genera_scadenza_auto = TRUE
   AND NEW.transazione_data_scadenza IS NULL THEN
    NEW.transazione_data_scadenza :=
        COALESCE(NEW.transazione_data_documento, NEW.transazione_data)
        + v_causale.causale_giorni_scadenza_default;
```

**RULE 3 - Coerenza Stato PAGATO:**
```sql
IF NEW.transazione_stato = 'PAGATO'
   AND NEW.transazione_data_pagamento IS NULL THEN
    RAISE EXCEPTION 'Se lo stato è PAGATO, la Data Pagamento è obbligatoria.'
```

**RULE 4 - Cleanup Stato DA_PAGARE:**
```sql
IF NEW.transazione_stato = 'DA_PAGARE'
   AND NEW.transazione_data_pagamento IS NOT NULL THEN
    NEW.transazione_data_pagamento := NULL;  -- Auto-pulizia
```

**Vantaggi Tecnici:**
1. **Zero Hardcoding** - Nessun codice causale nel trigger
2. **Multi-Tenant Ready** - Ogni azienda può configurare le sue causali
3. **Modifiche Istantanee** - Cambiare i metadati aggiorna subito il comportamento
4. **Manutenibilità** - Logica centralizzata in un unico trigger

#### 3. Constraint Aggiuntivi

**Data Documento Non Futura:**
```sql
ALTER TABLE mov_transazioni
ADD CONSTRAINT chk_data_documento_non_futura
CHECK (transazione_data_documento IS NULL
    OR transazione_data_documento <= transazione_data);
```

**Motivazione Contabile:**
La data del documento (es. fattura emessa il 10/02) non può essere successiva alla data di registrazione contabile (es. registrata il 05/02). Questo previene errori di data entry.

**⚠️ Constraint Rimosso (13/02/2026):**
Il constraint `chk_pagamento_dopo_scadenza` (che impediva pagamenti prima della scadenza) è stato **rimosso** perché errato. In contabilità è normale pagare fatture prima della scadenza (anzi, è auspicabile!). Il constraint `chk_pagamento_dopo_documento` (che impone `data_pagamento >= data_documento`) rimane attivo e garantisce la correttezza contabile.

**File:** [SqlScripts/Migration_Fix_Pagamento_Constraint.sql](SqlScripts/Migration_Fix_Pagamento_Constraint.sql)

---

## 💳 Sistema "Paga Ora" - Gestione Pagamenti Multipli

### Architettura Scelta: Transazioni PG/IN vs Tabella `mov_pagamenti`

#### Approccio Implementato: Creazione Transazioni PG/IN

**Motivazione Contabile Italiana:**
In contabilità italiana, i pagamenti sono movimenti contabili a tutti gli effetti. Creare una transazione separata con causale PG (Pagamento) o IN (Incasso) è lo standard:
- Appare nel partitario del fornitore/cliente
- Genera movimenti bancari tracciabili
- È compatibile con export per software contabili (TeamSystem, Zucchetti, ecc.)

**Alternativa Non Scelta:** Tabella `mov_pagamenti` separata
- Pro: Struttura più "relazionale" e normalizzata
- Contro: Pagamenti "nascosti" dalle transazioni principali, non compatibile con export contabili standard

**⚠️ TABELLA RIMOSSA (13/02/2026):**
La tabella `mov_pagamenti` è stata **eliminata** dal database perché non utilizzata. Tutti i pagamenti sono gestiti tramite transazioni PG/IN con `transazione_fattura_fk`. Le VIEW di reportistica calcolano i residui interrogando `mov_transazioni` con filtro `transazione_fattura_fk`. La sezione seguente è mantenuta per documentazione storica, ma lo schema SQL non è più presente nel database.

**Script di rimozione:** [SqlScripts/Migration_Drop_MovPagamenti.sql](SqlScripts/Migration_Drop_MovPagamenti.sql)

### Implementazione `PagaOraAsync()`

**File:** `MovTransazioniService.cs:443`

#### Step-by-Step Logic

**1. Validazione Stato:**
```csharp
if (originalTx.TransazioneStato == "PAGATO")
    throw new InvalidOperationException("Già pagata completamente");
if (originalTx.TransazioneStato == "ANNULLATO")
    throw new InvalidOperationException("Impossibile pagare transazione annullata");
```

**2. Identificazione Causale PG/IN (Cycle-Aware):**
```csharp
string pgCodice = originalCausale.CausaleCiclo == "ATTIVO" ? "IN" : "PG";
// PASSIVO → PG (Pagamento)
// ATTIVO → IN (Incasso)
```

**3. Calcolo Pagamenti Precedenti (FIX Pagamenti Multipli):**
```csharp
string sqlTotalePagato = @"
    SELECT COALESCE(SUM(ABS(transazione_importo_eur)), 0)
    FROM mov_transazioni
    WHERE transazione_fattura_fk = @FatturaId
      AND transazione_stato = 'PAGATO'";

decimal totalePagatoPrecedente = await conn.ExecuteScalarAsync<decimal>(
    sqlTotalePagato, new { FatturaId = transazioneId });
```

**Motivazione Tecnica:**
Questa query somma tutti i pagamenti PG/IN già collegati alla fattura via `transazione_fattura_fk`. Essenziale per gestire correttamente scenari come:
- Fattura 1000€ → Pagamento 1: 400€ → Pagamento 2: 600€

**4. Calcolo Stato Finale (Logica Algebrica Corretta):**
```csharp
decimal totalePagatoComplessivo = totalePagatoPrecedente + importoNuovoPagamento;

if (totalePagatoComplessivo >= importoDocumento)
    nuovoStato = "PAGATO";
else if (totalePagatoComplessivo > 0)
    nuovoStato = "PARZIALMENTE_PAGATO";
```

**5. Protezione da Sovrapagamento:**
```csharp
if (totalePagatoComplessivo > importoDocumento)
{
    throw new InvalidOperationException(
        $"Totale pagamenti ({totalePagatoComplessivo:N2} EUR) supererebbe " +
        $"l'importo del documento ({importoDocumento:N2} EUR). " +
        $"Residuo disponibile: {(importoDocumento - totalePagatoPrecedente):N2} EUR.");
}
```

**6. Transazione Atomica DB:**
```csharp
using var transaction = await conn.BeginTransactionAsync();
try
{
    // INSERT transazione PG con transazione_fattura_fk
    int pgId = await conn.ExecuteScalarAsync<int>(insertSql, ...);

    // UPDATE fattura originale: stato + data_pagamento
    await conn.ExecuteAsync(updateSql, ...);

    await transaction.CommitAsync();
}
catch { await transaction.RollbackAsync(); throw; }
```

**Motivazione Tecnica:**
COMMIT/ROLLBACK garantisce che o entrambe le operazioni riescono o nessuna. Prevenire stati inconsistenti (pagamento registrato ma fattura non aggiornata).

### Scenario di Test - Pagamenti Multipli

```sql
-- Fattura iniziale
INSERT INTO mov_transazioni (...) VALUES (
    ..., importo: 1000 EUR, stato: 'DA_PAGARE', causale: FT, ...
);  -- ID: 100

-- Primo pagamento (400€)
CALL PagaOraAsync(100, 400.00, '2026-02-12', 'Acconto 1');
-- Crea: Transazione PG ID:101, importo 400, fattura_fk=100, stato=PAGATO
-- Aggiorna: Transazione 100 → stato='PARZIALMENTE_PAGATO', data_pagamento=NULL

-- Secondo pagamento (600€)
CALL PagaOraAsync(100, 600.00, '2026-02-20', 'Saldo finale');
-- Query: SELECT SUM(importo) FROM mov_transazioni WHERE fattura_fk=100
--        Risultato: 400€ (pagamento precedente)
-- Calcolo: 400 + 600 = 1000 >= 1000 → PAGATO
-- Crea: Transazione PG ID:102, importo 600, fattura_fk=100, stato=PAGATO
-- Aggiorna: Transazione 100 → stato='PAGATO', data_pagamento='2026-02-20'
```

**Risultato Finale:**
- Fattura 100: PAGATO, data_pagamento = '2026-02-20'
- Pagamento PG 101: 400€, fattura_fk=100
- Pagamento PG 102: 600€, fattura_fk=100

### UI - Componenti Blazor

#### 1. `MovTransazioniEditDialog.razor` - Scadenza Reattiva

**Funzionalità:**
```csharp
private async Task OnCausaleChanged(int causaleId)
{
    _selectedCausale = await CausaliService.GetByIdAsync(causaleId);
    _scadenzaObbligatoria = _selectedCausale.CausaleRichiedeScadenza;

    // Auto-calcolo scadenza
    if (_selectedCausale.CausaleGeneraScadenzaAuto && !_dataScadenza.HasValue)
    {
        DateTime baseDate = _dataDocumento ?? _dataTransazione ?? DateTime.Today;
        _dataScadenza = baseDate.AddDays(_selectedCausale.CausaleGiorniScadenzaDefault.Value);
    }
}
```

**UX:**
- Label dinamica: "Data Scadenza *" se obbligatoria
- Auto-popolamento: Seleziono FT → scadenza appare automaticamente a +30gg
- Validazione client-side: Errore se manca scadenza obbligatoria

#### 2. `PagaOraDialog.razor` - Dialog Pagamento

**Features:**
- Input importo con limiti (min 0.01, max importo documento)
- Data pagamento (max oggi - non si può registrare pagamento futuro)
- Checkbox "Pagamento Totale" auto-imposta importo
- Validazione: impedisce sovrapagamenti

#### 3. `MovTransazioniPage.razor` - Bottone Azioni

**Visibilità Condizionale:**
```razor
@if (cellContext.Item.TransazioneStato is "DA_PAGARE" or "PARZIALMENTE_PAGATO")
{
    <MudIconButton Icon="@Icons.Material.Filled.Payment" Color="Color.Success" />
}
```

**Motivazione UX:**
- Bottone verde "Payment" appare solo per fatture non completamente pagate
- Chiama dialog → service → refresh automatico griglia

---

# PARTE II: ESTENSIONE IVA

## 📊 IVA - Obiettivi e Scelte Architetturali

### Obiettivo del Progetto

Integrare la gestione dell'IVA nel sistema contabile metadata-driven esistente, mantenendo la coerenza architetturale e garantendo:
- **Precisione fiscale** al centesimo
- **Facilità d'uso** per l'utente (calcoli automatici reattivi)
- **Flessibilità** per correzioni manuali (arrotondamenti)
- **Compatibilità** con dati storici pre-IVA
- **Scalabilità** per regimi speciali futuri (74-ter, reverse charge)

### Principi Guida ("Punti d'Oro")

1. **Il pezzo di carta vince sul calcolo matematico**
   Se la fattura cartacea dice 21,99€ ma il calcolo matematico dà 22,00€, il sistema deve permettere all'utente di inserire 21,99€ senza ricalcolare automaticamente. (Trigger - Regola 1)

2. **Modello mentale per CICLO**
   - **PASSIVO (Fornitori):** Utente inserisce LORDO → Sistema scorpora NETTO + IVA
   - **ATTIVO (Clienti):** Utente inserisce NETTO → Sistema calcola IVA + LORDO

3. **IVA solo in EUR**
   Per transazioni in valuta estera (USD, ZAR, TND), l'IVA locale è considerata costo totale (Fuori Campo IVA art. 7-ter). Solo le transazioni in EUR gestiscono IVA detraibile.

4. **Metadata-Driven (Zero Hardcoding)**
   La logica IVA è guidata dai metadati delle causali (`causale_genera_iva`, `causale_richiede_iva`), non da controlli su codici hardcoded nel codice.

5. **Tutti i campi editabili**
   Imponibile, IVA e Lordo sono **sempre editabili** per permettere correzioni manuali di arrotondamenti.

### Metriche di Successo

| Metrica | Target | Metodo Verifica |
|---------|--------|-----------------|
| Precisione calcoli IVA | 100% entro 0,01€ | Test SQL automatici |
| Compatibilità dati storici | 100% transazioni pre-IVA leggibili | Query report senza errori |
| Performance trigger | < 50ms per transazione | EXPLAIN ANALYZE |
| Copertura test | > 95% scenari reali | Checklist test manuali UI |
| Zero errori arrotondamento | 0 EXCEPTION per diff 1 centesimo | Log produzione 30gg |

### Modifiche Necessarie (Impatto Architettura)

| Componente | Tipo Modifica | Impatto | Complessità |
|------------|---------------|---------|-------------|
| `mov_transazioni` | +5 colonne (aliquota, imponibile, IVA, lordo, modalità) | ALTO | MEDIA |
| `ana_tipi_causali` | +3 colonne metadati IVA | MEDIO | BASSA |
| Trigger esistenti | Modifica priorità esecuzione | ALTO | ALTA |
| Service layer | Logica IVA in Create/Update | MEDIO | MEDIA |
| UI Dialog | Nuova sezione IVA con calcolo reattivo | ALTO | ALTA |
| View reportistica | Colonne IVA + calcolo netto/lordo | MEDIO | MEDIA |

**Principio di Compatibilità:**
Tutte le colonne IVA sono **NULLABLE** per garantire che le transazioni esistenti (pre-IVA) continuino a funzionare senza migrazione forzata dei dati.

### Scelte Tecniche Fondamentali

#### 1. Modalità Gestione IVA per CICLO

**Decisione:** Modalità **separata automatica per CICLO** con switch manuale opzionale.

**Razionale:**
- **PASSIVO:** L'utente ha in mano una fattura fornitore con importo LORDO (es. 122€). Chiedergli di scorporare manualmente il netto genera errori e frustrazione.
- **ATTIVO:** Quando l'agenzia emette fattura, ragiona in NETTO (es. "Viaggio 1.000€ + IVA 22%"). Il prezzo del servizio è il netto, l'IVA è una "aggiunta fiscale".

**Implementazione:**
- Campo `transazione_iva_modalita_input` (ENUM: 'LORDO', 'NETTO')
- Trigger auto-imposta modalità basata su `causale_ciclo` se non specificata dall'utente
- UI mostra bottone toggle per invertire la modalità manualmente (casi speciali)

**Calcoli:**
```
MODALITÀ LORDO (PASSIVO - Scorporo):
- Lordo = Importo inserito dall'utente
- Netto = Lordo / (1 + (Aliquota% / 100))
- IVA = Lordo - Netto

MODALITÀ NETTO (ATTIVO - Somma):
- Netto = Importo inserito dall'utente
- IVA = Netto × (Aliquota% / 100)
- Lordo = Netto + IVA
```

**Esempio Pratico:**
```sql
-- Fattura fornitore hotel: 122€ (lordo)
-- Utente inserisce 122€ in campo "Importo"
-- Trigger vede causale PASSIVO → modalità LORDO
-- Calcolo: Netto = 122 / 1.22 = 100.00, IVA = 22.00

-- Fattura cliente viaggio: 1.000€ (netto)
-- Utente inserisce 1.000€ in campo "Importo"
-- Trigger vede causale ATTIVO → modalità NETTO
-- Calcolo: IVA = 1000 × 0.22 = 220.00, Lordo = 1.220.00
```

#### 2. Struttura Aliquote IVA

**Decisione:** Tabella **`ana_aliquote_iva` separata** (non colonna diretta su transazione).

**Razionale:**
- **Multi-tenant:** Ogni azienda può configurare le proprie aliquote (es. aziende estere hanno aliquote diverse)
- **Descrizioni normative:** Possibilità di associare codici "natura" per fatturazione elettronica (N1, N2.1, ecc.)
- **Aliquote speciali:** Fuori Campo (FC), Esente (ES), Non Soggetto (NS) con percentuale 0% ma natura diversa
- **Storicità:** Se cambiano le aliquote nazionali, le transazioni storiche mantengono il riferimento all'aliquota applicata

**Aliquote Standard Italia:**
| Codice | Descrizione | Percentuale | Natura | Uso |
|--------|-------------|-------------|--------|-----|
| 22 | IVA Ordinaria 22% | 22.00 | - | Default fatture IT |
| 10 | IVA Ridotta 10% | 10.00 | - | Servizi turistici specifici |
| 5 | IVA Ridotta 5% | 5.00 | - | Casi speciali |
| 4 | IVA Ridotta 4% | 4.00 | - | Alimentari, libri |
| FC | Fuori Campo IVA | 0.00 | N1 | Servizi esteri art. 7-ter |
| ES | Operazione Esente | 0.00 | N4 | Servizi sanitari, educativi |
| NS | Non Soggetto IVA | 0.00 | N2.1 | Regime forfettario |

#### 3. Posizionamento Logica Calcolo IVA

**Decisione:** Calcolo via **Trigger PostgreSQL** con supporto UI per feedback immediato.

**Razionale:**

**PRO Trigger DB:**
- ✅ **Consistenza assoluta:** Funziona anche se inserimenti da pgAdmin, API esterne, batch jobs
- ✅ **Zero bypass:** Impossibile inserire transazioni con IVA incoerente
- ✅ **Performance:** Calcolo server-side più veloce di round-trip client-server
- ✅ **Audit completo:** Tutti i calcoli tracciati nei log PostgreSQL

**CONTRO Trigger DB:**
- ❌ **Debugging complesso:** Errori trigger meno chiari di exception C#
- ❌ **Testing:** Richiede test SQL invece di unit test C#

**SOLUZIONE IBRIDA (Scelta Finale):**
1. **UI Blazor:** Calcolo "preview" real-time mentre l'utente digita (feedback immediato)
2. **Trigger DB:** Ricalcolo definitivo al salvataggio (garanzia consistenza)
3. **Regola Aurea:** Se UI e Trigger calcolano valori diversi (es. per arrotondamenti), il Trigger mostra WARNING ma **non blocca** se differenza < 0,01€

#### 4. Gestione IVA con Valute Estere

**Decisione:** IVA **solo su transazioni in EUR** (Opzione 1 - MVP).

**Razionale Normativo:**
In Italia, quando un'agenzia viaggi paga un fornitore estero (es. hotel in Tunisia in TND), quella fattura è:
- **Fuori Campo IVA** (Art. 7-ter DPR 633/72) → Non c'è IVA italiana da detrarre
- L'eventuale "VAT" locale estera (es. 18% tunisina) **non è detraibile** in Italia → Diventa **costo**

**Regola Semplice:**
- Valuta = EUR → IVA **gestita** (scorporo/calcolo)
- Valuta ≠ EUR → IVA **azzerata** (tutto diventa costo)

**Implementazione Trigger:**
```sql
-- STEP 3 del trigger fn_calcola_iva_transazione()
IF v_valuta.valuta_codice_iso != 'EUR' THEN
    NEW.transazione_aliquota_iva_fk := NULL;
    NEW.transazione_imponibile_eur := NULL;
    NEW.transazione_iva_eur := NULL;
    NEW.transazione_lordo_eur := NULL;
    RETURN NEW; -- Esci subito
END IF;
```

**Messaggio UI (quando valuta ≠ EUR e causale genera IVA):**
```
ℹ️ Per le transazioni in valuta estera, l'IVA non viene scorporata
   in quanto considerata costo totale (Fuori Campo IVA art. 7-ter o 74-ter).
```

#### 5. Gestione Arrotondamenti (Il "Punto d'Oro")

**Decisione:** **Tutti e tre i campi IVA sempre editabili** + Trigger NON ricalcola se tutti compilati.

**Problema Reale:**
```
Fattura cartacea fornitore:
Imponibile: 100,01€
IVA 22%:     21,99€
Totale:     122,00€

Calcolo matematico software:
100,01 × 0.22 = 22,0022 → arrotondato a 22,00€
100,01 + 22,00 = 122,01€ ❌ NON QUADRA CON FATTURA!

Soluzione: Utente DEVE poter modificare manualmente:
Imponibile: 100,01€ (manuale)
IVA:         21,99€ (manuale corretto)
Totale:     122,00€ (manuale)
```

**Implementazione Trigger (Regola 1 - PRIORITÀ MASSIMA):**
```sql
-- Se TUTTI E TRE i campi sono NOT NULL, significa che l'utente ha inserito manualmente
-- Non ricalcolare, ma VALIDA solo la coerenza matematica
IF NEW.transazione_imponibile_eur IS NOT NULL
   AND NEW.transazione_iva_eur IS NOT NULL
   AND NEW.transazione_lordo_eur IS NOT NULL THEN

    -- Validazione con TOLLERANZA 0.01€ (1 centesimo)
    IF ABS(NEW.transazione_lordo_eur - (NEW.transazione_imponibile_eur + NEW.transazione_iva_eur)) > 0.01 THEN
        RAISE EXCEPTION 'Incoerenza IVA: Lordo (%) != Imponibile (%) + IVA (%)',
            NEW.transazione_lordo_eur, NEW.transazione_imponibile_eur, NEW.transazione_iva_eur;
    END IF;

    -- Tutto OK, non ricalcolare, esci
    RETURN NEW;
END IF;
```

**Tolleranza 0.01€:**
- **Perché 0.01€?** Le differenze di 1 centesimo tra calcolo software e fattura cartacea sono **la norma**, non l'eccezione (dovute a regole arrotondamento diverse tra software contabili)
- **Mai scendere sotto 0.01€** → Genererebbe falsi positivi e blocchi inutili

**UX Blazor:**
Tutti e tre i campi (`MudNumericField`) sono sempre:
- ✅ **Editabili** (non readonly)
- ✅ **OnBlur** triggera ricalcolo degli altri due campi se modificato
- ✅ **Alert informativo** mostra il calcolo automatico come "suggerimento" ma non forza il valore

---

## 🗄️ IVA - Implementazione Database (Step 1-4)

### STEP 1: Database - Tabella `ana_aliquote_iva`

**Obiettivo:** Creare anagrafica aliquote IVA multi-tenant.

**File creato:** `SqlScripts/Create_AnaAliquoteIva.sql`

**DDL Completo:**
```sql
-- =====================================================
-- TABELLA: ana_aliquote_iva
-- Scopo: Anagrafica aliquote IVA per azienda
-- Creato: 14/02/2026
-- =====================================================

CREATE TABLE public.ana_aliquote_iva (
    -- Identificativi
    iva_id SERIAL PRIMARY KEY,
    azienda_fk INTEGER NOT NULL REFERENCES ana_aziende(azienda_id) ON DELETE RESTRICT,

    -- Dati aliquota
    iva_codice VARCHAR(10) NOT NULL,           -- '22', '10', '4', 'FC', 'ES', 'NS'
    iva_descrizione VARCHAR(100) NOT NULL,     -- 'IVA Ordinaria 22%', 'Fuori Campo IVA'
    iva_percentuale NUMERIC(5, 2) NOT NULL DEFAULT 0,

    -- Fatturazione Elettronica (FE)
    iva_natura VARCHAR(10),                    -- N1, N2.1, N3.2, N4, N5, N6.x, N7

    -- Configurazione UI
    is_default BOOLEAN DEFAULT FALSE,          -- Aliquota default per azienda
    is_active BOOLEAN DEFAULT TRUE,
    ordinamento SMALLINT DEFAULT 100,          -- Ordinamento dropdown (1=primo)

    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMPTZ,
    updated_by VARCHAR(50),

    -- Constraint
    CONSTRAINT uk_iva_azienda_codice UNIQUE (azienda_fk, iva_codice),
    CONSTRAINT chk_iva_percentuale CHECK (iva_percentuale >= 0 AND iva_percentuale <= 100),
    CONSTRAINT chk_iva_codice_upper CHECK (iva_codice = UPPER(iva_codice))
);

-- Indici
CREATE INDEX idx_aliquote_iva_azienda ON ana_aliquote_iva(azienda_fk);
CREATE INDEX idx_aliquote_iva_attive ON ana_aliquote_iva(azienda_fk, is_active) WHERE is_active = TRUE;
CREATE INDEX idx_aliquote_iva_default ON ana_aliquote_iva(azienda_fk, is_default) WHERE is_default = TRUE;

-- Commenti
COMMENT ON TABLE ana_aliquote_iva IS 'Anagrafica aliquote IVA multi-tenant - supporta fatturazione elettronica e regimi speciali';
COMMENT ON COLUMN ana_aliquote_iva.iva_codice IS 'Codice aliquota (22, 10, 4, FC=Fuori Campo, ES=Esente, NS=Non Soggetto) - sempre UPPER CASE';
COMMENT ON COLUMN ana_aliquote_iva.iva_percentuale IS 'Percentuale IVA (22.00 per 22%) - 0.00 per FC/ES/NS';
COMMENT ON COLUMN ana_aliquote_iva.iva_natura IS 'Codice natura per FE: N1=escluso art.15, N2=non soggetto, N3=non imponibile, N4=esente, N5=regime margine, N6=reverse charge, N7=altro';
COMMENT ON COLUMN ana_aliquote_iva.is_default IS 'TRUE se aliquota default per azienda (max 1 per azienda) - preselezionata in UI';
COMMENT ON COLUMN ana_aliquote_iva.ordinamento IS 'Ordinamento dropdown UI (1=primo, 100=default, 999=ultimo)';
```

**Dati Iniziali (Azienda Test 6):**
```sql
-- Aliquote standard Italia per azienda 6
INSERT INTO ana_aliquote_iva (azienda_fk, iva_codice, iva_descrizione, iva_percentuale, iva_natura, is_default, ordinamento) VALUES
(6, '22', 'IVA Ordinaria 22%', 22.00, NULL, TRUE, 1),
(6, '10', 'IVA Ridotta 10%', 10.00, NULL, FALSE, 2),
(6, '5', 'IVA Ridotta 5%', 5.00, NULL, FALSE, 3),
(6, '4', 'IVA Ridotta 4%', 4.00, NULL, FALSE, 4),
(6, 'FC', 'Fuori Campo IVA (Art. 7-ter)', 0.00, 'N1', FALSE, 10),
(6, 'ES', 'Operazione Esente IVA', 0.00, 'N4', FALSE, 11),
(6, 'NS', 'Non Soggetto IVA (Regime Forfettario)', 0.00, 'N2.1', FALSE, 12);
```

**Validazioni Aggiuntive (Trigger):**
```sql
-- Trigger: Solo una aliquota default per azienda
CREATE OR REPLACE FUNCTION fn_check_single_default_iva()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_default = TRUE THEN
        -- Rimuovi flag default da altre aliquote della stessa azienda
        UPDATE ana_aliquote_iva
        SET is_default = FALSE
        WHERE azienda_fk = NEW.azienda_fk
          AND iva_id != NEW.iva_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_single_default_iva
BEFORE INSERT OR UPDATE ON ana_aliquote_iva
FOR EACH ROW
EXECUTE FUNCTION fn_check_single_default_iva();
```

**✅ STATO STEP 1: COMPLETATO (14/02/2026)**

**Implementazione Finale:**
- ✅ Tabella `ana_aliquote_iva` creata con successo
- ✅ Stored Functions CRUD create ([Create_AnaAliquoteIva_CRUD.sql](SqlScripts/Create_AnaAliquoteIva_CRUD.sql))
- ✅ **Architettura DB-First al 100%**: Zero SQL diretto nel service layer
- ✅ Model C# creato ([AnaAliquotaIva.cs](Models/AnaAliquotaIva.cs))
- ✅ Service layer implementato con solo chiamate a stored functions
- ✅ UI Page creata con EnterpriseDataGrid
- ✅ Dialog Edit creato con validazione e UPPER CASE forzato
- ✅ Documentazione aggiornata ([Funzioni_DB.md](Documents/Funzioni_DB.md) - Sezione 8)

---

### STEP 2: Database - Modifica `mov_transazioni`

**Obiettivo:** Aggiungere colonne IVA mantenendo compatibilità con transazioni esistenti.

**File creato:** `SqlScripts/Migration_Add_IVA_Columns.sql`

**Analisi Colonna Esistente `transazione_importo_eur`:**

**Problema:** La colonna `transazione_importo_eur` esiste già ed è calcolata dal trigger `fn_calcola_importo_eur()`. Dopo l'integrazione IVA, questa colonna diventa ambigua:
- È il lordo (con IVA)?
- È il netto (senza IVA)?
- È il totale senza distinzione (per transazioni pre-IVA)?

**Decisione:** DEPRECARE rinominandola in `transazione_importo_eur_old` e creare nuove colonne esplicite.

**Vantaggi:**
- ✅ Semantica chiara: `transazione_lordo_eur` = totale con IVA
- ✅ Compatibilità dati storici: colonna old preserva valori originali per 6 mesi
- ✅ Audit completo: se discrepanze nei report, si può confrontare old vs new

**DDL Migrazione:**
```sql
-- =====================================================
-- MIGRAZIONE: Aggiunta Colonne IVA su mov_transazioni
-- Scopo: Gestione IVA con compatibilità dati storici
-- Creato: 14/02/2026
-- =====================================================

BEGIN;

-- STEP 1: Rinomina colonna esistente (DEPRECAZIONE)
ALTER TABLE public.mov_transazioni
RENAME COLUMN transazione_importo_eur TO transazione_importo_eur_old;

COMMENT ON COLUMN mov_transazioni.transazione_importo_eur_old IS
'DEPRECATO dal 14/02/2026 - Sostituito da transazione_lordo_eur. Mantenuto per compatibilità dati storici (eliminare dopo 6 mesi).';

-- STEP 2: Aggiungi nuove colonne IVA
ALTER TABLE public.mov_transazioni
ADD COLUMN transazione_aliquota_iva_fk INTEGER REFERENCES ana_aliquote_iva(iva_id) ON DELETE RESTRICT,
ADD COLUMN transazione_imponibile_eur NUMERIC(10, 2),
ADD COLUMN transazione_iva_eur NUMERIC(10, 2),
ADD COLUMN transazione_lordo_eur NUMERIC(10, 2),
ADD COLUMN transazione_iva_modalita_input VARCHAR(10) CHECK (transazione_iva_modalita_input IN ('LORDO', 'NETTO', NULL));

-- STEP 3: Commenti colonne
COMMENT ON COLUMN mov_transazioni.transazione_aliquota_iva_fk IS
'FK a aliquota IVA - NULL se transazione in valuta estera o causale senza IVA (PG, IN, NC)';

COMMENT ON COLUMN mov_transazioni.transazione_imponibile_eur IS
'Importo netto (senza IVA) in EUR - editabile manualmente per correzioni arrotondamenti';

COMMENT ON COLUMN mov_transazioni.transazione_iva_eur IS
'Importo IVA in EUR - editabile manualmente per correzioni arrotondamenti';

COMMENT ON COLUMN mov_transazioni.transazione_lordo_eur IS
'Importo totale (imponibile + IVA) in EUR - deve coincidere con fattura cartacea al centesimo';

COMMENT ON COLUMN mov_transazioni.transazione_iva_modalita_input IS
'Modalità inserimento utente: LORDO (scorporo da totale) o NETTO (calcolo IVA su imponibile) - auto-determinata da ciclo causale';

-- STEP 4: Constraint di coerenza IVA
ALTER TABLE mov_transazioni
ADD CONSTRAINT chk_iva_completeness CHECK (
    -- Opzione 1: Nessun campo IVA compilato (transazione pre-IVA o senza IVA)
    (transazione_aliquota_iva_fk IS NULL
        AND transazione_imponibile_eur IS NULL
        AND transazione_iva_eur IS NULL
        AND transazione_lordo_eur IS NULL)
    OR
    -- Opzione 2: Tutti i campi IVA compilati (transazione con IVA completa)
    (transazione_aliquota_iva_fk IS NOT NULL
        AND transazione_imponibile_eur IS NOT NULL
        AND transazione_iva_eur IS NOT NULL
        AND transazione_lordo_eur IS NOT NULL)
);

-- STEP 5: Constraint IVA solo su EUR
ALTER TABLE mov_transazioni
ADD CONSTRAINT chk_iva_solo_eur CHECK (
    (transazione_aliquota_iva_fk IS NULL)
    OR
    (transazione_aliquota_iva_fk IS NOT NULL
        AND transazione_valuta_id = (SELECT valuta_id FROM ana_valute WHERE valuta_codice_iso = 'EUR' LIMIT 1))
);

-- STEP 6: Constraint coerenza matematica (tolleranza 0.01€)
ALTER TABLE mov_transazioni
ADD CONSTRAINT chk_iva_matematica CHECK (
    (transazione_lordo_eur IS NULL)
    OR
    (ABS(transazione_lordo_eur - (transazione_imponibile_eur + transazione_iva_eur)) <= 0.01)
);

-- STEP 7: Migrazione dati esistenti (transazioni pre-IVA)
-- Per transazioni in EUR, copia importo_eur_old in lordo_eur
UPDATE mov_transazioni
SET transazione_lordo_eur = transazione_importo_eur_old,
    transazione_imponibile_eur = transazione_importo_eur_old,
    transazione_iva_eur = 0
WHERE transazione_valuta_id = (SELECT valuta_id FROM ana_valute WHERE valuta_codice_iso = 'EUR' LIMIT 1)
  AND transazione_lordo_eur IS NULL;

-- STEP 8: Indici (opzionali ma consigliati per performance)
CREATE INDEX idx_transazioni_iva ON mov_transazioni(transazione_aliquota_iva_fk) WHERE transazione_aliquota_iva_fk IS NOT NULL;

COMMIT;
```

**Verifica Post-Migrazione:**
```sql
-- Test 1: Verifica migrazione dati esistenti
SELECT
    COUNT(*) AS totale_transazioni,
    COUNT(transazione_importo_eur_old) AS con_importo_old,
    COUNT(transazione_lordo_eur) AS con_lordo_nuovo,
    COUNT(transazione_aliquota_iva_fk) AS con_iva
FROM mov_transazioni;

-- Test 2: Verifica coerenza matematica
SELECT transazione_id,
       transazione_imponibile_eur,
       transazione_iva_eur,
       transazione_lordo_eur,
       (transazione_imponibile_eur + transazione_iva_eur) AS somma_calcolata,
       ABS(transazione_lordo_eur - (transazione_imponibile_eur + transazione_iva_eur)) AS differenza
FROM mov_transazioni
WHERE transazione_aliquota_iva_fk IS NOT NULL
  AND ABS(transazione_lordo_eur - (transazione_imponibile_eur + transazione_iva_eur)) > 0.01;

-- Atteso: 0 righe (nessuna incoerenza)
```

---

### STEP 3: Database - Modifica `ana_tipi_causali`

**Obiettivo:** Aggiungere metadati IVA alle causali (metadata-driven approach).

**File creato:** `SqlScripts/Migration_Add_Causale_IVA_Metadata.sql`

**DDL Migrazione:**
```sql
-- =====================================================
-- MIGRAZIONE: Metadati IVA su ana_tipi_causali
-- Scopo: Estendere sistema metadata-driven con logica IVA
-- Creato: 14/02/2026
-- =====================================================

BEGIN;

-- STEP 1: Aggiungi colonne metadati IVA
ALTER TABLE public.ana_tipi_causali
ADD COLUMN causale_genera_iva BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN causale_richiede_iva BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN causale_aliquota_iva_default_fk INTEGER REFERENCES ana_aliquote_iva(iva_id) ON DELETE SET NULL;

-- STEP 2: Commenti
COMMENT ON COLUMN ana_tipi_causali.causale_genera_iva IS
'TRUE se la causale può avere IVA (FT, FV, ND, NDA). FALSE per pagamenti/incassi (PG, IN) e note credito (NC, NCA) che stornano IVA già registrata.';

COMMENT ON COLUMN ana_tipi_causali.causale_richiede_iva IS
'TRUE se IVA è obbligatoria per questa causale (trigger validerà presenza aliquota). Usare solo per FT/FV dove IVA è sempre presente.';

COMMENT ON COLUMN ana_tipi_causali.causale_aliquota_iva_default_fk IS
'FK a aliquota IVA preselezionata in UI per questa causale (es. 22% per FT/FV italiane). NULL = utente sceglie manualmente.';

-- STEP 3: Aggiorna causali esistenti (Azienda 6)

-- Ciclo PASSIVO (Fornitori)
UPDATE ana_tipi_causali
SET causale_genera_iva = TRUE,
    causale_richiede_iva = TRUE,
    causale_aliquota_iva_default_fk = (SELECT iva_id FROM ana_aliquote_iva WHERE azienda_fk = 6 AND iva_codice = '22')
WHERE causale_codice IN ('FT', 'ND') AND azienda_fk = 6;
-- FT (Fattura Passiva) e ND (Nota Debito) hanno sempre IVA

UPDATE ana_tipi_causali
SET causale_genera_iva = FALSE,
    causale_richiede_iva = FALSE
WHERE causale_codice IN ('PG', 'NC') AND azienda_fk = 6;
-- PG (Pagamento) non ha IVA (è un movimento su fattura già registrata)
-- NC (Nota Credito) storna IVA già registrata nella FT originale, non genera nuova IVA

-- Ciclo ATTIVO (Clienti)
UPDATE ana_tipi_causali
SET causale_genera_iva = TRUE,
    causale_richiede_iva = TRUE,
    causale_aliquota_iva_default_fk = (SELECT iva_id FROM ana_aliquote_iva WHERE azienda_fk = 6 AND iva_codice = '22')
WHERE causale_codice IN ('FV', 'NDA') AND azienda_fk = 6;
-- FV (Fattura Vendita) e NDA (Nota Debito Attiva) hanno sempre IVA

UPDATE ana_tipi_causali
SET causale_genera_iva = FALSE,
    causale_richiede_iva = FALSE
WHERE causale_codice IN ('IN', 'NCA') AND azienda_fk = 6;
-- IN (Incasso) non ha IVA
-- NCA (Nota Credito Attiva) storna IVA già registrata

-- STEP 4: Constraint logico (richiede_iva implica genera_iva)
ALTER TABLE ana_tipi_causali
ADD CONSTRAINT chk_iva_richiede_implica_genera CHECK (
    (causale_richiede_iva = FALSE) OR (causale_genera_iva = TRUE)
);
-- Se richiede IVA obbligatoria, deve anche generare IVA

COMMIT;
```

**Nota Importante - Note di Credito:**

Le Note di Credito (NC passive e NCA attive) **NON generano IVA** perché:
1. Stornano una fattura già registrata (FT o FV)
2. L'IVA è già stata contabilizzata nella fattura originale
3. La NC si limita a "invertire" il segno dell'importo (segno = -1)

**Esempio:**
```
Transazione 1: FT Fornitore Hotel 122€ (Imponibile 100€, IVA 22€)
  → IVA a credito: +22€

Transazione 2: NC Fornitore -50€ (storno parziale per errore)
  → Non genera nuova IVA
  → Semplicemente riduce il debito verso fornitore
  → L'IVA rimane quella della FT originale (22€)
  → Il partitario mostra: Dare 122€, Avere 50€, Saldo 72€
```

---

### STEP 4: Database - Trigger Calcolo IVA

**Obiettivo:** Creare trigger metadata-driven per calcolo automatico IVA con supporto correzioni manuali.

**File creato:** `SqlScripts/Migration_Create_IVA_Trigger.sql`

**Principi del Trigger:**
1. **Priorità MASSIMA alla correzione manuale** (Regola 1 - "Punto d'Oro")
2. **Auto-determinazione modalità input** da ciclo causale
3. **Validazione IVA obbligatoria** per causali che la richiedono
4. **Azzeramento IVA** per valute estere e causali senza IVA
5. **Tolleranza 0.01€** per differenze arrotondamento

**DDL Trigger:**
```sql
-- =====================================================
-- TRIGGER: Calcolo Automatico IVA su mov_transazioni
-- Scopo: Calcolo IVA metadata-driven con supporto correzioni manuali
-- Creato: 14/02/2026
-- Priorità: ESEGUIRE PRIMA di trg_validate_transazione_metadata
-- =====================================================

CREATE OR REPLACE FUNCTION fn_calcola_iva_transazione()
RETURNS TRIGGER AS $$
DECLARE
    v_causale ana_tipi_causali%ROWTYPE;
    v_aliquota ana_aliquote_iva%ROWTYPE;
    v_valuta ana_valute%ROWTYPE;
    v_percentuale NUMERIC(5,2);
BEGIN
    -- =========================================
    -- STEP 1: Recupera metadati causale
    -- =========================================
    SELECT * INTO v_causale
    FROM ana_tipi_causali
    WHERE causale_id = NEW.transazione_causale_tipo_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Causale ID % non trovata in ana_tipi_causali', NEW.transazione_causale_tipo_id;
    END IF;

    -- =========================================
    -- STEP 2: Recupera metadati valuta
    -- =========================================
    SELECT * INTO v_valuta
    FROM ana_valute
    WHERE valuta_id = NEW.transazione_valuta_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Valuta ID % non trovata in ana_valute', NEW.transazione_valuta_id;
    END IF;

    -- =========================================
    -- STEP 3: Se valuta != EUR, azzera IVA e esci
    -- =========================================
    IF v_valuta.valuta_codice_iso != 'EUR' THEN
        NEW.transazione_aliquota_iva_fk := NULL;
        NEW.transazione_imponibile_eur := NULL;
        NEW.transazione_iva_eur := NULL;
        NEW.transazione_lordo_eur := NULL;
        NEW.transazione_iva_modalita_input := NULL;

        -- IMPORTANTE: Esci subito, non processare logica IVA
        RETURN NEW;
    END IF;

    -- =========================================
    -- STEP 4: Se causale NON genera IVA, copia importo in lordo e azzera IVA
    -- =========================================
    IF v_causale.causale_genera_iva = FALSE THEN
        -- Es. PG (Pagamento), IN (Incasso), NC (Nota Credito)
        -- Queste causali non hanno IVA propria
        NEW.transazione_aliquota_iva_fk := NULL;
        NEW.transazione_imponibile_eur := NEW.transazione_importo;
        NEW.transazione_iva_eur := 0;
        NEW.transazione_lordo_eur := NEW.transazione_importo;
        NEW.transazione_iva_modalita_input := NULL;

        RETURN NEW;
    END IF;

    -- =========================================
    -- STEP 5: Validazione IVA obbligatoria
    -- =========================================
    IF v_causale.causale_richiede_iva = TRUE
       AND NEW.transazione_aliquota_iva_fk IS NULL THEN
        RAISE EXCEPTION 'La causale "%" richiede IVA obbligatoria. Selezionare un''aliquota IVA.',
            v_causale.causale_descrizione;
    END IF;

    -- =========================================
    -- STEP 6: Se IVA non presente (opzionale e non selezionata), esci
    -- =========================================
    IF NEW.transazione_aliquota_iva_fk IS NULL THEN
        -- Causale genera IVA ma non è obbligatoria, e utente non l'ha selezionata
        NEW.transazione_imponibile_eur := NEW.transazione_importo;
        NEW.transazione_iva_eur := 0;
        NEW.transazione_lordo_eur := NEW.transazione_importo;
        NEW.transazione_iva_modalita_input := NULL;

        RETURN NEW;
    END IF;

    -- =========================================
    -- STEP 7: Recupera aliquota IVA
    -- =========================================
    SELECT * INTO v_aliquota
    FROM ana_aliquote_iva
    WHERE iva_id = NEW.transazione_aliquota_iva_fk;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aliquota IVA ID % non trovata in ana_aliquote_iva', NEW.transazione_aliquota_iva_fk;
    END IF;

    v_percentuale := v_aliquota.iva_percentuale;

    -- =========================================
    -- STEP 8: REGOLA 1 - CORREZIONE MANUALE (PRIORITÀ MASSIMA)
    -- =========================================
    -- Se TUTTI E TRE i campi IVA sono compilati, significa che l'utente ha inserito manualmente
    -- NON ricalcolare, ma VALIDA solo la coerenza matematica con tolleranza 0.01€
    IF NEW.transazione_imponibile_eur IS NOT NULL
       AND NEW.transazione_iva_eur IS NOT NULL
       AND NEW.transazione_lordo_eur IS NOT NULL THEN

        -- Validazione matematica con tolleranza 1 centesimo
        IF ABS(NEW.transazione_lordo_eur - (NEW.transazione_imponibile_eur + NEW.transazione_iva_eur)) > 0.01 THEN
            RAISE EXCEPTION 'Incoerenza IVA: Lordo (% EUR) != Imponibile (% EUR) + IVA (% EUR). Differenza: % EUR',
                NEW.transazione_lordo_eur,
                NEW.transazione_imponibile_eur,
                NEW.transazione_iva_eur,
                ABS(NEW.transazione_lordo_eur - (NEW.transazione_imponibile_eur + NEW.transazione_iva_eur));
        END IF;

        -- Tutto OK, non ricalcolare nulla, rispetta i valori inseriti dall'utente
        RETURN NEW;
    END IF;

    -- =========================================
    -- STEP 9: REGOLA 2 - AUTO-DETERMINA MODALITÀ INPUT
    -- =========================================
    -- Se utente non ha specificato modalità, deduci da ciclo causale
    IF NEW.transazione_iva_modalita_input IS NULL THEN
        IF v_causale.causale_ciclo = 'PASSIVO' THEN
            NEW.transazione_iva_modalita_input := 'LORDO';
        ELSIF v_causale.causale_ciclo = 'ATTIVO' THEN
            NEW.transazione_iva_modalita_input := 'NETTO';
        ELSE
            -- Fallback (causale senza ciclo, caso raro)
            NEW.transazione_iva_modalita_input := 'LORDO';
        END IF;
    END IF;

    -- =========================================
    -- STEP 10: REGOLA 3 - CALCOLO IVA
    -- =========================================
    IF NEW.transazione_iva_modalita_input = 'LORDO' THEN
        -- ----------------------------------------
        -- MODALITÀ LORDO (PASSIVO - Scorporo IVA)
        -- ----------------------------------------
        -- Utente ha inserito TOTALE con IVA inclusa (es. fattura fornitore 122€)
        -- Dobbiamo scorporare: Netto = Lordo / (1 + Aliquota%), IVA = Lordo - Netto

        NEW.transazione_lordo_eur := NEW.transazione_importo;

        IF v_percentuale > 0 THEN
            -- Scorporo IVA (es. 122 / 1.22 = 100.00)
            NEW.transazione_imponibile_eur := ROUND(NEW.transazione_importo / (1 + (v_percentuale / 100)), 2);
            NEW.transazione_iva_eur := NEW.transazione_lordo_eur - NEW.transazione_imponibile_eur;
        ELSE
            -- Aliquota 0% (FC, ES, NS)
            NEW.transazione_imponibile_eur := NEW.transazione_importo;
            NEW.transazione_iva_eur := 0;
        END IF;

    ELSIF NEW.transazione_iva_modalita_input = 'NETTO' THEN
        -- ----------------------------------------
        -- MODALITÀ NETTO (ATTIVO - Calcolo IVA)
        -- ----------------------------------------
        -- Utente ha inserito IMPONIBILE (es. viaggio venduto 1.000€ netto)
        -- Dobbiamo calcolare: IVA = Netto × Aliquota%, Lordo = Netto + IVA

        NEW.transazione_imponibile_eur := NEW.transazione_importo;

        IF v_percentuale > 0 THEN
            -- Calcolo IVA (es. 1000 × 0.22 = 220.00)
            NEW.transazione_iva_eur := ROUND(NEW.transazione_importo * (v_percentuale / 100), 2);
            NEW.transazione_lordo_eur := NEW.transazione_imponibile_eur + NEW.transazione_iva_eur;
        ELSE
            -- Aliquota 0%
            NEW.transazione_iva_eur := 0;
            NEW.transazione_lordo_eur := NEW.transazione_importo;
        END IF;
    ELSE
        -- Modalità non riconosciuta (non dovrebbe mai accadere per constraint CHECK)
        RAISE EXCEPTION 'Modalità IVA non valida: %. Ammessi: LORDO, NETTO', NEW.transazione_iva_modalita_input;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Creazione Trigger
DROP TRIGGER IF EXISTS trg_calcola_iva_transazione ON mov_transazioni;

CREATE TRIGGER trg_calcola_iva_transazione
BEFORE INSERT OR UPDATE ON mov_transazioni
FOR EACH ROW
EXECUTE FUNCTION fn_calcola_iva_transazione();

-- Commento
COMMENT ON FUNCTION fn_calcola_iva_transazione() IS
'Calcola automaticamente IVA su transazioni basandosi su: ciclo causale, modalità input (LORDO/NETTO), aliquota selezionata.
PRIORITÀ MASSIMA a correzioni manuali (se tutti e tre i campi IVA sono NOT NULL, non ricalcola).
Tolleranza arrotondamenti: 0.01 EUR.';
```

**Gestione Priorità Trigger:**

Il trigger `trg_calcola_iva_transazione` deve essere eseguito **PRIMA** di `trg_validate_transazione_metadata`.

**Verifica ordine trigger:**
```sql
-- Query per verificare ordine esecuzione trigger
SELECT tgname, tgtype, tgenabled, proname
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'mov_transazioni'::regclass
ORDER BY tgname;
```

**Modifica Trigger Esistente `fn_calcola_importo_eur()`:**

Il trigger esistente `fn_calcola_importo_eur()` deve essere **modificato** o **disabilitato** perché la sua logica è ora inglobata in `fn_calcola_iva_transazione()`.

**Opzione A - DISABILITARE (Recommended):**
```sql
-- Disabilita trigger vecchio (mantenere funzione per rollback)
ALTER TABLE mov_transazioni DISABLE TRIGGER trg_calcola_importo_eur;

COMMENT ON TRIGGER trg_calcola_importo_eur ON mov_transazioni IS
'DISABILITATO dal 14/02/2026 - Sostituito da trg_calcola_iva_transazione che gestisce anche conversione valute.';
```

---

# PARTE III: STRUTTURA DATI E REPORTISTICA

## 🗂️ Struttura Database - Dettaglio

### 9.1 Tabella: `ana_controparti`

```sql
CREATE TABLE public.ana_controparti (
    controparte_id SERIAL PRIMARY KEY,
    azienda_fk INTEGER NOT NULL REFERENCES ana_aziende(azienda_id),

    -- Anagrafica base
    ragione_sociale VARCHAR(100) NOT NULL,
    nome_breve VARCHAR(50),

    -- NUOVI FLAG FONDAMENTALI
    is_fornitore BOOLEAN NOT NULL DEFAULT FALSE,
    is_cliente BOOLEAN NOT NULL DEFAULT FALSE,

    -- Dati fiscali
    partita_iva VARCHAR(20),
    codice_fiscale VARCHAR(16),
    codice_destinatario_sdi VARCHAR(7),

    -- Contatti
    indirizzo VARCHAR(100),
    comune_fk INTEGER REFERENCES ana_geo_comuni(comune_id),
    telefono_prefisso VARCHAR(5),
    telefono_numero VARCHAR(20),
    email VARCHAR(100),
    pec VARCHAR(100),
    sito_web VARCHAR(100),

    -- Classificazione
    tipo_fornitore_fk INTEGER REFERENCES ana_tipo_fornitore(tipo_fornitore_id),
    fornitore_estero BOOLEAN DEFAULT FALSE,

    -- Operatività
    attivo BOOLEAN DEFAULT TRUE,
    priorita SMALLINT DEFAULT 5,
    note TEXT,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMPTZ,
    updated_by VARCHAR(50),

    -- Constraint: almeno un ruolo deve essere attivo
    CONSTRAINT chk_almeno_un_ruolo CHECK (is_fornitore = TRUE OR is_cliente = TRUE)
);

-- Indici per performance
CREATE INDEX idx_controparti_azienda ON ana_controparti(azienda_fk);
CREATE INDEX idx_controparti_fornitori ON ana_controparti(azienda_fk, is_fornitore)
    WHERE is_fornitore = TRUE;
CREATE INDEX idx_controparti_clienti ON ana_controparti(azienda_fk, is_cliente)
    WHERE is_cliente = TRUE;
CREATE INDEX idx_controparti_attivi ON ana_controparti(attivo)
    WHERE attivo = TRUE;
```

### 9.2 Tabella: `ana_aliquote_iva` (NUOVA - Step 1 IVA)

Vedi [STEP 1: Database - Tabella ana_aliquote_iva](#step-1-database---tabella-ana_aliquote_iva) per DDL completo.

**Schema riassuntivo:**
```sql
CREATE TABLE public.ana_aliquote_iva (
    iva_id SERIAL PRIMARY KEY,
    azienda_fk INTEGER NOT NULL,
    iva_codice VARCHAR(10) NOT NULL,           -- '22', '10', 'FC', 'ES'
    iva_descrizione VARCHAR(100) NOT NULL,
    iva_percentuale NUMERIC(5, 2),             -- 22.00
    iva_natura VARCHAR(10),                    -- N1, N2.1, N4 (fatturazione elettronica)
    is_default BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    ordinamento SMALLINT DEFAULT 100
);
```

### 9.3 Tabella: `ana_tipi_causali` (modificata)

```sql
-- Aggiunta colonna causale_ciclo (esistente)
ALTER TABLE public.ana_tipi_causali
ADD COLUMN causale_ciclo VARCHAR(10) NOT NULL DEFAULT 'PASSIVO'
CHECK (causale_ciclo IN ('ATTIVO', 'PASSIVO'));

-- Aggiunta colonne IVA (NUOVE - Step 3 IVA)
ALTER TABLE public.ana_tipi_causali
ADD COLUMN causale_genera_iva BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN causale_richiede_iva BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN causale_aliquota_iva_default_fk INTEGER REFERENCES ana_aliquote_iva(iva_id);

-- Indice per filtraggio
CREATE INDEX idx_causali_ciclo ON ana_tipi_causali(causale_ciclo);
```

**Causali Ciclo PASSIVO** (esistenti):
| Codice | Descrizione | Segno | Documento | Genera IVA | Richiede IVA |
|--------|-------------|-------|-----------|------------|--------------|
| FT | Fattura Passiva | +1 | Sì | TRUE | TRUE |
| NC | Nota di Credito | -1 | Sì | FALSE | FALSE |
| PG | Pagamento/Acconto | -1 | No | FALSE | FALSE |
| ND | Nota di Debito/Penale | +1 | Sì | TRUE | TRUE |

**Causali Ciclo ATTIVO** (nuove):
| Codice | Descrizione | Segno | Documento | Genera IVA | Richiede IVA |
|--------|-------------|-------|-----------|------------|--------------|
| FV | Fattura Attiva/Vendita | +1 | Sì | TRUE | TRUE |
| IN | Incasso/Acconto Cliente | -1 | No | FALSE | FALSE |
| NCA | Nota di Credito Emessa | -1 | Sì | FALSE | FALSE |
| NDA | Nota di Debito Emessa | +1 | Sì | TRUE | TRUE |

### 9.4 Tabella: `mov_transazioni` (modificata con colonne IVA)

```sql
-- Schema esistente +  nuove colonne IVA (Step 2 IVA)
CREATE TABLE public.mov_transazioni (
    transazione_id SERIAL PRIMARY KEY,

    -- ... (colonne esistenti omesse per brevità) ...

    -- COLONNE IVA (NUOVE - 14/02/2026)
    transazione_aliquota_iva_fk INTEGER REFERENCES ana_aliquote_iva(iva_id),
    transazione_imponibile_eur NUMERIC(10, 2),      -- Netto senza IVA
    transazione_iva_eur NUMERIC(10, 2),             -- Importo IVA
    transazione_lordo_eur NUMERIC(10, 2),           -- Totale con IVA
    transazione_iva_modalita_input VARCHAR(10),     -- 'LORDO' o 'NETTO'

    -- COLONNA DEPRECATA (mantenuta per 6 mesi)
    transazione_importo_eur_old NUMERIC(10, 2),     -- Ex transazione_importo_eur

    -- Constraint IVA
    CONSTRAINT chk_iva_completeness CHECK (...),    -- Tutti o nessuno
    CONSTRAINT chk_iva_solo_eur CHECK (...),        -- IVA solo su EUR
    CONSTRAINT chk_iva_matematica CHECK (           -- Tolleranza 0.01€
        ABS(transazione_lordo_eur - (transazione_imponibile_eur + transazione_iva_eur)) <= 0.01
    )
);

-- Indici IVA
CREATE INDEX idx_transazioni_iva ON mov_transazioni(transazione_aliquota_iva_fk)
    WHERE transazione_aliquota_iva_fk IS NOT NULL;
```

**Colonne Chiave con IVA:**
- `transazione_importo`: Importo inserito dall'utente (può essere netto o lordo)
- `transazione_imponibile_eur`: Importo netto **calcolato o manuale**
- `transazione_iva_eur`: Importo IVA **calcolato o manuale**
- `transazione_lordo_eur`: Importo totale **calcolato o manuale**
- `transazione_iva_modalita_input`: 'LORDO' (scorporo) o 'NETTO' (calcolo)

---

## 📊 View di Reportistica

### 10.1 View: `vw_partitario_fornitori` (AGGIORNATA CON IVA)

Estratto conto fornitori con saldo progressivo e dettaglio IVA.

```sql
CREATE OR REPLACE VIEW public.vw_partitario_fornitori AS
SELECT
    c.controparte_id,
    c.ragione_sociale,
    c.nome_breve,
    t.transazione_id,
    t.transazione_data,
    t.transazione_data_documento,
    t.transazione_numero_documento,
    ca.causale_codice,
    ca.causale_descrizione,

    -- IMPORTI (aggiornati per IVA)
    t.transazione_importo_eur AS importo_valuta_originale,
    t.transazione_imponibile_eur,
    t.transazione_iva_eur,
    t.transazione_lordo_eur,
    ca.causale_segno,

    -- Movimento contabile (dare/avere) - USA LORDO
    (t.transazione_lordo_eur * ca.causale_segno) as dare_avere,

    -- Saldo progressivo con window function - USA LORDO
    SUM(t.transazione_lordo_eur * ca.causale_segno)
        OVER (
            PARTITION BY c.controparte_id
            ORDER BY t.transazione_data, t.transazione_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) as saldo_progressivo,

    -- Stato transazione
    t.transazione_stato,
    t.transazione_data_scadenza,

    -- Residuo (solo per transazioni non pagate completamente)
    CASE
        WHEN t.transazione_stato IN ('DA_PAGARE', 'PARZIALMENTE_PAGATO')
        THEN (t.transazione_lordo_eur * ca.causale_segno) - COALESCE(
            (SELECT SUM(ABS(pg.transazione_lordo_eur))
             FROM mov_transazioni pg
             WHERE pg.transazione_fattura_fk = t.transazione_id
               AND pg.transazione_stato = 'PAGATO'), 0
        )
        ELSE 0
    END as residuo,

    -- Metadati IVA
    aiva.iva_codice AS aliquota_codice,
    aiva.iva_descrizione AS aliquota_descrizione,
    aiva.iva_percentuale,

    -- Metadati
    t.transazione_viaggio_id,
    t.transazione_note

FROM ana_controparti c
JOIN mov_transazioni t ON c.controparte_id = t.transazione_controparte_id
JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
LEFT JOIN ana_aliquote_iva aiva ON t.transazione_aliquota_iva_fk = aiva.iva_id
WHERE ca.causale_ciclo = 'PASSIVO'
  AND t.transazione_stato <> 'ANNULLATO'
  AND c.is_fornitore = TRUE
ORDER BY c.ragione_sociale, t.transazione_data, t.transazione_id;
```

**Modifiche Chiave per IVA:**
- ✅ Aggiunta colonne `transazione_imponibile_eur`, `transazione_iva_eur`, `transazione_lordo_eur`
- ✅ JOIN con `ana_aliquote_iva` per mostrare descrizione aliquota
- ✅ Calcolo `dare_avere` e `saldo_progressivo` basato su **lordo** (totale con IVA)
- ✅ Calcolo `residuo` basato su **lordo**

### 10.2 View: `vw_partitario_clienti` (AGGIORNATA CON IVA)

Estratto conto clienti con saldo progressivo e dettaglio IVA.

```sql
CREATE OR REPLACE VIEW public.vw_partitario_clienti AS
SELECT
    c.controparte_id,
    c.ragione_sociale,
    c.nome_breve,
    t.transazione_id,
    t.transazione_data,
    t.transazione_data_documento,
    t.transazione_numero_documento,
    ca.causale_codice,
    ca.causale_descrizione,

    -- IMPORTI (aggiornati per IVA)
    t.transazione_importo_eur AS importo_valuta_originale,
    t.transazione_imponibile_eur,
    t.transazione_iva_eur,
    t.transazione_lordo_eur,
    ca.causale_segno,

    -- Movimento contabile (dare/avere) - USA LORDO
    (t.transazione_lordo_eur * ca.causale_segno) as dare_avere,

    -- Saldo progressivo - USA LORDO
    SUM(t.transazione_lordo_eur * ca.causale_segno)
        OVER (
            PARTITION BY c.controparte_id
            ORDER BY t.transazione_data, t.transazione_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) as saldo_progressivo,

    -- Stato
    t.transazione_stato,
    t.transazione_data_scadenza,

    -- Residuo (calcola incassi già registrati usando transazione_fattura_fk)
    CASE
        WHEN t.transazione_stato IN ('DA_PAGARE', 'PARZIALMENTE_PAGATO')
        THEN (t.transazione_lordo_eur * ca.causale_segno) - COALESCE(
            (SELECT SUM(ABS(pg.transazione_lordo_eur))
             FROM mov_transazioni pg
             WHERE pg.transazione_fattura_fk = t.transazione_id
               AND pg.transazione_stato = 'PAGATO'), 0
        )
        ELSE 0
    END as residuo,

    -- Metadati IVA
    aiva.iva_codice AS aliquota_codice,
    aiva.iva_descrizione AS aliquota_descrizione,
    aiva.iva_percentuale,

    -- Metadati
    t.transazione_viaggio_id,
    t.transazione_note

FROM ana_controparti c
JOIN mov_transazioni t ON c.controparte_id = t.transazione_controparte_id
JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
LEFT JOIN ana_aliquote_iva aiva ON t.transazione_aliquota_iva_fk = aiva.iva_id
WHERE ca.causale_ciclo = 'ATTIVO'
  AND t.transazione_stato <> 'ANNULLATO'
  AND c.is_cliente = TRUE
ORDER BY c.ragione_sociale, t.transazione_data, t.transazione_id;
```

### 10.3 View: `vw_margini_viaggi` (AGGIORNATA CON IVA)

Calcolo margine per ogni viaggio (ricavi - costi) con dettaglio IVA.

```sql
CREATE OR REPLACE VIEW public.vw_margini_viaggi AS
SELECT
    v.viaggio_id,
    v.viaggio_nome,
    v.viaggio_anno,
    t.transazione_viaggio_id,

    -- Ricavi (ciclo ATTIVO) - USA LORDO
    SUM(CASE
        WHEN ca.causale_ciclo = 'ATTIVO'
        THEN t.transazione_lordo_eur * ca.causale_segno
        ELSE 0
    END) as ricavi_totali_eur,

    -- IVA su Ricavi
    SUM(CASE
        WHEN ca.causale_ciclo = 'ATTIVO'
        THEN t.transazione_iva_eur
        ELSE 0
    END) as iva_ricavi_eur,

    -- Ricavi Netti (senza IVA)
    SUM(CASE
        WHEN ca.causale_ciclo = 'ATTIVO'
        THEN t.transazione_imponibile_eur * ca.causale_segno
        ELSE 0
    END) as ricavi_netti_eur,

    -- Costi (ciclo PASSIVO) - USA LORDO
    SUM(CASE
        WHEN ca.causale_ciclo = 'PASSIVO'
        THEN ABS(t.transazione_lordo_eur * ca.causale_segno)
        ELSE 0
    END) as costi_totali_eur,

    -- IVA su Costi
    SUM(CASE
        WHEN ca.causale_ciclo = 'PASSIVO'
        THEN t.transazione_iva_eur
        ELSE 0
    END) as iva_costi_eur,

    -- Costi Netti (senza IVA)
    SUM(CASE
        WHEN ca.causale_ciclo = 'PASSIVO'
        THEN ABS(t.transazione_imponibile_eur * ca.causale_segno)
        ELSE 0
    END) as costi_netti_eur,

    -- Margine LORDO (con IVA)
    SUM(CASE
        WHEN ca.causale_ciclo = 'ATTIVO'
        THEN t.transazione_lordo_eur * ca.causale_segno
        WHEN ca.causale_ciclo = 'PASSIVO'
        THEN (t.transazione_lordo_eur * ca.causale_segno) * -1
        ELSE 0
    END) as margine_lordo_eur,

    -- Margine NETTO (senza IVA)
    SUM(CASE
        WHEN ca.causale_ciclo = 'ATTIVO'
        THEN t.transazione_imponibile_eur * ca.causale_segno
        WHEN ca.causale_ciclo = 'PASSIVO'
        THEN (t.transazione_imponibile_eur * ca.causale_segno) * -1
        ELSE 0
    END) as margine_netto_eur,

    -- Margine percentuale (su ricavi netti)
    CASE
        WHEN SUM(CASE WHEN ca.causale_ciclo = 'ATTIVO' THEN t.transazione_imponibile_eur * ca.causale_segno ELSE 0 END) > 0
        THEN (
            SUM(CASE
                WHEN ca.causale_ciclo = 'ATTIVO' THEN t.transazione_imponibile_eur * ca.causale_segno
                WHEN ca.causale_ciclo = 'PASSIVO' THEN (t.transazione_imponibile_eur * ca.causale_segno) * -1
                ELSE 0
            END) /
            SUM(CASE WHEN ca.causale_ciclo = 'ATTIVO' THEN t.transazione_imponibile_eur * ca.causale_segno ELSE 0 END)
        ) * 100
        ELSE 0
    END as margine_percentuale,

    -- Conteggi
    COUNT(DISTINCT CASE WHEN ca.causale_ciclo = 'ATTIVO' THEN t.transazione_id END) as num_transazioni_attive,
    COUNT(DISTINCT CASE WHEN ca.causale_ciclo = 'PASSIVO' THEN t.transazione_id END) as num_transazioni_passive

FROM ana_viaggi v
LEFT JOIN mov_transazioni t ON v.viaggio_id = t.transazione_viaggio_id
LEFT JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
WHERE t.transazione_stato <> 'ANNULLATO'
  OR t.transazione_id IS NULL
GROUP BY v.viaggio_id, v.viaggio_nome, v.viaggio_anno, t.transazione_viaggio_id
ORDER BY v.viaggio_anno DESC, v.viaggio_nome;
```

**Modifiche Chiave per IVA:**
- ✅ Aggiunta calcolo separato `ricavi_netti_eur` (imponibile senza IVA)
- ✅ Aggiunta calcolo separato `costi_netti_eur` (imponibile senza IVA)
- ✅ Calcolo `margine_lordo_eur` (con IVA) e `margine_netto_eur` (senza IVA)
- ✅ Aggiunta colonne `iva_ricavi_eur` e `iva_costi_eur` per analisi fiscale
- ✅ Margine percentuale calcolato su **ricavi netti** (standard contabile)

### 10.4 View: `vw_scadenzario` (AGGIORNATA CON IVA)

Riepilogo scadenze pagamenti/incassi con priorità e dettaglio IVA.

```sql
CREATE OR REPLACE VIEW public.vw_scadenzario AS
SELECT
    c.controparte_id,
    c.ragione_sociale,
    ca.causale_ciclo,
    ca.causale_descrizione,
    t.transazione_id,
    t.transazione_data_documento,
    t.transazione_numero_documento,
    t.transazione_data_scadenza,

    -- Importi (aggiornati per IVA)
    t.transazione_imponibile_eur,
    t.transazione_iva_eur,
    t.transazione_lordo_eur * ca.causale_segno as importo,

    -- Residuo da pagare/incassare (usa LORDO)
    (t.transazione_lordo_eur * ca.causale_segno) - COALESCE(
        (SELECT SUM(ABS(pg.transazione_lordo_eur))
         FROM mov_transazioni pg
         WHERE pg.transazione_fattura_fk = t.transazione_id
           AND pg.transazione_stato = 'PAGATO'), 0
    ) as residuo,

    -- Giorni alla scadenza (negativo = scaduto)
    t.transazione_data_scadenza - CURRENT_DATE as giorni_a_scadenza,

    -- Classificazione urgenza
    CASE
        WHEN t.transazione_data_scadenza < CURRENT_DATE THEN 'SCADUTO'
        WHEN t.transazione_data_scadenza <= CURRENT_DATE + 7 THEN 'URGENTE'
        WHEN t.transazione_data_scadenza <= CURRENT_DATE + 30 THEN 'IN_SCADENZA'
        ELSE 'NORMALE'
    END as urgenza,

    -- Metadati IVA
    aiva.iva_codice AS aliquota_codice,
    aiva.iva_percentuale,

    t.transazione_stato,
    t.transazione_viaggio_id,
    t.transazione_note

FROM mov_transazioni t
JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
LEFT JOIN ana_aliquote_iva aiva ON t.transazione_aliquota_iva_fk = aiva.iva_id
WHERE t.transazione_stato IN ('DA_PAGARE', 'PARZIALMENTE_PAGATO')
  AND t.transazione_data_scadenza IS NOT NULL
  AND t.transazione_stato <> 'ANNULLATO'
ORDER BY
    CASE
        WHEN t.transazione_data_scadenza < CURRENT_DATE THEN 1
        WHEN t.transazione_data_scadenza <= CURRENT_DATE + 7 THEN 2
        WHEN t.transazione_data_scadenza <= CURRENT_DATE + 30 THEN 3
        ELSE 4
    END,
    t.transazione_data_scadenza;
```

**Modifiche Chiave per IVA:**
- ✅ Aggiunta colonne dettaglio IVA (imponibile, IVA, lordo)
- ✅ Calcolo `importo` e `residuo` basato su **lordo** (totale con IVA)
- ✅ JOIN con `ana_aliquote_iva` per mostrare aliquota applicata

---

## 🔧 Trigger Automatici

Il sistema utilizza trigger PostgreSQL per garantire la coerenza e l'automazione dei calcoli contabili. I trigger operano in modo trasparente per l'utente, validando e calcolando automaticamente i dati durante l'inserimento o la modifica delle transazioni.

### 11.1 Trigger: Validazione Metadata-Driven

**Funzione:** `fn_validate_transazione_metadata()`
**Quando si attiva:** Prima di ogni inserimento o modifica di una transazione

**Cosa fa per l'utente contabile:**

Questo trigger garantisce che le regole contabili siano sempre rispettate, basandosi sui metadati configurati per ogni causale:

1. **Scadenze Obbligatorie:**
   - Se stai registrando una fattura (FT o FV), il sistema richiede sempre una data di scadenza
   - Se dimentichi di inserirla, ricevi un messaggio chiaro: "La causale FATTURA PASSIVA richiede la Data Scadenza obbligatoria"

2. **Auto-Generazione Scadenze:**
   - Quando inserisci una fattura senza specificare la scadenza, il sistema la calcola automaticamente
   - Esempio: Fattura del 12/02/2026 → Scadenza automatica 14/03/2026 (+ 30 giorni)
   - Puoi comunque modificarla manualmente se necessario

3. **Validazione Stati Pagamento:**
   - Se imposti lo stato "PAGATO", il sistema richiede obbligatoriamente la data di pagamento
   - Se lo stato è "DA_PAGARE" e hai una data di pagamento compilata, il sistema la rimuove automaticamente (pulizia dati)

4. **Coerenza Date:**
   - La data del documento non può essere successiva alla data di registrazione
   - Esempio: Non puoi registrare oggi (15/02) una fattura datata domani (16/02)

**Esempio pratico:**
```
Scenario: Inserimento fattura fornitore hotel
- Causale: FT (Fattura Passiva)
- Data documento: 10/02/2026
- Importo: 1.220,00 €
- Scadenza: (lasciata vuota)

Risultato: Il trigger calcola automaticamente scadenza = 12/03/2026 (30 giorni)
```

---

### 11.2 Trigger: Calcolo Automatico IVA

**Funzione:** `fn_calcola_iva_transazione()`
**Quando si attiva:** Prima della validazione metadata (priorità massima)

**Cosa fa per l'utente contabile:**

Questo è il "cuore" del sistema IVA. Calcola automaticamente imponibile, IVA e lordo basandosi sul tipo di transazione (fornitore o cliente) e sull'aliquota selezionata.

#### Il "Modello Mentale" per il Contabile

**CICLO PASSIVO (Fornitori) - Modalità SCORPORO:**

Quando registri una fattura da fornitore, hai in mano un documento con l'importo TOTALE (lordo con IVA inclusa). Il sistema scorpora automaticamente:

```
Esempio: Fattura hotel 1.220,00 €
- Tu inserisci: 1.220,00 € (il totale che devi pagare)
- Il sistema calcola automaticamente:
  * Imponibile: 1.000,00 € (calcolato come 1.220 / 1,22)
  * IVA 22%:     220,00 € (differenza)
  * Lordo:     1.220,00 € (quello che hai inserito)
```

**CICLO ATTIVO (Clienti) - Modalità CALCOLO:**

Quando emetti una fattura a cliente, ragioni in NETTO (il prezzo del servizio). Il sistema calcola l'IVA da aggiungere:

```
Esempio: Vendita viaggio 1.000,00 € + IVA
- Tu inserisci: 1.000,00 € (il prezzo netto del viaggio)
- Il sistema calcola automaticamente:
  * Imponibile: 1.000,00 € (quello che hai inserito)
  * IVA 22%:     220,00 € (calcolata come 1.000 × 22%)
  * Lordo:     1.220,00 € (totale da incassare)
```

#### Regole Speciali

1. **Valute Estere (USD, TND, ZAR, ecc.):**
   - Il sistema **azzera automaticamente** i campi IVA
   - Motivazione: l'IVA estera è Fuori Campo IVA (art. 7-ter) e non è detraibile in Italia
   - Tutto l'importo diventa "costo" senza distinzione IVA

2. **Causali senza IVA (PG, IN, NC):**
   - I pagamenti (PG/IN) non hanno IVA propria (sono movimenti finanziari)
   - Il sistema copia semplicemente l'importo nel campo lordo

3. **Correzioni Manuali (IL "PUNTO D'ORO"):**

   **Problema reale:** La fattura cartacea dice 1.220,00 € ma il calcolo matematico del software dà 1.220,01 € (differenza di arrotondamento).

   **Soluzione:** Puoi modificare MANUALMENTE tutti e tre i campi:

   ```
   Fattura cartacea:
   Imponibile: 1.000,01 €
   IVA 22%:     219,99 € (arrotondato dal fornitore)
   Totale:    1.220,00 €

   → Inserisci MANUALMENTE i tre valori esatti
   → Il sistema VALIDA che la somma quadri (con tolleranza 1 centesimo)
   → NON ricalcola, RISPETTA i tuoi valori
   ```

#### Validazione IVA Obbligatoria

Per alcune causali (configurabili), il sistema richiede obbligatoriamente la selezione di un'aliquota IVA:

```
Scenario: Fattura attiva senza IVA
- Causale: FV (Fattura Vendita)
- Aliquota: (non selezionata)

Risultato: ERRORE - "La causale FATTURA ATTIVA richiede IVA obbligatoria.
                      Selezionare un'aliquota IVA."
```

---

### 11.3 Trigger: Aggiornamento Stato dopo Pagamento

**Funzione:** `fn_aggiorna_stato_transazione()`
**Quando si attiva:** Dopo inserimento/modifica di un pagamento (transazione PG o IN)

**Cosa fa per l'utente contabile:**

Quando registri un pagamento parziale o totale, il sistema aggiorna automaticamente lo stato della fattura collegata:

```
Esempio: Fattura 1.000 € con pagamenti multipli

Situazione iniziale:
- Fattura FT-001: 1.000 € - Stato: DA_PAGARE

Primo pagamento (acconto):
- Registri pagamento PG-001: 400 € collegato a FT-001
- Il sistema aggiorna automaticamente:
  * FT-001: Stato → PARZIALMENTE_PAGATO

Secondo pagamento (saldo):
- Registri pagamento PG-002: 600 € collegato a FT-001
- Il sistema aggiorna automaticamente:
  * FT-001: Stato → PAGATO
  * FT-001: Data Pagamento → data di PG-002
```

**Protezione da errori:**
- Se provi a registrare un pagamento che supera l'importo dovuto, il sistema blocca l'operazione
- Esempio: Fattura 1.000 €, già pagati 400 €, provi a pagare 700 € → ERRORE

---

### 11.4 Trigger: Aliquota IVA Default Unica

**Funzione:** `fn_check_single_default_iva()`
**Quando si attiva:** Quando imposti un'aliquota IVA come "default"

**Cosa fa per l'utente contabile:**

Garantisce che ogni azienda abbia una sola aliquota IVA preselezionata di default (tipicamente il 22% ordinario):

```
Scenario: Modifica aliquota default
- Imposti IVA 10% come "default"
- Il sistema rimuove automaticamente il flag "default" dall'IVA 22%
- Risultato: Solo IVA 10% è ora default (preselezionata nei form)
```

---

## 🔧 Come Interagiscono i Trigger

**Ordine di Esecuzione (IMPORTANTE):**

```
1. trg_calcola_iva_transazione        ← Calcola IVA per primo
2. trg_validate_transazione_metadata  ← Poi valida scadenze/stati
3. (Salvataggio nel database)
```

Questo ordine è fondamentale perché la validazione ha bisogno dei campi IVA già calcolati.

---

# PARTE IV: MODIFICHE APPLICATIVE

## 📱 Modifiche UI Blazor

Questa sezione descrive le interfacce utente e come utilizzarle per la gestione contabile quotidiana.

### 12.1 Menu di Navigazione

**Menu Principale "Contabilità":**

```
📊 Contabilità
  ├── 📋 Controparti (fornitori e clienti)
  ├── 💳 Movimenti Contabili
  ├── 📊 Partitario Fornitori
  ├── 📈 Partitario Clienti
  ├── 💰 Margini Viaggi
  ├── ⏰ Scadenzario
  └── ⚙️ Tabelle
      ├── Causali Contabili
      └── Aliquote IVA
```

**Nota:** Il vecchio menu "Fornitori" è stato rinominato in "Controparti" per includere sia fornitori che clienti.

---

### 12.2 Anagrafica Controparti

**Pagina:** `AnaControparti.razor`

**Come usarla:**

1. **Creazione nuova controparte:**
   - Click su "+ Nuova Controparte"
   - Compila ragione sociale, P.IVA, dati fiscali
   - **IMPORTANTE:** Seleziona almeno un ruolo:
     * ☑ È un Fornitore
     * ☑ È un Cliente
     * (Puoi selezionare entrambi se la stessa società è sia fornitore che cliente)

2. **Filtraggio automatico:**
   - La controparte apparirà automaticamente nelle dropdown giuste:
     * Se è fornitore → disponibile nelle fatture passive (FT)
     * Se è cliente → disponibile nelle fatture attive (FV)

**Esempio pratico:**
```
Hotel Paradise S.r.l.
- Ragione Sociale: Hotel Paradise S.r.l.
- P.IVA: IT12345678901
- ☑ È un Fornitore (fornisce servizi alberghieri)
- ☐ È un Cliente (non acquista da noi)

→ Apparirà solo nelle fatture passive (FT, ND)
```

---

### 12.3 Gestione Aliquote IVA

**Pagina:** `AnaAliquoteIva.razor`

**Aliquote Standard Italia (preconfigurate):**

| Codice | Descrizione | % | Quando usarla |
|--------|-------------|---|---------------|
| **22** | IVA Ordinaria 22% | 22,00% | Maggior parte dei servizi turistici |
| **10** | IVA Ridotta 10% | 10,00% | Servizi specifici (es. guide turistiche) |
| **FC** | Fuori Campo IVA | 0,00% | Servizi esteri (art. 7-ter) |
| **ES** | Operazione Esente | 0,00% | Servizi sanitari, educativi |
| **NS** | Non Soggetto (Forfettario) | 0,00% | Regime forfettario |

**Come configurarle:**

1. **Aliquota Default:**
   - Imposta IVA 22% come "default" (flag ☑)
   - Sarà preselezionata automaticamente quando crei una nuova fattura

2. **Ordinamento:**
   - Imposta campo "Ordinamento" (1 = primo, 100 = in mezzo, 999 = ultimo)
   - Controlla l'ordine nel dropdown delle fatture

**Esempio configurazione agenzia viaggi:**
```
1. IVA 22% (default) - Ordinamento: 1
2. IVA 10% - Ordinamento: 2
3. FC (Fuori Campo) - Ordinamento: 10
```

---

### 12.4 Registrazione Movimenti Contabili con IVA

**Pagina:** `MovTransazioniPage.razor`
**Dialog:** `MovTransazioniEditDialog.razor`

#### Scenario 1: Fattura Fornitore (Ciclo PASSIVO)

**Esempio: Fattura hotel 1.220,00 €**

1. Click "+ Nuova Transazione"
2. Compila i campi:
   ```
   Causale: FT - FATTURA PASSIVA
   Controparte: Hotel Paradise S.r.l. (solo fornitori visibili)
   Data: 12/02/2026
   Numero Documento: H-2026-025
   Importo: 1.220,00 €
   Valuta: EUR
   ```

3. **Sezione IVA (auto-compilata):**
   ```
   Aliquota IVA: 22% (già selezionata di default)
   Modalità: LORDO (auto-impostata perché PASSIVO)

   → Il sistema SCORPORA automaticamente:
   Imponibile: 1.000,00 € (calcolato)
   IVA:          220,00 € (calcolato)
   Lordo:      1.220,00 € (confermato)
   ```

4. **Scadenza:**
   ```
   Data Scadenza: 14/03/2026 (calcolata automaticamente +30gg)
   → Puoi modificarla se il fornitore ha termini diversi
   ```

5. Click "Salva"

**Cosa succede dietro le quinte:**
- Trigger calcola IVA (scorporo)
- Trigger genera scadenza
- Trigger valida tutti i campi
- Transazione salvata con stato "DA_PAGARE"

---

#### Scenario 2: Fattura Cliente (Ciclo ATTIVO)

**Esempio: Vendita viaggio Marocco 2.000,00 € + IVA**

1. Click "+ Nuova Transazione"
2. Compila i campi:
   ```
   Causale: FV - FATTURA ATTIVA/VENDITA
   Controparte: Rossi Mario (solo clienti visibili)
   Data: 15/02/2026
   Numero Documento: FV-2026-010
   Importo: 2.000,00 €
   Valuta: EUR
   ```

3. **Sezione IVA (auto-compilata):**
   ```
   Aliquota IVA: 22% (default)
   Modalità: NETTO (auto-impostata perché ATTIVO)

   → Il sistema CALCOLA automaticamente:
   Imponibile: 2.000,00 € (quello che hai inserito)
   IVA:          440,00 € (calcolato come 2.000 × 22%)
   Lordo:      2.440,00 € (totale da incassare)
   ```

4. Click "Salva"

**Interpretazione contabile:**
- Il viaggio costa 2.000 € netti
- Aggiungi IVA 440 € (22%)
- Il cliente pagherà 2.440 €

---

#### Scenario 3: Fattura Fornitore Estero (Fuori Campo IVA)

**Esempio: Hotel Tunisia 500 TND**

1. Click "+ Nuova Transazione"
2. Compila i campi:
   ```
   Causale: FT - FATTURA PASSIVA
   Controparte: Hotel Sousse (Tunisia)
   Data: 15/02/2026
   Importo: 500,00
   Valuta: TND (Dinaro Tunisino) ← CHIAVE
   ```

3. **Sezione IVA:**
   ```
   ℹ️ MESSAGGIO AUTOMATICO:
   "Per le transazioni in valuta estera, l'IVA non viene scorporata
    in quanto considerata costo totale (Fuori Campo IVA art. 7-ter)."

   → Campi IVA nascosti/disabilitati
   → Tutto l'importo = costo (nessuna IVA detraibile)
   ```

4. Click "Salva"

**Motivazione contabile:**
- L'IVA tunisina (se presente sulla fattura) NON è detraibile in Italia
- Diventa parte del costo totale
- L'operazione è Fuori Campo IVA italiana

---

#### Scenario 4: Correzione Manuale IVA (Arrotondamenti)

**Problema:** La fattura cartacea ha arrotondamenti diversi dal calcolo automatico.

**Esempio: Fattura fornitore con IVA "strana"**

Fattura cartacea ricevuta:
```
Imponibile: 1.000,01 €
IVA 22%:     219,99 € (arrotondato dal loro software)
Totale:    1.220,00 €
```

**Come inserirla:**

1. Crea transazione normalmente
2. Il sistema calcola:
   ```
   Imponibile: 1.000,00 €
   IVA:          220,00 €
   Lordo:      1.220,00 €
   ```

3. **MODIFICA MANUALMENTE** i campi per far coincidere con la fattura:
   ```
   Imponibile: 1.000,01 € ← modificato a mano
   IVA:          219,99 € ← modificato a mano
   Lordo:      1.220,00 € ← confermato
   ```

4. Click "Salva"

**Cosa succede:**
- Il trigger NON ricalcola (rispetta i tuoi valori)
- Valida che 1.000,01 + 219,99 = 1.220,00 ✓
- Salva i valori ESATTI della fattura cartacea

**IMPORTANTE:** Tolleranza 1 centesimo:
- Se la somma non quadra per più di 0,01 €, ricevi un errore
- Esempio: 1.000,01 + 219,99 = 1.220,00 ✓ OK
- Esempio: 1.000,00 + 220,00 = 1.220,05 ✗ ERRORE (differenza 5 centesimi)

---

### 12.5 Gestione Pagamenti ("Paga Ora")

**Dialog:** `PagaOraDialog.razor`

**Come usare il pulsante "Paga Ora":**

1. Vai in "Movimenti Contabili"
2. Trova una fattura con stato "DA_PAGARE" o "PARZIALMENTE_PAGATO"
3. Click sul pulsante verde 💳 "Paga Ora"

**Dialog di pagamento:**
```
Documento: FT H-2026-025 - Hotel Paradise
Importo documento: 1.220,00 €
Già pagato: 0,00 €
Residuo: 1.220,00 €

┌─────────────────────────────────┐
│ Importo pagamento: [____,__] €  │ ← Inserisci quanto paghi oggi
│ Data pagamento: [12/02/2026]    │
│ Note: [________________]         │
│                                  │
│ ☑ Pagamento totale              │ ← Check per pagare tutto
└─────────────────────────────────┘
```

**Esempio pagamento parziale:**

```
Importo pagamento: 500,00 € (acconto)
Data: 12/02/2026
Note: "Acconto 1 - Bonifico"

→ Click "Conferma"
```

**Cosa succede:**
1. Sistema crea automaticamente transazione PG-001:
   ```
   Causale: PG (Pagamento)
   Importo: 500,00 €
   Collegato a: FT H-2026-025
   ```

2. Aggiorna fattura originale:
   ```
   FT H-2026-025:
   Stato: DA_PAGARE → PARZIALMENTE_PAGATO
   ```

3. Nelle view partitario:
   ```
   Residuo: 1.220,00 - 500,00 = 720,00 €
   ```

**Secondo pagamento (saldo):**
```
Residuo mostrato: 720,00 €
Importo pagamento: 720,00 €
Data: 20/02/2026

→ Click "Conferma"
```

**Risultato finale:**
```
FT H-2026-025:
Stato: PAGATO
Data Pagamento: 20/02/2026 (data ultimo pagamento)

Movimenti collegati:
- PG-001: 500,00 € (12/02/2026)
- PG-002: 720,00 € (20/02/2026)
Totale pagato: 1.220,00 € ✓
```

---

### 12.6 Toggle Modalità IVA (Casi Speciali)

**Quando usarlo:** Raramente, solo per casi particolari dove vuoi invertire il comportamento standard.

**Esempio: Fattura fornitore con importo NETTO**

Caso raro: Hai una fattura fornitore che riporta separatamente netto e IVA:
```
Fattura fornitore:
Imponibile: 1.000,00 €
IVA 22%:     220,00 €
Totale:    1.220,00 €
```

**Soluzione con toggle:**
1. Crea fattura FT normalmente
2. Invece di inserire 1.220 nell'importo, inserisci 1.000
3. **Click sul toggle** "Modalità IVA" → Passa da LORDO a NETTO
4. Il sistema ora calcola come ATTIVO:
   ```
   Imponibile: 1.000,00 € (inserito)
   IVA:          220,00 € (calcolato)
   Lordo:      1.220,00 € (calcolato)
   ```

**Nota:** Questo è un caso speciale. Normalmente NON devi usare il toggle.

---

## 💻 Codice Backend

### 13.1 Service Layer - Architettura DB-First

**Principio fondamentale:**
Il codice C# NON contiene SQL diretto. Tutte le operazioni passano attraverso **Stored Functions PostgreSQL**.

**Vantaggi per l'utente:**
- Logica contabile centralizzata nel database (single source of truth)
- Calcoli IVA consistenti anche se accedi da strumenti esterni (pgAdmin, Excel via ODBC, ecc.)
- Modifiche alle regole contabili senza ricompilare l'applicazione

---

### 13.2 Servizi CRUD Principali

#### AnaAliquoteIvaService.cs

**Metodi disponibili:**

```csharp
// Recupera tutte le aliquote dell'azienda
GetAllAsync(int aziendaId)

// Solo aliquote attive (per dropdown UI)
GetActiveAsync(int aziendaId)

// Aliquota default (22% ordinaria)
GetDefaultAsync(int aziendaId)

// CRUD standard
CreateAsync(AnaAliquotaIva aliquota)
UpdateAsync(AnaAliquotaIva aliquota)
DeleteAsync(int ivaId)
```

**Chiamate a stored functions:**
```csharp
// Esempio: GetAllAsync()
var aliquote = await conn.QueryAsync<AnaAliquotaIva>(
    "SELECT * FROM fn_ana_aliquote_iva_get_all(@AziendaId)",
    new { AziendaId = aziendaId }
);
```

---

#### MovTransazioniService.cs

**Metodi chiave:**

```csharp
// CRUD standard (trigger automatici gestiscono IVA)
CreateAsync(MovTransazioni transazione)
UpdateAsync(MovTransazioni transazione)

// Pagamento rapido (già visto in UI)
PagaOraAsync(int transazioneId, decimal importo, DateTime data, string note)

// Calcolo residuo da pagare
GetResiduoAsync(int transazioneId)
```

**Logica PagaOraAsync (semplificata):**

```csharp
public async Task<int> PagaOraAsync(int fatturaId, decimal importo, DateTime data)
{
    // 1. Carica fattura originale
    var fattura = await GetByIdAsync(fatturaId);

    // 2. Calcola totale già pagato
    decimal totalePagato = await CalcolaTotalePagato(fatturaId);

    // 3. Validazione sovrapagamento
    if (totalePagato + importo > fattura.TransazioneLordoEur)
        throw new Exception("Pagamento supererebbe importo documento");

    // 4. Crea transazione PG
    var pagamento = new MovTransazioni {
        CausaleId = GetCausalePG(),  // Causale PG o IN automatica
        ImportoEur = importo,
        TransazioneFatturaFk = fatturaId,  // Collega alla fattura
        DataPagamento = data,
        Stato = "PAGATO"
    };

    await CreateAsync(pagamento);

    // 5. Trigger automatico aggiorna lo stato della fattura originale
    //    (DA_PAGARE → PARZIALMENTE_PAGATO → PAGATO)

    return pagamento.TransazioneId;
}
```

---

#### ContropartiService.cs

**Filtraggio automatico per ciclo:**

```csharp
// Recupera solo fornitori
GetFornitoriAsync(int aziendaId)
→ WHERE is_fornitore = TRUE

// Recupera solo clienti
GetClientiAsync(int aziendaId)
→ WHERE is_cliente = TRUE

// Filtro dinamico in base a ciclo causale
GetByTipoAsync(int aziendaId, string causaleCiclo)
→ IF causaleCiclo = 'PASSIVO' THEN is_fornitore = TRUE
→ IF causaleCiclo = 'ATTIVO' THEN is_cliente = TRUE
```

**Uso nel componente UI:**

```razor
<ControparteSelect
    @bind-SelectedControparteId="@TransazioneControparteId"
    CausaleCiclo="@_causaleCorrente.CausaleCiclo"
    Label="@(_causaleCorrente.CausaleCiclo == "ATTIVO" ? "Cliente" : "Fornitore")" />
```

→ Se causale = FT (PASSIVO) → Dropdown mostra solo fornitori
→ Se causale = FV (ATTIVO) → Dropdown mostra solo clienti

---

# PARTE V: TESTING E DEPLOYMENT

## 🧪 Test di Validazione Completi

Questa sezione fornisce scenari di test per validare il corretto funzionamento del sistema.

### 14.1 Test Sistema Base (Pre-IVA)

#### Test 1: Migrazione Dati Fornitori → Controparti

**Obiettivo:** Verificare che tutti i fornitori siano stati migrati correttamente.

```sql
-- Verifica conteggio
SELECT
    (SELECT COUNT(*) FROM ana_fornitori) as fornitori_originali,
    (SELECT COUNT(*) FROM ana_controparti WHERE is_fornitore = TRUE) as controparti_fornitori;

-- Verifica integrità referenziale
SELECT COUNT(*) as transazioni_orfane
FROM mov_transazioni t
LEFT JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
WHERE c.controparte_id IS NULL;

-- Atteso: transazioni_orfane = 0
```

---

#### Test 2: Calcolo Margine Viaggio

**Obiettivo:** Verificare che il sistema calcoli correttamente ricavi - costi.

**Scenario di test:**
```
Viaggio "Marocco 2026" (ID: 100)

Ricavi (ATTIVO):
- FV-001: Vendita pacchetto 5.000,00 € (cliente Rossi)
- FV-002: Vendita extra 500,00 € (cliente Bianchi)
Totale ricavi: 5.500,00 €

Costi (PASSIVO):
- FT-001: Hotel 2.000,00 €
- FT-002: Guida 500,00 €
- FT-003: Transfer 300,00 €
Totale costi: 2.800,00 €

Margine atteso: 5.500 - 2.800 = 2.700,00 € (49% sul ricavo)
```

**Query di verifica:**
```sql
SELECT * FROM vw_margini_viaggi WHERE viaggio_id = 100;

-- Atteso:
-- ricavi_totali_eur: 5500.00
-- costi_totali_eur: 2800.00
-- margine_eur: 2700.00
-- margine_percentuale: 49.09
```

---

#### Test 3: Pagamenti Multipli

**Scenario:**
```
Fattura FT-100: 1.000,00 €
Pagamento 1: 400,00 € (12/02)
Pagamento 2: 600,00 € (20/02)
```

**Test step-by-step:**

1. **Crea fattura:**
```sql
INSERT INTO mov_transazioni (...) VALUES (
    ..., importo: 1000.00, causale: 'FT', stato: 'DA_PAGARE', ...
);  -- ID: 100
```

2. **Primo pagamento:**
```csharp
await TransazioniService.PagaOraAsync(100, 400.00m, DateTime.Parse("2026-02-12"));
```

**Verifica intermedia:**
```sql
SELECT transazione_stato, transazione_data_pagamento
FROM mov_transazioni
WHERE transazione_id = 100;

-- Atteso:
-- transazione_stato: 'PARZIALMENTE_PAGATO'
-- transazione_data_pagamento: NULL (non ancora completamente pagato)
```

3. **Secondo pagamento (saldo):**
```csharp
await TransazioniService.PagaOraAsync(100, 600.00m, DateTime.Parse("2026-02-20"));
```

**Verifica finale:**
```sql
SELECT
    t.transazione_stato,
    t.transazione_data_pagamento,
    COUNT(p.transazione_id) as num_pagamenti,
    SUM(p.transazione_importo_eur) as totale_pagato
FROM mov_transazioni t
LEFT JOIN mov_transazioni p ON p.transazione_fattura_fk = t.transazione_id
WHERE t.transazione_id = 100
GROUP BY t.transazione_id, t.transazione_stato, t.transazione_data_pagamento;

-- Atteso:
-- transazione_stato: 'PAGATO'
-- transazione_data_pagamento: '2026-02-20'
-- num_pagamenti: 2
-- totale_pagato: 1000.00
```

---

### 14.2 Test Sistema IVA

#### Test 4: Calcolo IVA Scorporo (PASSIVO)

**Scenario:** Fattura fornitore 1.220,00 € con IVA 22%

```sql
INSERT INTO mov_transazioni (
    transazione_azienda_id, transazione_causale_tipo_id,
    transazione_controparte_id, transazione_data,
    transazione_importo, transazione_valuta_id,
    transazione_aliquota_iva_fk, transazione_causale
) VALUES (
    6,
    (SELECT causale_id FROM ana_tipi_causali WHERE causale_codice = 'FT' AND azienda_fk = 6),
    100,
    CURRENT_DATE,
    1220.00,  -- ← Importo LORDO (con IVA inclusa)
    (SELECT valuta_id FROM ana_valute WHERE valuta_codice_iso = 'EUR'),
    (SELECT iva_id FROM ana_aliquote_iva WHERE iva_codice = '22' AND azienda_fk = 6),
    'TEST SCORPORO IVA'
) RETURNING
    transazione_id,
    transazione_imponibile_eur,
    transazione_iva_eur,
    transazione_lordo_eur,
    transazione_iva_modalita_input;

-- Atteso:
-- transazione_imponibile_eur: 1000.00
-- transazione_iva_eur: 220.00
-- transazione_lordo_eur: 1220.00
-- transazione_iva_modalita_input: 'LORDO'
```

---

#### Test 5: Calcolo IVA Somma (ATTIVO)

**Scenario:** Fattura cliente 2.000,00 € + IVA 10%

```sql
INSERT INTO mov_transazioni (
    transazione_azienda_id, transazione_causale_tipo_id,
    transazione_controparte_id, transazione_data,
    transazione_importo, transazione_valuta_id,
    transazione_aliquota_iva_fk, transazione_causale
) VALUES (
    6,
    (SELECT causale_id FROM ana_tipi_causali WHERE causale_codice = 'FV' AND azienda_fk = 6),
    200,  -- ← Cliente
    CURRENT_DATE,
    2000.00,  -- ← Importo NETTO (imponibile)
    (SELECT valuta_id FROM ana_valute WHERE valuta_codice_iso = 'EUR'),
    (SELECT iva_id FROM ana_aliquote_iva WHERE iva_codice = '10' AND azienda_fk = 6),
    'TEST CALCOLO IVA 10%'
) RETURNING
    transazione_imponibile_eur,
    transazione_iva_eur,
    transazione_lordo_eur,
    transazione_iva_modalita_input;

-- Atteso:
-- transazione_imponibile_eur: 2000.00
-- transazione_iva_eur: 200.00
-- transazione_lordo_eur: 2200.00
-- transazione_iva_modalita_input: 'NETTO'
```

---

#### Test 6: Arrotondamenti Manuali (Tolleranza 0.01€)

**Scenario VALIDO:** Differenza 1 centesimo (accettata)

```sql
INSERT INTO mov_transazioni (
    ...,
    transazione_importo,
    transazione_imponibile_eur,
    transazione_iva_eur,
    transazione_lordo_eur,
    ...
) VALUES (
    ...,
    1220.00,    -- ← Valore inserito dall'utente
    1000.01,    -- ← MANUALE (arrotondamento fattura)
    219.99,     -- ← MANUALE
    1220.00,    -- ← MANUALE
    ...
);

-- Verifica: 1000.01 + 219.99 = 1220.00 ✓
-- Differenza: 0.00 € < 0.01 € → SALVATAGGIO OK
```

**Scenario ERRORE:** Differenza 5 centesimi (rifiutata)

```sql
INSERT INTO mov_transazioni (
    ...,
    transazione_imponibile_eur: 1000.00,
    transazione_iva_eur: 220.00,
    transazione_lordo_eur: 1220.05,  -- ← ERRORE: 1000 + 220 = 1220 ≠ 1220.05
    ...
);

-- Atteso: EXCEPTION
-- "Incoerenza IVA: Lordo (1220.05 EUR) != Imponibile (1000.00 EUR) + IVA (220.00 EUR).
--  Differenza: 0.05 EUR"
```

---

#### Test 7: IVA su Valuta Estera (Azzeramento Automatico)

**Scenario:** Fattura fornitore Tunisia in TND

```sql
INSERT INTO mov_transazioni (
    ...,
    transazione_importo: 500.00,
    transazione_valuta_id: (SELECT valuta_id WHERE valuta_codice_iso = 'TND'),
    transazione_aliquota_iva_fk: (SELECT iva_id WHERE iva_codice = '22'),  -- ← Selezionata ma ignorata
    ...
) RETURNING
    transazione_aliquota_iva_fk,
    transazione_imponibile_eur,
    transazione_iva_eur,
    transazione_lordo_eur;

-- Atteso (trigger azzera IVA per valuta estera):
-- transazione_aliquota_iva_fk: NULL
-- transazione_imponibile_eur: NULL
-- transazione_iva_eur: NULL
-- transazione_lordo_eur: NULL
```

---

#### Test 8: Validazione IVA Obbligatoria

**Scenario:** Fattura attiva senza IVA (causale richiede IVA)

```sql
INSERT INTO mov_transazioni (
    ...,
    transazione_causale_tipo_id: (SELECT causale_id WHERE causale_codice = 'FV'),  -- Causale con causale_richiede_iva = TRUE
    transazione_aliquota_iva_fk: NULL,  -- ← IVA non selezionata
    ...
);

-- Atteso: EXCEPTION
-- "La causale "FATTURA ATTIVA/VENDITA" richiede IVA obbligatoria. Selezionare un'aliquota IVA."
```

---

### 14.3 Checklist Test UI (Manuali)

Questi test richiedono interazione umana con l'interfaccia:

**Test Interfaccia Movimenti con IVA:**

- [ ] Inserimento FT in EUR con IVA 22% → Calcolo automatico scorporo visibile real-time
- [ ] Inserimento FV in EUR con IVA 10% → Calcolo automatico somma visibile real-time
- [ ] Toggle modalità LORDO/NETTO → Ricalcolo corretto di imponibile/IVA/lordo
- [ ] Inserimento FT in USD → Sezione IVA nascosta + messaggio informativo
- [ ] Modifica manuale imponibile → Ricalcolo automatico IVA e lordo
- [ ] Modifica manuale IVA (arrotondamento) → Salvataggio senza errori se diff < 0.01€
- [ ] Causale PG (pagamento) → Sezione IVA nascosta automaticamente
- [ ] Causale FT senza aliquota selezionata → Errore chiaro all'utente
- [ ] Cambio causale da FT a FV → Cambio dropdown controparte (fornitori → clienti)
- [ ] Scadenza auto-generata quando causale richiede scadenza
- [ ] Data scadenza editabile manualmente

**Test Componente AliquotaIvaSelect:**

- [ ] Dropdown mostra solo aliquote attive
- [ ] Aliquota default (22%) preselezionata
- [ ] Ordinamento corretto (22%, 10%, 4%, FC, ES, NS)
- [ ] Cambio aliquota → Ricalcolo IVA immediato

**Test Dialog PagaOra:**

- [ ] Importo max limitato a residuo
- [ ] Checkbox "Pagamento totale" auto-compila importo
- [ ] Validazione data pagamento (non futuro)
- [ ] Protezione sovrapagamento (errore se > residuo)
- [ ] Refresh automatico griglia dopo salvataggio

---

## 🚀 Deployment e Rollback

### 15.1 Deployment Sequenziale

**Prerequisiti:**
- Backup completo database
- Accesso PostgreSQL con privilegi superuser
- Ambiente di test validato

**Sequenza di esecuzione script SQL:**

```bash
# FASE 1: Sistema Base (già deployato)
✅ Create_AnaControparti.sql
✅ Migration_Ana_Tipi_Causali_AddColumns.sql
✅ Migration_Create_Validation_Trigger.sql
✅ Migration_Fix_Pagamento_Constraint.sql

# FASE 2: Estensione IVA (nuovi script)
1. Create_AnaAliquoteIva.sql
2. Create_AnaAliquoteIva_CRUD.sql
3. Migration_Add_IVA_Columns.sql
4. Migration_Add_IVA_Metadata_Causali.sql
5. Migration_Create_IVA_Trigger.sql
6. Migration_Update_Views_IVA.sql

# FASE 3: Dati iniziali
7. Insert_Aliquote_IVA_Standard.sql
8. Update_Causali_Metadata_IVA.sql
```

**Esecuzione:**

```bash
# Connessione al database
psql -U postgres -d gestione_viaggi

# Esecuzione script in sequenza
\i SqlScripts/Create_AnaAliquoteIva.sql
\i SqlScripts/Create_AnaAliquoteIva_CRUD.sql
\i SqlScripts/Migration_Add_IVA_Columns.sql
\i SqlScripts/Migration_Add_IVA_Metadata_Causali.sql
\i SqlScripts/Migration_Create_IVA_Trigger.sql
\i SqlScripts/Migration_Update_Views_IVA.sql

# Verifica deployment
\dt ana_aliquote_iva
\df fn_calcola_iva_transazione
\d+ mov_transazioni
```

---

### 15.2 Rollback Plan

**Rollback Completo (se problemi gravi entro 7 giorni):**

```sql
-- =====================================================
-- ROLLBACK COMPLETO INTEGRAZIONE IVA
-- Ripristina stato pre-IVA (v1.3)
-- =====================================================

BEGIN;

-- 1. Elimina trigger IVA
DROP TRIGGER IF EXISTS trg_calcola_iva_transazione ON mov_transazioni;
DROP FUNCTION IF EXISTS fn_calcola_iva_transazione();

-- 2. Elimina trigger aliquote
DROP TRIGGER IF EXISTS trg_check_single_default_iva ON ana_aliquote_iva;
DROP FUNCTION IF EXISTS fn_check_single_default_iva();

-- 3. Rimuovi colonne IVA da mov_transazioni
ALTER TABLE mov_transazioni
    DROP COLUMN IF EXISTS transazione_aliquota_iva_fk,
    DROP COLUMN IF EXISTS transazione_imponibile_eur,
    DROP COLUMN IF EXISTS transazione_iva_eur,
    DROP COLUMN IF EXISTS transazione_lordo_eur,
    DROP COLUMN IF EXISTS transazione_iva_modalita_input;

-- 4. Ripristina colonna _old (se non ancora eliminata)
ALTER TABLE mov_transazioni
    RENAME COLUMN transazione_importo_eur_old TO transazione_importo_eur;

-- 5. Rimuovi metadati IVA da causali
ALTER TABLE ana_tipi_causali
    DROP COLUMN IF EXISTS causale_genera_iva,
    DROP COLUMN IF EXISTS causale_richiede_iva;

-- 6. Elimina tabella aliquote e stored functions
DROP TABLE IF EXISTS ana_aliquote_iva CASCADE;
DROP FUNCTION IF EXISTS fn_ana_aliquote_iva_get_all(INTEGER);
DROP FUNCTION IF EXISTS fn_ana_aliquote_iva_get_active(INTEGER);
DROP FUNCTION IF EXISTS sp_ana_aliquote_iva_create(...);
-- ... (altre functions)

-- 7. Riabilita trigger vecchio (se disabilitato)
ALTER TABLE mov_transazioni ENABLE TRIGGER trg_calcola_importo_eur;

COMMIT;

-- Verifica rollback
SELECT COUNT(*) FROM ana_aliquote_iva;  -- Atteso: ERROR (tabella non esiste)
\d mov_transazioni;  -- Verifica colonne IVA rimosse
```

**Rollback Parziale (solo UI):**

Se i problemi sono solo lato applicazione C#/Blazor:

```bash
# 1. Rollback codice applicativo
git revert <commit-hash-iva>

# 2. Ricompilazione
dotnet build

# 3. Deploy applicazione (database invariato)
```

**Nota:** Il database rimane con supporto IVA ma l'UI torna alla versione precedente.

---

### 15.3 Monitoraggio Post-Deployment

**Prime 48 ore:**

```sql
-- 1. Verifica inserimenti con IVA
SELECT
    COUNT(*) as tot_transazioni,
    COUNT(transazione_aliquota_iva_fk) as con_iva,
    ROUND(100.0 * COUNT(transazione_aliquota_iva_fk) / COUNT(*), 2) as percentuale_iva
FROM mov_transazioni
WHERE transazione_data >= CURRENT_DATE - INTERVAL '2 days';

-- 2. Verifica coerenza IVA (tolleranza)
SELECT
    transazione_id,
    transazione_numero_documento,
    transazione_imponibile_eur,
    transazione_iva_eur,
    transazione_lordo_eur,
    ABS(transazione_lordo_eur - (transazione_imponibile_eur + transazione_iva_eur)) as differenza
FROM mov_transazioni
WHERE transazione_aliquota_iva_fk IS NOT NULL
  AND ABS(transazione_lordo_eur - (transazione_imponibile_eur + transazione_iva_eur)) > 0.01
  AND transazione_data >= CURRENT_DATE - INTERVAL '2 days';

-- Atteso: 0 righe (nessuna incoerenza)

-- 3. Errori nei log PostgreSQL
SELECT * FROM pg_stat_activity WHERE state = 'idle in transaction (aborted)';
```

---

# PARTE VI: RIFERIMENTI E GOVERNANCE

## 📚 Glossario Contabile

### Termini Base

| Termine | Significato | Esempio |
|---------|-------------|---------|
| **Ciclo Attivo** | Transazioni con clienti (fatture emesse, incassi) | Fattura viaggio emessa a cliente |
| **Ciclo Passivo** | Transazioni con fornitori (fatture ricevute, pagamenti) | Fattura hotel ricevuta da fornitore |
| **Controparte** | Soggetto con cui si intrattiene un rapporto commerciale | Può essere sia fornitore che cliente |
| **Causale** | Tipologia di movimento contabile | FT = Fattura, PG = Pagamento, ecc. |
| **Dare/Avere** | Movimento contabile con segno algebrico | +850€ (dare), -500€ (avere) |
| **Saldo Progressivo** | Somma algebrica cumulativa dei movimenti | 1000 + 500 - 200 = 1300€ |
| **Residuo** | Importo ancora da pagare/incassare | Fattura 1000€ - Pagato 300€ = Residuo 700€ |
| **Margine** | Differenza tra ricavi e costi | Ricavi 5000€ - Costi 2000€ = Margine 3000€ |
| **Partitario** | Estratto conto dettagliato di una controparte | Tutti i movimenti con fornitore X |
| **Scadenzario** | Elenco scadenze pagamenti/incassi ordinate per urgenza | Fatture in scadenza nei prossimi 30 giorni |

### Termini IVA

| Termine | Significato | Esempio |
|---------|-------------|---------|
| **Imponibile** | Importo netto su cui si calcola l'IVA (base imponibile) | Viaggio 1.000€ + IVA → Imponibile = 1.000€ |
| **IVA** | Imposta sul Valore Aggiunto | 1.000€ × 22% = 220€ |
| **Lordo** | Importo totale comprensivo di IVA | 1.000€ + 220€ = 1.220€ lordo |
| **Scorporo IVA** | Calcolo inverso: da lordo a netto | 1.220€ / 1,22 = 1.000€ imponibile |
| **Aliquota IVA** | Percentuale IVA applicabile | 22% ordinaria, 10% ridotta, 4% super-ridotta |
| **Fuori Campo IVA** | Operazione esclusa dall'applicazione IVA (art. 7-ter) | Servizi esteri |
| **Operazione Esente** | Operazione senza IVA per legge (art. 10) | Servizi sanitari, educativi |
| **Natura (FE)** | Codice fatturazione elettronica per IVA speciali | N1, N2.1, N3.2, N4, ecc. |
| **Regime 74-ter** | Regime speciale margine agenzie viaggi | IVA solo su margine, non su totale |
| **Reverse Charge** | Inversione contabile IVA (debitore = acquirente) | Servizi intra-UE |
| **Split Payment** | Scissione pagamenti PA (IVA versata a Erario) | Fatture a Pubblica Amministrazione |

### Acronimi

| Acronimo | Significato | Uso |
|----------|-------------|-----|
| **FT** | Fattura (Passiva) | Fattura ricevuta da fornitore |
| **FV** | Fattura Vendita (Attiva) | Fattura emessa a cliente |
| **PG** | Pagamento | Pagamento a fornitore |
| **IN** | Incasso | Incasso da cliente |
| **NC** | Nota di Credito | Storno fattura (passiva) |
| **NCA** | Nota di Credito Attiva | Storno fattura emessa |
| **ND** | Nota di Debito | Addebito aggiuntivo (passiva) |
| **NDA** | Nota di Debito Attiva | Addebito cliente |
| **FC** | Fuori Campo IVA | Aliquota 0% per esclusione IVA |
| **ES** | Esente IVA | Aliquota 0% per esenzione |
| **NS** | Non Soggetto IVA | Regime forfettario |
| **P.IVA** | Partita IVA | Codice fiscale aziende |
| **SDI** | Sistema Di Interscambio | Sistema fatturazione elettronica |

---

## ⚠️ Note Importanti

### 17.1 Sicurezza e Audit

**Autenticazione e Autorizzazione:**
- Tutte le operazioni richiedono utente autenticato
- Ogni utente vede solo i dati della propria azienda (`azienda_fk`)
- Filtro automatico a livello service layer

**Audit Trail Completo:**
```
Ogni transazione contiene:
- created_at: Timestamp creazione
- created_by: Utente che ha creato
- updated_at: Timestamp ultima modifica
- updated_by: Utente che ha modificato
```

**Tracciabilità IVA:**
```
transazione_iva_modalita_input traccia se:
- LORDO: Calcolo automatico scorporo
- NETTO: Calcolo automatico somma
- NULL: Valori inseriti manualmente dall'utente

→ In caso di controllo fiscale, puoi dimostrare l'origine del calcolo
```

---

### 17.2 Performance e Ottimizzazioni

**Indici Ottimizzati:**
```sql
-- Partitari: JOIN veloce su controparte
idx_transazioni_controparte (transazione_controparte_id)

-- Scadenzario: ricerca per data
idx_transazioni_scadenza (transazione_data_scadenza)

-- IVA: JOIN veloce su aliquota
idx_transazioni_iva (transazione_aliquota_iva_fk)

-- Causali: filtro ciclo (attivo/passivo)
idx_causali_ciclo (causale_ciclo)
```

**Window Functions (Saldi Progressivi):**
- Performanti fino a ~100.000 transazioni per controparte
- Se superato, considerare materializzazione view

**Trigger Ottimizzati:**
- Trigger IVA esegue `RETURN NEW` immediato per valute estere (zero overhead)
- Validazione metadata solo su campi modificati (NEW vs OLD)

**Raccomandazioni:**
- **Vacuum periodico:** `VACUUM ANALYZE mov_transazioni;` (settimanale)
- **Reindex annuale:** `REINDEX TABLE mov_transazioni;` (fine anno fiscale)
- **Partition** su `transazione_data` se > 1 milione transazioni/anno

---

### 17.3 Backup e Disaster Recovery

**Strategia Backup:**

```bash
# Backup completo giornaliero (3:00 AM)
pg_dump -U postgres -F c -b -v -f /backup/gestione_viaggi_$(date +%Y%m%d).dump gestione_viaggi

# Backup incrementale orario (Point-In-Time Recovery)
pg_basebackup -U postgres -D /backup/wal_archive/ -Ft -z -P

# Retention policy:
# - Backup giornalieri: 30 giorni
# - Backup mensili: 12 mesi
# - Backup fine anno fiscale: permanente
```

**Ripristino:**

```bash
# Ripristino completo
pg_restore -U postgres -d gestione_viaggi -v /backup/gestione_viaggi_20260215.dump

# Ripristino point-in-time (es. prima di errore ore 14:30)
pg_restore ... --recovery-target-time='2026-02-15 14:25:00'
```

**Disaster Recovery Plan:**

1. **RPO (Recovery Point Objective):** Max 1 ora di dati persi (backup incrementale orario)
2. **RTO (Recovery Time Objective):** Ripristino entro 4 ore
3. **Backup off-site:** Copia giornaliera su cloud storage (AWS S3 / Azure Blob)

---

### 17.4 Compatibilità Dati Storici

**Transazioni Pre-IVA:**

Tutte le transazioni inserite PRIMA dell'integrazione IVA continuano a funzionare:

```sql
-- Transazione vecchia (pre-IVA)
transazione_aliquota_iva_fk: NULL
transazione_imponibile_eur: NULL
transazione_iva_eur: NULL
transazione_lordo_eur: NULL
transazione_importo_eur_old: 1220.00  ← Valore originale preservato

-- View partitario gestisce il fallback:
COALESCE(transazione_lordo_eur, transazione_importo_eur_old) as importo
```

**Raccomandazione:**
- NON modificare transazioni storiche pre-IVA (rischio perdita dati audit)
- Se necessario correggere, creare nuova transazione di storno + nuova corretta

**Cleanup colonna _old:**
- Dopo 6 mesi di produzione stabile IVA, eliminare `transazione_importo_eur_old`
- Script: `Migration_Cleanup_IVA_Old_Column.sql` (da eseguire manualmente)

---

## 💡 Best Practices e Raccomandazioni

### 18.1 Configurazione Causali per Nuova Azienda

Quando aggiungi una nuova azienda, configura le causali standard:

```sql
-- Template causali Italia (azienda_id = ?)
INSERT INTO ana_tipi_causali (
    azienda_fk, causale_codice, causale_descrizione,
    causale_segno, causale_is_documento, causale_ciclo,
    causale_richiede_scadenza, causale_giorni_scadenza_default,
    causale_genera_scadenza_auto, causale_genera_iva, causale_richiede_iva
) VALUES
-- Ciclo PASSIVO
(?, 'FT', 'FATTURA PASSIVA', 1, TRUE, 'PASSIVO', TRUE, 30, TRUE, TRUE, TRUE),
(?, 'NC', 'NOTA DI CREDITO', -1, TRUE, 'PASSIVO', FALSE, NULL, FALSE, FALSE, FALSE),
(?, 'PG', 'PAGAMENTO', -1, FALSE, 'PASSIVO', FALSE, NULL, FALSE, FALSE, FALSE),
(?, 'ND', 'NOTA DI DEBITO', 1, TRUE, 'PASSIVO', TRUE, 30, TRUE, TRUE, TRUE),

-- Ciclo ATTIVO
(?, 'FV', 'FATTURA ATTIVA/VENDITA', 1, TRUE, 'ATTIVO', TRUE, 30, TRUE, TRUE, TRUE),
(?, 'IN', 'INCASSO', -1, FALSE, 'ATTIVO', FALSE, NULL, FALSE, FALSE, FALSE),
(?, 'NCA', 'NOTA DI CREDITO EMESSA', -1, TRUE, 'ATTIVO', FALSE, NULL, FALSE, TRUE, FALSE),
(?, 'NDA', 'NOTA DI DEBITO EMESSA', 1, TRUE, 'ATTIVO', TRUE, 30, TRUE, TRUE, TRUE);
```

---

### 18.2 Personalizzazione Termini Pagamento

Alcuni settori hanno scadenze diverse:

```sql
-- Grande Distribuzione: 90 giorni
UPDATE ana_tipi_causali
SET causale_giorni_scadenza_default = 90
WHERE causale_codice = 'FT'
  AND azienda_fk IN (SELECT azienda_id FROM ana_aziende WHERE settore = 'GDO');

-- Pagamenti immediati: 0 giorni (pronta cassa)
UPDATE ana_tipi_causali
SET causale_giorni_scadenza_default = 0
WHERE causale_codice = 'FT'
  AND azienda_fk IN (SELECT azienda_id FROM ana_aziende WHERE ragione_sociale LIKE '%Retail%');

-- 60 giorni data fattura fine mese
UPDATE ana_tipi_causali
SET causale_giorni_scadenza_default = 60
WHERE causale_codice = 'FT'
  AND azienda_fk = ?;
```

---

### 18.3 Gestione Aliquote IVA

**Aliquote Standard Italia (sempre configurare):**

```sql
INSERT INTO ana_aliquote_iva (azienda_fk, iva_codice, iva_descrizione, iva_percentuale, iva_natura, is_default, ordinamento) VALUES
(?, '22', 'IVA Ordinaria 22%', 22.00, NULL, TRUE, 1),    -- Default
(?, '10', 'IVA Ridotta 10%', 10.00, NULL, FALSE, 2),
(?, '5', 'IVA Ridotta 5%', 5.00, NULL, FALSE, 3),
(?, '4', 'IVA Ridotta 4%', 4.00, NULL, FALSE, 4),
(?, 'FC', 'Fuori Campo IVA (Art. 7-ter)', 0.00, 'N1', FALSE, 10),
(?, 'ES', 'Operazione Esente IVA', 0.00, 'N4', FALSE, 11),
(?, 'NS', 'Non Soggetto IVA (Forfettario)', 0.00, 'N2.1', FALSE, 12);
```

**Aliquote Speciali Agenzie Viaggi:**

```sql
-- Regime 74-ter (margine) - Solo per contabilità separata
(?, '74TER', 'Regime Margine Agenzie (74-ter)', 0.00, 'N5', FALSE, 20);
```

**Cambio Aliquota Default:**

```sql
-- Imposta IVA 10% come default (es. azienda regime ridotto)
UPDATE ana_aliquote_iva
SET is_default = TRUE
WHERE iva_codice = '10' AND azienda_fk = ?;

-- Il trigger rimuove automaticamente il flag dalle altre
```

---

### 18.4 Monitoring Pagamenti Multipli

Query per verificare fatture con pagamenti parziali/multipli:

```sql
SELECT
    f.transazione_numero_documento as fattura,
    c.ragione_sociale as controparte,
    f.transazione_lordo_eur as importo_fattura,
    f.transazione_stato,
    COUNT(p.transazione_id) as num_pagamenti,
    SUM(ABS(p.transazione_importo_eur)) as totale_pagato,
    f.transazione_lordo_eur - COALESCE(SUM(ABS(p.transazione_importo_eur)), 0) as residuo
FROM mov_transazioni f
JOIN ana_controparti c ON f.transazione_controparte_id = c.controparte_id
LEFT JOIN mov_transazioni p ON p.transazione_fattura_fk = f.transazione_id
WHERE f.transazione_causale_tipo_id IN (
    SELECT causale_id FROM ana_tipi_causali WHERE causale_is_documento = TRUE
)
GROUP BY f.transazione_id, f.transazione_numero_documento, c.ragione_sociale,
         f.transazione_lordo_eur, f.transazione_stato
HAVING COUNT(p.transazione_id) >= 1  -- Solo fatture con almeno 1 pagamento
ORDER BY f.transazione_data DESC
LIMIT 50;
```

---

### 18.5 Correzioni Manuali IVA (Procedure)

**Quando usare la correzione manuale:**

1. **Arrotondamenti software diversi:**
   - Fattura fornitore con IVA arrotondata diversamente
   - Software fornitore usa regole arrotondamento diverse

2. **Fatture con sconti:**
   - Sconto applicato DOPO calcolo IVA (raro)
   - IVA calcolata su importo scontato

3. **Fatture rettificate:**
   - Storno parziale con IVA ricalcolata

**Procedura corretta:**

```
1. Inserisci fattura normalmente
2. Sistema calcola automaticamente IVA
3. Confronta con fattura cartacea:
   - Se coincide → OK, salva
   - Se differenza ≤ 0.01€ → OK, accettabile
   - Se differenza > 0.01€ → Modifica manualmente

4. Per modificare manualmente:
   a. Click su campi Imponibile, IVA, Lordo
   b. Inserisci valori ESATTI della fattura cartacea
   c. Verifica che la somma quadri (Imp + IVA = Lordo)
   d. Salva

5. Il sistema VALIDA (non ricalcola) e salva i tuoi valori
```

**Audit Trail:**
```sql
-- Verifica correzioni manuali (per audit)
SELECT
    transazione_numero_documento,
    transazione_imponibile_eur,
    transazione_iva_eur,
    transazione_lordo_eur,
    CASE
        WHEN transazione_iva_modalita_input IS NULL THEN 'MANUALE'
        ELSE transazione_iva_modalita_input
    END as origine_calcolo,
    created_by,
    created_at
FROM mov_transazioni
WHERE transazione_aliquota_iva_fk IS NOT NULL
  AND transazione_imponibile_eur IS NOT NULL
  AND ABS(transazione_lordo_eur - (transazione_imponibile_eur + transazione_iva_eur)) BETWEEN 0.01 AND 0.05
ORDER BY created_at DESC;

-- Trova transazioni con correzioni manuali (diff arrotondamenti)
```

---

### 18.6 Audit Log Pagamenti

Tracciamento completo storia pagamenti per una fattura:

```sql
SELECT
    f.transazione_numero_documento as fattura,
    f.transazione_lordo_eur as importo_fattura,
    p.transazione_id as pagamento_id,
    ca_p.causale_descrizione as tipo_pagamento,  -- PG o IN
    p.transazione_data as data_pagamento,
    ABS(p.transazione_importo_eur) as importo_pagato,
    p.transazione_note as note,
    p.created_by as registrato_da,
    p.created_at as registrato_quando,
    -- Saldo progressivo pagamenti
    SUM(ABS(p.transazione_importo_eur)) OVER (
        PARTITION BY f.transazione_id
        ORDER BY p.transazione_data, p.created_at
    ) as saldo_progressivo
FROM mov_transazioni f
JOIN mov_transazioni p ON p.transazione_fattura_fk = f.transazione_id
JOIN ana_tipi_causali ca_p ON p.transazione_causale_tipo_id = ca_p.causale_id
WHERE f.transazione_id = ?  -- ID fattura da analizzare
ORDER BY p.transazione_data, p.created_at;
```

**Output esempio:**
```
fattura    | importo_fattura | pagamento_id | tipo_pagamento | data_pagamento | importo_pagato | saldo_progressivo
-----------|-----------------|--------------|----------------|----------------|----------------|------------------
FT-2026-10 | 1220.00        | 501          | PAGAMENTO      | 2026-02-12     | 400.00         | 400.00
FT-2026-10 | 1220.00        | 502          | PAGAMENTO      | 2026-02-20     | 600.00         | 1000.00
FT-2026-10 | 1220.00        | 503          | PAGAMENTO      | 2026-02-28     | 220.00         | 1220.00
```

---

## 🏆 Benefici del Sistema Implementato

### 19.1 Benefici Tecnici

1. **Manutenibilità:**
   - Modificare regole IVA = UPDATE su metadati, non modifica codice
   - Aggiungere nuova causale = semplice INSERT
   - Zero hardcoding di logica contabile nel codice C#

2. **Scalabilità:**
   - Multi-tenant ready (ogni azienda sue causali/aliquote)
   - Supporto regimi speciali IVA futuri (74-ter, reverse charge, split payment)
   - Indici ottimizzati per dataset > 1 milione transazioni

3. **Atomicità:**
   - Transazioni DB garantiscono consistenza stato pagamenti
   - Impossibile avere pagamenti senza fattura collegata
   - Impossibile avere stati inconsistenti (es. PAGATO senza data)

4. **Tracciabilità:**
   - Ogni pagamento è una transazione contabile completa (audit completo)
   - Campo `transazione_iva_modalita_input` traccia origine calcolo IVA
   - Audit trail completo (chi, quando, cosa)

5. **Database-First:**
   - Logica contabile nel database (PostgreSQL)
   - Consistenza garantita anche se accedi da strumenti esterni
   - Modifiche senza ricompilazione applicazione

---

### 19.2 Benefici Contabili

1. **Conformità Standard Italiani:**
   - Pagamenti come movimenti contabili separati (causale PG/IN)
   - Supporto aliquote IVA standard + speciali (FC, ES, NS, 74-ter)
   - Regole validazione conformi normativa (scorporo PASSIVO, somma ATTIVO)

2. **Export Ready:**
   - Struttura compatibile con software contabili (TeamSystem, Zucchetti, SAP)
   - Codici natura IVA per fatturazione elettronica (N1, N2.1, ecc.)
   - Partitari completi con saldo progressivo

3. **Cashflow Accurato:**
   - Scadenze obbligatorie per fatture (previsioni affidabili)
   - Scadenzario con urgenza (SCADUTO, URGENTE, IN_SCADENZA)
   - Residui calcolati real-time (non batch notturni)

4. **Partitari Completi:**
   - Tutti i movimenti (fatture + pagamenti) visibili insieme
   - Saldo progressivo per ogni controparte
   - Filtro ciclo ATTIVO/PASSIVO

5. **Riconciliazione Bancaria:**
   - Movimenti PG/IN tracciabili con estratti conto
   - Data pagamento effettivo registrata
   - Note libere per riferimenti (CRO, TRN, assegno, ecc.)

6. **Gestione IVA Completa:**
   - Scorporo automatico fatture passive (nessun calcolo manuale)
   - Calcolo automatico fatture attive (zero errori)
   - Correzioni manuali possibili (rispetto "carta vince software")
   - Registri IVA pronti (imponibile/IVA/lordo sempre separati)

---

### 19.3 Benefici UX (Esperienza Utente)

1. **Meno Errori:**
   - Auto-generazione scadenze (riduce dimenticanze)
   - Validazione real-time (errori bloccati prima di salvare)
   - Protezione sovrapagamenti (impossibile pagare troppo)
   - Calcolo IVA automatico (zero errori matematici)

2. **Velocità Operativa:**
   - Bottone "Paga Ora": da 5 click a 2 click
   - Dropdown filtrati automaticamente (solo fornitori per FT, solo clienti per FV)
   - Aliquota IVA preselezionata (22% default)
   - Scadenze auto-calcolate (+30gg)

3. **Chiarezza Interfaccia:**
   - Label dinamiche ("Cliente *" vs "Fornitore *" a seconda di causale)
   - Messaggi errore chiari ("La causale FATTURA PASSIVA richiede...")
   - Campi obbligatori evidenziati (asterisco rosso)
   - Calcoli IVA visibili real-time mentre digiti

4. **Flessibilità:**
   - Tutte le date modificabili manualmente
   - Tutti i campi IVA editabili (correzioni arrotondamenti)
   - Toggle modalità LORDO/NETTO (casi speciali)
   - Note libere su ogni transazione

5. **Feedback Informativo:**
   - Messaggi contestuali (es. "IVA non scorporata per valuta estera")
   - Riepilogo calcoli visibile prima di salvare
   - Stato fattura aggiornato immediatamente dopo pagamento
   - Residui visibili in partitari e scadenzario

---

### 19.4 ROI - Risparmio Tempo

**Scenario:** Agenzia viaggi con 80 fatture/mese (50 passive, 30 attive), 25% con pagamenti parziali.

#### PRIMA del sistema (gestione manuale):

```
Tempo mensile:
- Inserimento scadenze manuale: 80 × 30 sec = 40 min
- Errori scadenza (correzioni): 8 fatture × 3 min = 24 min
- Calcolo IVA manuale (scorporo): 50 × 45 sec = 38 min
- Calcolo IVA manuale (somma): 30 × 30 sec = 15 min
- Correzioni arrotondamenti IVA: 10 × 2 min = 20 min
- Gestione pagamenti parziali: 20 × 5 min = 100 min
- Ricerca fatture da pagare: 15 min
- Controllo saldi fornitori: 20 min

TOTALE: 272 min/mese = 4,5 ore/mese = 54 ore/anno
```

#### DOPO il sistema (gestione automatica):

```
Tempo mensile:
- Scadenze auto-generate: 0 min
- Errori scadenza: 0 min (validazione automatica)
- Calcolo IVA automatico: 0 min
- Correzioni arrotondamenti: 5 × 1 min = 5 min (solo casi rari)
- "Paga Ora" pagamenti parziali: 20 × 1 min = 20 min
- Scadenzario (ricerca istantanea): 2 min
- Partitari (saldi real-time): 5 min

TOTALE: 32 min/mese = 0,5 ore/mese = 6 ore/anno
```

**RISPARMIO: 48 ore/anno**

Valorizzazione:
- 48 ore × costo orario contabile (€ 25-35/h) = **€ 1.200 - 1.680/anno**
- ROI investimento sviluppo: 6-8 mesi

---

## 📊 Metriche di Qualità

### 20.1 Copertura Validazione

**Sistema Base:**
- ✅ 100% fatture con scadenza obbligatoria (metadata-driven)
- ✅ 100% stati PAGATO con data pagamento validata
- ✅ 0% pagamenti sovra-importo (protezione matematica)
- ✅ 100% pagamenti tracciabili (transazione_fattura_fk)

**Sistema IVA:**
- ✅ 100% fatture EUR con IVA calcolata automaticamente
- ✅ 100% transazioni valute estere con IVA azzerata (Fuori Campo)
- ✅ 0% errori arrotondamento > 0.01€ (tolleranza validata)
- ✅ 100% causali con metadata IVA configurati

---

### 20.2 Performance

**Trigger Database:**
- Validazione metadata: < 5ms per transazione
- Calcolo IVA: < 3ms per transazione
- Auto-generazione scadenza: < 1ms
- Calcolo pagamenti multipli: < 10ms (query su indice)
- Transazione atomica PagaOra: < 50ms (2 query + COMMIT)

**View Reportistica:**
- Partitario singolo fornitore: < 200ms (fino a 10.000 transazioni)
- Scadenzario (30 giorni): < 100ms
- Margini viaggi (anno fiscale): < 500ms
- Window function (saldo progressivo): O(n log n) - accettabile fino a 100k transazioni

**Raccomandazioni Performance:**
- < 100.000 transazioni/anno: performance ottimali senza ottimizzazioni
- 100.000 - 500.000 transazioni/anno: considerare materializzazione view partitari
- > 500.000 transazioni/anno: partition annuale su `transazione_data`

---

### 20.3 Affidabilità

**Atomicità Operazioni:**
- ✅ Pagamenti: COMMIT/ROLLBACK garantito (transazione DB)
- ✅ Calcoli IVA: consistenza matematica garantita (trigger)
- ✅ Stati: zero stati inconsistenti (trigger + constraint)

**Idempotenza:**
- ✅ Retry sicuro su errori di rete (ogni transazione ha ID univoco)
- ✅ Pagamenti non duplicabili (controllo residuo < importo)

**Data Integrity:**
- ✅ Constraint referenziali (ON DELETE RESTRICT - nessuna cancellazione accidentale)
- ✅ Check constraint matematici (IVA, date, stati)
- ✅ Trigger validazione pre-salvataggio (errori PRIMA del commit)

---

## 🔮 Roadmap Futura Unificata

### FASE 8 (Q2 2026) - Completamento UI IVA

**Obiettivo:** Completare interfacce mancanti sistema IVA

- [ ] Dashboard IVA in homepage:
  * Card "Debito IVA Stimato Trimestre"
  * Grafico IVA acquisti vs IVA vendite
  * Alert scadenze liquidazione periodica

- [ ] Pagina Registri IVA:
  * Registro IVA Acquisti (mensile/trimestrale)
  * Registro IVA Vendite (mensile/trimestrale)
  * Export Excel/PDF per commercialista

- [ ] Deprecazione componenti legacy:
  * `FornitoreSelect.razor` → sostituito da `ControparteSelect`
  * `AnaFornitori.razor` → route disabilitata
  * Cleanup codice obsoleto

---

### FASE 9 (Q3 2026) - Estensioni Fiscali

**Obiettivo:** Supporto regimi IVA speciali

1. **Regime 74-ter (Margine Agenzie Viaggi):**
   - Tabella `mov_regime_74ter` per contabilità separata
   - Calcolo IVA solo su margine (ricavo - costo servizio)
   - Report ministeriale margini

2. **Reverse Charge UE:**
   - Flag `transazione_reverse_charge` su causali
   - Auto-generazione doppia registrazione (acquisto + vendita)
   - Integrazione con VIES per validazione P.IVA UE

3. **Split Payment PA:**
   - Flag `transazione_split_payment`
   - IVA non incassata (versata direttamente da PA)
   - Export XML per tracciabilità

4. **Aliquote Storiche:**
   - Tabella `ana_aliquote_iva_storico` (aliquote cambiate nel tempo)
   - VIEW transazioni con aliquota vigente alla data

---

### FASE 10 (Q4 2026) - Workflow Avanzati

**Obiettivo:** Automazione processi contabili

1. **Workflow Approvazione Pagamenti:**
   - Stato `IN_APPROVAZIONE` per pagamenti > soglia
   - Tabella `approvazioni_pagamenti` con livelli (L1, L2, L3)
   - Notifiche email automatiche pre-scadenza
   - Dashboard approvatore con bulk actions

2. **Riconciliazione Bancaria Automatica:**
   - Import movimenti bancari (CSV, CBI, MT940)
   - Algoritmo matching automatico (importo + data ± 3gg)
   - Stato transazione `RICONCILIATO`
   - Report discrepanze (pagamenti non riconciliati)

3. **Alert Intelligenti:**
   - Email scadenze imminenti (7gg prima)
   - SMS per fatture scadute (overdue)
   - Dashboard "Azioni Richieste" (fatture da pagare oggi)
   - Previsione cashflow 30/60/90 giorni

4. **Batch Operations:**
   - Pagamento multiplo fatture stesso fornitore (unico bonifico)
   - Generazione SEPA XML per home banking
   - Stampa massiva scadenzario mese

---

### FASE 11 (Q1 2027) - Fatturazione Elettronica

**Obiettivo:** Integrazione completa con SDI (Sistema Di Interscambio)

1. **Generazione XML FatturaPA:**
   - Mapping transazioni → formato FatturaPA 1.2.2
   - Compilazione automatica da anagrafica controparti
   - Codici natura IVA (N1-N7) da aliquote
   - Validazione XSD prima invio

2. **Invio SDI:**
   - Integrazione web service SDI (trasmissione)
   - Firma digitale automatica (certificato digitale)
   - Tracciamento ID SDI (codice univoco fattura)

3. **Ricezione Notifiche SDI:**
   - Polling/webhook notifiche (RC, MC, NS, EC)
   - Aggiornamento stato fattura (accettata/rifiutata)
   - Alert errori formali (invio fallito)

4. **Conservazione Sostitutiva:**
   - Archiviazione XML firmati (10 anni legge)
   - Integration con provider conservazione (Aruba, Infocert)
   - Registro fatture elettroniche

5. **Fatture Passive (Ricezione):**
   - Import fatture XML ricevute (da SDI o PEC)
   - Parsing automatico → creazione transazione FT
   - Matching automatico ordini/DDT
   - Workflow approvazione contabile

---

### FASE 12 (Q2 2027) - Business Intelligence

**Obiettivo:** Reportistica avanzata e analytics predittivi

1. **Dashboard Direzionale:**
   - KPI real-time (margini, cashflow, DSO, DPO)
   - Grafici interattivi (Chart.js, ApexCharts)
   - Drill-down da overview a dettaglio transazione

2. **Analisi Margini:**
   - Margini per viaggio (già implementato)
   - Margini per cliente (profittabilità cliente)
   - Margini per fornitore (costo medio servizio)
   - Trend storici margini (QoQ, YoY)

3. **Previsioni Machine Learning:**
   - Forecasting cashflow (ARIMA, Prophet)
   - Predizione ritardi pagamento (classification ML)
   - Anomaly detection (pagamenti anomali, frodi)

4. **Export Business Intelligence:**
   - Connettori Power BI / Tableau
   - API REST per integrazione sistemi esterni
   - Webhook eventi (fattura scaduta, pagamento ricevuto)

---

## 📞 Supporto e Documentazione

### 22.1 File Chiave Implementazione

**Database - Sistema Base:**
- `SqlScripts/Create_AnaControparti.sql` - Tabella controparti
- `SqlScripts/Migration_Ana_Tipi_Causali_AddColumns.sql` - Metadata causali
- `SqlScripts/Migration_Create_Validation_Trigger.sql` - Trigger validazione
- `SqlScripts/Migration_Fix_Pagamento_Constraint.sql` - Correzione constraint pagamenti

**Database - Sistema IVA:**
- `SqlScripts/Create_AnaAliquoteIva.sql` - Tabella aliquote IVA
- `SqlScripts/Create_AnaAliquoteIva_CRUD.sql` - Stored functions CRUD aliquote
- `SqlScripts/Migration_Add_IVA_Columns.sql` - Colonne IVA su transazioni
- `SqlScripts/Migration_Add_IVA_Metadata_Causali.sql` - Metadata IVA causali
- `SqlScripts/Migration_Create_IVA_Trigger.sql` - Trigger calcolo IVA
- `SqlScripts/Migration_Update_Views_IVA.sql` - Aggiornamento view con colonne IVA

**Backend C# - Modelli:**
- `Models/AnaControparte.cs` - Modello controparti (fornitori + clienti)
- `Models/AnaAliquotaIva.cs` - Modello aliquote IVA
- `Models/MovTransazioni.cs` - Modello transazioni (esteso con IVA)
- `Models/AnaTipoCausale.cs` - Modello causali (metadati IVA)

**Backend C# - Servizi:**
- `Services/CRUD/ContropartiService.cs` - CRUD controparti (filtraggio ciclo)
- `Services/CRUD/AnaAliquoteIvaService.cs` - CRUD aliquote IVA (DB-first)
- `Services/CRUD/MovTransazioniService.cs` - CRUD transazioni + PagaOraAsync()
- `Services/CRUD/AnaTipiCausaliService.cs` - CRUD causali

**Frontend Blazor - Componenti:**
- `Components/Pages/Tabelle/AnaControparti.razor` - Anagrafica controparti
- `Components/Pages/Tabelle/AnaAliquoteIvaPage.razor` - Gestione aliquote IVA
- `Components/Pages/MovTransazioniPage.razor` - Lista movimenti + Paga Ora
- `Components/Pages/MovTransazioniEditDialog.razor` - Form transazioni con IVA
- `Components/Shared/ControparteSelect.razor` - Dropdown controparti filtrata
- `Components/Shared/AliquotaIvaSelect.razor` - Dropdown aliquote IVA
- `Components/Shared/PagaOraDialog.razor` - Dialog pagamento rapido

**Documentazione:**
- `Documents/Implementazione_Contabile.md` - Questo documento
- `Documents/Funzioni_DB.md` - Documentazione stored functions PostgreSQL
- `Documents/DataBaseLocale.md` - Schema database completo
- `BUGFIX-SUMMARY.txt` - Change log bugfix e modifiche

---

### 22.2 Link Utili

**Repository Progetto:**
- GitHub: [https://github.com/tuouser/gestione-viaggi](URL da aggiornare)
- Issue Tracker: [https://github.com/tuouser/gestione-viaggi/issues](URL da aggiornare)

**Normativa Fiscale:**
- Agenzia Entrate - IVA: [https://www.agenziaentrate.gov.it/portale/web/guest/iva](https://www.agenziaentrate.gov.it/portale/web/guest/iva)
- DPR 633/72 (Decreto IVA): [https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.del.presidente.della.repubblica:1972-10-26;633](https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.del.presidente.della.repubblica:1972-10-26;633)
- Art. 74-ter (Regime Margine Agenzie): Testo coordinato DPR 633/72

**Fatturazione Elettronica:**
- Specifiche Tecniche FatturaPA: [https://www.fatturapa.gov.it/export/documenti/fatturapa/v1.2.2/Specifiche_tecniche_FatturaPA_v1.2.2.pdf](https://www.fatturapa.gov.it/export/documenti/fatturapa/v1.2.2/Specifiche_tecniche_FatturaPA_v1.2.2.pdf)
- SDI (Sistema Di Interscambio): [https://www.fatturapa.gov.it](https://www.fatturapa.gov.it)

**PostgreSQL:**
- Trigger Documentation: [https://www.postgresql.org/docs/current/triggers.html](https://www.postgresql.org/docs/current/triggers.html)
- Window Functions: [https://www.postgresql.org/docs/current/tutorial-window.html](https://www.postgresql.org/docs/current/tutorial-window.html)

---

### 22.3 Versioning e Changelog

**Tabella Versioni:**

| Versione | Data | Modifiche Principali | Stato |
|----------|------|----------------------|-------|
| **1.0** | 12/02/2026 | Sistema base contabile (cicli ATTIVO/PASSIVO) | ✅ COMPLETATO |
| | | - Refactoring ana_fornitori → ana_controparti | |
| | | - Causali con metadata ciclo | |
| | | - Sistema pagamenti con transazioni PG/IN | |
| | | - View partitari e margini | |
| **1.1** | 12/02/2026 | Sistema metadata-driven + "Paga Ora" | ✅ COMPLETATO |
| | | - Metadati causali (scadenze, auto-generazione) | |
| | | - Trigger validazione dinamica | |
| | | - Metodo PagaOraAsync() con pagamenti multipli | |
| | | - Dialog PagaOraDialog.razor | |
| **1.2** | 13/02/2026 | Allineamento VIEW con transazione_fattura_fk | ✅ COMPLETATO |
| | | - Aggiornamento vw_partitario_* con calcolo residui | |
| | | - ControparteSelect.razor con filtraggio automatico | |
| | | - Correzioni nomi tabelle/colonne | |
| **1.3** | 13/02/2026 | Cleanup database e code | ✅ COMPLETATO |
| | | - Eliminata tabella mov_pagamenti (non utilizzata) | |
| | | - Eliminato AnaFornitoriService.cs (obsoleto) | |
| | | - Rimossa registrazione servizi legacy | |
| | | - Fix constraint pagamenti (rimosso chk_pagamento_dopo_scadenza) | |
| **2.0** | **15/02/2026** | **INTEGRAZIONE IVA COMPLETA** | **✅ COMPLETATO** |
| | | **Database:** | |
| | | - Tabella ana_aliquote_iva con stored functions CRUD | ✅ |
| | | - Colonne IVA su mov_transazioni (imponibile, IVA, lordo, modalità) | ✅ |
| | | - Metadata IVA su ana_tipi_causali (genera_iva, richiede_iva) | ✅ |
| | | - Trigger fn_calcola_iva_transazione() (scorporo/calcolo automatico) | ✅ |
| | | - Aggiornamento view con colonne IVA (partitari, margini, scadenzario) | ✅ |
| | | **Backend:** | |
| | | - Model AnaAliquotaIva.cs | ✅ |
| | | - Service AnaAliquoteIvaService.cs (DB-first, zero SQL diretto) | ✅ |
| | | - Estensione MovTransazioni.cs con proprietà IVA | ✅ |
| | | **Frontend:** | |
| | | - Pagina AnaAliquoteIvaPage.razor (gestione aliquote) | ✅ |
| | | - Componente AliquotaIvaSelect.razor | ✅ |
| | | - Sezione IVA in MovTransazioniEditDialog.razor | ✅ |
| | | - Calcolo reattivo IVA (scorporo/somma automatici) | ✅ |
| | | - Toggle modalità LORDO/NETTO | ✅ |
| | | - Correzioni manuali con tolleranza 0.01€ | ✅ |
| | | **Documentazione:** | |
| | | - Documento unificato Implementazione_Contabile.md (questo file) | ✅ |
| | | - Sezione "Come Funziona" per utenti contabili | ✅ |
| | | - Esempi pratici uso quotidiano | ✅ |
| | | - Glossario termini IVA | ✅ |

**Prossime Release (Roadmap):**
- v2.1 (Q2 2026): Dashboard IVA + Registri IVA
- v2.5 (Q3 2026): Regime 74-ter + Reverse Charge + Split Payment
- v3.0 (Q1 2027): Fatturazione Elettronica completa (SDI)

---

**FINE DOCUMENTO**

**Versione:** 2.0 - Sistema Completo con Gestione IVA
**Data Pubblicazione:** 15 Febbraio 2026
**Autore:** Adriano Visconti
**Progetto:** Gestione Viaggi Offroad - Sistema Contabile Integrato

---

**Nota per i Lettori:**

Questo documento descrive il funzionamento del sistema contabile nella sua versione attuale (2.0). Per aggiornamenti futuri, consultare il changelog nella sezione 22.3 e la roadmap nella sezione 21.

Per segnalazioni, domande o richieste di chiarimenti, contattare il team di sviluppo tramite il repository GitHub o creare una issue nell'issue tracker.

