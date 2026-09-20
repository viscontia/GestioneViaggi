using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

/// <summary>
/// Service DB-First per le modalità di pagamento (<c>ana_modalita_pagamento</c>).
/// Tutta la logica sta nelle funzioni PostgreSQL (script 645 e 646).
/// </summary>
public class AnaModalitaPagamentoService : BaseCrudService<AnaModalitaPagamento>
{
    protected override string TableName => "ana_modalita_pagamento";
    protected override string IdColumnName => "modpag_id";
    protected override string? TenantColumnName => "azienda_fk";

    public AnaModalitaPagamentoService(IDatabaseService databaseService,
                                       ILogger<AnaModalitaPagamentoService> logger,
                                       ITenantContext? tenantContext = null)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>Tutte le modalità dell'azienda, attive e non: è la vista della tabella.</summary>
    public async Task<IEnumerable<AnaModalitaPagamento>> GetAllByAziendaAsync(int aziendaId)
        => await LeggiAsync("fn_ana_modalita_pagamento_get_all", aziendaId,
                            "recupero modalità di pagamento");

    /// <summary>Solo le attive: è quello che serve alle tendine.</summary>
    public async Task<IEnumerable<AnaModalitaPagamento>> GetActiveByAziendaAsync(int aziendaId)
        => await LeggiAsync("fn_ana_modalita_pagamento_get_active", aziendaId,
                            "recupero modalità di pagamento attive");

    private async Task<IEnumerable<AnaModalitaPagamento>> LeggiAsync(string funzione, int aziendaId, string cosa)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand($"SELECT * FROM {funzione}(@AziendaId)", conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var results = new List<AnaModalitaPagamento>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(MapFromReader(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il {Cosa} per azienda {AziendaId}", cosa, aziendaId);
            return Enumerable.Empty<AnaModalitaPagamento>();
        }
    }

    public override async Task<AnaModalitaPagamento> CreateAsync(AnaModalitaPagamento entity)
    {
        await PopulateAuditFieldsAsync(entity, true);

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            string sql = @"SELECT sp_ana_modalita_pagamento_create(
                @AziendaFk,
                @ModpagCodice::VARCHAR,
                @ModpagDescrizione::VARCHAR,
                @ModpagGiorni,
                @ModpagFineMese,
                @ModpagSdiModalita::VARCHAR,
                @ModpagSdiCondizioni::VARCHAR,
                @ModpagOrdinamento,
                @IsActive,
                @CreatedBy::VARCHAR
            )";

            await using var cmd = new NpgsqlCommand(sql, conn);
            AggiungiParametriComuni(cmd, entity);
            cmd.Parameters.AddWithValue("AziendaFk", entity.AziendaFk);
            cmd.Parameters.AddWithValue("CreatedBy", (object?)entity.CreatedBy ?? DBNull.Value);

            var result = await cmd.ExecuteScalarAsync();
            entity.ModpagId = Convert.ToInt32(result);

            _logger.LogInformation("Modalità di pagamento {Codice} creata con ID {Id}", entity.ModpagCodice, entity.ModpagId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business logic durante creazione modalità di pagamento: {Error}", pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della modalità di pagamento {Codice}", entity.ModpagCodice);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "modalità di pagamento");
        }
    }

    public override async Task<AnaModalitaPagamento> UpdateAsync(AnaModalitaPagamento entity)
    {
        await PopulateAuditFieldsAsync(entity, false);

        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();

            string sql = @"SELECT sp_ana_modalita_pagamento_update(
                @ModpagId,
                @ModpagCodice::VARCHAR,
                @ModpagDescrizione::VARCHAR,
                @ModpagGiorni,
                @ModpagFineMese,
                @ModpagSdiModalita::VARCHAR,
                @ModpagSdiCondizioni::VARCHAR,
                @ModpagOrdinamento,
                @IsActive,
                @UpdatedBy::VARCHAR
            )";

            await using var cmd = new NpgsqlCommand(sql, conn);
            AggiungiParametriComuni(cmd, entity);
            cmd.Parameters.AddWithValue("ModpagId", entity.ModpagId);
            cmd.Parameters.AddWithValue("UpdatedBy", (object?)entity.UpdatedBy ?? DBNull.Value);

            await cmd.ExecuteNonQueryAsync();

            _logger.LogInformation("Modalità di pagamento {Id} aggiornata", entity.ModpagId);
            return entity;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            _logger.LogWarning("Errore business logic durante aggiornamento modalità di pagamento: {Error}", pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della modalità di pagamento {Id}", entity.ModpagId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "modalità di pagamento");
        }
    }

    public override async Task<bool> DeleteAsync(int id)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand("SELECT sp_ana_modalita_pagamento_delete(@ModpagId)", conn);
            cmd.Parameters.AddWithValue("ModpagId", id);

            await cmd.ExecuteNonQueryAsync();

            _logger.LogInformation("Modalità di pagamento {Id} eliminata", id);
            return true;
        }
        catch (PostgresException pex) when (pex.SqlState == "P0001")
        {
            // ⚠️ Il messaggio dice gia' CHI la sta usando (script 646): arriva all'utente
            // cosi' com'e', perche' riscriverlo qui vorrebbe dire perderlo.
            _logger.LogWarning("Eliminazione modalità di pagamento {Id} rifiutata: {Error}", id, pex.MessageText);
            throw new InvalidOperationException(pex.MessageText);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione della modalità di pagamento {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, "modalità di pagamento");
        }
    }

    private static void AggiungiParametriComuni(NpgsqlCommand cmd, AnaModalitaPagamento entity)
    {
        cmd.Parameters.AddWithValue("ModpagCodice", entity.ModpagCodice.Trim().ToUpperInvariant());
        cmd.Parameters.AddWithValue("ModpagDescrizione", entity.ModpagDescrizione.Trim());
        cmd.Parameters.AddWithValue("ModpagGiorni", entity.ModpagGiorni);
        cmd.Parameters.AddWithValue("ModpagFineMese", entity.ModpagFineMese);
        cmd.Parameters.AddWithValue("ModpagSdiModalita",
            string.IsNullOrWhiteSpace(entity.ModpagSdiModalita) ? DBNull.Value : entity.ModpagSdiModalita);
        cmd.Parameters.AddWithValue("ModpagSdiCondizioni",
            string.IsNullOrWhiteSpace(entity.ModpagSdiCondizioni) ? "TP02" : entity.ModpagSdiCondizioni);
        cmd.Parameters.AddWithValue("ModpagOrdinamento", entity.ModpagOrdinamento);
        cmd.Parameters.AddWithValue("IsActive", entity.IsActive);
    }

    protected override AnaModalitaPagamento MapFromReader(NpgsqlDataReader reader)
    {
        return new AnaModalitaPagamento
        {
            ModpagId = ReadInt(reader, "modpag_id"),
            AziendaFk = ReadInt(reader, "azienda_fk"),
            ModpagCodice = reader.GetString(reader.GetOrdinal("modpag_codice")),
            ModpagDescrizione = reader.GetString(reader.GetOrdinal("modpag_descrizione")),
            ModpagGiorni = ReadInt(reader, "modpag_giorni"),
            ModpagFineMese = reader.GetBoolean(reader.GetOrdinal("modpag_fine_mese")),
            ModpagSdiModalita = ReadNullableString(reader, "modpag_sdi_modalita"),
            ModpagSdiCondizioni = reader.GetString(reader.GetOrdinal("modpag_sdi_condizioni")),
            ModpagOrdinamento = ReadInt(reader, "modpag_ordinamento"),
            IsActive = reader.GetBoolean(reader.GetOrdinal("is_active")),
            Created = ReadNullableDateTime(reader, "created_at"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Updated = ReadNullableDateTime(reader, "updated_at"),
            UpdatedBy = ReadNullableString(reader, "updated_by")
        };
    }
}
