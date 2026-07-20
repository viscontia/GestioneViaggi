# Contenuti Web — UX salvataggio, semaforo tab, gating bozza — design

> Elimina la "trappola dei due Salva" nel dialog Viaggio e introduce feedback di completamento + gating pubblicazione. Validato con Adriano (2026-07-20).

## Problema (confermato con evidenza)
Il dialog "Modifica Viaggio" (`AnaViaggiDialog`) ha un **"Salva" in basso** (salva il viaggio e **chiude** → torna alla lista) e, dentro il tab **Contenuti Web** (`WebEdizioniManager` → sub-tab Contenuti/Itinerario/Galleria/Mappa/Traduzioni), ogni sub-tab ha il **proprio** pulsante "Salva Contenuti Web" (salva e **resta**).
Trappola: il "Salva" del dialog è più visibile → l'utente lo preme, il viaggio si salva ma **i contenuti web NO**, e la finestra si chiude. Verificato: cliccando il pulsante giusto (`SALVA-START`/`SALVA-OK` a log) i dati vengono salvati; cliccando quello del dialog no. Il salvataggio contenuti **funziona**: il problema è puramente UX.

## Obiettivi (richiesta utente)
1. **Niente doppio Salva ambiguo.** Restare nel form finché non si esce con azione **esplicita** (chiusura). Il salvataggio di un sub-tab salva quel sub-tab e **si resta** nel form.
2. **Semaforo sui sub-tab**: 🟢 tutti gli obbligatori compilati · 🔴 iniziato ma mancano obbligatori · 🟡 non compilato / in attesa.
3. **Gating bozza**: non si può passare da "bozza" a "pubblicato" finché **tutti i sub-tab e i campi obbligatori** non sono completi. (Verificato: oggi NON esiste alcun gating; lo `Stato` è un select libero.)

## Soluzione — 3 fasi

### Fase 1 — Elimina la trappola (critica, UI)
- **Footer del dialog context-aware.** `AnaViaggiDialog` conosce il tab attivo (`_activeTabIndex`/`OnTabChanged`). Sui tab **Dati Generali / Date e Costi** → footer con "Salva" (viaggio) + "Annulla" come oggi. Sul tab **Contenuti Web** → footer con solo **"Chiudi"** (uscita esplicita): niente "Salva" del viaggio che compete e chiude. Così l'unico salvataggio dei contenuti è quello dei sub-tab, che resta nel form.
- **Guard modifiche non salvate.** Se si cambia edizione/sub-tab o si chiude con modifiche non salvate nel sub-tab attivo → chiedere conferma ("Ci sono modifiche non salvate. Salvare / Scartare / Annulla"). Richiede che i sub-tab espongano un flag `HasUnsavedChanges` (dirty) al parent.
- Rendere il pulsante "Salva Contenuti Web" **più evidente** (colore primario, posizione coerente) — già primario, verificare posizione.

### Fase 2 — Semaforo sui sub-tab
- Ogni sub-tab espone uno **stato di completamento** al `WebEdizioniManager` (via `EventCallback`/parametro): `Completo` (tutti gli obbligatori ok), `Parziale` (iniziato, mancano obbligatori), `Vuoto` (nulla inserito).
- `WebEdizioniManager` colora l'icona del `MudTabPanel` di conseguenza (pattern `GetTabColor` già usato in `ClienteDialog`/`AnaViaggiDialog`): 🟢 Success · 🔴 Error · 🟡 Warning.
- **DECISIONE APERTA (serve l'utente):** definizione di "obbligatorio/completo" per **ogni** sub-tab (vedi sotto). Senza questa non si può implementare Fase 2/3.

### Fase 3 — Gating bozza → pubblicato
- Alla richiesta di passare lo `Stato` a "pubblicato": verificare che **tutti** i sub-tab siano 🟢. Se no → bloccare con messaggio che elenca i tab mancanti; lo Stato resta "bozza".
- Enforcement anche **DB-first** (difesa): una funzione/regola che rifiuta `stato_pubblicazione='pubblicato'` se i requisiti non sono soddisfatti (a valle della definizione dei requisiti).

## DECISIONE APERTA — definizione di "completo" per sub-tab
Da concordare prima di Fase 2/3 (proposta iniziale, da confermare):
- **Contenuti**: obbligatori `slug` (già Required) + `sottotitolo` + `descrizione`. (title/meta opzionali)
- **Itinerario**: almeno 1 giornata con almeno 1 passo? oppure opzionale?
- **Galleria**: almeno 1 immagine + copertina? oppure opzionale?
- **Mappa**: opzionale (dipende dal GPX)?
- **Traduzioni**: opzionale, oppure obbligatorie per le lingue attive dell'azienda?

## File coinvolti (previsti)
- `Components/Shared/AnaViaggiDialog.razor` (footer context-aware, gating)
- `Components/Shared/WebEdizioniManager.razor` (semaforo sub-tab, guard non-salvato, gating)
- I 5 sub-tab (`WebTourContenutiTab`, `WebTourItinerarioTab`, `WebTourGalleriaTab`, `WebTourMappaTab`, `WebTraduzioniTab`): espongono stato completamento + dirty
- Eventuale `SqlScripts/NNN` per il gating DB-first + `Funzioni_DB.md`

## Note
- Il catch difensivo aggiunto in `WebTourContenutiTab.Salva` (evita crash circuito) resta.
- Priorità: **Fase 1** risolve subito il rischio di perdita dati (la trappola). Fase 2/3 sono migliorie che dipendono dalla definizione dei requisiti per-tab.
