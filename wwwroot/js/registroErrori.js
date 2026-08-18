// Quello che va storto dalla parte JavaScript, portato nel registro su file.
//
// Serve perche' meta' del programma gira dentro la WebView e di quella meta' non sapevamo niente:
// la console del browser sulla macchina di chi usa il programma non esiste. Diagnosticando la
// chiusura improvvisa si vedevano solo gli effetti lato .NET, mai la causa.
//
// Il punto delicato e' il momento in cui serve. Quando il canale fra JavaScript e .NET muore, i
// clic non arrivano piu' e subito dopo la pagina si ricarica: un messaggio spedito in quell'istante
// si perderebbe. Percio' qui non si spedisce niente: si scrive in localStorage — che al
// ricaricamento e perfino al riavvio sopravvive — e la coda se la viene a prendere .NET quando e'
// pronto. La riga scritta un istante prima della morte si legge un istante dopo.
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
    }

    // Consegna la coda e la svuota. Chiamata DA .NET, mai il contrario.
    //
    // La prima versione chiamava lei .NET, con un tentativo al secondo dall'avvio. Non parte piu'
    // niente: mandare un messaggio prima che Blazor abbia agganciato la pagina fa
    // «Cannot receive IPC messages when no page is attached», e l'avvio non si completa — schermo
    // nero, "Caricamento in corso" per sempre. Uno strumento di diagnosi che rompe il programma da
    // diagnosticare e' peggio di nessuno strumento.
    //
    // Chiamata da .NET il problema non esiste: se .NET puo' chiedere, la pagina c'e' per
    // definizione. E arriva comunque tutto, perche' cio' che conta e' scritto in localStorage e
    // aspetta li' quanto serve — anche attraverso un riavvio.
    function preleva() {
        try {
            const righe = localStorage.getItem(CHIAVE) || '[]';
            localStorage.removeItem(CHIAVE);
            return righe;
        } catch (_) {
            return '[]';
        }
    }

    window.addEventListener('error', function (e) {
        accoda('errore', e.message,
               (e.error && e.error.stack) || (e.filename + ':' + e.lineno + ':' + e.colno));
    }, true);

    window.addEventListener('unhandledrejection', function (e) {
        const r = e.reason;
        accoda('promessa', (r && r.message) || r, (r && r.stack) || '');
    });

    // Come e' arrivata qui questa pagina. Il registro lato .NET dice CHE la pagina si ricarica su
    // una rotta dell'applicazione, non PERCHE': "reload" e "navigate" sono due guasti diversi —
    // il primo e' la pagina che si riavvia da sola, il secondo e' qualcuno che ci porta.
    try {
        const n = performance.getEntriesByType('navigation')[0];
        accoda('pagina-caricata', location.href, 'tipo: ' + ((n && n.type) || 'sconosciuto'));
    } catch (_) { }

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

    return { accoda: accoda, preleva: preleva };
})();
