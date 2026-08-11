using GestioneViaggi.Models.Web;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Aggancia un blocco di newsletter a una partenza, riempiendolo con i dati di quel tour.
/// </summary>
/// <remarks>
/// Serve in tre momenti che devono comportarsi allo stesso modo: quando si sceglie il tour di un
/// riquadro, quando si sceglie il tour a cui punta un pulsante, e quando una newsletter creata da
/// un modello va riagganciata alla partenza giusta. Erano due copie della stessa sequenza dentro
/// la form dei blocchi; la terza avrebbe fatto tre.
/// </remarks>
public sealed class NewsletterTourApplicatore
{
    private readonly NewsletterRenderService _render;

    public NewsletterTourApplicatore(NewsletterRenderService render) => _render = render;

    /// <summary>Cosa fare dei testi gia' presenti nel blocco.</summary>
    public enum ModoTesti
    {
        /// <summary>Sovrascrive con quelli del tour.</summary>
        Sostituisci,

        /// <summary>Riempie solo i campi vuoti: aiuta senza cancellare quello che l'operatore ha scritto.</summary>
        SoloSeVuoti
    }

    /// <param name="Applicato">false = il blocco non e' stato toccato.</param>
    /// <param name="Errore">Perche' non si e' potuto applicare. Da mostrare all'utente.</param>
    /// <param name="InBozza">La scheda web del tour non e' pubblicata: il collegamento non funziona ancora.</param>
    /// <param name="SenzaSito">Non si e' potuto comporre il collegamento (sito dell'azienda non configurato).</param>
    public sealed record Esito(bool Applicato, string? Errore, bool InBozza, bool SenzaSito)
    {
        public static Esito Fallito(string errore) => new(false, errore, false, false);
    }

    /// <summary>Etichetta di partenza del pulsante, quando l'utente non ne ha scritta una.</summary>
    public const string EtichettaTour = "Vai alla pagina del Tour";

    public async Task<Esito> ApplicaAsync(WebNewsletterBlocco b, int dataViaggioId, ModoTesti modo)
    {
        // Su un pulsante del tour interessa solo il collegamento: scaricare e convertire
        // l'immagine di copertina sarebbe lavoro buttato.
        var soloCollegamento = b.Tipo == "pulsante";

        var dati = await _render.GetDatiTourAsync(dataViaggioId, b.AziendaId,
                                                  convertiImmagine: !soloCollegamento);
        if (dati is null)
        {
            return Esito.Fallito(
                "Questa partenza non ha una scheda di contenuti web: creala prima di inserirla in newsletter.");
        }

        if (soloCollegamento && dati.LinkCompleto is null)
        {
            return Esito.Fallito(
                "Non è stato possibile comporre il collegamento a quel tour (scheda web assente o sito non configurato).");
        }

        // Dati strutturali: si aggiornano sempre, perche' sono il legame col tour scelto.
        b.DataViaggioIdFk = dataViaggioId;
        b.LinkUrl = dati.LinkCompleto;
        if (string.IsNullOrWhiteSpace(b.LinkEtichetta)) b.LinkEtichetta = EtichettaTour;

        if (!soloCollegamento)
        {
            b.ImmagineUrl = dati.ImmagineUrl;
            b.ImmagineStoragePath = dati.ImmagineStoragePath;

            if (modo == ModoTesti.Sostituisci)
            {
                b.Titolo = dati.Titolo;
                b.Sottotitolo = dati.Periodo;
                b.ImmagineAlt = dati.Titolo;
                if (!string.IsNullOrWhiteSpace(dati.Testo)) b.CorpoHtml = $"<p>{dati.Testo}</p>";
            }
            else
            {
                if (string.IsNullOrWhiteSpace(b.Titolo)) b.Titolo = dati.Titolo;
                if (string.IsNullOrWhiteSpace(b.Sottotitolo)) b.Sottotitolo = dati.Periodo;
                if (string.IsNullOrWhiteSpace(b.ImmagineAlt)) b.ImmagineAlt = dati.Titolo;
                if (string.IsNullOrWhiteSpace(b.CorpoHtml) && !string.IsNullOrWhiteSpace(dati.Testo))
                    b.CorpoHtml = $"<p>{dati.Testo}</p>";
            }
        }

        return new Esito(true, null, InBozza: !dati.Pubblicato,
                         SenzaSito: string.IsNullOrWhiteSpace(dati.LinkCompleto));
    }
}
