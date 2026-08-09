// Anteprima newsletter: scrive l'HTML dentro l'iframe dal DOM invece di usare srcdoc.
//
// Perche' non srcdoc: l'HTML di una newsletter e' lungo alcuni KB e pieno di virgolette e di
// a-capo. Passarlo come ATTRIBUTO significa affidarne l'integrita' all'escaping dell'attributo,
// e nella WebView il risultato e' un riquadro vuoto senza alcun errore. Scrivere nel documento
// dell'iframe e' il modo classico e non ha limiti di lunghezza ne' problemi di quoting.
window.newsletterPreview = {
    scrivi: function (iframe, html) {
        if (!iframe) return false;
        try {
            const doc = iframe.contentDocument || (iframe.contentWindow && iframe.contentWindow.document);
            if (!doc) return false;
            doc.open();
            doc.write(html);
            doc.close();
            return true;
        } catch (e) {
            console.error('newsletterPreview.scrivi', e);
            return false;
        }
    }
};
