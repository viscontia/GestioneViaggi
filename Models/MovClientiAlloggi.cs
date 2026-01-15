
using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

public class MovClientiAlloggi
{
    [Key]
    public int MovClientiAlloggioPk { get; set; }

    public int ViaggioIdFk { get; set; }
    public int DataViaggioIdFk { get; set; }
    public int TipoAlloggioIdFk { get; set; }

    public int? ClienteId1Fk { get; set; }
    public int? ClienteId2Fk { get; set; }
    public int? ClienteId3Fk { get; set; }
    public int? ClienteId4Fk { get; set; }
    public int? ClienteId5Fk { get; set; }
    public int? ClienteId6Fk { get; set; }
}
