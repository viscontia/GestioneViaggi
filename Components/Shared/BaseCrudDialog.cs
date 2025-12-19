using Microsoft.AspNetCore.Components;
using MudBlazor;

namespace GestioneViaggi.Components.Shared
{
    /// <summary>
    /// Classe base per tutti i CRUD dialog.
    ///
    /// IMPORTANTE - TAB NAVIGATION:
    /// Il FocusTrap di MudDialog blocca la navigazione TAB standard del browser.
    ///
    /// SOLUZIONE IMPLEMENTATA:
    /// - Tutti i dialog devono iniettare IJSRuntime e implementare IDisposable
    /// - In OnAfterRenderAsync(firstRender): chiamare await JS.InvokeVoidAsync("dialogFormHelper.setupTabNavigation")
    /// - In Dispose(): chiamare JS.InvokeVoidAsync("dialogFormHelper.cleanup")
    /// - Il JavaScript helper (dialogFormHelper.js) intercetta il TAB e forza il focus manualmente
    ///
    /// ESEMPIO:
    /// @inject IJSRuntime JS
    /// @implements IDisposable
    ///
    /// protected override async Task OnAfterRenderAsync(bool firstRender)
    /// {
    ///     if (firstRender)
    ///     {
    ///         try { await JS.InvokeVoidAsync("dialogFormHelper.setupTabNavigation"); }
    ///         catch (Exception ex) { Console.WriteLine($"Error: {ex.Message}"); }
    ///     }
    /// }
    ///
    /// public void Dispose()
    /// {
    ///     try { JS.InvokeVoidAsync("dialogFormHelper.cleanup"); }
    ///     catch { }
    /// }
    /// </summary>
    public abstract class BaseCrudDialog<T> : ComponentBase
    {
        [CascadingParameter]
        protected IMudDialogInstance? DialogInstance { get; set; }

        /// <summary>
        /// Annulla il dialog senza salvare.
        /// </summary>
        protected void CancelDialog()
        {
            DialogInstance?.Cancel();
        }

        /// <summary>
        /// Chiude il dialog con un risultato.
        /// </summary>
        protected void CloseDialog(DialogResult result)
        {
            DialogInstance?.Close(result);
        }
    }
}
