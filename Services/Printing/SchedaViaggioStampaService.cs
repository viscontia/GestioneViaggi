using Microsoft.Extensions.Logging;
using MudBlazor;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Il flusso unico della scheda data viaggio e del suo dettaglio: controllo dei documenti,
/// generazione del PDF, apertura.
///
/// Nasce per lo stesso motivo di <see cref="RoomingListStampaService"/>, e da un errore
/// concreto: il controllo sui documenti era stato agganciato alle <i>schermate</i>, ma la
/// scheda viaggio si lancia da <b>sette punti diversi</b> — il tab Partecipanti, il menu,
/// le due dashboard, l'elenco delle date. Il risultato è che l'avviso compariva da uno solo
/// di quei punti, ed è esattamente il difetto che la centralizzazione doveva togliere.
///
/// Chi deve stampare una scheda viaggio chiama questo, e non compone più il flusso a mano.
/// </summary>
public class SchedaViaggioStampaService
{
    private readonly ITravelPrintService _dati;
    private readonly ControlloDocumentiPrestampa _documenti;
    private readonly IPdfOpenerService _pdf;
    private readonly ISnackbar _snackbar;
    private readonly ILogger<SchedaViaggioStampaService> _logger;

    public SchedaViaggioStampaService(
        ITravelPrintService dati,
        ControlloDocumentiPrestampa documenti,
        IPdfOpenerService pdf,
        ISnackbar snackbar,
        ILogger<SchedaViaggioStampaService> logger)
    {
        _dati = dati;
        _documenti = documenti;
        _pdf = pdf;
        _snackbar = snackbar;
        _logger = logger;
    }

    /// <summary>
    /// Stampa la scheda di una partenza. Con <paramref name="dettagliata"/> esce la versione
    /// col dettaglio dei partecipanti.
    /// </summary>
    /// <returns>false se non si è stampato: dati non validi, avviso annullato, o errore.</returns>
    public async Task<bool> StampaAsync(int dataViaggioId, bool dettagliata = false)
    {
        if (dataViaggioId <= 0)
        {
            _snackbar.Add("Impossibile stampare: partenza non valida", Severity.Error);
            return false;
        }

        // Chi parte con un documento che non arriva alla fine del viaggio. Non blocca:
        // si può proseguire, ma chi preferisce sistemare prima annulla di qui.
        if (!await _documenti.SiPuoStampareAsync(dataViaggioId)) return false;

        try
        {
            var data = await _dati.GetPrintDataAsync(dataViaggioId);

            var fileName = PdfFileNameHelper.GetTravelSheetFileName(data.Header, detailed: dettagliata);
            var outputPath = Path.Combine(_pdf.GetPdfOutputFolder(), fileName);

            if (dettagliata)
                await ViaggiPrinter.GenerateDetailedPdfAsync(data, outputPath);
            else
                await ViaggiPrinter.GeneratePdfAsync(data, outputPath);

            await _pdf.OpenPdfAsync(outputPath,
                dettagliata ? "Stampa Dettagliata Completata" : "Stampa Completata");
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Scheda viaggio {Id}: stampa fallita", dataViaggioId);
            _snackbar.Add($"Errore stampa: {ex.Message}", Severity.Error);
            return false;
        }
    }
}
