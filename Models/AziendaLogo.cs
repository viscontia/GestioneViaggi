using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta un logo aziendale (tabella ana_aziende_logo)
/// </summary>
public class AziendaLogo
{
    public Guid Id { get; set; }

    [Required(ErrorMessage = "L'azienda è obbligatoria")]
    public int AziendaIdFk { get; set; }

    [Required(ErrorMessage = "Il tipo di logo è obbligatorio")]
    [StringLength(20, ErrorMessage = "Il tipo logo non può superare i 20 caratteri")]
    public string LogoType { get; set; } = "primary";

    [StringLength(30, ErrorMessage = "La variante non può superare i 30 caratteri")]
    public string? LogoVariant { get; set; } = "standard";

    [Required(ErrorMessage = "Il nome file è obbligatorio")]
    [StringLength(255, ErrorMessage = "Il nome file non può superare i 255 caratteri")]
    public string FileName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Il nome file originale è obbligatorio")]
    [StringLength(255, ErrorMessage = "Il nome file originale non può superare i 255 caratteri")]
    public string OriginalFilename { get; set; } = string.Empty;

    [Required(ErrorMessage = "Il formato file è obbligatorio")]
    [StringLength(10, ErrorMessage = "Il formato file non può superare i 10 caratteri")]
    public string FileFormat { get; set; } = string.Empty;

    [Required(ErrorMessage = "Il tipo MIME è obbligatorio")]
    [StringLength(100, ErrorMessage = "Il tipo MIME non può superare i 100 caratteri")]
    public string MimeType { get; set; } = string.Empty;

    [Required(ErrorMessage = "La dimensione file è obbligatoria")]
    public int FileSizeBytes { get; set; }

    [Required(ErrorMessage = "I dati binari sono obbligatori")]
    public byte[] BinaryData { get; set; } = Array.Empty<byte>();

    public int? ImageWidth { get; set; }
    public int? ImageHeight { get; set; }

    public bool HasTransparency { get; set; } = false;

    [StringLength(20, ErrorMessage = "La modalità colore non può superare i 20 caratteri")]
    public string? ColorMode { get; set; } = "rgb";

    public short? ColorDepth { get; set; }

    public bool IsCompressed { get; set; } = false;
    public short? CompressionQuality { get; set; }
    public bool IsWebOptimized { get; set; } = false;
    public short? Dpi { get; set; }

    [Required(ErrorMessage = "L'hash del file è obbligatorio")]
    [StringLength(64, ErrorMessage = "L'hash non può superare i 64 caratteri")]
    public string FileHash { get; set; } = string.Empty;

    [Required(ErrorMessage = "L'hash MD5 è obbligatorio")]
    [StringLength(32, ErrorMessage = "L'hash MD5 non può superare i 32 caratteri")]
    public string Md5Hash { get; set; } = string.Empty;

    public string[]? UsageContext { get; set; } = new[] { "web" };

    public string? Description { get; set; }

    [Required(ErrorMessage = "Il testo alternativo è obbligatorio")]
    [StringLength(500, ErrorMessage = "Il testo alternativo non può superare i 500 caratteri")]
    public string AltText { get; set; } = string.Empty;

    public string[]? SeoKeywords { get; set; }
    public string? BrandGuidelinesNotes { get; set; }

    public bool IsActive { get; set; } = true;
    public bool IsDefault { get; set; } = false;

    public short Priority { get; set; } = 1;

    public bool IsApproved { get; set; } = false;
    public DateTime? ApprovalDate { get; set; }
    public Guid? ApprovedBy { get; set; }

    public short VersionNumber { get; set; } = 1;
    public Guid? ParentLogoId { get; set; }
    public bool IsCurrentVersion { get; set; } = true;

    public DateTime? LastAccessed { get; set; }
    public int AccessCount { get; set; } = 0;

    [Required(ErrorMessage = "L'utente creatore è obbligatorio")]
    public Guid CreatedBy { get; set; }

    public DateTime CreatedAt { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTime? UpdatedAt { get; set; }

    /// <summary>
    /// Crea una copia dell'entità per evitare modifiche accidentali all'oggetto originale
    /// </summary>
    public AziendaLogo Clone()
    {
        return new AziendaLogo
        {
            Id = this.Id,
            AziendaIdFk = this.AziendaIdFk,
            LogoType = this.LogoType,
            LogoVariant = this.LogoVariant,
            FileName = this.FileName,
            OriginalFilename = this.OriginalFilename,
            FileFormat = this.FileFormat,
            MimeType = this.MimeType,
            FileSizeBytes = this.FileSizeBytes,
            BinaryData = (byte[])this.BinaryData.Clone(),
            ImageWidth = this.ImageWidth,
            ImageHeight = this.ImageHeight,
            HasTransparency = this.HasTransparency,
            ColorMode = this.ColorMode,
            ColorDepth = this.ColorDepth,
            IsCompressed = this.IsCompressed,
            CompressionQuality = this.CompressionQuality,
            IsWebOptimized = this.IsWebOptimized,
            Dpi = this.Dpi,
            FileHash = this.FileHash,
            Md5Hash = this.Md5Hash,
            UsageContext = this.UsageContext != null ? (string[])this.UsageContext.Clone() : null,
            Description = this.Description,
            AltText = this.AltText,
            SeoKeywords = this.SeoKeywords != null ? (string[])this.SeoKeywords.Clone() : null,
            BrandGuidelinesNotes = this.BrandGuidelinesNotes,
            IsActive = this.IsActive,
            IsDefault = this.IsDefault,
            Priority = this.Priority,
            IsApproved = this.IsApproved,
            ApprovalDate = this.ApprovalDate,
            ApprovedBy = this.ApprovedBy,
            VersionNumber = this.VersionNumber,
            ParentLogoId = this.ParentLogoId,
            IsCurrentVersion = this.IsCurrentVersion,
            LastAccessed = this.LastAccessed,
            AccessCount = this.AccessCount,
            CreatedBy = this.CreatedBy,
            CreatedAt = this.CreatedAt,
            UpdatedBy = this.UpdatedBy,
            UpdatedAt = this.UpdatedAt
        };
    }
}
