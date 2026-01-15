
using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

public class MovClientiViaggi
{
    // Composite PK
    public int ViaggioIdFk { get; set; }
    public int DataViaggioIdFk { get; set; }
    public int ClienteIdFk { get; set; }

    public int TipoPartecipanteIdFk { get; set; }

    public int? AnaMezziIdFk { get; set; }
    public int? MezzoModelloIdFk { get; set; }
    public int? ClientePilotaIdFk { get; set; } // For passengers linked to a pilot

    public decimal? MovClienteViaggioScontovalTotale { get; set; }

    // Note: Dapper maps snake_case to PascalCase generally fine, but we might need explicit query aliases if not.
    public string? MovClienteViaggioTargaMezzo { get; set; }

    public string MovClienteViaggioCaneSino { get; set; } = "N";

    public string? MovClienteViaggioNote { get; set; }
}
