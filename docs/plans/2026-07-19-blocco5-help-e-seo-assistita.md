# Blocco 5 — Help contestuale + SEO assistita — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: superpowers:executing-plans (o subagent-driven) per eseguire task-by-task.

**Goal:** Rendere i campi tecnici di `WebTourContenutiTab` comprensibili/assistiti per utenti non tecnici (help contestuale, label statica, pre-compilazione SEO), e collegare i meta al sito.

**Architettura:** Fase 1 UI pura (help + label). Fase 2 DB-first (esporre meta con fallback) + pulsanti "Suggerisci".

**Stack:** MAUI Blazor + MudBlazor; PostgreSQL (DB-first); build `dotnet build -f net9.0-maccatalyst`. Branch `feature/estensione-web`. Commit finali con `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. graphify-first per esplorare; VPN off non rilevante qui.

**Riferimento design:** `Documents/2026-07-19-Blocco5_HelpContestuale_e_SEO_Assistita-design.md`

---

## FASE 1 — Help contestuale + label statica (UI, basso rischio)

### Task 1 — Componente condiviso `FieldHelp`

**Files:** Create `Components/Shared/FieldHelp.razor`

- Icona `MudIconButton` `Icons.Material.Outlined.HelpOutline`, `Size="Size.Small"`, `Color="Color.Info"`, aria-label "Aiuto".
- Click → toggla un `MudPopover` (`Open="_open"`, `Fixed="true"`, `AnchorOrigin=BottomLeft`, `TransformOrigin=TopLeft`) contenente `MudPaper Class="pa-3" Style="max-width:320px"`: `MudText Typo=subtitle2` = `Title`, poi `MudText Typo=body2` = `Text` (supporta `ChildContent` per esempi formattati).
- Chiusura: `MudOverlay` invisibile o `@onblur`/click fuori (usa `MudPopover` + un `MudOverlay Visible="_open" OnClick="() => _open=false" AutoClose="true" LockScroll="false"`).
- Parametri: `[Parameter] string Title`, `[Parameter] string? Text`, `[Parameter] RenderFragment? ChildContent`.

**Verifica:** `dotnet build -f net9.0-maccatalyst` → 0 errori. Commit.

### Task 2 — Applicare `FieldHelp` + riscrivere HelperText nei 5 campi

**Files:** Modify `Components/Shared/WebTourContenutiTab.razor`

Per ciascun campo, aggiungere `<FieldHelp>` accanto (adornment Start dove il campo non ha già adornment; per lo slug che ha già il "genera" sull'End, usare Start). Testi (verbatim):

- **Indirizzo web (URL)** — Title "Indirizzo web" · Text: "È l'indirizzo della pagina sul sito. Tienilo corto e semplice, tutto minuscolo, parole separate da trattini (es. tour-dune-gallura). ⚠️ Dopo la pubblicazione non cambiarlo: il vecchio link smetterebbe di funzionare." HelperText inline: "Minuscolo, senza spazi (es. dalle-dune-alla-gallura). Non cambiarlo dopo la pubblicazione."
- **Meta title** — Text: "Il titolo che Google mostra nei risultati di ricerca e nella scheda del browser. Tienilo entro ~60 caratteri, con le parole più importanti all'inizio. Se lo lasci vuoto verrà usato il titolo del tour." HelperText: "~60 caratteri."
- **Meta description** — Text: "La breve frase che appare sotto il titolo nei risultati di Google: serve a invogliare il clic. Circa 150 caratteri, invitante e chiara." HelperText: "~150 caratteri."
- **Ordine sul sito** — Text: "Decide in che ordine appaiono i tour nell'elenco del sito. Numeri più bassi vanno prima. Lascia 0 se non ti interessa; usa 1, 2, 3… per mettere alcuni tour in cima." HelperText: "Più basso = più in alto nell'elenco."
- **Prima pubblicazione** — Text: "Data in cui il tour è stato pubblicato la prima volta. La imposta il sistema automaticamente, non serve toccarla."

**Verifica:** build 0 errori; runtime (utente): icone ? aprono i popover. Commit.

### Task 3 — "Prima pubblicazione" come label statica

**Files:** Modify `WebTourContenutiTab.razor` (righe ~118-119)

Sostituire il `MudTextField ReadOnly` con una resa non-input, es. `MudField Label="Prima pubblicazione" Variant="Variant.Text" InnerPadding="false" Adornment="Adornment.End" AdornmentIcon="@Icons.Material.Filled.Lock"` con dentro il valore formattato o "—", stile attenuato + `FieldHelp` accanto. Deve apparire come etichetta, non come casella editabile.

**Verifica:** build 0 errori; runtime: il campo non sembra più un input. Commit.

---

## FASE 2 — Meta al sito + pre-compilazione (fare il DB prima)

### Task 4 — Esporre `meta_title`/`meta_description` in `fn_web_tour_pubblicati` con fallback

**Files:** Create `SqlScripts/NNN_FnWebTourPubblicati_Meta.sql`; Modify `Documents/Funzioni_DB.md`; checklist go-live.

- `graphify query "fn_web_tour_pubblicati"` + leggere la funzione. Aggiungere al `RETURNS TABLE` `meta_title varchar, meta_description varchar` e nel SELECT: `COALESCE(NULLIF(btrim(c.meta_title),''), c.<titolo>)` e `COALESCE(NULLIF(btrim(c.meta_description),''), c.sottotitolo)` (verificare i nomi colonna reali su `web_tour_contenuti`).
- **Consumer**: cercare chi mappa la funzione (`graphify query "fn_web_tour_pubblicati consumer model mapping"`); se esiste un modello/servizio C#, aggiungere i due campi al mapping (mapping per nome → retro-compatibile; se posizionale, aggiornare).
- Deploy via `./deploy_sql.sh`; verifica: la funzione ritorna i due campi con fallback corretto su un contenuto senza meta.
- **Checklist go-live**: annotare lo script e il **grant `SELECT` colonnare ad `anon`** su `web_tour_contenuti.meta_title/meta_description` (se la funzione è SECURITY INVOKER letta da anon).

**Verifica:** query DB mostra meta con fallback. Commit.

### Task 5 — Pulsanti "Suggerisci" per Meta title/description

**Files:** Modify `WebTourContenutiTab.razor`

- Helper `StripHtml(string?)`: rimuove tag, decodifica entità (`System.Net.WebUtility.HtmlDecode`), comprime spazi.
- Helper `Troncatura(text, max)`: taglia a `max` su confine parola.
- `SuggerisciMetaTitle()` → `_model.MetaTitle = Troncatura(DescrizioneBreve, 60)`.
- `SuggerisciMetaDescription()` → `_model.MetaDescription = Troncatura(StripHtml(_model.DescrizioneHtml) ?? _model.Sottotitolo, 155)`.
- Aggiungere accanto ai due campi un pulsante/adornment "Suggerisci" (come il "genera" dello slug). Valore resta editabile.

**Verifica:** build 0 errori; runtime: "Suggerisci" riempie i campi con valori sensati e troncati. Commit.

### Task 6 — Documentazione

**Files:** `Documents/ComponentiShared.md` (FieldHelp + note Blocco 5); `Documents/Funzioni_DB.md` (già in Task 4). Poi `/graphify --update`.

---

## Definition of Done
- [ ] Ogni campo tecnico ha `?` con help in linguaggio semplice; HelperText riscritti.
- [ ] "Prima pubblicazione" appare come label statica, non input.
- [ ] `fn_web_tour_pubblicati` espone meta con fallback; consumer aggiornato; grant anon annotato in go-live.
- [ ] "Suggerisci" pre-compila meta title/description con best-practice, editabili.
- [ ] build verde; doc aggiornate; grafo riallineato.

## Note
- Fase 1 (Task 1-3) indipendente e a basso rischio → si può rilasciare da sola.
- Task 5 dipende da Task 4 (senza esposizione, i meta non raggiungono il sito).
- Nessuna modifica alla logica dello slug.
