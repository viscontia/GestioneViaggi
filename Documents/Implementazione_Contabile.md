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

### 11.1 Trigger: Validazione Metad (segue nella prossima parte...)

---

**NOTA DOCUMENTO:** Il documento completo è troppo lungo per una singola risposta. Proseguo nella parte successiva con:
- Sezione 11: Trigger Automatici (base + IVA)
- PARTE IV: Modifiche Applicative
- PARTE V: Testing e Deployment
- PARTE VI: Riferimenti e Governance

