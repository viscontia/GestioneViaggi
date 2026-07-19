# Blocco 5 — Help contestuale + SEO assistita (campi contenuti web) — design

> Rendere i campi tecnici della scheda contenuti web (`WebTourContenutiTab`) comprensibili e assistiti per **utenti non tecnici**. Validato con Adriano (2026-07-19).

## Contesto / verifiche
- Componente: `Components/Shared/WebTourContenutiTab.razor` (Blocco 5). Campi in oggetto: **Indirizzo web (slug)**, **Meta title**, **Meta description**, **Ordine sul sito**, **Prima pubblicazione**.
- **Unicità slug**: `uq_web_tour_contenuti_slug UNIQUE (azienda_id, slug)` → **per-azienda** (non globale).
- **Meta title/description NON esposti** oggi da `fn_web_tour_pubblicati` (assenti dal `RETURNS TABLE`) → non arrivano al sito, nessun fallback esistente. Vanno esposti prima di renderli utili (punto 4).
- Problema UX: campi da specialista dati in mano a utenti che non ne conoscono il significato.

## Decisioni
1. **Help contestuale via popover, non modali.** Componente **condiviso** `FieldHelp` = icona `?` accanto al campo che apre un piccolo `MudPopover` (titolo + testo semplice + esempio). Niente dialog per-campo (troppo pesanti). In più `HelperText` inline riscritti in linguaggio non tecnico.
2. **"Prima pubblicazione" resa label statica** di sola lettura (non deve sembrare un input): `MudField` senza bordo/attenuato + icona lucchetto + hint "impostata automaticamente".
3. **Meta title/description pre-compilabili** con pulsante **"Suggerisci"** (valore editabile), best-practice: title da titolo (≤60), description da descrizione senza HTML (≤155).
4. **(propedeutico al 3)** esporre `meta_title`/`meta_description` in `fn_web_tour_pubblicati` con **fallback** (`meta_title → titolo`, `meta_description → sottotitolo/estratto`), così il sito li consuma. Richiede grant colonnare `anon` sulle nuove colonne (go-live).

## Fasi
- **Fase 1 (UI pura, basso rischio): punti 1 + 2.** `FieldHelp` + HelperText + label statica "Prima pubblicazione".
- **Fase 2: punti 3 + 4.** Prima il DB (esporre meta + fallback, punto 4), poi i pulsanti "Suggerisci" (punto 3) — il 3 senza il 4 curerebbe campi inerti.

## Componenti / testi
- **`FieldHelp.razor`** (nuovo, condiviso): parametri `Title` (string), `Text` (string o RenderFragment). Icona `Icons.Material.Outlined.HelpOutline`, `Size.Small`; click → `MudPopover` ancorato con `MudPaper` (max ~320px), chiusura on-outside-click. Riusabile ovunque.
- **Testi help (linguaggio utente)** — vedi il piano per il contenuto esatto dei 5 campi.
- **Suggerimenti**:
  - Meta title ← `DescrizioneBreve` (titolo viaggio), troncato a 60 su confine parola.
  - Meta description ← testo di `DescrizioneHtml` ripulito dall'HTML (tag rimossi, entità decodificate, spazi compressi), primi ~155 su confine parola; fallback `Sottotitolo`.

## File toccati (previsti)
- `Components/Shared/FieldHelp.razor` (nuovo)
- `Components/Shared/WebTourContenutiTab.razor` (help, HelperText, label statica, pulsanti Suggerisci, helper strip-HTML)
- `SqlScripts/NNN_*.sql` — `fn_web_tour_pubblicati` +meta con fallback; `Documents/Funzioni_DB.md`; checklist go-live (grant anon colonnare)
- eventuale modello/mapping C# del consumer di `fn_web_tour_pubblicati` (se esiste già lato gestionale)
- `Documents/ComponentiShared.md` (FieldHelp)

## Note
- Slug: l'help deve avvertire "dopo la pubblicazione non cambiarlo" (rischio 404). Nessun cambio di logica slug in questo intervento.
- Esporre i meta al pubblico (punto 4) implica grant `SELECT` colonnare ad `anon` su `web_tour_contenuti.meta_title/meta_description` se la funzione è SECURITY INVOKER → aggiungere alla checklist go-live.
