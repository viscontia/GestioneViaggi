
# AGENTS.md

## PRIMO PASSO OBBLIGATORIO — LEGGERE PRIMA DI QUALSIASI ALTRA COSA

**Prima di rispondere a qualsiasi richiesta, prima di esplorare il codice, prima di fare qualunque cosa:**

Leggi il file:
```
/Users/adrianovisconti/Documents/Sviluppo Software/MAUI/GestioneViaggi/Documents/overview.md
```

Questo file contiene l'architettura completa del progetto, le regole obbligatorie (DB-first, componenti shared, UI rules), la mappa dei servizi, le connessioni DB e il flusso standard per aggiungere feature. Senza averlo letto non puoi lavorare correttamente su questo progetto.

**Non è opzionale. Non è possibile saltare questo passaggio.**

---

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## graphify (grafo di conoscenza del progetto)

Questo progetto ha un grafo di conoscenza in `graphify-out/` (god node, struttura a community, relazioni cross-file). Esiste `graphify-out/graph.json`.

### A. Uso quotidiano — OBBLIGATORIO orientarsi con graphify PRIMA di leggere i sorgenti

Quando esiste `graphify-out/graph.json`, per qualsiasi domanda sul codebase o esplorazione del codice **devi interrogare graphify prima di leggere/grep-are i file grezzi**:
- `graphify query "<domanda>"` → sottografo mirato (molto più piccolo di GRAPH_REPORT.md o del grep grezzo). È il punto di partenza per capire "come funziona X", "cosa usa Y", "dov'è definito Z".
- `graphify path "<A>" "<B>"` → relazione/percorso tra due concetti.
- `graphify explain "<concetto>"` → spiegazione focalizzata di un nodo.
- Leggi `graphify-out/GRAPH_REPORT.md` solo per una review architetturale ampia o quando query/path/explain non bastano.
- Leggi i file sorgente grezzi **solo dopo** che graphify ti ha orientato, oppure per modificare/debuggare righe specifiche.
- Questa regola vale **anche per i subagent**: includila in ogni prompt di subagent che esplora codice.

### B. Aggiornamento del grafo — mantenerlo allineato dopo ogni modifica

Un `graph.json` obsoleto rende inaffidabili query/path/explain, quindi il grafo va sempre riallineato dopo aver modificato elementi del progetto.

**Codice e script DB → automatico (hook git installato).** È attivo un hook `post-commit` (+`post-checkout`) che, a ogni commit, rileva i file di codice cambiati (`git diff HEAD~1 HEAD`), ri-estrae via AST solo quelli e ricostruisce `graph.json` + `GRAPH_REPORT.md` in background. Copre:
- **Codice** C#/XAML/Razor/JS (`Components/`, `Services/`, `Models/`, `Validation/`, `Statistics/`, ecc.).
- **Funzioni/script DB** in `SqlScripts/` (`.sql`) — trattati come file di codice.

Nessun comando manuale necessario per questi: basta committare. (Gestione hook: `graphify hook status | install | uninstall`.)

**Documentazione → manuale via assistente.** Le modifiche a doc/PDF/immagini NON sono coperte dall'hook (richiedono estrazione semantica). Dopo aver aggiornato `Documents/`, `overview.md`, `Funzioni_DB.md` o le spec dell'Estensione Web, esegui nell'assistente:

```
/graphify --update
```

Note operative:
- L'estrazione documentale usa subagent semantici (ha un costo di token); quella del codice è AST puro e gratuita.
- Evita il raw `graphify update .` da shell per riallineamenti manuali: fa un merge incrementale sull'intero albero che può accumulare nodi. Per il codice affidati all'hook; per i doc usa `/graphify --update`.
