namespace GestioneViaggi.Models;

/// <summary>
/// Un prefisso telefonico internazionale (tabella <c>ana_tel_pref_int</c>).
///
/// Il nome del paese non è salvato qui: viene da <c>eba_countries</c>, dove i 249
/// paesi stanno già con il loro nome italiano. Questa è solo la mappa paese → prefisso.
/// </summary>
public class PrefissoTelefonico
{
    /// <summary>Il prefisso come si compone, col «+»: è ciò che finisce in anagrafica.</summary>
    public string Codice { get; set; } = string.Empty;

    /// <summary>Sigla del paese (ISO 3166-1 alpha-2).</summary>
    public string Iso2 { get; set; } = string.Empty;

    /// <summary>Nome italiano del paese.</summary>
    public string Paese { get; set; } = string.Empty;

    /// <summary>«+39 Italia»: si cerca sia per numero sia per nome del paese.</summary>
    public string Descrizione { get; set; } = string.Empty;
}
