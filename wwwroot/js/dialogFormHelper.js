// Gestione TAB personalizzata per i MudDialog form
// Risolve il problema del FocusTrap che blocca la navigazione TAB nei dialog
window.dialogFormHelper = {
    setupTabNavigation: function(dialogSelector = '.mud-dialog-content') {
        // Retry mechanism per aspettare che MudBlazor renderizzi gli input
        const trySetup = (attempts = 0) => {
            if (attempts > 20) {
                console.log('Dialog form inputs not found after 20 attempts');
                return;
            }

            // Trova il contenitore del dialog
            const dialogContent = document.querySelector(dialogSelector);
            if (!dialogContent) {
                setTimeout(() => trySetup(attempts + 1), 100);
                return;
            }

            // Trova tutti gli input, select, numeric fields all'interno del dialog
            // MudBlazor wrappa gli input in div con classe .mud-input-slot
            const allInputs = dialogContent.querySelectorAll('input:not([type="hidden"]):not([disabled]), select:not([disabled]), textarea:not([disabled])');

            if (allInputs.length === 0) {
                // Gli input non sono ancora pronti, riprova tra 100ms
                setTimeout(() => trySetup(attempts + 1), 100);
                return;
            }

            // Filtra solo gli input visibili e focusabili
            const fields = Array.from(allInputs).filter(input => {
                const rect = input.getBoundingClientRect();
                return rect.width > 0 && rect.height > 0; // Solo elementi visibili
            });

            console.log(`Dialog TAB setup: found ${fields.length} focusable fields`);

            // Gestione TAB personalizzata
            fields.forEach((field, index) => {
                // Rimuovi eventuale listener precedente per evitare duplicati
                field.removeEventListener('keydown', field._tabHandler);

                // Crea il nuovo handler
                const tabHandler = function(e) {
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

            // Focus automatico sul primo campo
            if (fields.length > 0) {
                setTimeout(() => {
                    fields[0].focus();
                    console.log('Dialog TAB navigation setup complete - focus set on first field');
                }, 150);
            }
        };

        // Inizia il tentativo
        trySetup();
    },

    // Cleanup quando il dialog viene chiuso
    cleanup: function(dialogSelector = '.mud-dialog-content') {
        const dialogContent = document.querySelector(dialogSelector);
        if (!dialogContent) return;

        const allInputs = dialogContent.querySelectorAll('input, select, textarea');
        allInputs.forEach(input => {
            if (input._tabHandler) {
                input.removeEventListener('keydown', input._tabHandler);
                delete input._tabHandler;
            }
        });
        console.log('Dialog TAB handlers cleaned up');
    }
};
