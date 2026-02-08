using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta una data di un viaggio (tabella ana_date_viaggi)
/// </summary>
public class AnaDataViaggio : BaseEntity, IAuditable
{
    // === Foreign Keys ===
    [Column("viaggio_id_fk")]
    public int ViaggioIdFk { get; set; }

    // === Dates ===
    [Column("data_viaggio_data_inizio")]
    public DateTime? DataInizio { get; set; }

    [Column("data_viaggio_data_fine")]
    public DateTime? DataFine { get; set; }

    // === Flags ===
    [Column("data_viaggio_effettuato_sino")]
    public string EffettuatoSino { get; set; } = "N"; // 'Y' o 'N'

    // === Costs ===
    [Column("data_viaggio_costo_pilota")]
    public decimal? CostoPilota { get; set; }

    [Column("data_viaggio_costo_passeggero")]
    public decimal? CostoPasseggero { get; set; }

    [Column("data_viaggio_costo_passeggero_auto_guida")]
    public decimal? CostoPasseggeroAutoGuida { get; set; }

    [Column("data_viaggio_costo_bambino_0_2")]
    public decimal? CostoBambino02 { get; set; }

    [Column("data_viaggio_costo_bambino_2_6")]
    public decimal? CostoBambino26 { get; set; }

    [Column("data_viaggio_costo_bambino_6_12")]
    public decimal? CostoBambino612 { get; set; }

    // === Note ===
    [Column("data_viaggio_note")]
    public string? Note { get; set; }

    // === Tenant ===
    [Column("azienda_id")]
    public int AziendaId { get; set; }

    // === Audit Fields ===
    [Column("created_by")]
    public string? CreatedBy { get; set; }

    [Column("created")]
    public DateTime? Created { get; set; }

    [Column("updated_by")]
    public string? UpdatedBy { get; set; }

    [Column("updated")]
    public DateTime? Updated { get; set; }

    // === Computed ===
    [Column("tot_mezzi")]
    public int TotMezzi { get; set; }

    [Column("tot_clienti")]
    public int TotClienti { get; set; }
}
