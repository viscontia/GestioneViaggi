namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Dati azienda estesi per intestazione fattura (emittente)
/// </summary>
public class InvoiceCompanyInfo
{
    public string RagioneSociale { get; set; } = string.Empty;
    public string FormaGiuridica { get; set; } = string.Empty;
    public string PartitaIva { get; set; } = string.Empty;
    public string? CodiceFiscale { get; set; }
    public string Telefono { get; set; } = string.Empty;
    public string? Pec { get; set; }
    public string? SitoWeb { get; set; }
    public string? CodiceSdi { get; set; }
    public byte[] LogoData { get; set; } = Array.Empty<byte>();

    // Sede principale
    public string Indirizzo { get; set; } = string.Empty;
    public string? NumeroCivico { get; set; }
    public string Cap { get; set; } = string.Empty;
    public string Comune { get; set; } = string.Empty;
    public string ProvinciaSigla { get; set; } = string.Empty;

    // REA
    public string? ReaNumero { get; set; }
    public string? ReaProvinciaSigla { get; set; }

    // Regime Fiscale
    public string? RegimeCodice { get; set; }
    public string? RegimeDescrizione { get; set; }
    public bool IsIvaDetraibile { get; set; } = true;

    // SDI - FatturaPA
    public string? RegimeCodiceSdi { get; set; }
    public string? TipoCassaSdi { get; set; }
    public decimal? CassaPrevPercentuale { get; set; }

    // Capitale Sociale
    public decimal? CapitaleSociale { get; set; }
    public bool SocioUnico { get; set; }
    public bool InLiquidazione { get; set; }

    // Computed
    public string IndirizzoCompleto => string.IsNullOrEmpty(NumeroCivico)
        ? Indirizzo
        : $"{Indirizzo}, {NumeroCivico}";

    public string CittaCompleta => $"{Cap} {Comune} ({ProvinciaSigla})";

    public string? ReaDisplay => !string.IsNullOrEmpty(ReaNumero) && !string.IsNullOrEmpty(ReaProvinciaSigla)
        ? $"REA {ReaProvinciaSigla} - {ReaNumero}"
        : null;

    public string? CapitaleSocialeDisplay
    {
        get
        {
            if (!CapitaleSociale.HasValue) return null;
            var parts = new List<string> { $"Cap. Soc. EUR {CapitaleSociale:N2}" };
            if (SocioUnico) parts.Add("Socio Unico");
            if (InLiquidazione) parts.Add("In Liquidazione");
            return string.Join(" - ", parts);
        }
    }

    public bool IsForfettario => RegimeCodice == "FORFETTARIO";
}

/// <summary>
/// Dati cliente/controparte per sezione destinatario fattura
/// </summary>
public class InvoiceClientInfo
{
    public int Id { get; set; }
    public string RagioneSociale { get; set; } = string.Empty;
    public string? Indirizzo { get; set; }
    public string? Cap { get; set; }
    public string? Comune { get; set; }
    public string? ProvinciaSigla { get; set; }
    public string? PartitaIva { get; set; }
    public string? CodiceFiscale { get; set; }
    public string? CodiceSdi { get; set; }
    public string? Pec { get; set; }
    public bool FornitoreEstero { get; set; }

    public string IndirizzoCompleto
    {
        get
        {
            var parts = new List<string>();
            if (!string.IsNullOrEmpty(Indirizzo)) parts.Add(Indirizzo);
            var citta = new List<string>();
            if (!string.IsNullOrEmpty(Cap)) citta.Add(Cap);
            if (!string.IsNullOrEmpty(Comune)) citta.Add(Comune);
            if (!string.IsNullOrEmpty(ProvinciaSigla)) citta.Add($"({ProvinciaSigla})");
            if (citta.Any()) parts.Add(string.Join(" ", citta));
            return string.Join("\n", parts);
        }
    }
}

/// <summary>
/// Riga fattura (da mov_transazioni_righe JOIN ana_aliquote_iva)
/// </summary>
public class InvoiceLineItem
{
    public int RigaNumero { get; set; }
    public string RigaDescrizione { get; set; } = string.Empty;
    public string RigaTipo { get; set; } = "PRESTAZIONE";
    public decimal RigaImponibile { get; set; }
    public string? AliquotaIvaCodice { get; set; }
    public decimal? AliquotaIvaPercentuale { get; set; }
    public decimal RigaIvaValore { get; set; }
    public decimal RigaLordo { get; set; }
    public string? AliquotaIvaNatura { get; set; }

    public string AliquotaDisplay => AliquotaIvaPercentuale.HasValue && AliquotaIvaPercentuale > 0
        ? $"{AliquotaIvaPercentuale:0.##}%"
        : AliquotaIvaCodice ?? "-";

    public string TipoDisplay => RigaTipo switch
    {
        "PRESTAZIONE" => "Prestazione",
        "CASSA_PREV" => "Cassa Prev.",
        "BOLLO" => "Bollo",
        "SPESA_ART15" => "Spesa Art.15",
        _ => RigaTipo
    };
}

/// <summary>
/// Riga riepilogo IVA raggruppata per aliquota
/// </summary>
public class InvoiceVatSummaryRow
{
    public string AliquotaCodice { get; set; } = string.Empty;
    public decimal AliquotaPercentuale { get; set; }
    public decimal TotaleImponibile { get; set; }
    public decimal TotaleIva { get; set; }
    public decimal TotaleLordo { get; set; }
    public string? AliquotaNatura { get; set; }

    public string AliquotaDisplay => AliquotaPercentuale > 0
        ? $"{AliquotaCodice} ({AliquotaPercentuale:0.##}%)"
        : AliquotaCodice;
}

/// <summary>
/// Dati bancari per sezione pagamento fattura
/// </summary>
public class InvoiceBankInfo
{
    public string NomeBanca { get; set; } = string.Empty;
    public string? Filiale { get; set; }
    public string Iban { get; set; } = string.Empty;
    public string? SwiftBic { get; set; }
}

/// <summary>
/// Container principale per tutti i dati necessari alla stampa di una fattura attiva
/// </summary>
public class FatturaAttivaPrintData
{
    // Identificativi fattura
    public int TransazioneId { get; set; }
    public string? NumeroDocumento { get; set; }
    public DateTime? DataDocumento { get; set; }
    public DateTime? DataScadenza { get; set; }
    public string Stato { get; set; } = string.Empty;
    public string? Causale { get; set; }
    public string? CausaleDescrizione { get; set; }
    public string? CausaleCodice { get; set; }
    public int? NumeroProtocolloIva { get; set; }
    public string? TipoDocumentoSdi { get; set; }

    // Totali da transazione header
    public decimal ImponibileEur { get; set; }
    public decimal IvaEur { get; set; }
    public decimal LordoEur { get; set; }

    // Entita
    public InvoiceCompanyInfo Company { get; set; } = new();
    public InvoiceClientInfo Client { get; set; } = new();
    public InvoiceBankInfo? Bank { get; set; }

    // Righe e riepilogo
    public List<InvoiceLineItem> Righe { get; set; } = new();
    public List<InvoiceVatSummaryRow> RiepilogoIva { get; set; } = new();

    // Regime
    public bool IsForfettario => Company.IsForfettario;
    public bool HasBollo => Righe.Any(r => r.RigaTipo == "BOLLO");
    public decimal? BolloImporto => HasBollo ? Righe.Where(r => r.RigaTipo == "BOLLO").Sum(r => r.RigaImponibile) : null;

    // Metadati stampa
    public DateTime DataStampa { get; set; } = DateTime.Now;
    public string UtenteStampa { get; set; } = string.Empty;

    // Formatted helpers
    public string DataDocumentoFormatted => DataDocumento?.ToString("dd/MM/yyyy") ?? "-";
    public string DataScadenzaFormatted => DataScadenza?.ToString("dd/MM/yyyy") ?? "-";
    public string NumeroProtocolloDisplay => NumeroProtocolloIva.HasValue && DataDocumento.HasValue
        ? $"{DataDocumento.Value.Year}/V/{NumeroProtocolloIva}"
        : "-";

    public string StatoDisplay => Stato switch
    {
        "DA_PAGARE" => "Da Pagare",
        "PAGATO" => "Pagato",
        "PARZIALMENTE_PAGATO" => "Parzialmente Pagato",
        "ANNULLATO" => "Annullato",
        _ => Stato
    };

    // Note legali
    public string? ForfettarioNotice => IsForfettario
        ? "Operazione in franchigia da IVA ai sensi dell'art. 1, commi da 54 a 89 della Legge n. 190/2014 - Regime Forfettario"
        : null;

    public string? BolloNotice => HasBollo
        ? $"Imposta di bollo assolta in modo virtuale ai sensi del D.M. 17/06/2014 - EUR {BolloImporto:N2}"
        : null;
}

/// <summary>
/// Item per la DataGrid nella pagina di ricerca fatture attive
/// </summary>
public class FatturaAttivaListItem
{
    public int TransazioneId { get; set; }
    public DateTime? TransazioneData { get; set; }
    public DateTime? DataDocumento { get; set; }
    public string? NumeroDocumento { get; set; }
    public int? NumeroProtocolloIva { get; set; }
    public string ControparteRagioneSociale { get; set; } = string.Empty;
    public decimal ImponibileEur { get; set; }
    public decimal IvaEur { get; set; }
    public decimal LordoEur { get; set; }
    public string Stato { get; set; } = string.Empty;
    public DateTime? DataScadenza { get; set; }
    public string? CausaleDescrizione { get; set; }

    public string DataDocumentoFormatted => DataDocumento?.ToString("dd/MM/yyyy") ?? "-";
    public string DataScadenzaFormatted => DataScadenza?.ToString("dd/MM/yyyy") ?? "-";
    public string ImponibileFormatted => $"{ImponibileEur:N2}";
    public string IvaFormatted => $"{IvaEur:N2}";
    public string LordoFormatted => $"{LordoEur:N2}";

    public string StatoDisplay => Stato switch
    {
        "DA_PAGARE" => "Da Pagare",
        "PAGATO" => "Pagato",
        "PARZIALMENTE_PAGATO" => "Parz. Pagato",
        "ANNULLATO" => "Annullato",
        _ => Stato
    };
}
