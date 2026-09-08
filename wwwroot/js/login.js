// Gestione TAB personalizzata per il form di login
window.loginFormHelper = {
    setupTabNavigation: function(focusPassword = false) {
        // Retry mechanism per aspettare che MudBlazor renderizzi gli input
        const trySetup = (attempts = 0) => {
            if (attempts > 20) {
                console.log('Login form inputs not found after 20 attempts');
                return;
            }

            // Trova tutti gli input del form di login
            const inputs = document.querySelectorAll('.login-input input');
            const emailInput = inputs[0];
            const passwordInput = inputs[1];
            const checkbox = document.querySelector('.mud-checkbox input');
            const submitButton = document.querySelector('button.login-button');

            if (!emailInput || !passwordInput) {
                // Gli input non sono ancora pronti, riprova tra 100ms
                setTimeout(() => trySetup(attempts + 1), 100);
                return;
            }

            const fields = [emailInput, passwordInput, checkbox, submitButton].filter(f => f);

            // Gestione TAB
            fields.forEach((field, index) => {
                if (field) {
                    field.addEventListener('keydown', function(e) {
                        if (e.key === 'Tab' && !e.shiftKey) {
                            e.preventDefault();
                            const nextIndex = (index + 1) % fields.length;
                            if (fields[nextIndex]) {
                                fields[nextIndex].focus();
                            }
                        } else if (e.key === 'Tab' && e.shiftKey) {
                            e.preventDefault();
                            const prevIndex = (index - 1 + fields.length) % fields.length;
                            if (fields[prevIndex]) {
                                fields[prevIndex].focus();
                            }
                        }
                    });
                }
            });

            // Gestione ENTER per checkbox specificamente
            if (checkbox) {
                checkbox.addEventListener('keydown', function(e) {
                    if (e.key === 'Enter' && submitButton) {
                        e.preventDefault();
                        // Evita una seconda gestione di Enter da MudBlazor/Blazor.
                        e.stopPropagation();
                        if (!e.repeat) submitButton.click();
                    }
                });
            }

            // La scelta arriva dal model Blazor, anche prima del rendering dell'email.
            const initialField = focusPassword ? passwordInput : emailInput;
            initialField.focus();
        };

        // Inizia il tentativo
        trySetup();
    }
};
