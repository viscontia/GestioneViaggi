// Quello che va storto dalla parte JavaScript, portato nel registro su file.
//
// Serve perche' meta' del programma gira dentro la WebView e di quella meta' non sapevamo niente:
// la console del browser sulla macchina di chi usa il programma non esiste. Diagnosticando la
// chiusura improvvisa si vedevano solo gli effetti lato .NET, mai la causa.
//
// Il punto delicato e' il momento in cui serve. Quando il canale fra JavaScript e .NET muore, i
// clic non arrivano piu' e subito dopo la pagina si ricarica: un messaggio spedito in quell'istante
// si perderebbe. Percio' si accoda PRIMA in localStorage — che al ricaricamento sopravvive — e si
// svuota la coda appena il canale c'e'. Cosi' la riga scritta un istante prima della morte si
// legge un istante dopo.
//
// Va caricato per primo, prima di blazor.webview.js: deve poter registrare anche cio' che accade
// durante l'avvio.
//
// Solo diagnostica: non cambia il comportamento di niente.

window.registroErrori = (function () {
    const CHIAVE = 'gv-errori-js';
    const MASSIMO = 50;   // oltre, si buttano le piu' vecchie: la coda non deve crescere all'infinito

    function accoda(tipo, messaggio, dettaglio) {
        try {
            const righe = JSON.parse(localStorage.getItem(CHIAVE) || '[]');
            righe.push({
                q: new Date().toISOString(),
                tipo: tipo,
                messaggio: String(messaggio),
                dettaglio: String(dettaglio || '')
            });
            while (righe.length > MASSIMO) righe.shift();
            localStorage.setItem(CHIAVE, JSON.stringify(righe));
        } catch (_) { /* archivio pieno o non disponibile: si perde la riga, non la pagina */ }

        svuota();
    }

    // Manda a .NET quello che c'e' in coda, e la ripulisce solo a consegna avvenuta: se il canale
    // e' morto la coda resta, e riparte al prossimo avvio.
    function svuota() {
        if (typeof DotNet === 'undefined' || !DotNet.invokeMethodAsync) return;

        let righe;
        try { righe = JSON.parse(localStorage.getItem(CHIAVE) || '[]'); } catch (_) { return; }
        if (!righe.length) return;

        DotNet.invokeMethodAsync('GestioneViaggi', 'RegistraErroriJs', JSON.stringify(righe))
            .then(function () { try { localStorage.removeItem(CHIAVE); } catch (_) { } })
            .catch(function () { /* canale non pronto: si riprova al prossimo giro */ });
    }

    window.addEventListener('error', function (e) {
        accoda('errore', e.message,
               (e.error && e.error.stack) || (e.filename + ':' + e.lineno + ':' + e.colno));
    }, true);

    window.addEventListener('unhandledrejection', function (e) {
        const r = e.reason;
        accoda('promessa', (r && r.message) || r, (r && r.stack) || '');
    });

    // La pagina sta per andarsene. E' la riga piu' importante di tutte: se lo schermo nero nasce da
    // una NAVIGAZIONE della WebView — e non da un'eccezione — questo e' l'unico posto dove si vede,
    // insieme all'indirizzo da cui si stava partendo.
    window.addEventListener('pagehide', function () {
        accoda('pagina-lasciata', location.href, 'la pagina sta per essere sostituita o ricaricata');
    });

    // Blazor mostra questo riquadro quando un'eccezione non gestita arriva fino a lui. Spesso non
    // si fa in tempo a leggerlo perche' la pagina si ricarica: qui resta scritto che e' comparso.
    document.addEventListener('DOMContentLoaded', function () {
        const riquadro = document.getElementById('blazor-error-ui');
        if (!riquadro) return;
        new MutationObserver(function () {
            if (riquadro.style.display && riquadro.style.display !== 'none') {
                accoda('blazor-error-ui', 'Blazor segnala un\'eccezione non gestita',
                       'il riquadro d\'errore e\' stato mostrato');
            }
        }).observe(riquadro, { attributes: true, attributeFilter: ['style'] });
    });

    // All'avvio la coda del giro precedente e' quella che racconta la morte. Il canale non c'e'
    // subito: si insiste per un po', poi si lascia perdere.
    let tentativi = 0;
    const attesa = setInterval(function () {
        svuota();
        if (++tentativi > 30) clearInterval(attesa);   // ~30 secondi
    }, 1000);

    return { accoda: accoda, svuota: svuota };
})();
