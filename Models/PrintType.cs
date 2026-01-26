namespace GestioneViaggi.Models;

/// <summary>
/// Tipi di stampa disponibili per il sistema
/// </summary>
public enum PrintType
{
    /// <summary>
    /// Scheda completa Data Viaggio con partecipanti e veicoli
    /// </summary>
    TravelDataSheet,

    /// <summary>
    /// Lista passeggeri
    /// </summary>
    PassengerList,

    /// <summary>
    /// Rooming List - Lista alloggi con dati anagrafici e documenti
    /// </summary>
    RoomingList,

    /// <summary>
    /// Scheda Data Viaggio Dettagliata (con documenti e nazionalità)
    /// </summary>
    TravelDataSheetDetailed,

    /// <summary>
    /// Report fatturazione
    /// </summary>
    InvoiceReport,
    
    /// <summary>
    /// Report personalizzato
    /// </summary>
    CustomReport
}

/// <summary>
/// Estensioni per PrintType
/// </summary>
public static class PrintTypeExtensions
{
    public static string GetDisplayName(this PrintType printType)
    {
        return printType switch
        {
            PrintType.TravelDataSheet => "Scheda Data Viaggio",
            PrintType.TravelDataSheetDetailed => "Scheda Dettaglio Data Viaggio",
            PrintType.PassengerList => "Lista Passeggeri",
            PrintType.RoomingList => "Rooming List",
            PrintType.InvoiceReport => "Report Fatturazione",
            PrintType.CustomReport => "Report Personalizzato",
            _ => printType.ToString()
        };
    }

    public static string GetIcon(this PrintType printType)
    {
        return printType switch
        {
            PrintType.TravelDataSheet => "@Icons.Material.Filled.Article",
            PrintType.TravelDataSheetDetailed => "@Icons.Material.Filled.Description",
            PrintType.PassengerList => "@Icons.Material.Filled.People",
            PrintType.RoomingList => "@Icons.Material.Filled.Hotel",
            PrintType.InvoiceReport => "@Icons.Material.Filled.Receipt",
            PrintType.CustomReport => "@Icons.Material.Filled.Description",
            _ => "@Icons.Material.Filled.Print"
        };
    }
}
