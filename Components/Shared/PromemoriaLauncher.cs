using GestioneViaggi.Services.Web;
using MudBlazor;

namespace GestioneViaggi.Components.Shared;

/// <summary>
/// Apre il promemoria all'apertura (L2): all'avvio dalla dashboard, a richiesta dal menu.
/// </summary>
public static class PromemoriaLauncher
{
    /// <summary>
    /// Apre la finestra e aspetta che si chiuda. Non si chiude cliccando fuori, con Esc o con la
    /// rotella: la regola è centrale (MudDialogProvider nei layout, dalla 2.2), qui si ribadisce.
    /// </summary>
    public static async Task MostraAsync(IDialogService dialogService, int aziendaId)
    {
        var parameters = new DialogParameters<PromemoriaDialog> { { x => x.AziendaId, aziendaId } };
        var options = new DialogOptions
        {
            BackdropClick = false,
            CloseOnEscapeKey = false,
            CloseButton = false,
            MaxWidth = MaxWidth.Large,
            FullWidth = true
        };
        var dialog = await dialogService.ShowAsync<PromemoriaDialog>("", parameters, options);
        await dialog.Result;
    }

    /// <summary>
    /// All'avvio, una volta per utente: solo se il promemoria è acceso per l'azienda, l'utente non
    /// l'ha nascosto per oggi e c'è almeno una riga. ⛔️ Se non c'è niente, la finestra non compare.
    /// </summary>
    public static async Task MostraAllAvvioSeServeAsync(
        IDialogService dialogService, PromemoriaService promemoria, WebAziendeFunzioniService funzioni,
        Guid utenteId, int aziendaId)
    {
        if (promemoria.GiaMostratoInQuestoAvvio(utenteId)) return;
        promemoria.SegnaMostrato(utenteId);

        if (!await funzioni.IsAttivaAsync(aziendaId, WebAziendeFunzioniService.FunzionePromemoria, defaultWhenMissing: true)) return;
        if (await promemoria.NascostoOggiAsync()) return;
        if ((await promemoria.ElencoAsync(aziendaId)).Count == 0) return;

        await MostraAsync(dialogService, aziendaId);
    }
}
