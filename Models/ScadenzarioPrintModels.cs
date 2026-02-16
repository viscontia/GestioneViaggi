using GestioneViaggi.Services.Printing;

namespace GestioneViaggi.Models;

/// <summary>
/// Dati completi per la stampa dello scadenzario
/// </summary>
public class ScadenzarioPrintData
{
    public DateTime DataStampa { get; set; }
    public string UtenteStampa { get; set; } = string.Empty;
    public string ValutaTargetCodiceIso { get; set; } = string.Empty;
    public CompanyPrintInfo Azienda { get; set; } = new();
    public ScadenzarioFiltriApplicatiInfo Filtri { get; set; } = new();

    public List<ScadenzarioItem> Dettagli { get; set; } = new();
    public List<ScadenzarioSubTotale> Subtotali { get; set; } = new();

    public decimal TotaleGeneraleAttivo { get; set; }  // Entrate previste (crediti)
    public decimal TotaleGeneralePassivo { get; set; } // Uscite previste (debiti)
    public decimal SaldoNetto { get; set; }            // Attivo - Passivo
}

/// <summary>
/// Singolo elemento dello scadenzario
/// </summary>
public class ScadenzarioItem
{
    // Raggruppamento
    public string GruppoChiave { get; set; } = string.Empty;
    public string GruppoDisplay { get; set; } = string.Empty;
    public int GruppoOrdine { get; set; }

    // Dati transazione
    public int TransazioneId { get; set; }
    public DateTime? DataScadenza { get; set; }
    public DateTime? DataDocumento { get; set; }
    public string? NumeroDocumento { get; set; }

    // Controparte
    public string ControparteRagioneSociale { get; set; } = string.Empty;
    public string CausaleCiclo { get; set; } = string.Empty; // ATTIVO | PASSIVO
    public string CausaleDescrizione { get; set; } = string.Empty;

    // Importi
    public decimal ImportoOriginale { get; set; }
    public decimal Residuo { get; set; }
    public string ValutaCodiceIso { get; set; } = string.Empty;

    // Urgenza
    public int GiorniAScadenza { get; set; }
    public string Urgenza { get; set; } = string.Empty; // SCADUTO | URGENTE | IN_SCADENZA | NORMALE

    // Stato
    public string Stato { get; set; } = string.Empty;
    public string? ViaggioDescrizione { get; set; }
    public string? Note { get; set; }
}

/// <summary>
/// Subtotali per gruppo (per urgenza o per periodo)
/// </summary>
public class ScadenzarioSubTotale
{
    public string GruppoChiave { get; set; } = string.Empty;
    public string GruppoDisplay { get; set; } = string.Empty;
    public int GruppoOrdine { get; set; }

    public decimal TotaleAttivo { get; set; }   // Entrate previste in questo gruppo
    public decimal TotalePassivo { get; set; }  // Uscite previste in questo gruppo
    public decimal SaldoNetto { get; set; }     // Attivo - Passivo

    public int ConteggioTransazioni { get; set; }
    public bool IsTotaleGenerale { get; set; }
}

/// <summary>
/// Informazioni sui filtri applicati alla stampa scadenzario
/// </summary>
public class ScadenzarioFiltriApplicatiInfo
{
    public string? Azienda { get; set; }
    public string? Controparte { get; set; }
    public string? CausaleCiclo { get; set; }
    public string? Urgenza { get; set; }
    public string? DataScadenzaDal { get; set; }
    public string? DataScadenzaAl { get; set; }
    public string? Viaggio { get; set; }
    public List<string> Checkbox { get; set; } = new();

    public bool HasAnyFilter =>
        !string.IsNullOrEmpty(Controparte) ||
        !string.IsNullOrEmpty(CausaleCiclo) ||
        !string.IsNullOrEmpty(Urgenza) ||
        !string.IsNullOrEmpty(DataScadenzaDal) ||
        !string.IsNullOrEmpty(DataScadenzaAl) ||
        !string.IsNullOrEmpty(Viaggio) ||
        Checkbox.Any();
}

/// <summary>
/// DTO per i filtri dello scadenzario
/// </summary>
public class ScadenzarioFiltriDTO
{
    public int? AziendaId { get; set; }
    public int? ControparteId { get; set; }
    public string? CausaleCiclo { get; set; } // ATTIVO | PASSIVO | null (entrambi)
    public string? Urgenza { get; set; }      // SCADUTO | URGENTE | IN_SCADENZA | NORMALE
    public DateTime? DataScadenzaDa { get; set; }
    public DateTime? DataScadenzaA { get; set; }
    public int? ViaggioId { get; set; }
    public bool SoloConViaggio { get; set; }
    public bool SoloSenzaViaggio { get; set; }

    // Nomi per visualizzazione
    public string? AziendaNome { get; set; }
    public string? ControparteNome { get; set; }
    public string? ViaggioNome { get; set; }

    public ScadenzarioFiltriApplicatiInfo ToFiltriApplicatiInfo()
    {
        var info = new ScadenzarioFiltriApplicatiInfo
        {
            Azienda = AziendaNome,
            Controparte = ControparteNome,
            CausaleCiclo = CausaleCiclo,
            Urgenza = Urgenza,
            DataScadenzaDal = DataScadenzaDa?.ToString("dd/MM/yyyy"),
            DataScadenzaAl = DataScadenzaA?.ToString("dd/MM/yyyy"),
            Viaggio = ViaggioNome
        };

        if (SoloConViaggio) info.Checkbox.Add("Solo con viaggio");
        if (SoloSenzaViaggio) info.Checkbox.Add("Solo senza viaggio");

        return info;
    }
}
