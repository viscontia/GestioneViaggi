using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class AziendaLogoService
{
    protected readonly IDatabaseService _databaseService;
    protected readonly ILogger<AziendaLogoService> _logger;

    public AziendaLogoService(IDatabaseService databaseService, ILogger<AziendaLogoService> logger)
    {
        _databaseService = databaseService;
        _logger = logger;
    }

    protected int ReadInt(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.GetInt32(ordinal);
    }

    protected int? ReadNullableInt(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetInt32(ordinal);
    }

    protected string? ReadNullableString(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    }

    protected DateTime? ReadNullableDateTime(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetDateTime(ordinal);
    }

    protected void NormalizeEntityBeforeSave(AziendaLogo entity)
    {
        if (string.IsNullOrWhiteSpace(entity.Description))
            entity.Description = null;
        if (string.IsNullOrWhiteSpace(entity.BrandGuidelinesNotes))
            entity.BrandGuidelinesNotes = null;
    }

    public async Task<AziendaLogo> CreateAsync(AziendaLogo entity)
    {
        // Normalizza stringhe nullable (converte "" in NULL)
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_aziende_logo (
                    azienda_fk, logo_type, logo_variant, file_name, original_filename,
                    file_format, mime_type, file_size_bytes, binary_data, image_width,
                    image_height, has_transparency, color_mode, color_depth, is_compressed,
                    compression_quality, is_web_optimized, dpi, file_hash, md5_hash,
                    usage_context, description, alt_text, seo_keywords, brand_guidelines_notes,
                    is_active, is_default, priority, is_approved, approval_date,
                    approved_by, version_number, parent_logo_id, is_current_version,
                    created_by
                )
                VALUES (
                    @aziendaFk, @logoType, @logoVariant, @fileName, @originalFilename,
                    @fileFormat, @mimeType, @fileSizeBytes, @binaryData, @imageWidth,
                    @imageHeight, @hasTransparency, @colorMode, @colorDepth, @isCompressed,
                    @compressionQuality, @isWebOptimized, @dpi, @fileHash, @md5Hash,
                    @usageContext, @description, @altText, @seoKeywords, @brandGuidelinesNotes,
                    @isActive, @isDefault, @priority, @isApproved, @approvalDate,
                    @approvedBy, @versionNumber, @parentLogoId, @isCurrentVersion,
                    @createdBy
                )
                RETURNING logo_id, azienda_fk, logo_type, logo_variant, file_name, original_filename,
                          file_format, mime_type, file_size_bytes, image_width, image_height,
                          has_transparency, color_mode, color_depth, is_compressed, compression_quality,
                          is_web_optimized, dpi, file_hash, md5_hash, usage_context, description,
                          alt_text, seo_keywords, brand_guidelines_notes, is_active, is_default,
                          priority, is_approved, approval_date, approved_by, version_number,
                          parent_logo_id, is_current_version, last_accessed, access_count,
                          created_by, created_at, updated_by, updated_at";

            await using var command = new NpgsqlCommand(sql, connection);
            AddLogoParameters(command, entity);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader, includeBinaryData: false);
            }

            throw new Exception("Impossibile creare il logo");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione del logo");
            throw;
        }
    }

    public async Task<AziendaLogo> UpdateAsync(AziendaLogo entity)
    {
        // Normalizza stringhe nullable (converte "" in NULL)
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_aziende_logo
                SET logo_type = @logoType,
                    logo_variant = @logoVariant,
                    file_name = @fileName,
                    original_filename = @originalFilename,
                    file_format = @fileFormat,
                    mime_type = @mimeType,
                    file_size_bytes = @fileSizeBytes,
                    binary_data = @binaryData,
                    image_width = @imageWidth,
                    image_height = @imageHeight,
                    has_transparency = @hasTransparency,
                    color_mode = @colorMode,
                    color_depth = @colorDepth,
                    is_compressed = @isCompressed,
                    compression_quality = @compressionQuality,
                    is_web_optimized = @isWebOptimized,
                    dpi = @dpi,
                    file_hash = @fileHash,
                    md5_hash = @md5Hash,
                    usage_context = @usageContext,
                    description = @description,
                    alt_text = @altText,
                    seo_keywords = @seoKeywords,
                    brand_guidelines_notes = @brandGuidelinesNotes,
                    is_active = @isActive,
                    is_default = @isDefault,
                    priority = @priority,
                    is_approved = @isApproved,
                    approval_date = @approvalDate,
                    approved_by = @approvedBy,
                    version_number = @versionNumber,
                    parent_logo_id = @parentLogoId,
                    is_current_version = @isCurrentVersion,
                    updated_by = @updatedBy
                WHERE logo_id = @id
                RETURNING logo_id, azienda_fk, logo_type, logo_variant, file_name, original_filename,
                          file_format, mime_type, file_size_bytes, image_width, image_height,
                          has_transparency, color_mode, color_depth, is_compressed, compression_quality,
                          is_web_optimized, dpi, file_hash, md5_hash, usage_context, description,
                          alt_text, seo_keywords, brand_guidelines_notes, is_active, is_default,
                          priority, is_approved, approval_date, approved_by, version_number,
                          parent_logo_id, is_current_version, last_accessed, access_count,
                          created_by, created_at, updated_by, updated_at";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", Guid.Parse(entity.Id.ToString()));
            command.Parameters.AddWithValue("updatedBy", (object?)entity.UpdatedBy ?? DBNull.Value);
            AddLogoParameters(command, entity);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader, includeBinaryData: false);
            }

            throw new Exception($"Logo con ID {entity.Id} non trovato");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento del logo");
            throw;
        }
    }

    private void AddLogoParameters(NpgsqlCommand command, AziendaLogo entity)
    {
        command.Parameters.AddWithValue("aziendaFk", entity.AziendaIdFk);
        command.Parameters.AddWithValue("logoType", entity.LogoType);
        command.Parameters.AddWithValue("logoVariant", (object?)entity.LogoVariant ?? DBNull.Value);
        command.Parameters.AddWithValue("fileName", entity.FileName);
        command.Parameters.AddWithValue("originalFilename", entity.OriginalFilename);
        command.Parameters.AddWithValue("fileFormat", entity.FileFormat);
        command.Parameters.AddWithValue("mimeType", entity.MimeType);
        command.Parameters.AddWithValue("fileSizeBytes", entity.FileSizeBytes);
        command.Parameters.AddWithValue("binaryData", entity.BinaryData);
        command.Parameters.AddWithValue("imageWidth", (object?)entity.ImageWidth ?? DBNull.Value);
        command.Parameters.AddWithValue("imageHeight", (object?)entity.ImageHeight ?? DBNull.Value);
        command.Parameters.AddWithValue("hasTransparency", entity.HasTransparency);
        command.Parameters.AddWithValue("colorMode", (object?)entity.ColorMode ?? DBNull.Value);
        command.Parameters.AddWithValue("colorDepth", (object?)entity.ColorDepth ?? DBNull.Value);
        command.Parameters.AddWithValue("isCompressed", entity.IsCompressed);
        command.Parameters.AddWithValue("compressionQuality", (object?)entity.CompressionQuality ?? DBNull.Value);
        command.Parameters.AddWithValue("isWebOptimized", entity.IsWebOptimized);
        command.Parameters.AddWithValue("dpi", (object?)entity.Dpi ?? DBNull.Value);
        command.Parameters.AddWithValue("fileHash", entity.FileHash);
        command.Parameters.AddWithValue("md5Hash", entity.Md5Hash);
        command.Parameters.AddWithValue("usageContext", entity.UsageContext ?? new string[] { "web" });
        command.Parameters.AddWithValue("description", (object?)entity.Description ?? DBNull.Value);
        command.Parameters.AddWithValue("altText", entity.AltText);
        command.Parameters.AddWithValue("seoKeywords", (object?)entity.SeoKeywords ?? DBNull.Value);
        command.Parameters.AddWithValue("brandGuidelinesNotes", (object?)entity.BrandGuidelinesNotes ?? DBNull.Value);
        command.Parameters.AddWithValue("isActive", entity.IsActive);
        command.Parameters.AddWithValue("isDefault", entity.IsDefault);
        command.Parameters.AddWithValue("priority", entity.Priority);
        command.Parameters.AddWithValue("isApproved", entity.IsApproved);
        command.Parameters.AddWithValue("approvalDate", (object?)entity.ApprovalDate ?? DBNull.Value);
        command.Parameters.AddWithValue("approvedBy", (object?)entity.ApprovedBy ?? DBNull.Value);
        command.Parameters.AddWithValue("versionNumber", entity.VersionNumber);
        command.Parameters.AddWithValue("parentLogoId", (object?)entity.ParentLogoId ?? DBNull.Value);
        command.Parameters.AddWithValue("isCurrentVersion", entity.IsCurrentVersion);
        command.Parameters.AddWithValue("createdBy", entity.CreatedBy);
    }

    protected AziendaLogo MapFromReader(NpgsqlDataReader reader)
    {
        return MapFromReader(reader, includeBinaryData: true);
    }

    private AziendaLogo MapFromReader(NpgsqlDataReader reader, bool includeBinaryData)
    {
        return new AziendaLogo
        {
            Id = reader.GetGuid(reader.GetOrdinal("logo_id")),
            AziendaIdFk = ReadInt(reader, "azienda_fk"),
            LogoType = reader.GetString(reader.GetOrdinal("logo_type")),
            LogoVariant = ReadNullableString(reader, "logo_variant"),
            FileName = reader.GetString(reader.GetOrdinal("file_name")),
            OriginalFilename = reader.GetString(reader.GetOrdinal("original_filename")),
            FileFormat = reader.GetString(reader.GetOrdinal("file_format")),
            MimeType = reader.GetString(reader.GetOrdinal("mime_type")),
            FileSizeBytes = reader.GetInt32(reader.GetOrdinal("file_size_bytes")),
            BinaryData = includeBinaryData ? (byte[])reader["binary_data"] : Array.Empty<byte>(),
            ImageWidth = ReadNullableInt(reader, "image_width"),
            ImageHeight = ReadNullableInt(reader, "image_height"),
            HasTransparency = reader.GetBoolean(reader.GetOrdinal("has_transparency")),
            ColorMode = ReadNullableString(reader, "color_mode"),
            ColorDepth = ReadNullableShort(reader, "color_depth"),
            IsCompressed = reader.GetBoolean(reader.GetOrdinal("is_compressed")),
            CompressionQuality = ReadNullableShort(reader, "compression_quality"),
            IsWebOptimized = reader.GetBoolean(reader.GetOrdinal("is_web_optimized")),
            Dpi = ReadNullableShort(reader, "dpi"),
            FileHash = reader.GetString(reader.GetOrdinal("file_hash")),
            Md5Hash = reader.GetString(reader.GetOrdinal("md5_hash")),
            UsageContext = ReadStringArray(reader, "usage_context"),
            Description = ReadNullableString(reader, "description"),
            AltText = reader.GetString(reader.GetOrdinal("alt_text")),
            SeoKeywords = ReadStringArray(reader, "seo_keywords"),
            BrandGuidelinesNotes = ReadNullableString(reader, "brand_guidelines_notes"),
            IsActive = reader.GetBoolean(reader.GetOrdinal("is_active")),
            IsDefault = reader.GetBoolean(reader.GetOrdinal("is_default")),
            Priority = reader.GetInt16(reader.GetOrdinal("priority")),
            IsApproved = reader.GetBoolean(reader.GetOrdinal("is_approved")),
            ApprovalDate = ReadNullableDateTime(reader, "approval_date"),
            ApprovedBy = ReadNullableGuid(reader, "approved_by"),
            VersionNumber = reader.GetInt16(reader.GetOrdinal("version_number")),
            ParentLogoId = ReadNullableGuid(reader, "parent_logo_id"),
            IsCurrentVersion = reader.GetBoolean(reader.GetOrdinal("is_current_version")),
            LastAccessed = ReadNullableDateTime(reader, "last_accessed"),
            AccessCount = reader.GetInt32(reader.GetOrdinal("access_count")),
            CreatedBy = reader.GetGuid(reader.GetOrdinal("created_by")),
            CreatedAt = reader.GetDateTime(reader.GetOrdinal("created_at")),
            UpdatedBy = ReadNullableGuid(reader, "updated_by"),
            UpdatedAt = ReadNullableDateTime(reader, "updated_at")
        };
    }

    private short? ReadNullableShort(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetInt16(ordinal);
    }

    private Guid? ReadNullableGuid(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetGuid(ordinal);
    }

    private string[]? ReadStringArray(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : (string[])reader[columnName];
    }

    /// <summary>
    /// Ottiene tutti i loghi di una specifica azienda (senza binary data per performance)
    /// </summary>
    public async Task<List<AziendaLogo>> GetByAziendaIdAsync(int aziendaId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT logo_id, azienda_fk, logo_type, logo_variant, file_name, original_filename,
                       file_format, mime_type, file_size_bytes, image_width, image_height,
                       has_transparency, color_mode, color_depth, is_compressed, compression_quality,
                       is_web_optimized, dpi, file_hash, md5_hash, usage_context, description,
                       alt_text, seo_keywords, brand_guidelines_notes, is_active, is_default,
                       priority, is_approved, approval_date, approved_by, version_number,
                       parent_logo_id, is_current_version, last_accessed, access_count,
                       created_by, created_at, updated_by, updated_at
                FROM ana_aziende_logo
                WHERE azienda_fk = @aziendaId
                ORDER BY priority ASC, created_at DESC";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaId", aziendaId);
            await using var reader = await command.ExecuteReaderAsync();

            var logos = new List<AziendaLogo>();
            while (await reader.ReadAsync())
            {
                logos.Add(MapFromReader(reader, includeBinaryData: false));
            }

            return logos;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento dei loghi per azienda {AziendaId}", aziendaId);
            throw;
        }
    }

    /// <summary>
    /// Ottiene un logo specifico con i dati binari
    /// </summary>
    public async Task<AziendaLogo?> GetByIdWithBinaryAsync(Guid logoId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT logo_id, azienda_fk, logo_type, logo_variant, file_name, original_filename,
                       file_format, mime_type, file_size_bytes, binary_data, image_width, image_height,
                       has_transparency, color_mode, color_depth, is_compressed, compression_quality,
                       is_web_optimized, dpi, file_hash, md5_hash, usage_context, description,
                       alt_text, seo_keywords, brand_guidelines_notes, is_active, is_default,
                       priority, is_approved, approval_date, approved_by, version_number,
                       parent_logo_id, is_current_version, last_accessed, access_count,
                       created_by, created_at, updated_by, updated_at
                FROM ana_aziende_logo
                WHERE logo_id = @logoId";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("logoId", logoId);
            await using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                return MapFromReader(reader, includeBinaryData: true);
            }

            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento del logo {LogoId}", logoId);
            throw;
        }
    }
}
