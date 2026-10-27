// L'editor HTML delle bozze (Components/Shared/EditorHtmlBozza.razor): carica e incolla PASSANDO DAL MODELLO di Quill.
//
// Perché: Blazored.TextEditor carica il testo scrivendo root.innerHTML, cioè nella pagina e non nel modello di Quill;
// e l'incolla di Quill 1.3.6 (passa da una casella nascosta) nella WebView del gestionale può lasciare il testo nella
// pagina ma non nel modello. Quando pagina e modello non coincidono, alla prima modifica Quill ridisegna dal suo
// modello e il resto sparisce: prova di Adriano del 2026-10-27 sulle FAQ (testo incollato con Cmd+V da una pagina web,
// sparito al primo tasto). Qui il testo entra sempre con i comandi di Quill; l'incolla lo facciamo noi dagli appunti,
// e se gli appunti arrivano vuoti lasciamo incollare la WebView e poi rifacciamo il modello da ciò che c'è sulla pagina.
// Ogni incolla lascia una riga di diagnosi nel registro del gestionale (solo lunghezze, mai il testo).

window.editorHtmlBozza = (function () {
    function quillDi(contenitore) {
        const el = contenitore && contenitore.querySelector('.ql-container');
        return el && el.__quill ? el.__quill : null;
    }

    function diagnosi(contenitore, messaggio) {
        try { if (contenitore.__dotnet) contenitore.__dotnet.invokeMethodAsync('Diagnosi', messaggio); } catch (_) { }
    }

    // Avvisa EditorHtmlBozza che il testo è cambiato (ascolta «input» sul suo contenitore).
    function avvisa(q) {
        q.root.dispatchEvent(new Event('input', { bubbles: true }));
    }

    function incolla(contenitore, q, e) {
        const dati = e.clipboardData;
        const html = dati ? dati.getData('text/html') : '';
        const testo = dati ? dati.getData('text/plain') : '';
        const tipi = dati && dati.types ? Array.prototype.join.call(dati.types, ',') : '(nessuno)';
        e.stopImmediatePropagation();         // l'incolla di Quill non parte: lo gestiamo noi, in un modo o nell'altro
        const prima = q.getLength();
        if (html || testo) {
            e.preventDefault();
            // il punto del cursore (anche tornando da un altro campo Quill ricorda l'ultimo); se non c'è mai stato, in fondo
            const sel = q.getSelection(true) || { index: Math.max(0, q.getLength() - 1), length: 0 };
            if (sel.length) q.deleteText(sel.index, sel.length, 'user');
            const base = q.getLength();
            if (html) q.clipboard.dangerouslyPasteHTML(sel.index, html, 'user');
            else q.insertText(sel.index, testo, 'user');
            q.setSelection(sel.index + (q.getLength() - base), 0, 'silent');
            avvisa(q);
            diagnosi(contenitore, 'incolla dagli appunti (tipi ' + tipi + ', html ' + html.length + ', testo ' + testo.length +
                '): lunghezza ' + prima + ' → ' + q.getLength());
            return;
        }
        // appunti vuoti per lo script: incolla la WebView; subito dopo il modello si rifà da ciò che c'è sulla pagina
        setTimeout(function () {
            const sel = q.getSelection();
            const pagina = q.root.innerHTML;
            q.setContents(q.clipboard.convert(pagina), 'user');
            if (sel) q.setSelection(Math.min(q.getLength() - 1, sel.index + sel.length), 0, 'silent');
            avvisa(q);
            diagnosi(contenitore, 'incolla della WebView (appunti vuoti per lo script, tipi ' + tipi +
                '): modello rifatto dalla pagina, lunghezza ' + prima + ' → ' + q.getLength());
        }, 0);
    }

    return {
        // Mette il testo della bozza nell'editor (anche vuoto) e prende in mano l'incolla. Aspetta che Quill sia pronto
        // (fino a 5 s: in una scheda piena può partire tardi); false = non è mai partito. dotnet: per la diagnosi.
        carica: async function (contenitore, html, dotnet) {
            for (let i = 0; i < 100 && !quillDi(contenitore); i++) await new Promise(function (r) { setTimeout(r, 50); });
            const q = quillDi(contenitore);
            if (!q) return false;
            contenitore.__dotnet = dotnet || null;
            q.setContents([], 'silent');
            if (html) q.clipboard.dangerouslyPasteHTML(0, html, 'silent');
            q.history.clear();                // «annulla» non deve togliere il testo appena caricato
            if (!contenitore.__incollaGestito) {
                contenitore.__incollaGestito = true;
                q.root.addEventListener('paste', function (e) { incolla(contenitore, q, e); }, true);
            }
            return true;
        },

        // Quando l'editor sparisce: niente più chiamate verso .NET da un oggetto liberato.
        stacca: function (contenitore) {
            if (contenitore) contenitore.__dotnet = null;
        }
    };
})();
