// Anteprima newsletter: scrive l'HTML dentro l'iframe dal DOM invece di usare srcdoc.
//
// Perche' non srcdoc: l'HTML di una newsletter e' lungo alcuni KB e pieno di virgolette e di
// a-capo. Passarlo come ATTRIBUTO significa affidarne l'integrita' all'escaping dell'attributo,
// e nella WebView il risultato e' un riquadro vuoto senza alcun errore. Scrivere nel documento
// dell'iframe e' il modo classico e non ha limiti di lunghezza ne' problemi di quoting.
window.newsletterPreview = {
    // Scrive il contenuto e ATTENDE che le immagini siano caricate.
    // Senza l'attesa l'anteprima appare subito ma con i riquadri vuoti e le immagini che
    // compaiono una alla volta: per qualche secondo sembra una newsletter composta male.
    scrivi: function (iframe, html, timeoutMs) {
        return new Promise(function (resolve) {
            if (!iframe) { resolve(false); return; }
            try {
                const doc = iframe.contentDocument || (iframe.contentWindow && iframe.contentWindow.document);
                if (!doc) { resolve(false); return; }

                doc.open();
                doc.write(html);
                doc.close();

                const imgs = Array.prototype.slice.call(doc.images || []);
                const mancanti = imgs.filter(function (i) { return !i.complete; });
                if (mancanti.length === 0) { resolve(true); return; }

                let rimaste = mancanti.length;
                let chiuso = false;
                const fine = function () {
                    if (chiuso) return;
                    if (--rimaste > 0) return;
                    chiuso = true;
                    resolve(true);
                };

                mancanti.forEach(function (i) {
                    // Anche l'errore conta come "finita": un'immagine irraggiungibile non deve
                    // tenere l'utente in attesa all'infinito.
                    i.addEventListener('load', fine, { once: true });
                    i.addEventListener('error', fine, { once: true });
                });

                // Rete lenta o immagine che non risponde: si procede comunque.
                setTimeout(function () { if (!chiuso) { chiuso = true; resolve(true); } },
                           timeoutMs || 10000);
            } catch (e) {
                console.error('newsletterPreview.scrivi', e);
                resolve(false);
            }
        });
    }
};
