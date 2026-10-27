// L'editor HTML delle bozze (Components/Shared/EditorHtmlBozza.razor): carica e incolla PASSANDO DAL MODELLO di Quill.
//
// Perché: Blazored.TextEditor carica il testo scrivendo root.innerHTML, cioè nella pagina e non nel modello di Quill.
// Quando pagina e modello non coincidono, alla prima modifica Quill ridisegna dal suo modello e il resto sparisce:
// prova di Adriano del 2026-10-27 sulle FAQ (testo incollato da una pagina web con Cmd+V, sparito al primo tasto).
// Qui il testo entra sempre con i comandi di Quill (dangerouslyPasteHTML), e l'incolla lo facciamo noi dagli appunti.

window.editorHtmlBozza = (function () {
    function quillDi(contenitore) {
        const el = contenitore && contenitore.querySelector('.ql-container');
        return el && el.__quill ? el.__quill : null;
    }

    // Avvisa EditorHtmlBozza che il testo è cambiato (ascolta «input» sul suo contenitore).
    function avvisa(q) {
        q.root.dispatchEvent(new Event('input', { bubbles: true }));
    }

    function incolla(q, e) {
        const dati = e.clipboardData;
        if (!dati) return;
        const html = dati.getData('text/html');
        const testo = dati.getData('text/plain');
        if (!html && !testo) return;          // immagini o altro: lo lascia a Quill
        e.preventDefault();                   // Quill salta l'incolla già gestito (defaultPrevented)
        e.stopImmediatePropagation();
        // il punto del cursore (anche tornando da un altro campo Quill ricorda l'ultimo); se non c'è mai stato, in fondo
        const sel = q.getSelection(true) || { index: Math.max(0, q.getLength() - 1), length: 0 };
        if (sel.length) q.deleteText(sel.index, sel.length, 'user');
        const prima = q.getLength();
        if (html) q.clipboard.dangerouslyPasteHTML(sel.index, html, 'user');
        else q.insertText(sel.index, testo, 'user');
        q.setSelection(sel.index + (q.getLength() - prima), 0, 'silent');
        avvisa(q);
    }

    return {
        // Mette il testo della bozza nell'editor (anche vuoto) e prende in mano l'incolla. Aspetta che Quill sia pronto
        // (fino a 5 s: in una scheda piena può partire tardi); false = non è mai partito.
        carica: async function (contenitore, html) {
            for (let i = 0; i < 100 && !quillDi(contenitore); i++) await new Promise(function (r) { setTimeout(r, 50); });
            const q = quillDi(contenitore);
            if (!q) return false;
            q.setContents([], 'silent');
            if (html) q.clipboard.dangerouslyPasteHTML(0, html, 'silent');
            q.history.clear();                // «annulla» non deve togliere il testo appena caricato
            if (!contenitore.__incollaGestito) {
                contenitore.__incollaGestito = true;
                q.root.addEventListener('paste', function (e) { incolla(q, e); }, true);
            }
            return true;
        }
    };
})();
