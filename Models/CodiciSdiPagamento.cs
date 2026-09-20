namespace GestioneViaggi.Models;

/// <summary>
/// I codici di pagamento della fattura elettronica italiana, come li pretende il Sistema
/// di Interscambio nel blocco <c>DatiPagamento</c>.
/// </summary>
/// <remarks>
/// ⚠️ Sono scritti qui una volta sola perché sono un fatto esterno, non una scelta nostra:
/// li fissa l'Agenzia delle Entrate e valgono per chiunque fatturi in Italia. Chi deve
/// mostrarli, validarli o scriverli nell'XML parte da qui, così non nascono due elenchi
/// che divergono alla prima modifica.
/// Riferimento: specifiche tecniche FatturaPA, tabelle ModalitaPagamento e CondizioniPagamento.
/// </remarks>
public static class CodiciSdiPagamento
{
    /// <summary>Come si paga: da MP01 a MP23.</summary>
    public static readonly IReadOnlyList<(string Codice, string Descrizione)> Modalita = new[]
    {
        ("MP01", "Contanti"),
        ("MP02", "Assegno"),
        ("MP03", "Assegno circolare"),
        ("MP04", "Contanti presso Tesoreria"),
        ("MP05", "Bonifico"),
        ("MP06", "Vaglia cambiario"),
        ("MP07", "Bollettino bancario"),
        ("MP08", "Carta di pagamento"),
        ("MP09", "RID"),
        ("MP10", "RID utenze"),
        ("MP11", "RID veloce"),
        ("MP12", "RIBA"),
        ("MP13", "MAV"),
        ("MP14", "Quietanza erario"),
        ("MP15", "Giroconto su conti di contabilità speciale"),
        ("MP16", "Domiciliazione bancaria"),
        ("MP17", "Domiciliazione postale"),
        ("MP18", "Bollettino di c/c postale"),
        ("MP19", "SEPA Direct Debit"),
        ("MP20", "SEPA Direct Debit CORE"),
        ("MP21", "SEPA Direct Debit B2B"),
        ("MP22", "Trattenuta su somme già riscosse"),
        ("MP23", "PagoPA")
    };

    /// <summary>Quando si paga: TP01 a rate, TP02 in una volta sola, TP03 anticipo.</summary>
    public static readonly IReadOnlyList<(string Codice, string Descrizione)> Condizioni = new[]
    {
        ("TP01", "Pagamento a rate"),
        ("TP02", "Pagamento completo"),
        ("TP03", "Anticipo")
    };

    /// <summary>«MP05 — Bonifico», o il solo codice se non è in elenco.</summary>
    public static string DescriviModalita(string? codice)
    {
        if (string.IsNullOrWhiteSpace(codice)) return string.Empty;
        var voce = Modalita.FirstOrDefault(m => m.Codice == codice);
        return voce.Codice is null ? codice : $"{voce.Codice} — {voce.Descrizione}";
    }
}
