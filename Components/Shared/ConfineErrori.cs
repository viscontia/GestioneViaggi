using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Components.Shared;

/// <summary>
/// Confine d'errore che <b>scrive nel registro</b> quello che ferma.
/// </summary>
/// <remarks>
/// <see cref="ErrorBoundary"/> intercetta l'eccezione e mostra ErrorContent, ma non la registra da
/// nessuna parte: chiuso il messaggio a video, di quel guasto non resta traccia. Su un programma
/// che gira sulla macchina di chi lo usa e' la differenza fra una segnalazione utile e "si e'
/// chiuso da solo".
/// <para>Nasce da un difetto reale: l'applicazione tornava allo schermo nero con "Caricamento in
/// corso" mentre si inserivano le date di partenza. Il registro conteneva solo la conseguenza —
/// un'attesa di JavaScript completata due volte — e in fondo alla pila
/// <c>IpcSender.NotifyUnhandledException</c>: Blazor stava gia' segnalando un'eccezione non
/// gestita, che nessuno aveva scritto. Un'eccezione non gestita in un componente fa ricostruire
/// l'intero albero, cioe' riparte l'applicazione.</para>
/// <para>Il posto dove serviva non era la pagina — li' un confine c'era gia' — ma i
/// <b>dialoghi</b>: MudDialogProvider vive nel layout, fuori dal confine che avvolge il corpo
/// della pagina, quindi le finestre che apre non erano coperte da niente. Ed e' nei dialoghi che
/// si inserisce quasi tutto.</para>
/// </remarks>
public sealed class ConfineErrori : ErrorBoundary
{
    [Inject] private ILogger<ConfineErrori> Log { get; set; } = default!;

    /// <summary>Dove e' successo: finisce nel registro per distinguere le righe fra loro.</summary>
    [Parameter] public string Contesto { get; set; } = "";

    protected override Task OnErrorAsync(Exception exception)
    {
        // Livello Error: e' la soglia da cui il registro su file scrive davvero.
        Log.LogError(exception, "Eccezione non gestita fermata dal confine{Dove}",
                     string.IsNullOrWhiteSpace(Contesto) ? "" : $" — {Contesto}");
        return Task.CompletedTask;
    }
}
