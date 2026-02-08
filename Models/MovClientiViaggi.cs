
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models;

public class MovClientiViaggi : IAuditable
{
    // Composite PK
    [Column("viaggio_id_fk")]
    public int ViaggioIdFk { get; set; }

    [Column("data_viaggio_id_fk")]
    public int DataViaggioIdFk { get; set; }

    [Column("cliente_id_fk")]
    public int ClienteIdFk { get; set; }

    [Column("tipo_partecipante_id_fk")]
    public int TipoPartecipanteIdFk { get; set; }

    [Column("ana_mezzi_id_fk")]
    public int? AnaMezziIdFk { get; set; }

    [Column("mezzo_modello_id_fk")]
    public int? MezzoModelloIdFk { get; set; }

    [Column("cliente_pilota_id_fk")]
    public int? ClientePilotaIdFk { get; set; } // For passengers linked to a pilot

    [Column("mov_cliente_viaggio_scontoval_totale")]
    public decimal? MovClienteViaggioScontovalTotale { get; set; }

    [Column("mov_cliente_viaggio_targa_mezzo")]
    public string? MovClienteViaggioTargaMezzo { get; set; }

    [Column("mov_cliente_viaggio_cane_sino")]
    public string MovClienteViaggioCaneSino { get; set; } = "N";

    [Column("mov_cliente_viaggio_note")]
    public string? MovClienteViaggioNote { get; set; }

    // Audit Fields
    [Column("created_by")]
    public string? CreatedBy { get; set; }

    [Column("created")]
    public DateTime? Created { get; set; }

    [Column("updated_by")]
    public string? UpdatedBy { get; set; }

    [Column("updated")]
    public DateTime? Updated { get; set; }
}
