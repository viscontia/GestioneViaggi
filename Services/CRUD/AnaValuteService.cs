using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.CRUD;

public class AnaValuteService
{
    private readonly IDatabaseService _dbService;
    private readonly ILogger<AnaValuteService> _logger;

    public AnaValuteService(IDatabaseService dbService, ILogger<AnaValuteService> logger)
    {
        _dbService = dbService;
        _logger = logger;
    }

    /// <summary>
    /// Recupera tutte le valute attive.
    /// Ordinate per Codice ISO (prima EUR poi le altre).
    /// </summary>
    public async Task<IEnumerable<AnaValute>> GetAllValuteAsync()
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();
            // Ordiniamo EUR per primo, poi alfabetico
            string sql = @"
                SELECT * FROM ana_valute 
                WHERE valuta_attiva = TRUE 
                ORDER BY CASE WHEN valuta_codice_iso = 'EUR' THEN 0 ELSE 1 END, valuta_codice_iso";
            
            return await conn.QueryAsync<AnaValute>(sql);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero delle valute");
            return Enumerable.Empty<AnaValute>();
        }
    }

    /// <summary>
    /// Recupera una valuta per ID.
    /// </summary>
    public async Task<AnaValute?> GetValutaByIdAsync(int id)
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();
            return await conn.QueryFirstOrDefaultAsync<AnaValute>("SELECT * FROM ana_valute WHERE valuta_id = @Id", new { Id = id });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il recupero della valuta {Id}", id);
            return null;
        }
    }

    /// <summary>
    /// Crea una nuova valuta.
    /// </summary>
    public async Task CreateAsync(AnaValute valuta)
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();
            string sql = @"
                INSERT INTO ana_valute (
                    valuta_codice_iso,
                    valuta_descrizione,
                    valuta_simbolo,
                    valuta_is_base,
                    valuta_attiva,
                    valuta_decimali
                ) VALUES (
                    @ValutaCodiceIso,
                    @ValutaDescrizione,
                    @ValutaSimbolo,
                    @ValutaIsBase,
                    @ValutaAttiva,
                    @ValutaDecimali
                )";
            
            await conn.ExecuteAsync(sql, valuta);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della valuta {Iso}", valuta.ValutaCodiceIso);
            throw;
        }
    }

    /// <summary>
    /// Aggiorna una valuta esistente.
    /// </summary>
    public async Task UpdateAsync(AnaValute valuta)
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();
            string sql = @"
                UPDATE ana_valute SET 
                    valuta_codice_iso = @ValutaCodiceIso,
                    valuta_descrizione = @ValutaDescrizione,
                    valuta_simbolo = @ValutaSimbolo,
                    valuta_is_base = @ValutaIsBase,
                    valuta_attiva = @ValutaAttiva,
                    valuta_decimali = @ValutaDecimali
                WHERE valuta_id = @ValutaId";
            
            await conn.ExecuteAsync(sql, valuta);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della valuta {Id}", valuta.ValutaId);
            throw;
        }
    }

    /// <summary>
    /// Elimina una valuta per ID.
    /// </summary>
    public async Task DeleteAsync(int id)
    {
        try
        {
            using var conn = await _dbService.GetConnectionAsync();
            await conn.ExecuteAsync("DELETE FROM ana_valute WHERE valuta_id = @Id", new { Id = id });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'eliminazione della valuta {Id}", id);
            throw;
        }
    }
}
