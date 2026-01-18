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
            // MudBlazor wrappa gli input in div con classe .mud-input-slot
            const allInputs = dialogContent.querySelectorAll('input:not([type="hidden"]):not([disabled]):not([readonly]), select:not([disabled]), textarea:not([disabled])');

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

            // Focus automatico sul primo campo (SOLO se non è un refresh)
            if (fields.length > 0 && !skipAutoFocus) {
                setTimeout(() => {
                    fields[0].focus();
                    console.log('Dialog TAB navigation setup complete - focus set on first field');
                }, 150);
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
