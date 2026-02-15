using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class AnaValuteService : BaseCrudService<AnaValute>
{
    protected override string TableName => "ana_valute";
    protected override string IdColumnName => "valuta_id";

    public AnaValuteService(IDatabaseService dbService, ILogger<AnaValuteService> logger, ITenantContext tenantContext)
        : base(dbService, logger, tenantContext)
    {
    }

    /// <summary>
    /// Recupera tutte le valute attive.
    /// Ordinate per Codice ISO (prima EUR poi le altre).
    /// </summary>
    public async Task<IEnumerable<AnaValute>> GetAllValuteAsync()
    {
        try
        {
            using var conn = await _databaseService.GetConnectionAsync();
            // Ordiniamo EUR per primo, poi alfabetico
            string sql = @"
                SELECT * FROM ana_valute 
                WHERE valuta_attiva = TRUE 
                ORDER BY CASE WHEN valuta_codice_iso = 'EUR' THEN 0 ELSE 1 END, valuta_codice_iso";
            
            var results = await conn.QueryAsync<AnaValute>(sql);
            // Siccome Dapper non mappa automaticamente Id a ValutaId via attributi in QueryAsync senza configurazione extra,
            // e noi abbiamo ValutaId nel modello, assicuriamoci che Id sia popolato se necessario (anche se abbiamo l'override).
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero delle valute");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "valuta");
        }
    }

    public override async Task<AnaValute> CreateAsync(AnaValute entity)
    {
        await PopulateAuditFieldsAsync(entity, true);
        try
        {
            using var conn = await _databaseService.GetConnectionAsync();
            string sql = @"
                INSERT INTO ana_valute (
                    valuta_codice_iso,
                    valuta_descrizione,
                    valuta_simbolo,
                    valuta_is_base,
                    valuta_attiva,
                    valuta_decimali,
                    created_at,
                    created_by,
                    updated_at,
                    updated_by
                ) VALUES (
                    @ValutaCodiceIso,
                    @ValutaDescrizione,
                    @ValutaSimbolo,
                    @ValutaIsBase,
                    @ValutaAttiva,
                    @ValutaDecimali,
                    @Created,
                    @CreatedBy,
                    @Updated,
                    @UpdatedBy
                ) RETURNING valuta_id";
            
            entity.ValutaId = await conn.ExecuteScalarAsync<int>(sql, entity);
            return entity;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della valuta {Iso}", entity.ValutaCodiceIso);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<AnaValute> UpdateAsync(AnaValute entity)
    {
        await PopulateAuditFieldsAsync(entity, false);
        try
        {
            using var conn = await _databaseService.GetConnectionAsync();
            string sql = @"
                UPDATE ana_valute SET 
                    valuta_codice_iso = @ValutaCodiceIso,
                    valuta_descrizione = @ValutaDescrizione,
                    valuta_simbolo = @ValutaSimbolo,
                    valuta_is_base = @ValutaIsBase,
                    valuta_attiva = @ValutaAttiva,
                    valuta_decimali = @ValutaDecimali,
                    updated_at = @Updated,
                    updated_by = @UpdatedBy
                WHERE valuta_id = @ValutaId";
            
            await conn.ExecuteAsync(sql, entity);
            return entity;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della valuta {Id}", entity.ValutaId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    protected override AnaValute MapFromReader(NpgsqlDataReader reader)
    {
        return new AnaValute
        {
            ValutaId = ReadInt(reader, "valuta_id"),
            ValutaCodiceIso = reader.GetString(reader.GetOrdinal("valuta_codice_iso")),
            ValutaDescrizione = reader.GetString(reader.GetOrdinal("valuta_descrizione")),
            ValutaSimbolo = ReadNullableString(reader, "valuta_simbolo"),
            ValutaIsBase = reader.GetBoolean(reader.GetOrdinal("valuta_is_base")),
            ValutaAttiva = reader.GetBoolean(reader.GetOrdinal("valuta_attiva")),
            ValutaDecimali = reader.GetInt32(reader.GetOrdinal("valuta_decimali")),
            Created = ReadNullableDateTime(reader, "created_at"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Updated = ReadNullableDateTime(reader, "updated_at"),
            UpdatedBy = ReadNullableString(reader, "updated_by")
        };
    }
}
