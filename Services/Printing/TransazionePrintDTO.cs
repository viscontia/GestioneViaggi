namespace GestioneViaggi.Services.Printing;

/// <summary>
/// DTO per una singola transazione stampabile.
/// Mappato direttamente da fn_get_transazioni_stampa_dettaglio.
/// </summary>
public class TransazionePrintItem
{
    // Chiave raggruppamento dinamica
    public string? GruppoChiave { get; set; }
    public string? GruppoDisplay { get; set; }
    public int GruppoOrdine { get; set; }
    
    // Dati transazione
    public int TransazioneId { get; set; }
    public DateTime? DataTransazione { get; set; }
    public DateTime? DataDocumento { get; set; }
    public DateTime? DataScadenza { get; set; }
    public DateTime? DataPagamento { get; set; }
    public string Fornitore { get; set; } = string.Empty;
    public string TipoMovimento { get; set; } = string.Empty;
    public string? Causale { get; set; }
    public string Stato { get; set; } = string.Empty;
    public string? NumeroDocumento { get; set; }
    public string ValutaCodiceIso { get; set; } = "EUR";
    public decimal Importo { get; set; }
    public decimal ImportoValutaTarget { get; set; }
    public string ValutaTargetIso { get; set; } = "EUR";
    public string? ViaggioDescrizione { get; set; }
    public DateTime? DataViaggioInizio { get; set; }

    public string ViaggioFullDisplay
    {
        get
        {
            if (string.IsNullOrEmpty(ViaggioDescrizione)) return "-";
            var dataStr = DataViaggioInizio?.ToString("dd/MM/yyyy");
            return string.IsNullOrEmpty(dataStr) ? ViaggioDescrizione : $"{ViaggioDescrizione} ({dataStr})";
        }
    }

    // Proprietà formattate per stampa
    public string DataDocumentoFormatted => DataDocumento?.ToString("dd/MM/yyyy") ?? "-";
    public string DataTransazioneFormatted => DataTransazione?.ToString("dd/MM/yyyy") ?? "-";
    public string DataScadenzaFormatted => DataScadenza?.ToString("dd/MM/yyyy") ?? "-";
    public string ImportoFormatted => $"{Importo:N2} {ValutaCodiceIso}";
    public string ImportoTargetFormatted => $"{ImportoValutaTarget:N2} {ValutaTargetIso}";
    
    public string StatoDisplay => Stato switch
    {
        "DA_PAGARE" => "Da Pagare",
        "PAGATO" => "Pagato",
        "PARZIALMENTE_PAGATO" => "Parz. Pagato",
        "ANNULLATO" => "Annullato",
        _ => Stato
    };

    public string TipoMovimentoDisplay => TipoMovimento switch
    {
        "ENTRATA" => "Entrata",
        "USCITA" => "Uscita",
        _ => TipoMovimento
    };
}

/// <summary>
/// DTO per un sub-totale (per gruppo/valuta o totale generale).
/// Mappato direttamente da fn_get_transazioni_stampa_subtotali.
/// </summary>
public class SubTotaleItem
{
    public string? GruppoChiave { get; set; }
    public string? GruppoDisplay { get; set; }
    public int GruppoOrdine { get; set; }
    public string ValutaCodiceIso { get; set; } = "EUR";
    public decimal TotaleOriginale { get; set; }
    public decimal TotaleValutaTarget { get; set; }
    public string ValutaTargetIso { get; set; } = "EUR";
    public int ConteggioTransazioni { get; set; }
    public bool IsTotaleGenerale { get; set; }

    // Proprietà formattate
    public string TotaleOriginaleFormatted => $"{TotaleOriginale:N2} {ValutaCodiceIso}";
    public string TotaleTargetFormatted => $"{TotaleValutaTarget:N2} {ValutaTargetIso}";
}

/// <summary>
/// Informazioni sui filtri applicati per stampa header
/// </summary>
public class FiltriApplicatiInfo
{
    public string? Azienda { get; set; }
    public string? Fornitore { get; set; }
    public string? TipoMovimento { get; set; }
    public string? Valuta { get; set; }
    public string? Viaggio { get; set; }
    public string? DataDocumentoDal { get; set; }
    public string? DataDocumentoAl { get; set; }
    public string? DataTransazioneDal { get; set; }
    public string? DataTransazioneAl { get; set; }
    public string? ImportoDa { get; set; }
    public string? ImportoA { get; set; }
    public string? NumeroDocumento { get; set; }
    public List<string> Checkbox { get; set; } = new();
    
    public bool HasAnyFilter => 
        !string.IsNullOrEmpty(Azienda) ||
        !string.IsNullOrEmpty(Fornitore) ||
        !string.IsNullOrEmpty(TipoMovimento) ||
        !string.IsNullOrEmpty(Valuta) ||
        !string.IsNullOrEmpty(Viaggio) ||
        !string.IsNullOrEmpty(DataDocumentoDal) ||
        !string.IsNullOrEmpty(DataDocumentoAl) ||
        !string.IsNullOrEmpty(DataTransazioneDal) ||
        !string.IsNullOrEmpty(DataTransazioneAl) ||
        !string.IsNullOrEmpty(ImportoDa) ||
        !string.IsNullOrEmpty(ImportoA) ||
        !string.IsNullOrEmpty(NumeroDocumento) ||
        Checkbox.Any();
}

/// <summary>
/// Contenitore principale per tutti i dati necessari alla stampa PDF.
/// </summary>
public class TransazioniPrintData
{
    public string TipoOrdinamento { get; set; } = "FORNITORE";
    public string ValutaTargetCodiceIso { get; set; } = "EUR";
    public CompanyPrintInfo Company { get; set; } = new();
    public FiltriApplicatiInfo Filtri { get; set; } = new();
    public List<TransazionePrintItem> Dettagli { get; set; } = new();
    public List<SubTotaleItem> SubTotali { get; set; } = new();
    
    public DateTime DataStampa { get; set; } = DateTime.Now;
    public string UtenteStampa { get; set; } = string.Empty;

    // Proprietà calcolate
    public int TotaleTransazioni => Dettagli.Count;
    
    public IEnumerable<SubTotaleItem> TotaliGenerali => 
        SubTotali.Where(s => s.IsTotaleGenerale);
    
    public IEnumerable<SubTotaleItem> SubTotaliGruppi => 
        SubTotali.Where(s => !s.IsTotaleGenerale);

    // Raggruppa dettagli per facilitare iterazione nel PDF
    public IEnumerable<IGrouping<string?, TransazionePrintItem>> DettagliRaggruppati =>
        Dettagli.GroupBy(d => d.GruppoChiave);
    
    public string TipoOrdinamentoDisplay => TipoOrdinamento switch
    {
        "FORNITORE" => "Fornitore",
        "DATA_DOCUMENTO" => "Data Documento (Mese/Anno)",
        "IMPORTO_ASC" => "Importo (crescente)",
        "IMPORTO_DESC" => "Importo (decrescente)",
        "TIPO_MOVIMENTO" => "Tipo Movimento",
        _ => TipoOrdinamento
    };
}
