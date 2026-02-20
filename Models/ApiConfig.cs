using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta una configurazione API esterna (tabella ana_api_config).
/// Tabella globale (non multi-tenant), gestita solo dal SuperAdmin.
/// </summary>
[Table("ana_api_config")]
public class ApiConfig
{
    [Key]
    [Column("config_id")]
    public int ConfigId { get; set; }

    [Column("service_code")]
    [Required(ErrorMessage = "Il codice servizio è obbligatorio")]
    [StringLength(50)]
    public string ServiceCode { get; set; } = string.Empty;

    [Column("service_name")]
    [Required(ErrorMessage = "Il nome servizio è obbligatorio")]
    [StringLength(100)]
    public string ServiceName { get; set; } = string.Empty;

    [Column("config_key")]
    [Required(ErrorMessage = "La chiave di configurazione è obbligatoria")]
    [StringLength(100)]
    public string ConfigKey { get; set; } = string.Empty;

    [Column("config_value")]
    public string? ConfigValue { get; set; }

    [Column("config_type")]
    [Required(ErrorMessage = "Il tipo è obbligatorio")]
    [StringLength(20)]
    public string ConfigType { get; set; } = "TEXT";

    [Column("config_description")]
    [StringLength(255)]
    public string? ConfigDescription { get; set; }

    [Column("is_secret")]
    public bool IsSecret { get; set; }

    [Column("is_active")]
    public bool IsActive { get; set; } = true;

    [Column("display_order")]
    public short DisplayOrder { get; set; }

    [Column("created_at")]
    public DateTime? CreatedAt { get; set; }

    [Column("created_by")]
    [StringLength(50)]
    public string? CreatedBy { get; set; }

    [Column("updated_at")]
    public DateTime? UpdatedAt { get; set; }

    [Column("updated_by")]
    [StringLength(50)]
    public string? UpdatedBy { get; set; }

    /// <summary>
    /// Valore visualizzato nella griglia (mascherato se segreto)
    /// </summary>
    [NotMapped]
    public string ConfigValueDisplay => IsSecret && !string.IsNullOrEmpty(ConfigValue)
        ? "●●●●●●●●●●"
        : ConfigValue ?? string.Empty;
}
