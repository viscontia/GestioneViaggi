# 📊 Implementazione Sistema Contabile - Gestione Viaggi Offroad

**Progetto**: Gestione Viaggi Offroad
**Database**: PostgreSQL 17.5
**Data Creazione**: 12/02/2026
**Versione**: 1.0

---

## 🎯 Obiettivi del Refactoring

### Problema Iniziale
Il sistema attuale gestisce solo il **ciclo passivo** (fornitori), con una semantica del segno orientata esclusivamente ai debiti:
- `causale_segno = +1` → aumenta il debito verso fornitore
- `causale_segno = -1` → diminuisce il debito

Questa impostazione rende impossibile gestire il **ciclo attivo** (clienti) e calcolare correttamente il margine dei viaggi.

### Soluzione Implementata
1. **Refactoring `ana_fornitori` → `ana_controparti`**
   - Supporto sia fornitori che clienti nella stessa tabella
   - Flag `is_fornitore` e `is_cliente` (possono essere entrambi TRUE)

2. **Aggiunta colonna `causale_ciclo`**
   - `ATTIVO`: ciclo clienti (fatture emesse, incassi)
   - `PASSIVO`: ciclo fornitori (fatture ricevute, pagamenti)

3. **Tabella `mov_pagamenti`**
   - Tracciabilità completa dei pagamenti parziali
   - Calcolo automatico del residuo da pagare/incassare

4. **View di reportistica**
   - Partitari fornitori/clienti con saldo progressivo
   - Margini viaggi (ricavi - costi)
   - Scadenzario pagamenti/incassi

---

## 📋 Roadmap di Implementazione

### FASE 1: Schema Database
- [x] Creare tabella `ana_controparti`
- [x] Migrare dati da `ana_fornitori` a `ana_controparti`
- [x] Aggiungere colonna `causale_ciclo` a `ana_tipi_causali`
- [x] Creare causali per ciclo ATTIVO (FV, IN, NCA, NDA)
- [x] Creare tabella `mov_pagamenti`
- [x] Rinominare `transazione_fornitore_id` → `transazione_controparte_id`

### FASE 2: View e Logica di Business
- [x] View `vw_partitario_fornitori`
- [x] View `vw_partitario_clienti`
- [x] View `vw_margini_viaggi`
- [x] View `vw_scadenzario`
- [x] Trigger aggiornamento automatico `transazione_stato`

### FASE 3: Codice C# Backend
- [ ] Refactoring modelli DTO
- [ ] Adattamento servizi CRUD
- [ ] Aggiornamento validazioni
- [ ] Unit test

### FASE 4: UI Frontend (Blazor)
- [ ] Rinominare menu "Fornitori" → "Controparti"
- [ ] Dropdown con filtro `is_fornitore` / `is_cliente`
- [ ] Form gestione causali con `causale_ciclo`
- [ ] Nuove pagine per partitari clienti
- [ ] Dashboard margini viaggi

---

## 🗂️ Struttura Database - Dettaglio

### Tabella: `ana_controparti`

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
    comune_fk INTEGER REFERENCES ana_comuni(comune_id),
    telefono_prefisso VARCHAR(5),
    telefono_numero VARCHAR(20),
    email VARCHAR(100),
    pec VARCHAR(100),
    sito_web VARCHAR(100),

    -- Classificazione
    tipo_fornitore_fk INTEGER REFERENCES ana_tipi_fornitore(tipo_fornitore_id),
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

### Tabella: `ana_tipi_causali` (modificata)

```sql
-- Aggiunta colonna causale_ciclo
ALTER TABLE public.ana_tipi_causali
ADD COLUMN causale_ciclo VARCHAR(10) NOT NULL DEFAULT 'PASSIVO'
CHECK (causale_ciclo IN ('ATTIVO', 'PASSIVO'));

-- Indice per filtraggio
CREATE INDEX idx_causali_ciclo ON ana_tipi_causali(causale_ciclo);
```

**Causali Ciclo PASSIVO** (esistenti):
| Codice | Descrizione | Segno | Documento |
|--------|-------------|-------|-----------|
| FT | Fattura Passiva | +1 | Sì |
| NC | Nota di Credito | -1 | Sì |
| PG | Pagamento/Acconto | -1 | No |
| ND | Nota di Debito/Penale | +1 | Sì |
| AB | Abbuoni e Arrotondamenti | -1 | Sì |
| SA | Saldo Apertura Negativo | -1 | Sì |
| SM | Saldo Apertura Positivo | +1 | Sì |
| CO | Compensazione | -1 | Sì |

**Causali Ciclo ATTIVO** (nuove):
| Codice | Descrizione | Segno | Documento |
|--------|-------------|-------|-----------|
| FV | Fattura Attiva/Vendita | +1 | Sì |
| IN | Incasso/Acconto Cliente | -1 | No |
| NCA | Nota di Credito Emessa | -1 | Sì |
| NDA | Nota di Debito Emessa | +1 | Sì |

### Tabella: `mov_pagamenti` (nuova)

```sql
CREATE TABLE public.mov_pagamenti (
    pagamento_id SERIAL PRIMARY KEY,
    transazione_fk INTEGER NOT NULL REFERENCES mov_transazioni(transazione_id) ON DELETE CASCADE,

    -- Dati pagamento
    pagamento_data DATE NOT NULL,
    pagamento_importo_eur NUMERIC(10,2) NOT NULL CHECK (pagamento_importo_eur > 0),
    pagamento_metodo VARCHAR(50), -- Bonifico, Assegno, Contanti, RiBa, ecc.
    pagamento_note TEXT,

    -- Riferimenti bancari (opzionali)
    pagamento_conto_bancario_fk INTEGER, -- FK verso eventuale tabella conti bancari
    pagamento_riferimento VARCHAR(100), -- Numero assegno, CRO, TRN, ecc.

    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(50),
    updated_at TIMESTAMPTZ,
    updated_by VARCHAR(50)
);

-- Indici
CREATE INDEX idx_pagamenti_transazione ON mov_pagamenti(transazione_fk);
CREATE INDEX idx_pagamenti_data ON mov_pagamenti(pagamento_data);
```

### Tabella: `mov_transazioni` (modificata)

```sql
-- Rinominare colonna fornitore → controparte
ALTER TABLE public.mov_transazioni
RENAME COLUMN transazione_fornitore_id TO transazione_controparte_id;

-- Rinominare constraint FK
ALTER TABLE public.mov_transazioni
DROP CONSTRAINT fk_transazioni_fornitore;

ALTER TABLE public.mov_transazioni
ADD CONSTRAINT fk_transazioni_controparte
FOREIGN KEY (transazione_controparte_id) REFERENCES ana_controparti(controparte_id);
```

---

## 📊 View di Reportistica

### 1. View: `vw_partitario_fornitori`

Estratto conto fornitori con saldo progressivo.

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
    t.transazione_importo_eur,
    ca.causale_segno,

    -- Movimento contabile (dare/avere)
    (t.transazione_importo_eur * ca.causale_segno) as dare_avere,

    -- Saldo progressivo con window function
    SUM(t.transazione_importo_eur * ca.causale_segno)
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
        THEN (t.transazione_importo_eur * ca.causale_segno) - COALESCE(
            (SELECT SUM(p.pagamento_importo_eur)
             FROM mov_pagamenti p
             WHERE p.transazione_fk = t.transazione_id), 0
        )
        ELSE 0
    END as residuo,

    -- Metadati
    t.transazione_viaggio_id,
    t.transazione_note

FROM ana_controparti c
JOIN mov_transazioni t ON c.controparte_id = t.transazione_controparte_id
JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
WHERE ca.causale_ciclo = 'PASSIVO'
  AND t.transazione_stato <> 'ANNULLATO'
  AND c.is_fornitore = TRUE
ORDER BY c.ragione_sociale, t.transazione_data, t.transazione_id;
```

### 2. View: `vw_partitario_clienti`

Estratto conto clienti con saldo progressivo.

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
    t.transazione_importo_eur,
    ca.causale_segno,

    -- Movimento contabile (dare/avere)
    (t.transazione_importo_eur * ca.causale_segno) as dare_avere,

    -- Saldo progressivo
    SUM(t.transazione_importo_eur * ca.causale_segno)
        OVER (
            PARTITION BY c.controparte_id
            ORDER BY t.transazione_data, t.transazione_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) as saldo_progressivo,

    -- Stato
    t.transazione_stato,
    t.transazione_data_scadenza,

    -- Residuo
    CASE
        WHEN t.transazione_stato IN ('DA_PAGARE', 'PARZIALMENTE_PAGATO')
        THEN (t.transazione_importo_eur * ca.causale_segno) - COALESCE(
            (SELECT SUM(p.pagamento_importo_eur)
             FROM mov_pagamenti p
             WHERE p.transazione_fk = t.transazione_id), 0
        )
        ELSE 0
    END as residuo,

    -- Metadati
    t.transazione_viaggio_id,
    t.transazione_note

FROM ana_controparti c
JOIN mov_transazioni t ON c.controparte_id = t.transazione_controparte_id
JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
WHERE ca.causale_ciclo = 'ATTIVO'
  AND t.transazione_stato <> 'ANNULLATO'
  AND c.is_cliente = TRUE
ORDER BY c.ragione_sociale, t.transazione_data, t.transazione_id;
```

### 3. View: `vw_margini_viaggi`

Calcolo margine per ogni viaggio (ricavi - costi).

```sql
CREATE OR REPLACE VIEW public.vw_margini_viaggi AS
SELECT
    v.viaggio_id,
    v.viaggio_nome,
    v.viaggio_anno,
    t.transazione_viaggio_id,

    -- Ricavi (ciclo ATTIVO)
    SUM(CASE
        WHEN ca.causale_ciclo = 'ATTIVO'
        THEN t.transazione_importo_eur * ca.causale_segno
        ELSE 0
    END) as ricavi_totali_eur,

    -- Costi (ciclo PASSIVO, invertito di segno)
    SUM(CASE
        WHEN ca.causale_ciclo = 'PASSIVO'
        THEN ABS(t.transazione_importo_eur * ca.causale_segno)
        ELSE 0
    END) as costi_totali_eur,

    -- Margine (ricavi - costi)
    SUM(CASE
        WHEN ca.causale_ciclo = 'ATTIVO'
        THEN t.transazione_importo_eur * ca.causale_segno
        WHEN ca.causale_ciclo = 'PASSIVO'
        THEN (t.transazione_importo_eur * ca.causale_segno) * -1
        ELSE 0
    END) as margine_eur,

    -- Margine percentuale
    CASE
        WHEN SUM(CASE WHEN ca.causale_ciclo = 'ATTIVO' THEN t.transazione_importo_eur * ca.causale_segno ELSE 0 END) > 0
        THEN (
            SUM(CASE
                WHEN ca.causale_ciclo = 'ATTIVO' THEN t.transazione_importo_eur * ca.causale_segno
                WHEN ca.causale_ciclo = 'PASSIVO' THEN (t.transazione_importo_eur * ca.causale_segno) * -1
                ELSE 0
            END) /
            SUM(CASE WHEN ca.causale_ciclo = 'ATTIVO' THEN t.transazione_importo_eur * ca.causale_segno ELSE 0 END)
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

### 4. View: `vw_scadenzario`

Riepilogo scadenze pagamenti/incassi con priorità.

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
    t.transazione_importo_eur * ca.causale_segno as importo,

    -- Residuo da pagare/incassare
    (t.transazione_importo_eur * ca.causale_segno) - COALESCE(
        (SELECT SUM(p.pagamento_importo_eur)
         FROM mov_pagamenti p
         WHERE p.transazione_fk = t.transazione_id), 0
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

    t.transazione_stato,
    t.transazione_viaggio_id,
    t.transazione_note

FROM mov_transazioni t
JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
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

---

## 🔧 Trigger Automatici

### Trigger: Aggiornamento Automatico `transazione_stato`

Quando viene inserito/modificato un pagamento, il trigger aggiorna automaticamente lo stato della transazione.

```sql
CREATE OR REPLACE FUNCTION fn_aggiorna_stato_transazione()
RETURNS TRIGGER AS $$
DECLARE
    v_transazione_id INTEGER;
    v_totale_documento NUMERIC(10,2);
    v_totale_pagato NUMERIC(10,2);
    v_causale_segno INTEGER;
BEGIN
    -- Determina l'ID della transazione (gestisce INSERT, UPDATE, DELETE)
    IF TG_OP = 'DELETE' THEN
        v_transazione_id := OLD.transazione_fk;
    ELSE
        v_transazione_id := NEW.transazione_fk;
    END IF;

    -- Recupera totale documento e causale_segno
    SELECT
        t.transazione_importo_eur,
        ca.causale_segno
    INTO v_totale_documento, v_causale_segno
    FROM mov_transazioni t
    JOIN ana_tipi_causali ca ON t.transazione_causale_tipo_id = ca.causale_id
    WHERE t.transazione_id = v_transazione_id;

    -- Calcola totale pagato
    SELECT COALESCE(SUM(pagamento_importo_eur), 0)
    INTO v_totale_pagato
    FROM mov_pagamenti
    WHERE transazione_fk = v_transazione_id;

    -- Aggiorna stato in base a totale pagato
    UPDATE mov_transazioni
    SET transazione_stato = CASE
        WHEN v_totale_pagato = 0 THEN 'DA_PAGARE'
        WHEN v_totale_pagato >= ABS(v_totale_documento * v_causale_segno) THEN 'PAGATO'
        ELSE 'PARZIALMENTE_PAGATO'
    END,
    transazione_data_pagamento = CASE
        WHEN v_totale_pagato >= ABS(v_totale_documento * v_causale_segno)
        THEN (SELECT MAX(pagamento_data) FROM mov_pagamenti WHERE transazione_fk = v_transazione_id)
        ELSE NULL
    END
    WHERE transazione_id = v_transazione_id;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_aggiorna_stato_dopo_pagamento
AFTER INSERT OR UPDATE OR DELETE ON mov_pagamenti
FOR EACH ROW
EXECUTE FUNCTION fn_aggiorna_stato_transazione();
```

---

## 🎨 Modifiche UI (Blazor)

### Rinominare Menu NavBar

**Prima**:
- Fornitori
- Movimenti Contabili

**Dopo**:
- **Controparti** (include fornitori e clienti)
- Movimenti Contabili
- **Partitari** (nuovo menu)
  - Partitario Fornitori
  - Partitario Clienti
- **Margini Viaggi** (nuovo)
- **Scadenzario** (nuovo)

### Form Controparti

Aggiungere checkbox:
```razor
<div class="form-check">
    <input class="form-check-input" type="checkbox" id="isFornitore" @bind="model.IsFornitore">
    <label class="form-check-label" for="isFornitore">
        È un Fornitore
    </label>
</div>

<div class="form-check">
    <input class="form-check-input" type="checkbox" id="isCliente" @bind="model.IsCliente">
    <label class="form-check-label" for="isCliente">
        È un Cliente
    </label>
</div>
```

### Dropdown Controparte in Form Movimenti

Filtraggio dinamico in base al `causale_ciclo`:

```csharp
private async Task OnCausaleChanged(int causaleId)
{
    var causale = await CausaliService.GetByIdAsync(causaleId);

    if (causale.CausaleCiclo == "PASSIVO")
    {
        // Carica solo fornitori
        controparti = await ContropartiService.GetFornitoriAsync();
    }
    else if (causale.CausaleCiclo == "ATTIVO")
    {
        // Carica solo clienti
        controparti = await ContropartiService.GetClientiAsync();
    }
}
```

---

## 🧪 Test di Validazione

### Test 1: Migrazione Dati

```sql
-- Verifica che tutti i fornitori siano stati migrati
SELECT COUNT(*) as totale_fornitori_originali FROM ana_fornitori;
SELECT COUNT(*) as totale_controparti_fornitori FROM ana_controparti WHERE is_fornitore = TRUE;

-- Verifica integrità referenziale
SELECT COUNT(*) as transazioni_orfane
FROM mov_transazioni t
LEFT JOIN ana_controparti c ON t.transazione_controparte_id = c.controparte_id
WHERE c.controparte_id IS NULL;
```

### Test 2: Calcolo Margine Viaggio

```sql
-- Inserisci transazioni di test per un viaggio
INSERT INTO mov_transazioni (
    transazione_azienda_id,
    transazione_viaggio_id,
    transazione_controparte_id,
    transazione_tipo_movimento,
    transazione_importo,
    transazione_valuta_id,
    transazione_data,
    transazione_stato,
    transazione_causale,
    transazione_causale_tipo_id,
    created_by
) VALUES
-- Fattura attiva (ricavo)
(6, 862, 1, 'ENTRATA', 5000.00, 1, CURRENT_DATE, 'DA_PAGARE', 'Vendita pacchetto viaggio',
 (SELECT causale_id FROM ana_tipi_causali WHERE causale_codice = 'FV' LIMIT 1), 'test'),
-- Fattura passiva (costo)
(6, 862, 2, 'USCITA', 2000.00, 1, CURRENT_DATE, 'DA_PAGARE', 'Hotel',
 (SELECT causale_id FROM ana_tipi_causali WHERE causale_codice = 'FT' LIMIT 1), 'test');

-- Verifica margine
SELECT * FROM vw_margini_viaggi WHERE viaggio_id = 862;
-- Atteso: ricavi_totali_eur = 5000, costi_totali_eur = 2000, margine_eur = 3000
```

### Test 3: Pagamento Parziale

```sql
-- Inserisci pagamento parziale
INSERT INTO mov_pagamenti (transazione_fk, pagamento_data, pagamento_importo_eur, pagamento_metodo, created_by)
VALUES (35, CURRENT_DATE, 500.00, 'Bonifico', 'test');

-- Verifica aggiornamento automatico stato
SELECT transazione_id, transazione_stato, transazione_importo_eur
FROM mov_transazioni
WHERE transazione_id = 35;
-- Atteso: transazione_stato = 'PARZIALMENTE_PAGATO'

-- Verifica residuo
SELECT * FROM vw_partitario_fornitori WHERE transazione_id = 35;
-- Atteso: residuo = 350.00 (se importo originale era 850.00)
```

---

## 📚 Glossario Contabile

| Termine | Significato | Esempio |
|---------|-------------|---------|
| **Ciclo Attivo** | Transazioni con clienti (fatture emesse, incassi) | Fattura viaggio emessa |
| **Ciclo Passivo** | Transazioni con fornitori (fatture ricevute, pagamenti) | Fattura hotel ricevuta |
| **Dare/Avere** | Movimento contabile con segno algebrico | +850€ (dare), -500€ (avere) |
| **Saldo Progressivo** | Somma algebrica cumulativa dei movimenti | 1000 + 500 - 200 = 1300€ |
| **Residuo** | Importo ancora da pagare/incassare | Fattura 1000€ - Pagato 300€ = Residuo 700€ |
| **Margine** | Differenza tra ricavi e costi | Ricavi 5000€ - Costi 2000€ = Margine 3000€ |
| **Partitario** | Estratto conto dettagliato di una controparte | Tutti i movimenti con fornitore X |

---

## 🚨 Note Importanti

### Sicurezza
- Tutte le operazioni richiedono autenticazione
- Ogni utente vede solo i dati della propria azienda (`azienda_fk`)
- Audit trail completo (created_by, updated_by)

### Performance
- Indici ottimizzati per query partitari
- Window function performante su dataset medio (< 100k transazioni/fornitore)
- Valutare materializzazione view per dataset molto grandi

### Backup
- **CRITICO**: Eseguire backup completo PRIMA della migrazione
- Testare su ambiente di sviluppo prima di produzione
- Script di rollback disponibili

---

## 📞 Supporto

Per domande o problemi durante l'implementazione:
- Repository: [GitHub repo link]
- Documentazione DB: [Documents/DataBaseLocale.md](DataBaseLocale.md)
- Change log: [BUGFIX-SUMMARY.txt](../BUGFIX-SUMMARY.txt)

---

**Fine Documento**
