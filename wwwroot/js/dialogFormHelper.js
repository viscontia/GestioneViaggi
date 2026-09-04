// Gestione TAB personalizzata per i MudDialog form
// Risolve il problema del FocusTrap che blocca la navigazione TAB nei dialog
window.dialogFormHelper = {
    setupTabNavigation: function (dialogSelector = '.mud-dialog-content', skipAutoFocus = false) {
        // Retry mechanism per aspettare che MudBlazor renderizzi gli input
        const trySetup = (attempts = 0) => {
            if (attempts > 20) {
                console.log('Dialog form inputs not found after 20 attempts');
                return;
            }

            // Trova il contenitore del dialog (prendi l'ultimo se ce ne sono multipli, per gestire nested dialogs)
            const dialogs = document.querySelectorAll(dialogSelector);
            const dialogContent = dialogs.length > 0 ? dialogs[dialogs.length - 1] : null;

            if (!dialogContent) {
                setTimeout(() => trySetup(attempts + 1), 100);
                return;
            }

            // Trova tutti gli input, select, numeric fields all'interno del dialog
            // MudSelect usa un div con classe .mud-input-slot e tabindex="0" OPPURE un input readonly
            // Rimossa esclusione readonly perché MudSelect usa input readonly nascosti o visibili che devono ricevere focus
            const allInputs = dialogContent.querySelectorAll('input:not([type="hidden"]):not([disabled]), select:not([disabled]), textarea:not([disabled]), .mud-input-slot[tabindex="0"]:not([disabled])');

            if (allInputs.length === 0) {
                // Gli input non sono ancora pronti, riprova tra 100ms
                setTimeout(() => trySetup(attempts + 1), 100);
                return;
            }

            // Filtra solo gli input visibili e focusabili, escludendo elementi ausiliari di MudBlazor
            const fields = Array.from(allInputs).filter(input => {
                // Escludi se è figlio di un button o di elementi MudBlazor ausiliari
                if (input.closest('button, .mud-input-adornment, .mud-picker-calendar')) {
                    return false;
                }
                
                // Escludi se ha attributo tabindex negativo
                const tabIndex = input.getAttribute('tabindex');
                if (tabIndex && parseInt(tabIndex) < 0) {
                    return false;
                }
                
                const rect = input.getBoundingClientRect();
                return rect.width > 0 && rect.height > 0; // Solo elementi visibili
            });

            console.log(`Dialog TAB setup: found ${fields.length} focusable fields`);

            // Gestione TAB personalizzata
            fields.forEach((field, index) => {
                // Rimuovi eventuale listener precedente per evitare duplicati
                field.removeEventListener('keydown', field._tabHandler);

                // Crea il nuovo handler
                const tabHandler = function (e) {
                    if (e.key === 'Tab' && !e.shiftKey) {
                        // TAB forward
                        e.preventDefault();
                        const nextIndex = (index + 1) % fields.length;
                        if (fields[nextIndex]) {
                            fields[nextIndex].focus();
                        }
                    } else if (e.key === 'Tab' && e.shiftKey) {
                        // SHIFT+TAB backward
                        e.preventDefault();
                        const prevIndex = (index - 1 + fields.length) % fields.length;
                        if (fields[prevIndex]) {
                            fields[prevIndex].focus();
                        }
                    }
                };

                // Salva il riferimento all'handler per poterlo rimuovere in futuro
                field._tabHandler = tabHandler;
                field.addEventListener('keydown', tabHandler);
            });

            // Focus automatico sul primo campo (SOLO se non è un refresh).
            //
            // Un tentativo solo non basta: MudBlazor prende il fuoco per sé mentre apre il
            // dialogo, e lo fa DOPO di noi — il campo si illuminava per un istante e poi il
            // cursore spariva. Si riprova a intervalli finché il fuoco non è dentro al dialogo.
            //
            // La condizione "è già dentro" non è una precauzione qualsiasi: è ciò che impedisce
            // di calpestare i dialoghi che scelgono da sé quale campo attivare (molti lo fanno da
            // C# a +300ms). Se il fuoco è già su un loro campo, qui non si tocca niente.
            if (fields.length > 0 && !skipAutoFocus) {
                const assicuraFocus = (tentativo = 0) => {
                    // Si insiste finche' il fuoco non e' su QUESTO campo, non finche' e'
                    // genericamente dentro al dialogo: MudBlazor lo mette sulla superficie del
                    // dialogo o su un altro campo, che stanno comunque "dentro", e con la
                    // condizione larga si rinunciava proprio nel caso da correggere.
                    if (document.activeElement === fields[0]) return;
                    if (tentativo > 4) {
                        console.log('Dialog focus: rinuncio dopo 5 tentativi');
                        return;
                    }
                    fields[0].focus();
                    setTimeout(() => assicuraFocus(tentativo + 1), 150);
                };
                setTimeout(() => assicuraFocus(), 150);
            } else if (skipAutoFocus) {
                console.log('Dialog TAB navigation setup complete - auto-focus skipped (refresh mode)');
            }
        };

        // Inizia il tentativo
        trySetup();
    },

    // Cleanup quando il dialog viene chiuso
    cleanup: function (dialogSelector = '.mud-dialog-content') {
        const dialogs = document.querySelectorAll(dialogSelector);
        const dialogContent = dialogs.length > 0 ? dialogs[dialogs.length - 1] : null;

        if (!dialogContent) return;

        const allInputs = dialogContent.querySelectorAll('input, select, textarea');
        allInputs.forEach(input => {
            if (input._tabHandler) {
                input.removeEventListener('keydown', input._tabHandler);
                delete input._tabHandler;
            }
        });
        console.log('Dialog TAB handlers cleaned up');
    },

    // Filtro per campi telefono: accetta solo numeri, +, spazi, -, .
    setupPhoneInputFilter: function (inputElement) {
        if (!inputElement) {
            console.warn('Phone input filter: element not found');
            return;
        }

        const phoneInputHandler = function (e) {
            const allowedChars = /[0-9+\s\-\.]/g;
            const currentValue = e.target.value;
            const filteredValue = currentValue.split('').filter(char => allowedChars.test(char)).join('');

            if (currentValue !== filteredValue) {
                e.target.value = filteredValue;
                // Trigger change event per aggiornare il binding Blazor
                e.target.dispatchEvent(new Event('change', { bubbles: true }));
            }
        };

        inputElement._phoneInputHandler = phoneInputHandler;
        inputElement.addEventListener('input', phoneInputHandler);
        console.log('Phone input filter attached');
    },

    // Nei campi data si battono solo cifre e barre
    //
    // Il campo accetta la sola forma gg/mm/aaaa (vedi ConvertitoreDataFlessibile), quindi
    // tutto il resto verrebbe rifiutato dopo: meglio non farlo nemmeno digitare.
    //
    // UN SOLO ascoltatore su tutto il documento, non uno per campo. Vale cosi' per i
    // dialoghi e per le pagine, per i 26 campi che esistono oggi e per quelli che
    // verranno aggiunti domani — basta che abbiano la classe `campo-data`.
    //
    // Il filtro sta QUI, in JavaScript, e non torna a .NET per ogni tasto: e' la
    // differenza con la vecchia DateMask, che rimandava ogni battuta al codice C# e
    // riposizionava il cursore con un secondo viaggio — su MacCatalyst 4-8 chiamate per
    // tasto, e digitando in fretta le cifre slittavano, fino a scrivere in produzione una
    // data che nessuno aveva battuto. Qui il tasto non ammesso viene semplicemente
    // ignorato dal browser, e nessun altro ne sa niente.
    _filtroDateInstallato: false,

    installaFiltroDate: function () {
        if (this._filtroDateInstallato) return;
        this._filtroDateInstallato = true;

        const dentroUnCampoData = (elemento) =>
            elemento && elemento.tagName === 'INPUT' && elemento.closest('.campo-data');

        document.addEventListener('keydown', function (e) {
            if (!dentroUnCampoData(e.target)) return;

            // Le combinazioni di sistema (copia, incolla, seleziona tutto) e i tasti di
            // spostamento non si toccano: filtrarli renderebbe il campo inutilizzabile
            // per chi lavora di tastiera.
            if (e.ctrlKey || e.metaKey || e.altKey) return;
            if (e.key.length > 1) return;   // Backspace, Tab, frecce, Invio…

            if (!/[0-9/]/.test(e.key)) e.preventDefault();
        }, true);

        document.addEventListener('paste', function (e) {
            if (!dentroUnCampoData(e.target)) return;

            // Chi copia «18-04-2036» da un'altra parte non deve ritrovarselo dentro in
            // una forma che il campo non sa leggere: si incolla ripulito.
            const testo = (e.clipboardData || window.clipboardData)?.getData('text') ?? '';
            if (/[^0-9/]/.test(testo)) {
                e.preventDefault();
                const pulito = testo.replace(/[^0-9/]/g, '');
                if (pulito) document.execCommand('insertText', false, pulito);
            }
        }, true);

        console.log('Filtro campi data installato (cifre e barra)');
    },

    // Setup filtro per tutti i campi telefono in un dialog
    setupPhoneFilters: function (dialogSelector = '.mud-dialog-content') {
        const trySetup = (attempts = 0) => {
            if (attempts > 20) {
                console.log('Phone input fields not found after 20 attempts');
                return;
            }

            const dialogs = document.querySelectorAll(dialogSelector);
            const dialogContent = dialogs.length > 0 ? dialogs[dialogs.length - 1] : null;

            if (!dialogContent) {
                setTimeout(() => trySetup(attempts + 1), 100);
                return;
            }

            // Trova tutti gli input di tipo telefono
            const phoneInputs = dialogContent.querySelectorAll('input[type="tel"]');

            if (phoneInputs.length === 0) {
                setTimeout(() => trySetup(attempts + 1), 100);
                return;
            }

            phoneInputs.forEach(input => {
                window.dialogFormHelper.setupPhoneInputFilter(input);
            });

            console.log(`Phone filters setup: found ${phoneInputs.length} phone fields`);
        };

        trySetup();
    }
};
