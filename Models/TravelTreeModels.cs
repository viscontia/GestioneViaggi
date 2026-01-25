namespace GestioneViaggi.Models;

/// <summary>
/// Stato del viaggio/data viaggio
/// </summary>
public enum TravelStatus
{
    /// <summary>
    /// Viaggio futuro (data_inizio > oggi)
    /// </summary>
    Future,

    /// <summary>
    /// Viaggio effettuato (effettuato_sino = 'Y')
    /// </summary>
    Completed,

    /// <summary>
    /// Viaggio non effettuato (data_inizio < oggi AND effettuato_sino = 'N')
    /// </summary>
    NotCompleted
}

/// <summary>
/// Nodo generico per TreeView dei viaggi
/// </summary>
public class TravelTreeNode
{
    public TravelTreeNodeType Type { get; set; }
    public int? Year { get; set; }
    public int? ViaggioId { get; set; }
    public int? DataViaggioId { get; set; }
    public string DisplayText { get; set; } = string.Empty;
    public TravelStatus? Status { get; set; }
    public bool IsExpanded { get; set; }

    // For equality comparison in MudTreeView
    public override bool Equals(object? obj)
    {
        if (obj is not TravelTreeNode other) return false;
        return Type == other.Type &&
               Year == other.Year &&
               ViaggioId == other.ViaggioId &&
               DataViaggioId == other.DataViaggioId;
    }

    public override int GetHashCode()
    {
        return HashCode.Combine(Type, Year, ViaggioId, DataViaggioId);
    }
}

public enum TravelTreeNodeType
{
    Year,
    Viaggio,
    DataViaggio
}

/// <summary>
/// DTO per dati TreeView da database
/// </summary>
public class TravelTreeData
{
    public int Anno { get; set; }
    public int ViaggioId { get; set; }
    public string ViaggioDescrizione { get; set; } = string.Empty;
    public int DataViaggioId { get; set; }
    public DateTime? DataInizio { get; set; }
    public DateTime? DataFine { get; set; }
    public char EffettuatoSino { get; set; } = 'N';

    public TravelStatus GetStatus()
    {
        if (EffettuatoSino == 'Y' || EffettuatoSino == 'S')
            return TravelStatus.Completed;

        if (DataInizio.HasValue && DataInizio.Value.Date > DateTime.Today)
            return TravelStatus.Future;

        return TravelStatus.NotCompleted;
    }
}

/// <summary>
/// Estensioni per TravelStatus
/// </summary>
public static class TravelStatusExtensions
{
    public static string GetColor(this TravelStatus status)
    {
        return status switch
        {
            TravelStatus.Future => "Warning",
            TravelStatus.Completed => "Success",
            TravelStatus.NotCompleted => "Error",
            _ => "Default"
        };
    }

    public static string GetIcon(this TravelStatus status)
    {
        return status switch
        {
            TravelStatus.Future => "@Icons.Material.Filled.Schedule",
            TravelStatus.Completed => "@Icons.Material.Filled.CheckCircle",
            TravelStatus.NotCompleted => "@Icons.Material.Filled.Cancel",
            _ => "@Icons.Material.Filled.Circle"
        };
    }

    public static string GetLabel(this TravelStatus status)
    {
        return status switch
        {
            TravelStatus.Future => "Futuro",
            TravelStatus.Completed => "Effettuato",
            TravelStatus.NotCompleted => "Non Effettuato",
            _ => "N/D"
        };
    }
}
