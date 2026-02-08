
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models;

public class MovClientiAlloggi : IAuditable
{
    [Key]
    [Column("mov_clienti_alloggio_pk")]
    public int MovClientiAlloggioPk { get; set; }

    [Column("viaggio_id_fk")]
    public int ViaggioIdFk { get; set; }

    [Column("data_viaggio_id_fk")]
    public int DataViaggioIdFk { get; set; }

    [Column("tipo_alloggio_id_fk")]
    public int TipoAlloggioIdFk { get; set; }

    [Column("cliente_id1_fk")]
    public int? ClienteId1Fk { get; set; }

    [Column("cliente_id2_fk")]
    public int? ClienteId2Fk { get; set; }

    [Column("cliente_id3_fk")]
    public int? ClienteId3Fk { get; set; }

    [Column("cliente_id4_fk")]
    public int? ClienteId4Fk { get; set; }

    [Column("cliente_id5_fk")]
    public int? ClienteId5Fk { get; set; }

    [Column("cliente_id6_fk")]
    public int? ClienteId6Fk { get; set; }

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
