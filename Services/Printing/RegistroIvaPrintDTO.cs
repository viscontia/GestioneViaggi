namespace GestioneViaggi.Services.Printing;

/// <summary>
/// Singola riga del Registro IVA (fattura con dettaglio IVA).
/// Mappato da fn_get_registro_iva.
/// </summary>
public class RegistroIvaItem
{
    public string CausaleCiclo { get; set; } = string.Empty;
    public int TransazioneId { get; set; }
    public DateTime? TransazioneDataDocumento { get; set; }
    public string? TransazioneNumeroDocumento { get; set; }
    public string ControparteRagioneSociale { get; set; } = string.Empty;
    public string CausaleCodice { get; set; } = string.Empty;
    public string CausaleDescrizione { get; set; } = string.Empty;
    public string? AliquotaIvaCodice { get; set; }
    public decimal? AliquotaIvaPercentuale { get; set; }
    public string? AliquotaIvaDescrizione { get; set; }
    public decimal ImponibileEur { get; set; }
    public decimal IvaEur { get; set; }
    public decimal LordoEur { get; set; }
    public int CausaleSegno { get; set; } = 1;

    // Proprietà formattate
    public string DataDocumentoFormatted => TransazioneDataDocumento?.ToString("dd/MM/yyyy") ?? "-";
    public string ImponibileFormatted => $"{ImponibileEur:N2}";
    public string IvaFormatted => $"{IvaEur:N2}";
    public string LordoFormatted => $"{LordoEur:N2}";
    public string AliquotaDisplay => !string.IsNullOrEmpty(AliquotaIvaCodice)
        ? $"{AliquotaIvaCodice}"
        : "-";
}

/// <summary>
/// Riepilogo per singola aliquota IVA (con totali Acquisti e Vendite).
/// </summary>
public class RiepilogoAliquotaItem
{
    public string AliquotaCodice { get; set; } = string.Empty;
    public decimal AliquotaPercentuale { get; set; }
    public string? AliquotaDescrizione { get; set; }

    // Acquisti (PASSIVO)
    public decimal ImponibileAcquisti { get; set; }
    public decimal IvaAcquisti { get; set; }
    public int ConteggioAcquisti { get; set; }

    // Vendite (ATTIVO)
    public decimal ImponibileVendite { get; set; }
    public decimal IvaVendite { get; set; }
    public int ConteggioVendite { get; set; }

    // Display
    public string AliquotaDisplay => AliquotaPercentuale > 0
        ? $"{AliquotaCodice} ({AliquotaPercentuale:0.##}%)"
        : AliquotaCodice;
}

/// <summary>
/// Risultato della liquidazione IVA del periodo.
/// </summary>
public class LiquidazioneIva
{
    /// <summary>IVA sulle vendite (debito verso lo Stato)</summary>
    public decimal IvaDebito { get; set; }

    /// <summary>IVA sugli acquisti (credito verso lo Stato)</summary>
    public decimal IvaCredito { get; set; }

    /// <summary>IVA da versare (positivo) o a credito (negativo)</summary>
    public decimal Saldo => IvaDebito - IvaCredito;

    public bool IsDebito => Saldo > 0;
    public bool IsCredito => Saldo < 0;
    public bool IsPari => Saldo == 0;

    public string SaldoFormatted => $"{Math.Abs(Saldo):N2} EUR";
    public string SaldoLabel => IsDebito ? "IVA DA VERSARE" : IsCredito ? "IVA A CREDITO" : "IVA IN PAREGGIO";
}

/// <summary>
/// Sub-totale per aliquota all'interno di una sezione (Acquisti o Vendite).
/// </summary>
public class SubTotaleAliquota
{
    public string AliquotaCodice { get; set; } = string.Empty;
    public decimal AliquotaPercentuale { get; set; }
    public string? AliquotaDescrizione { get; set; }
    public decimal TotaleImponibile { get; set; }
    public decimal TotaleIva { get; set; }
    public decimal TotaleLordo { get; set; }
    public int Conteggio { get; set; }

    public string AliquotaDisplay => AliquotaPercentuale > 0
        ? $"{AliquotaCodice} ({AliquotaPercentuale:0.##}%)"
        : AliquotaCodice;
}

/// <summary>
/// Container principale per tutti i dati del Registro IVA.
/// </summary>
public class RegistroIvaPrintData
{
    public CompanyPrintInfo Azienda { get; set; } = new();
    public DateTime PeriodoDa { get; set; }
    public DateTime PeriodoA { get; set; }
    public DateTime DataStampa { get; set; } = DateTime.Now;
    public string UtenteStampa { get; set; } = string.Empty;

    // Dettagli
    public List<RegistroIvaItem> Acquisti { get; set; } = new();
    public List<RegistroIvaItem> Vendite { get; set; } = new();

    // Sub-totali per aliquota (all'interno di ciascuna sezione)
    public List<SubTotaleAliquota> SubTotaliAcquisti { get; set; } = new();
    public List<SubTotaleAliquota> SubTotaliVendite { get; set; } = new();

    // Totali di sezione
    public decimal TotaleImponibileAcquisti { get; set; }
    public decimal TotaleIvaAcquisti { get; set; }
    public decimal TotaleLordoAcquisti { get; set; }
    public decimal TotaleImponibileVendite { get; set; }
    public decimal TotaleIvaVendite { get; set; }
    public decimal TotaleLordoVendite { get; set; }

    // Riepilogo per aliquota (cross Acquisti/Vendite)
    public List<RiepilogoAliquotaItem> RiepilogoPerAliquota { get; set; } = new();

    // Liquidazione
    public LiquidazioneIva Liquidazione { get; set; } = new();

    // Helpers
    public string PeriodoDisplay => $"Dal {PeriodoDa:dd/MM/yyyy} al {PeriodoA:dd/MM/yyyy}";
    public bool HasAcquisti => Acquisti.Any();
    public bool HasVendite => Vendite.Any();
    public bool HasData => HasAcquisti || HasVendite;
}
