# Promemoria all'apertura (L2) — Piano di implementazione

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** all'avvio del gestionale una finestra con la tabella delle cose in sospeso, ognuna con
«Apri» verso la scheda che la risolve; la soglia della newsletter è un parametro dell'azienda.

**Architecture:** il database decide tutto in `fn_promemoria_apertura(azienda)` (script 671): una
riga per caso, già ordinabile per urgenza. Il gestionale la disegna in `PromemoriaDialog` e apre le
schede che esistono già (`AnaViaggiDialog`, `ClienteDialog`, `ViaggioPartecipantiManagerDialog`,
pagina Newsletter). Il parametro vive in `web_aziende_funzioni` (funzione `promemoria`, JSONB
`parametri`), come le recensioni.

**Tech Stack:** PostgreSQL (PL/pgSQL, Docker locale `postgres_db`), .NET MAUI Blazor Hybrid,
MudBlazor, Npgsql.

**Disegno:** `2026-09-27-promemoria-apertura-design.md` (stessa cartella). Leggerlo prima.

---

## Regole del progetto da rispettare (non negoziabili)

- ⛔️ SQL solo in `SqlScripts/NNN_*.sql`, applicato con `./deploy_sql.sh SqlScripts/NNN_….sql`
  (dalla radice di `MAUI/GestioneViaggi`). Il test in `SqlScripts/Test_NNN_….sql`, in una
  transazione annullata (`BEGIN … ROLLBACK`), lanciato con
  `docker exec -i postgres_db psql -U postgres -d gestione_viaggi -v ON_ERROR_STOP=1 < SqlScripts/Test_NNN_….sql`.
- Funzioni nuove: `SET search_path = public, pg_temp`, nessun GRANT (nascono chiuse, script 659).
- Il C# **non ricalcola** regole: legge le righe e le disegna.
- ⛔️ Il DB locale ha i **dati veri** dell'azienda 2 (email vere). Nessun test manda mail.
- Colonne azienda: `ana_clienti.azienda_fk`, quasi tutte le altre `azienda_id`.
- Commenti e messaggi in italiano, stile dei file vicini. Commit piccoli, messaggi in italiano con
  la riga `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Build Mac: `dotnet build -f net9.0-maccatalyst` (Debug → DB locale). Avvio: `./run_maui.sh`.

---

### Task 1: Script 671 — parametro e funzione del promemoria

**Files:**
- Create: `SqlScripts/671_Promemoria_Apertura.sql`
- Test: `SqlScripts/Test_671_Promemoria_Apertura.sql`

**Step 1: scrivere il test (deve fallire: la funzione non esiste)**

```sql
-- ============================================================================
-- Test dello script 671. Transazione annullata: costruisce un caso per voce sui
-- dati esistenti, verifica che compaia e che sparisca risolto.
-- ============================================================================
BEGIN;
DO $$
DECLARE
    v_az   integer := 2;
    d      RECORD;
    v_n    integer;
    v_cont bigint;
BEGIN
    -- 0. parametro: senza riga vale 90
    DELETE FROM web_aziende_funzioni WHERE azienda_id = v_az AND funzione = 'promemoria';
    ASSERT fn_promemoria_giorni_newsletter(v_az) = 90, '0: default 90';
    INSERT INTO web_aziende_funzioni (azienda_id, funzione, attiva, parametri)
    VALUES (v_az, 'promemoria', true, '{"giorni_newsletter": 3650}');
    ASSERT fn_promemoria_giorni_newsletter(v_az) = 3650, '0: parametro letto';

    -- 1. partenza passata non effettuata
    SELECT * INTO d FROM ana_date_viaggi WHERE azienda_id = v_az AND data_viaggio_data_fine < current_date LIMIT 1;
    UPDATE ana_date_viaggi SET data_viaggio_effettuato_sino = 'N' WHERE data_viaggio_id = d.data_viaggio_id;
    ASSERT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'PARTENZA_NON_EFFETTUATA' AND data_viaggio_id = d.data_viaggio_id), '1: manca';
    UPDATE ana_date_viaggi SET data_viaggio_effettuato_sino = 'Y' WHERE data_viaggio_id = d.data_viaggio_id;
    ASSERT NOT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'PARTENZA_NON_EFFETTUATA' AND data_viaggio_id = d.data_viaggio_id), '1: non sparisce';

    -- 2. scheda in bozza / pubblicata, e senza foto
    SELECT c.web_tour_contenuti_id, c.data_viaggio_id_fk INTO v_cont, v_n
      FROM web_tour_contenuti c JOIN ana_date_viaggi dv ON dv.data_viaggio_id = c.data_viaggio_id_fk
     WHERE c.azienda_id = v_az AND dv.data_viaggio_data_inizio >= current_date LIMIT 1;
    UPDATE web_tour_contenuti SET stato_pubblicazione = 'bozza' WHERE web_tour_contenuti_id = v_cont;
    ASSERT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'SCHEDA_IN_BOZZA' AND data_viaggio_id = v_n), '2: bozza manca';
    UPDATE web_tour_contenuti SET stato_pubblicazione = 'pubblicato' WHERE web_tour_contenuti_id = v_cont;
    ASSERT NOT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'SCHEDA_IN_BOZZA' AND data_viaggio_id = v_n), '2: bozza non sparisce';
    DELETE FROM web_tour_immagini WHERE web_tour_contenuti_id_fk = v_cont;
    ASSERT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'SCHEDA_SENZA_FOTO' AND data_viaggio_id = v_n), '2: senza foto manca';

    -- 3. partenza futura senza scheda
    SELECT dv.* INTO d FROM ana_date_viaggi dv
     WHERE dv.azienda_id = v_az AND dv.data_viaggio_data_inizio >= current_date
       AND NOT EXISTS (SELECT 1 FROM web_tour_contenuti c WHERE c.data_viaggio_id_fk = dv.data_viaggio_id) LIMIT 1;
    IF FOUND THEN
        ASSERT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'SENZA_SCHEDA_WEB' AND data_viaggio_id = d.data_viaggio_id), '3: manca';
    END IF;

    -- 4. capienza: una riga per viaggio
    SELECT * INTO d FROM ana_date_viaggi WHERE azienda_id = v_az AND data_viaggio_data_inizio >= current_date LIMIT 1;
    UPDATE ana_viaggi SET viaggio_capienza_max = 20, viaggio_capienza_alert = 5 WHERE viaggio_id = d.viaggio_id_fk;
    ASSERT NOT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'SENZA_CAPIENZA' AND viaggio_id = d.viaggio_id_fk), '4: con capienza non deve comparire';
    UPDATE ana_viaggi SET viaggio_capienza_alert = NULL WHERE viaggio_id = d.viaggio_id_fk;
    SELECT count(*) INTO v_n FROM fn_promemoria_apertura(v_az) WHERE voce = 'SENZA_CAPIENZA' AND viaggio_id = d.viaggio_id_fk;
    ASSERT v_n = 1, '4: una sola riga per viaggio, trovate ' || v_n;

    -- 5. newsletter: con 3650 giorni la partenza futura c'e'; con 0 no
    ASSERT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'SENZA_NEWSLETTER' AND data_viaggio_id = d.data_viaggio_id), '5: manca';
    UPDATE web_aziende_funzioni SET parametri = '{"giorni_newsletter": 0}' WHERE azienda_id = v_az AND funzione = 'promemoria';
    ASSERT NOT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE voce = 'SENZA_NEWSLETTER'), '5: con 0 giorni niente';

    -- 6. isolamento: un'azienda inesistente non vede niente
    ASSERT NOT EXISTS (SELECT 1 FROM fn_promemoria_apertura(999999)), '6: altra azienda';

    -- 7. ordinamento: urgenza non nulla su ogni riga
    ASSERT NOT EXISTS (SELECT 1 FROM fn_promemoria_apertura(v_az) WHERE urgenza IS NULL OR voce_titolo IS NULL OR oggetto IS NULL), '7: colonne vuote';

    -- 8. chiusa ad anon/authenticated
    FOR d IN SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated') LOOP
        ASSERT NOT has_function_privilege(d.rolname, 'fn_promemoria_apertura(integer)', 'EXECUTE'), d.rolname || ' esegue';
    END LOOP;

    RAISE NOTICE 'Test 671: tutto OK';
END $$;
ROLLBACK;
```

ℹ️ La newsletter «inviata» (stato `inviata` o `in_invio`) che toglie la riga si prova a mano nel
Task 7: costruirla qui richiederebbe un invio completo.

**Step 2: lanciarlo** — atteso: `ERROR: function fn_promemoria_giorni_newsletter(integer) does not exist`.

**Step 3: scrivere lo script**

```sql
-- ============================================================================
-- 671 — Il promemoria all'apertura (L2)
--
-- Disegno: Documents/Progetti/Promemoria_Apertura/2026-09-27-promemoria-apertura-design.md
--
--   fn_promemoria_giorni_newsletter(azienda) → integer
--     quanti giorni avanti guardare per le partenze senza newsletter; dal
--     parametro 'giorni_newsletter' della funzione 'promemoria' (linguetta
--     Funzioni Web dell'azienda). Senza riga o senza parametro: 90.
--   fn_promemoria_apertura(azienda) → una riga per caso in sospeso
--     Il gestionale la disegna e basta: voci, testi, urgenza e cosa aprire
--     stanno qui. La mail del lunedi' la richiamera' cosi' com'e'.
--
-- Clienti e documenti: le STESSE regole del sito e dell'iscrizione
-- (fn_cliente_iscrivibile, fn_documento_esito_per_partenza), non una copia.
--
-- Solo per il gestionale: nessun GRANT (script 659). search_path fissato (655).
-- Rigiocabile.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_promemoria_giorni_newsletter(p_azienda_id integer)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path = public, pg_temp
AS $$
    SELECT COALESCE(
        (SELECT CASE WHEN f.parametri->>'giorni_newsletter' ~ '^\d+$'
                     THEN (f.parametri->>'giorni_newsletter')::integer END
           FROM web_aziende_funzioni f
          WHERE f.azienda_id = p_azienda_id AND f.funzione = 'promemoria'),
        90);
$$;

CREATE OR REPLACE FUNCTION fn_promemoria_apertura(p_azienda_id integer)
 RETURNS TABLE(voce varchar, voce_titolo varchar, perche text, oggetto text, urgenza integer,
               data_rif date, viaggio_id integer, data_viaggio_id integer, cliente_id integer)
 LANGUAGE sql
 STABLE
 SET search_path = public, pg_temp
AS $$
    WITH partenze AS (
        SELECT d.data_viaggio_id, d.viaggio_id_fk, d.data_viaggio_data_inizio AS inizio,
               d.data_viaggio_data_fine AS fine, d.data_viaggio_effettuato_sino AS effettuato,
               upper(v.viaggio_descrizione_breve) || ' · ' || to_char(d.data_viaggio_data_inizio, 'DD/MM/YYYY') AS etichetta
          FROM ana_date_viaggi d
          JOIN ana_viaggi v ON v.viaggio_id = d.viaggio_id_fk
         WHERE d.azienda_id = p_azienda_id
    ), future AS (
        SELECT * FROM partenze WHERE inizio >= current_date
    ), iscritti AS (
        SELECT m.cliente_id_fk, f.data_viaggio_id, f.viaggio_id_fk, f.inizio, f.etichetta,
               c.cliente_cognome || ' ' || c.cliente_nome AS nome,
               c.cliente_documento_rilasciato_scadenza AS scadenza,
               COALESCE(tp.tipo_partecipante_pilota, false) AS guida
          FROM mov_clienti_viaggi m
          JOIN future f ON f.data_viaggio_id = m.data_viaggio_id_fk
          JOIN ana_clienti c ON c.cliente_id = m.cliente_id_fk AND c.azienda_fk = p_azienda_id
          LEFT JOIN ana_tipo_partecipante tp ON tp.tipo_partecipante_id = m.tipo_partecipante_id_fk
    )
    -- Correzioni proposte dal sito (L12-bis): un cliente aspetta la risposta
    SELECT 'PROPOSTA_DAL_SITO'::varchar, 'Correzione dal sito da approvare'::varchar,
           'Il cliente aspetta la mail per completare l''iscrizione'::text,
           p.cognome || ' ' || p.nome, 10, p.creata_il::date, NULL::integer, NULL::integer, p.cliente_id
      FROM fn_web_proposte_in_attesa(p_azienda_id) p
    UNION ALL
    -- Documento scaduto o in scadenza per una partenza futura
    SELECT DISTINCT ON (i.cliente_id_fk, i.data_viaggio_id)
           'DOCUMENTO', 'Documento da controllare', e.messaggio,
           i.nome || ' — ' || i.etichetta, 20, i.inizio, i.viaggio_id_fk, i.data_viaggio_id, i.cliente_id_fk
      FROM iscritti i
     CROSS JOIN LATERAL fn_documento_esito_per_partenza(i.data_viaggio_id, i.scadenza, i.nome) e
     WHERE upper(e.gravita) IN ('ERRORE', 'AVVISO')
    UNION ALL
    -- Iscritto che oggi non potrebbe iscriversi: blocca iscrizione e schedina alloggiati
    SELECT DISTINCT ON (i.cliente_id_fk)
           'CLIENTE_INCOMPLETO', 'Scheda cliente incompleta', e.messaggio,
           i.nome || ' — ' || i.etichetta, 30, i.inizio, i.viaggio_id_fk, i.data_viaggio_id, i.cliente_id_fk
      FROM iscritti i
     CROSS JOIN LATERAL fn_cliente_iscrivibile(i.cliente_id_fk, p_azienda_id, i.guida) e
     WHERE upper(e.gravita) = 'ERRORE'
    UNION ALL
    SELECT 'SENZA_SCHEDA_WEB', 'Partenza senza scheda web', 'Senza scheda il tour non esiste per il sito',
           f.etichetta, 40, f.inizio, f.viaggio_id_fk, f.data_viaggio_id, NULL
      FROM future f
     WHERE NOT EXISTS (SELECT 1 FROM web_tour_contenuti c WHERE c.data_viaggio_id_fk = f.data_viaggio_id)
    UNION ALL
    SELECT 'SCHEDA_IN_BOZZA', 'Scheda web in bozza', 'Pronta ma invisibile sul sito',
           f.etichetta, 41, f.inizio, f.viaggio_id_fk, f.data_viaggio_id, NULL
      FROM future f
      JOIN web_tour_contenuti c ON c.data_viaggio_id_fk = f.data_viaggio_id
     WHERE c.stato_pubblicazione = 'bozza'
    UNION ALL
    SELECT 'SCHEDA_SENZA_FOTO', 'Scheda web senza foto', 'Non pubblicabile: sul sito sarebbe una casella grigia',
           f.etichetta, 42, f.inizio, f.viaggio_id_fk, f.data_viaggio_id, NULL
      FROM future f
      JOIN web_tour_contenuti c ON c.data_viaggio_id_fk = f.data_viaggio_id
     WHERE NOT EXISTS (SELECT 1 FROM web_tour_immagini i WHERE i.web_tour_contenuti_id_fk = c.web_tour_contenuti_id)
    UNION ALL
    SELECT 'SENZA_CAPIENZA', 'Viaggio senza capienza o soglia', 'Il sito non può scrivere «rimangono N posti»',
           upper(v.viaggio_descrizione_breve), 50, min(f.inizio), v.viaggio_id, NULL, NULL
      FROM future f
      JOIN ana_viaggi v ON v.viaggio_id = f.viaggio_id_fk
     WHERE v.viaggio_capienza_max IS NULL OR v.viaggio_capienza_alert IS NULL
     GROUP BY v.viaggio_id, v.viaggio_descrizione_breve
    UNION ALL
    SELECT 'SENZA_NEWSLETTER', 'Partenza senza newsletter', 'Un viaggio che nessuno sa che esiste non si riempie',
           f.etichetta, 60, f.inizio, f.viaggio_id_fk, f.data_viaggio_id, NULL
      FROM future f
     WHERE f.inizio < current_date + fn_promemoria_giorni_newsletter(p_azienda_id)
       AND NOT EXISTS (
           SELECT 1 FROM web_newsletter_blocchi b
             JOIN web_newsletter_invii n ON n.web_newsletter_invii_id = b.invio_id_fk
            WHERE b.data_viaggio_id_fk = f.data_viaggio_id
              AND n.stato IN ('inviata', 'in_invio') AND NOT n.is_modello)
    UNION ALL
    SELECT 'PARTENZA_NON_EFFETTUATA', 'Partenza passata non segnata come effettuata',
           'Falsa i conti e le statistiche, e resta lì per sempre',
           p.etichetta, 70, p.fine, p.viaggio_id_fk, p.data_viaggio_id, NULL
      FROM partenze p
     WHERE p.fine < current_date AND COALESCE(p.effettuato, 'N') <> 'Y';
$$;

-- La riga del parametro per ogni azienda, attiva, 90 giorni (non tocca chi l'ha gia')
INSERT INTO web_aziende_funzioni (azienda_id, funzione, attiva, parametri)
SELECT a.azienda_id, 'promemoria', true, '{"giorni_newsletter": 90}'::jsonb
  FROM ana_aziende a
ON CONFLICT (azienda_id, funzione) DO NOTHING;

COMMIT;
```

⚠️ Verificare prima di lanciare, con `\d`: il nome della colonna in `ana_tipo_partecipante`
(`tipo_partecipante_pilota`), `is_modello` in `web_newsletter_invii`, e che `web_aziende_funzioni`
non abbia colonne NOT NULL senza default oltre a quelle usate (created/updated). Adeguare, non
aggirare.

**Step 4:** `./deploy_sql.sh SqlScripts/671_Promemoria_Apertura.sql`, poi il test → atteso
`NOTICE: Test 671: tutto OK`. Poi a occhio:
`SELECT voce, count(*) FROM fn_promemoria_apertura(2) GROUP BY 1 ORDER BY 1;` — confrontare con i
conteggi del disegno §1 (con 90 giorni la newsletter ne mostra meno di 12).

**Step 5: commit** — `sql: 671 il promemoria all'apertura (L2)`, con script, test e
`Documents/Architettura/Funzioni_DB.md` (appendice rigenerata + due righe nella parte curata).

---

### Task 2: Modello e servizio

**Files:**
- Create: `Models/Web/PromemoriaVoce.cs`
- Create: `Services/Web/PromemoriaService.cs`
- Modify: `MauiProgram.cs` (registrazione accanto a `WebAziendeFunzioniService`, riga ~204)

```csharp
namespace GestioneViaggi.Models.Web;

/// <summary>Una riga del promemoria all'apertura (fn_promemoria_apertura, SqlScripts/671).</summary>
public sealed record PromemoriaVoce(
    string Voce, string VoceTitolo, string Perche, string Oggetto, int Urgenza,
    DateOnly? DataRif, int? ViaggioId, int? DataViaggioId, int? ClienteId);
```

`PromemoriaService` (stile di `UserPreferenzeService`: `IDatabaseService`, `ITenantContext`,
`ILogger`), con:
- `Task<List<PromemoriaVoce>> ElencoAsync(int aziendaId)` — `SELECT * FROM fn_promemoria_apertura(@AziendaId::integer) ORDER BY urgenza, data_rif, oggetto`; in errore logga e **rilancia** (il promemoria che tace su un errore sembra «tutto a posto»).
- `Task<bool> NascostoOggiAsync()` / `Task NascondiOggiAsync()` — via `UserPreferenzeService`, chiave `promemoria_nascosto_il`, valore `DateOnly.FromDateTime(DateTime.Now).ToString("yyyy-MM-dd")`.
- `bool GiaMostratoInQuestoAvvio(Guid utenteId)` / `void SegnaMostrato(Guid utenteId)` — un `static readonly HashSet<Guid>`: una volta per avvio e per utente.

Build: `dotnet build -f net9.0-maccatalyst` → 0 errori. Commit `feat(promemoria): servizio e modello (L2)`.

---

### Task 3: Il parametro nella linguetta «Funzioni Web»

**Files:**
- Modify: `Services/Web/WebAziendeFunzioniService.cs` — `public const string FunzionePromemoria = "promemoria";`
  e `GetGiorniNewsletterAsync(int aziendaId)` (`SELECT fn_promemoria_giorni_newsletter(@AziendaId::integer)`:
  il 90 lo decide il DB) e `SaveGiorniNewsletterAsync(int aziendaId, int giorni)` sul modello di
  `SaveRecensioniConfigAsync` (JSON `{"giorni_newsletter": N}`; se la riga manca la crea attiva).
- Modify: `Components/Shared/AziendaTabs/AziendaTabFunzioniWeb.razor`:
  - nuovo `ToggleDef(FunzionePromemoria, "Promemoria all'apertura", "All'avvio mostra le cose rimaste in sospeso: partenze da chiudere, schede web, newsletter, clienti e documenti.", true)`;
  - quando è acceso, un riquadro come quello delle recensioni con
    `MudNumericField<int>` «Giorni di anticipo per la newsletter» (Min 1, Max 365,
    HelperText «Le partenze entro questi giorni senza una newsletter inviata compaiono nel promemoria.»)
    e bottone «Salva».

Verifica a mano (`./run_maui.sh`, Anagrafica Aziende → azienda 2 → Funzioni Web): il campo mostra
90; salvato 60, `SELECT parametri FROM web_aziende_funzioni WHERE azienda_id=2 AND funzione='promemoria'`
dice 60. Rimettere 90. Commit `feat(promemoria): i giorni della newsletter nelle Funzioni Web (L2)`.

---

### Task 4: `AnaViaggiDialog` si apre sui Contenuti Web di una partenza

**Files:**
- Modify: `Components/Shared/AnaViaggiDialog.razor` — `[Parameter] public bool StartOnContenutiWebTab { get; set; }`
  e `[Parameter] public int? StartDataViaggioId { get; set; }`. Dove oggi c'è `if (StartOnDatesTab) _activeTabIndex = 1;`
  (in `OnInitialized` e in `OnAfterRenderAsync`) aggiungere il caso `StartOnContenutiWebTab && IsEditMode`
  → `ContenutiWebTabIndex`. Passare `InitialDataViaggioId="@StartDataViaggioId"` a `WebEdizioniManager`.
- Modify: `Components/Shared/WebEdizioniManager.razor` — `[Parameter] public int? InitialDataViaggioId { get; set; }`;
  in `OnInitializedAsync`, prima di `ReloadAsync()`: `if (InitialDataViaggioId is int id) _selectedDataId = id;`.

Nessun comportamento cambia per chi non passa i parametri nuovi. Build, commit
`feat(viaggi): la scheda si apre sui contenuti web di una partenza (L2)`.

---

### Task 5: `PromemoriaDialog`

**Files:**
- Create: `Components/Shared/PromemoriaDialog.razor`

Parametri: `AziendaId`. Contenuto:
- in alto una riga di `MudChip` filtro: «Tutte (N)» + una per voce presente, testo `VoceTitolo (conteggio)`; selezione singola;
- `MudTextField` ricerca (filtra su `Oggetto` e `VoceTitolo`, senza distinzione di maiuscole);
- `MudTable<PromemoriaVoce>` con `RowsPerPage="25"` e `MudTablePager` (opzioni 25/50/100), colonne:
  **Cosa** (`VoceTitolo`), **Su che cosa** (`Oggetto`), **Perché conta** (`Perche`), bottone **Apri**;
  l'ordine è quello del DB, il C# non riordina;
- `DialogActions`: «Non mostrarmelo più oggi» (chiama `NascondiOggiAsync`, chiude) e «Chiudi».
- Stato vuoto: «Niente in sospeso.» (serve solo quando lo si apre dal menu).

`Apri`, in un `switch (riga.Voce)`:

| Voce | Azione |
|---|---|
| `PARTENZA_NON_EFFETTUATA` | `AnaViaggiDialog` con `StartOnDatesTab = true` |
| `SENZA_SCHEDA_WEB`, `SCHEDA_IN_BOZZA`, `SCHEDA_SENZA_FOTO` | `AnaViaggiDialog` con `StartOnContenutiWebTab = true`, `StartDataViaggioId = riga.DataViaggioId` |
| `SENZA_CAPIENZA` | `AnaViaggiDialog` normale (Dati Generali) |
| `SENZA_NEWSLETTER` | `TabManager.OpenTab("/newsletter", "Newsletter", "mail")` e chiude il promemoria |
| `CLIENTE_INCOMPLETO`, `PROPOSTA_DAL_SITO` | `ClienteDialog` con l'entità da `ClienteService.GetByIdAsync(id, AziendaId)`, `IsEditMode = true` |
| `DOCUMENTO` | `ViaggioPartecipantiManagerDialog` con `DataViaggioId`, `ViaggioId`, `AziendaId`, `HeaderTitle = riga.Oggetto` |

Per `AnaViaggiDialog` copiare parametri e opzioni da `DashboardAdmin.OnCalendarTravelClick`
(`ViaggiService.GetByIdAsync`, `CloseButton = false`, `BackdropClick = false`); per `ClienteDialog`
quelli di `Clienti.razor` (~riga 430). Dopo che la scheda aperta si chiude: `await CaricaAsync()`
(il caso risolto sparisce). Errori di caricamento → `MudAlert` rosso nella finestra, non la
finestra vuota.

Build, commit `feat(promemoria): la finestra con la tabella (L2)`.

---

### Task 6: All'avvio e nel menu

**Files:**
- Create: `Components/Shared/PromemoriaLauncher.cs` — classe statica o servizio con
  `Task MostraAsync(IDialogService, int aziendaId)` che apre `PromemoriaDialog` con
  `new DialogOptions { BackdropClick = false, CloseOnEscapeKey = false, CloseButton = false, MaxWidth = MaxWidth.Large, FullWidth = true }`
  (⛔️ regola della 2.2: niente chiusura fuori, Esc o rotella).
- Modify: `Components/Pages/DashboardAdmin.razor` — in `OnAfterRenderAsync(firstRender)` (crearlo se
  manca): se utente con azienda, `!GiaMostratoInQuestoAvvio`, funzione `promemoria` attiva
  (`WebAziendeFunzioniService.IsAttivaAsync(az, FunzionePromemoria, defaultWhenMissing: true)`),
  `!NascostoOggiAsync()` ed `ElencoAsync(az).Count > 0` → `SegnaMostrato` e `MostraAsync`.
  ⛔️ Se l'elenco è vuoto la finestra non compare.
- Modify: `Components/Shared/NavMenu.razor` — `MudNavLink` «Promemoria» (icona
  `Icons.Material.Filled.NotificationsActive`) subito sotto «Dashboard», che apre `MostraAsync`
  sempre (anche se nascosto per oggi); il conteggio fra parentesi letto in `OnInitializedAsync` e
  riletto alla chiusura della finestra.

Build, commit `feat(promemoria): all'avvio e dal menu (L2)`.

---

### Task 7: Prova a mano sui dati veri (azienda 2, DB locale)

`./run_maui.sh`, login azienda 2:
1. All'avvio compare il promemoria; i conteggi dei chip coincidono con
   `SELECT voce, count(*) FROM fn_promemoria_apertura(2) GROUP BY 1`.
2. Filtro, ricerca e paginazione funzionano; clic fuori, Esc e rotella non la chiudono.
3. Un **Apri** per ogni voce presente porta al posto giusto (Contenuti Web sulla partenza giusta).
4. Segnare effettuata una partenza passata → chiusa la scheda, la riga sparisce.
5. «Non mostrarmelo più oggi» → riavvio: non compare; dal menu sì. Poi
   `DELETE FROM sys_utente_preferenze WHERE chiave='promemoria_nascosto_il'` → riavvio: ricompare.
6. Spento l'interruttore in Funzioni Web → all'avvio non compare; riacceso → compare.
7. Newsletter: una newsletter di prova **non inviata** con un blocco sulla partenza non toglie la riga.
   ⛔️ Non inviarla: il DB locale ha le email vere.

Esiti in `Documents/Piani_Test/` (file del gestionale per le prove a mano, se esiste, altrimenti
nelle note di rilascio 2.4).

---

### Task 8: Documenti e liste

- `Documents/Versioni/Note_Rilascio_Versione_2_4.md`: §1 Novità (il promemoria, il parametro),
  §4 Database (671, ⏳ PROD).
- `Documents/Analisi_e_Design/2026-09-27-Cose_Da_Fare_MAUI_Versione_2_4.md`: L2 «✅ fatto in
  locale», riga in «Già nel codice, da portare con la 2.4».
- ⛔️ **Nella stessa sessione** `Sito Web SFT/Documenti/2026-09-25-Cose_Da_Fare_Sito.md`, riga L2.
- Manuale per Antonio: capitolo breve nel manuale più vicino (o note Novità 2.4), voce aziendale,
  niente «noi».
- Applicazione a PROD dello script 671: **solo con il via di Adriano**, poi segnare la data nelle
  note (§4) e nelle due liste.
