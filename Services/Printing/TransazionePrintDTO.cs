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
    
    // ex Fornitore
    public string ControparteRagioneSociale { get; set; } = string.Empty;
    
    public string TipoMovimentoCodice { get; set; } = string.Empty;
    public string TipoMovimentoDescrizione { get; set; } = string.Empty;
    public int CausaleSegno { get; set; } = 1;
    public string? Causale { get; set; }
    public string? CausaleCiclo { get; set; } // ATTIVO / PASSIVO

    public string Stato { get; set; } = string.Empty;
    public string? NumeroDocumento { get; set; }
    public string ValutaCodiceIso { get; set; } = "EUR";
    
    // Valori Originali
    public decimal ImponibileEur { get; set; }
    public decimal IvaEur { get; set; }
    public decimal LordoEur { get; set; } // ex transazione_importo

    // Dati IVA
    public string? AliquotaIvaCodice { get; set; }
    public decimal? AliquotaIvaPercentuale { get; set; }

    // Valori Convertiti
    public decimal ImportoValutaTarget { get; set; } // Calcolato su LORDO
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
    
    public string ImponibileFormatted => $"{ImponibileEur:N2} {ValutaCodiceIso}";
    public string IvaFormatted => $"{IvaEur:N2} {ValutaCodiceIso}";
    public string LordoFormatted => $"{LordoEur:N2} {ValutaCodiceIso}";
    
    public string ImportoTargetFormatted => $"{ImportoValutaTarget:N2} {ValutaTargetIso}";
    public string AliquotaDisplay => !string.IsNullOrEmpty(AliquotaIvaCodice) ? $"{AliquotaIvaCodice} ({AliquotaIvaPercentuale:0.##}%)" : "-";

    // Helpers Logici
    public bool IsCicloAttivo => CausaleCiclo == "ATTIVO";
    public bool IsCicloPassivo => CausaleCiclo == "PASSIVO";

    // Saldo progressivo (calcolato dinamicamente nel Printer o nel Service)
    public decimal SaldoProgressivo { get; set; }
    public string SaldoProgressivoFormatted => $"{SaldoProgressivo:N2} {ValutaTargetIso}";
    
    // Indica se l'importo deve essere sottratto (Uscita/Pagamento/NC) o sommato (Entrata/Fattura)
    public decimal ImportoAlgebricoTarget => ImportoValutaTarget * CausaleSegno;
    
    public string StatoDisplay => Stato switch
    {
        "DA_PAGARE" => "Da Pagare",
        "PAGATO" => "Pagato",
        "PARZIALMENTE_PAGATO" => "Parz. Pagato",
        "ANNULLATO" => "Annullato",
        _ => Stato
    };

    public string TipoMovimentoDisplay => TipoMovimentoDescrizione;
    public string TipoMovimento => TipoMovimentoCodice;
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
    
    // Algebrico (Saldo)
    public decimal TotaleValutaOriginale { get; set; } // Saldo Lordo Orig
    public decimal TotaleValutaTarget { get; set; }    // Saldo Lordo Target
    
    // Tripartizione Cash Flow (Target)
    public decimal TotaleFatturatoTarget { get; set; }
    public decimal TotalePagatoTarget { get; set; }

    // Nuovi totali (Target)
    public decimal TotaleImponibileTarget { get; set; }
    public decimal TotaleIvaTarget { get; set; }
    
    public string ValutaTargetIso { get; set; } = "EUR";
    public int ConteggioTransazioni { get; set; }
    public bool IsTotaleGenerale { get; set; }

    // Proprietà formattate
    public string TotaleOriginaleFormatted => $"{(TotaleValutaOriginale >= 0 ? "" : "-")}{Math.Abs(TotaleValutaOriginale):N2} {ValutaCodiceIso}";
    public string TotaleTargetFormatted => $"{(TotaleValutaTarget >= 0 ? "" : "-")}{Math.Abs(TotaleValutaTarget):N2} {ValutaTargetIso}";
    
    public string TotaleFatturatoTargetFormatted => $"{TotaleFatturatoTarget:N2} {ValutaTargetIso}";
    public string TotalePagatoTargetFormatted => $"{TotalePagatoTarget:N2} {ValutaTargetIso}";
    
    public string TotaleImponibileFormatted => $"{TotaleImponibileTarget:N2} {ValutaTargetIso}";
    public string TotaleIvaFormatted => $"{TotaleIvaTarget:N2} {ValutaTargetIso}";
}

/// <summary>
/// Informazioni sui filtri applicati per stampa header
/// </summary>
public class FiltriApplicatiInfo
{
    public string? Azienda { get; set; }
    public string? Controparte { get; set; } // ex Fornitore
    public string? CausaleCiclo { get; set; } // Nuovo
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
        !string.IsNullOrEmpty(Controparte) ||
        !string.IsNullOrEmpty(CausaleCiclo) ||
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
    public string TipoOrdinamento { get; set; } = "CONTROPARTE"; // ex FORNITORE
    public string ValutaTargetCodiceIso { get; set; } = "EUR";
    public CompanyPrintInfo Azienda { get; set; } = new();
    public FiltriApplicatiInfo Filtri { get; set; } = new();
    public List<TransazionePrintItem> Dettagli { get; set; } = new();
    public List<SubTotaleItem> Subtotali { get; set; } = new();
    public decimal TotaleGeneraleValutaTarget { get; set; }
    
    public DateTime DataStampa { get; set; } = DateTime.Now;
    public string UtenteStampa { get; set; } = string.Empty;

    // Proprietà calcolate
    public int TotaleTransazioni => Dettagli.Count;
    
    public IEnumerable<SubTotaleItem> TotaliGenerali => 
        Subtotali.Where(s => s.IsTotaleGenerale);
    
    public IEnumerable<SubTotaleItem> SubTotaliGruppi => 
        Subtotali.Where(s => !s.IsTotaleGenerale);

    // Raggruppa dettagli per facilitare iterazione nel PDF
    public IEnumerable<IGrouping<string?, TransazionePrintItem>> DettagliRaggruppati =>
        Dettagli.GroupBy(d => d.GruppoChiave);
    
    public string TipoOrdinamentoDisplay => TipoOrdinamento switch
    {
        "FORNITORE" => "Controparte", // Legacy string, new label
        "CONTROPARTE" => "Controparte",
        "DATA_DOCUMENTO" => "Data Documento (Mese/Anno)",
        "IMPORTO_ASC" => "Importo (crescente)",
        "IMPORTO_DESC" => "Importo (decrescente)",
        "TIPO_MOVIMENTO" => "Tipo Movimento",
        _ => TipoOrdinamento
    };
}
