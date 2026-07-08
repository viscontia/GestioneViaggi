# Blocco 9 — GPX → mappa statica — DESIGN DOC

> **USO INTERNO (Adriano + AI).** Design consolidato prima dell'implementazione.
> **Versione:** 1.0 · **Data:** 2026-07-08
> **Base:** Piano Operativo (Blocco 9, Fase 2.6), Analisi Tecnica (Geoapify/Douglas-Peucker), tabella/model/service `web_tour_mappa` (Blocchi 1/4), storage Blocco 7.

---

## 1. Scope e obiettivo

Generare **una mappa statica** (immagine) dalla traccia GPX di un tour, **tutto lato gestionale C#**. La traccia **non raggiunge mai il browser**: le coordinate sono "cotte" nei pixel; il sito servirà solo l'URL dell'immagine (CDN). Attribuzione **© OpenStreetMap contributors**.

Il piano impone uno **SPIKE tecnico prima della UI**: parse GPX + Douglas-Peucker + 1 chiamata Geoapify reale su 1 GPX vero.

## 2. Decisioni prese (brainstorming 2026-07-08)

- **Chiave Geoapify: nessuna cifratura.** È free e rigenerabile dal cliente; il gestionale gira sul PC del cliente pagante. Sta in `appsettings` (sezione `Geoapify`, placeholder nel committato) — ogni installazione ha la propria. Lo spike usa la chiave in memoria (non committata).
- **⚠️ SMTP/ESP:** i campi `_enc` sono **finti** (plaintext JSONB, vedi `AziendaSmtpService`). Cifratura reale = **must pre-rilascio**, tracciato a parte (memoria `encrypt-smtp-esp-before-release`). Non è parte di questo blocco.
- **Bucket:** stesso `tour-media`, path `{azienda}/{viaggio}/mappa.webp` (riuso `IWebMediaStorage`, nessuna config nuova).
- **Douglas-Peucker a mano** (~30 righe, no NetTopologySuite) + cap sul numero di punti (limite lunghezza URL Geoapify).

## 3. Pipeline (server-side, C#)

`gpx (testo)` → **parse** `<trkpt lat lon>` → **Douglas-Peucker** (tolleranza + cap punti) → **bbox** (min/max lat/lon) + margine → **Geoapify Static Maps** (URL: stile `osm-bright`, size, `area=rect` sul bbox, `geometry=polyline` semplificata con colore/spessore outdoor, marker start/end) → scarica PNG → **WebP** (`WebImageProcessor`) → **upload** (`IWebMediaStorage`) → salva `web_tour_mappa`.

`web_tour_mappa` (1:1 viaggio, già esistente): `gpx_originale` (testo, mai al browser), `gpx_filename`, `bbox_*`, `provider='geoapify'`, `stile`, `parametri_render` (jsonb: size, tolleranza, colori, n. punti), `immagine_url`/`immagine_storage_path`, `data_generazione`.

## 4. Componenti nuovi

- `Services/Shared/Geo/GpxParser.cs` — parse del testo GPX → lista `(lat, lon)`.
- `Services/Shared/Geo/DouglasPeucker.cs` — decimazione a mano; input punti + tolleranza (gradi/metri) → punti ridotti; cap finale sul numero max.
- `Services/Shared/Geo/GeoapifyStaticMapClient.cs` — costruisce l'URL Static Maps e scarica il PNG via `HttpClient` (no SDK); opzioni da `GeoapifyOptions` (ApiKey, stile, size, colori).
- `Services/Web/WebTourMappaGeneratorService.cs` — orchestrazione pipeline (parse→DP→bbox→Geoapify→WebP→storage→persist via `WebTourMappaService`).
- Config `GeoapifyOptions` + registrazione DI (sezione `Geoapify` in appsettings).
- **UI**: `WebTourMappaTab.razor` (6° tab "Mappa" in `AnaViaggiDialog`, solo edit): upload `.gpx` (`MudFileUpload`), "Genera mappa", anteprima immagine, bbox, rigenera/elimina. GPX salvato in `gpx_originale` (server-side).

## 5. Note tecniche / rischi

- **URL length**: la polyline nell'URL Geoapify ha un limite → cap punti (es. ≤ ~300) dopo DP. Verificare nello spike.
- **Formato geometry/area**: `geometry=polyline:lon,lat,...` e `area=rect:lon1,lat1,lon2,lat2` (lon,lat!). Da confermare nello spike (Geoapify risponde con JSON d'errore se il formato è sbagliato → auto-correzione).
- **GPX grandi**: la traccia originale resta in `gpx_originale`; solo la versione decimata va nell'URL.
- Errore Geoapify (chiave/quota/rete) → snackbar; nessun record parziale.

## 6. Verifica (criteri del blocco)

- **Spike**: parse OK, DP riduce i punti, chiamata Geoapify reale su GPX vero → immagine **centrata** e valida.
- Mappa centrata su più GPX reali; traccia semplificata; **nessun dato vettoriale/GPX al browser**; URL pubblico valido; `bbox`/parametri salvati.
- Build `net9.0-maccatalyst`: 0 errori.

## 7. Deliverable

1. Spike (validazione Geoapify + DP su GPX reale).
2. `GpxParser`, `DouglasPeucker`, `GeoapifyStaticMapClient`, `GeoapifyOptions` + DI.
3. `WebTourMappaGeneratorService`.
4. `WebTourMappaTab` + 6° tab in `AnaViaggiDialog`.
5. Doc: `ComponentiShared.md` + eventuale `Funzioni_DB.md`.
