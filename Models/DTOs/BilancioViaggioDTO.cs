using System;

namespace GestioneViaggi.Models.DTOs;

public class BilancioViaggioDTO
{
    // Trip Info
    public int ViaggioId { get; set; }
    public string ViaggioDescrizione { get; set; } = string.Empty;
    public DateTime? ViaggioDataInizio { get; set; }
    public DateTime? ViaggioDataFine { get; set; }
    public int ViaggioNumeroPartecipanti { get; set; }
    public int ViaggioNumeroMezzi { get; set; }

    // Trip Date Info (Riga)
    public int? DataViaggioId { get; set; }
    public DateTime? DataViaggioDataInizio { get; set; }
    public DateTime? DataViaggioDataFine { get; set; }
    public int DataViaggioNumeroPartecipanti { get; set; }
    public int DataViaggioNumeroMezzi { get; set; }

    // Transaction Info
    public int TransazioneId { get; set; }
    public DateTime? DataDocumento { get; set; }
    public DateTime DataRegistrazione { get; set; }
    public string NumeroDocumento { get; set; } = string.Empty;
    public string TransazioneDescrizione { get; set; } = string.Empty;

    // Counterparty Info
    public string ControparteRagioneSociale { get; set; } = string.Empty;
    public string CategoriaNome { get; set; } = string.Empty; // "Vendite" or specific cost category
    public string CategoriaTipo { get; set; } = string.Empty; // "RICAVO" or "COSTO"

    // Economic Values
    public decimal ImportoNettoEur { get; set; }
    public decimal ImportoIvaEur { get; set; }
    public decimal ImportoLordoEur { get; set; }
    
    // Financial Status
    public decimal ImportoPagatoEur { get; set; }
    public string StatoPagamento { get; set; } = string.Empty;
}
