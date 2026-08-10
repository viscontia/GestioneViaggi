using GestioneViaggi.Components.Shared;
using Microsoft.Extensions.Logging;
using MudBlazor;
using Color = MudBlazor.Color;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Unico punto da cui si stampa una rooming list: lettura dati, controlli sugli abbinamenti,
/// generazione del PDF e apertura.
/// </summary>
/// <remarks>
/// <para>Lo stesso flusso era ripetuto in <b>cinque</b> punti (menu, gestione partecipanti, elenco
/// date, le due dashboard). Aggiungere i controlli in cinque copie avrebbe significato cinque
/// occasioni di dimenticarsene una, e la sesta schermata sarebbe nata senza.</para>
/// <para><b>Le regole sugli abbinamenti stanno qui</b>, non nelle schermate:
/// <list type="bullet">
///   <item>nessun cliente abbinato → non si stampa e si spiega perché;</item>
///   <item>alcuni abbinati e altri no → si chiede conferma, e il PDF riporta quanti mancano.</item>
/// </list></para>
/// </remarks>
public sealed class RoomingListStampaService
{
    private readonly IRoomingListPrintService _dati;
    private readonly IPdfOpenerService _pdf;
    private readonly IDialogService _dialoghi;
    private readonly ISnackbar _snackbar;
    private readonly ILogger<RoomingListStampaService> _logger;

    public RoomingListStampaService(
        IRoomingListPrintService dati, IPdfOpenerService pdf, IDialogService dialoghi,
        ISnackbar snackbar, ILogger<RoomingListStampaService> logger)
    {
        _dati = dati; _pdf = pdf; _dialoghi = dialoghi; _snackbar = snackbar; _logger = logger;
    }

    /// <summary>
    /// Stampa la rooming list di una partenza. Restituisce false se non si è stampato — perché
    /// non c'era nulla da stampare o perché l'utente ha annullato.
    /// </summary>
    public async Task<bool> StampaAsync(int dataViaggioId)
    {
        RoomingListPrintDTO data;
        try
        {
            data = await _dati.GetRoomingListDataAsync(dataViaggioId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Rooming list {Id}: lettura dati fallita", dataViaggioId);
            _snackbar.Add($"Errore stampa Rooming List: {ex.Message}", Severity.Error);
            return false;
        }

        // Nessun partecipante: non e' un problema di abbinamenti, non c'e' proprio nessuno.
        if (data.TotalParticipants == 0)
        {
            _snackbar.Add("Questa partenza non ha partecipanti: non c'è nulla da stampare.", Severity.Warning);
            return false;
        }

        // Nessun abbinamento: il prospetto uscirebbe con l'elenco dei nominativi e nessuna camera,
        // cioe' un documento che sembra una rooming list ma non lo e'.
        if (data.NessunAbbinamento)
        {
            _snackbar.Add(
                $"Nessuno dei {data.TotalParticipants} clienti è abbinato a una camera: la rooming list non può essere stampata. " +
                "Assegna le camere dalla gestione partecipanti.", Severity.Warning);
            return false;
        }

        // Abbinamenti parziali: si puo' stampare, ma chi lo fa deve saperlo prima.
        if (data.AbbinamentiParziali)
        {
            var quanti = data.ClientiNonAbbinati == 1
                ? "1 cliente non è abbinato a una camera"
                : $"{data.ClientiNonAbbinati} clienti non sono abbinati a una camera";

            var parametri = new DialogParameters<DeleteConfirmationDialog>
            {
                { x => x.Title, "Abbinamenti incompleti" },
                { x => x.ContentText, $"Ci sono {quanti} su {data.TotalParticipants}: vuoi proseguire lo stesso? " +
                                      "Il prospetto lo riporterà in evidenza." },
                { x => x.ButtonText, "Stampa lo stesso" },
                { x => x.Color, Color.Warning }
            };
            var dlg = await _dialoghi.ShowAsync<DeleteConfirmationDialog>("Abbinamenti incompleti", parametri,
                new DialogOptions { BackdropClick = false });
            if ((await dlg.Result)!.Canceled) return false;
        }

        try
        {
            var cartella = _pdf.GetPdfOutputFolder();
            var nomeFile = PdfFileNameHelper.GetRoomingListFileName(data.Header);
            var percorso = Path.Combine(cartella, nomeFile);

            if (File.Exists(percorso)) File.Delete(percorso);

            await RoomingListPrinter.GeneratePdfAsync(data, percorso);
            await _pdf.OpenPdfAsync(percorso, "Stampa Rooming List Completata");
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Rooming list {Id}: generazione PDF fallita", dataViaggioId);
            _snackbar.Add($"Errore stampa Rooming List: {ex.Message}", Severity.Error);
            return false;
        }
    }
}
