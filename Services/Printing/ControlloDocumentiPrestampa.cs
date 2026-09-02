using GestioneViaggi.Components.Shared;
using GestioneViaggi.Models;
using GestioneViaggi.Services.CRUD;
using MudBlazor;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Il controllo che precede le stampe di partenza: rooming list, scheda data viaggio,
/// dettaglio data viaggio. Le altre stampe non lo usano — registro IVA e scadenzario non
/// hanno niente a che vedere con chi parte.
///
/// Sta qui e non dentro le tre chiamate perché era già successo, con i campi del mezzo,
/// che la stessa regola scritta in due form divergesse. Un punto solo: se cambia il modo
/// di avvisare, cambia per tutte e tre.
/// </summary>
public class ControlloDocumentiPrestampa
{
    private readonly DocumentiPartecipantiService _documenti;
    private readonly IDialogService _dialoghi;

    public ControlloDocumentiPrestampa(DocumentiPartecipantiService documenti, IDialogService dialoghi)
    {
        _documenti = documenti;
        _dialoghi = dialoghi;
    }

    /// <summary>
    /// Mostra l'avviso se qualcuno parte con un documento che non arriva alla fine del
    /// viaggio, e restituisce <c>false</c> solo se l'utente sceglie di annullare.
    ///
    /// Nessun problema trovato ⇒ nessuna finestra: chi lavora su partenze a posto non deve
    /// imparare a chiudere un dialogo per stampare.
    /// </summary>
    public async Task<bool> SiPuoStampareAsync(int dataViaggioId)
    {
        var daSistemare = await _documenti.DaSistemareAsync(dataViaggioId);
        if (daSistemare.Count == 0) return true;

        var parametri = new DialogParameters<AvvisoDocumentiDialog>
        {
            { x => x.Partecipanti, daSistemare }
        };
        var opzioni = new DialogOptions
        {
            BackdropClick = false,
            CloseButton = true,
            MaxWidth = MaxWidth.Medium,
            FullWidth = true
        };

        var dialogo = await _dialoghi.ShowAsync<AvvisoDocumentiDialog>(
            "Documenti da verificare", parametri, opzioni);
        var esito = await dialogo.Result;

        return esito is { Canceled: false };
    }

    /// <summary>
    /// Le righe da mettere in fondo al PDF, o lista vuota se non c'è niente da segnalare.
    /// La stampa esce comunque: la nota serve a chi la leggerà in ufficio o in viaggio,
    /// che potrebbe non essere la persona che l'ha lanciata.
    /// </summary>
    public Task<List<DocumentoNonValido>> DaSegnalareInStampaAsync(int dataViaggioId)
        => _documenti.DaSistemareAsync(dataViaggioId);
}
