using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class AziendaService : BaseCrudService<Azienda>
{
    protected override string TableName => "ana_aziende";
    protected override string IdColumnName => "azienda_id";

    public AziendaService(
        IDatabaseService databaseService, 
        ILogger<AziendaService> logger,
        ITenantContext tenantContext)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>
    /// Override GetAllAsync con filtro multi-tenant:
    /// - SuperAdmin: vede TUTTE le aziende
    /// - Altri ruoli: vedono SOLO la propria azienda
    /// </summary>
    public override async Task<List<Azienda>> GetAllAsync()
    {
        try
        {
            var currentAziendaId = await GetCurrentAziendaIdAsync();

            await using var connection = await _databaseService.GetConnectionAsync();

            // Base query con JOIN per provincia REA
            var sql = @"
                SELECT
                    a.azienda_id,
                    a.ragione_sociale,
                    a.forma_giuridica,
                    a.data_costituzione,
                    a.data_inizio_attivita,
                    a.capitale_sociale,
                    a.socio_unico,
                    a.in_liquidazione,
                    a.partita_iva,
                    a.codice_fiscale,
                    a.rea_provincia_fk,
                    a.rea_numero,
                    a.rea_data_iscrizione,
                    a.codice_destinatario_sdi,
                    a.pec,
                    a.sito_web,
                    a.telefono_principale,
                    a.attivo,
                    a.data_creazione,
                    a.data_ultima_modifica,
                    p.provincia_sigla as rea_provincia_sigla
                FROM ana_aziende a
                LEFT JOIN ana_geo_province p ON a.rea_provincia_fk = p.provincia_id";

            // Applica filtro tenant se NON SuperAdmin
            if (currentAziendaId.HasValue)
            {
                sql += $" WHERE a.azienda_id = {currentAziendaId.Value}";
                _logger.LogDebug("GetAllAsync: Filtering by AziendaId={AziendaId} (non-SuperAdmin)", currentAziendaId.Value);
            }
            else
            {
                _logger.LogDebug("GetAllAsync: No tenant filter (SuperAdmin access)");
            }

            sql += " ORDER BY a.ragione_sociale ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var aziende = new List<Azienda>();
            while (await reader.ReadAsync())
            {
                aziende.Add(MapFromReaderWithJoins(reader));
            }

            _logger.LogInformation("GetAllAsync: Returned {Count} aziende", aziende.Count);
            return aziende;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento delle aziende");
            throw;
        }
    }

    /// <summary>
    /// Override GetByIdAsync con validazione tenant access
    /// </summary>
    public override async Task<Azienda?> GetByIdAsync(int id)
    {
        await ValidateTenantAccessAsync(id);
        return await base.GetByIdAsync(id);
    }

    /// <summary>
    /// Override CreateAsync con validazione tenant:
    /// SOLO SuperAdmin può creare nuove aziende.
    /// </summary>
    public override async Task<Azienda> CreateAsync(Azienda entity)
    {
        // BUSINESS RULE: Solo SuperAdmin può creare aziende
        var currentAziendaId = await GetCurrentAziendaIdAsync();
        if (currentAziendaId.HasValue)
        {
            _logger.LogWarning("SECURITY: Non-SuperAdmin user attempted to create new Azienda");
            throw new UnauthorizedAccessException("Solo l'amministratore SuperAdmin può creare nuove aziende.");
        }

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_aziende (
                    ragione_sociale,
                    forma_giuridica,
                    data_costituzione,
                    data_inizio_attivita,
                    capitale_sociale,
                    socio_unico,
                    in_liquidazione,
                    partita_iva,
                    codice_fiscale,
                    rea_provincia_fk,
                    rea_numero,
                    rea_data_iscrizione,
                    codice_destinatario_sdi,
                    pec,
                    sito_web,
                    telefono_principale,
                    attivo
                )
                VALUES (
                    @ragioneSociale,
                    @formaGiuridica,
                    @dataCostituzione,
                    @dataInizioAttivita,
                    @capitaleSociale,
                    @socioUnico,
                    @inLiquidazione,
                    @partitaIva,
                    @codiceFiscale,
                    @reaProvinciaFk,
                    @reaNumero,
                    @reaDataIscrizione,
                    @codiceDestinatarioSdi,
                    @pec,
                    @sitoWeb,
                    @telefonoPrincipale,
                    @attivo
                )
                RETURNING 
                    azienda_id,
                    ragione_sociale,
                    forma_giuridica,
                    data_costituzione,
                    data_inizio_attivita,
                    capitale_sociale,
                    socio_unico,
                    in_liquidazione,
                    partita_iva,
                    codice_fiscale,
                    rea_provincia_fk,
                    rea_numero,
                    rea_data_iscrizione,
                    codice_destinatario_sdi,
                    pec,
                    sito_web,
                    telefono_principale,
                    attivo,
                    data_creazione,
                    data_ultima_modifica";

            await using var command = new NpgsqlCommand(sql, connection);
            AddCommandParameters(command, entity);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare l'azienda");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione dell'azienda");
            throw;
        }
    }

    /// <summary>
    /// Override UpdateAsync con validazione tenant:
    /// - SuperAdmin: può modificare qualsiasi azienda
    /// - Altri ruoli: possono modificare SOLO la propria azienda
    /// </summary>
    public override async Task<Azienda> UpdateAsync(Azienda entity)
    {
        // Valida che l'utente possa accedere a questa azienda
        await ValidateTenantAccessAsync(entity.Id);

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_aziende
                SET
                    ragione_sociale = @ragioneSociale,
                    forma_giuridica = @formaGiuridica,
                    data_costituzione = @dataCostituzione,
                    data_inizio_attivita = @dataInizioAttivita,
                    capitale_sociale = @capitaleSociale,
                    socio_unico = @socioUnico,
                    in_liquidazione = @inLiquidazione,
                    partita_iva = @partitaIva,
                    codice_fiscale = @codiceFiscale,
                    rea_provincia_fk = @reaProvinciaFk,
                    rea_numero = @reaNumero,
                    rea_data_iscrizione = @reaDataIscrizione,
                    codice_destinatario_sdi = @codiceDestinatarioSdi,
                    pec = @pec,
                    sito_web = @sitoWeb,
                    telefono_principale = @telefonoPrincipale,
                    attivo = @attivo
                WHERE azienda_id = @id
                RETURNING 
                    azienda_id,
                    ragione_sociale,
                    forma_giuridica,
                    data_costituzione,
                    data_inizio_attivita,
                    capitale_sociale,
                    socio_unico,
                    in_liquidazione,
                    partita_iva,
                    codice_fiscale,
                    rea_provincia_fk,
                    rea_numero,
                    rea_data_iscrizione,
                    codice_destinatario_sdi,
                    pec,
                    sito_web,
                    telefono_principale,
                    attivo,
                    data_creazione,
                    data_ultima_modifica";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            AddCommandParameters(command, entity);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Azienda con ID {entity.Id} non trovata");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento dell'azienda");
            throw;
        }
    }

    /// <summary>
    /// Override DeleteAsync con validazione tenant:
    /// - SuperAdmin: può eliminare qualsiasi azienda
    /// - Altri ruoli: possono eliminare SOLO la propria azienda (business rule discutibile)
    /// </summary>
    public override async Task<bool> DeleteAsync(int id)
    {
        // Valida che l'utente possa accedere a questa azienda
        await ValidateTenantAccessAsync(id);

        // BUSINESS RULE CONSIDERATION: Permettere agli utenti di eliminare la propria azienda?
        // Potrebbe essere pericoloso. Considerare di limitare solo a SuperAdmin.
        var currentAziendaId = await GetCurrentAziendaIdAsync();
        if (currentAziendaId.HasValue && currentAziendaId.Value == id)
        {
            _logger.LogWarning("SECURITY: User attempted to delete their own Azienda (AziendaId={AziendaId})", id);
            throw new InvalidOperationException("Non è possibile eliminare la propria azienda. Contattare SuperAdmin.");
        }

        return await base.DeleteAsync(id);
    }

    protected override Azienda MapFromReader(NpgsqlDataReader reader)
    {
        return new Azienda
        {
            Id = ReadInt(reader, "azienda_id"),
            RagioneSociale = reader.GetString(reader.GetOrdinal("ragione_sociale")),
            FormaGiuridica = reader.GetString(reader.GetOrdinal("forma_giuridica")),
            DataCostituzione = ReadNullableDateTime(reader, "data_costituzione"),
            DataInizioAttivita = ReadNullableDateTime(reader, "data_inizio_attivita"),
            CapitaleSociale = ReadNullableDecimal(reader, "capitale_sociale"),
            SocioUnico = reader.GetBoolean(reader.GetOrdinal("socio_unico")),
            InLiquidazione = reader.GetBoolean(reader.GetOrdinal("in_liquidazione")),
            PartitaIva = reader.GetString(reader.GetOrdinal("partita_iva")),
            CodiceFiscale = ReadNullableString(reader, "codice_fiscale"),
            ReaProvinciaFk = ReadNullableInt(reader, "rea_provincia_fk"),
            ReaNumero = ReadNullableString(reader, "rea_numero"),
            ReaDataIscrizione = ReadNullableDateTime(reader, "rea_data_iscrizione"),
            CodiceDestinatarioSdi = reader.GetString(reader.GetOrdinal("codice_destinatario_sdi")),
            Pec = ReadNullableString(reader, "pec"),
            SitoWeb = ReadNullableString(reader, "sito_web"),
            TelefonoPrincipale = reader.GetString(reader.GetOrdinal("telefono_principale")),
            Attivo = reader.GetBoolean(reader.GetOrdinal("attivo")),
            DataCreazione = reader.GetDateTime(reader.GetOrdinal("data_creazione")),
            DataUltimaModifica = ReadNullableDateTime(reader, "data_ultima_modifica")
        };
    }

    private Azienda MapFromReaderWithJoins(NpgsqlDataReader reader)
    {
        var azienda = MapFromReader(reader);
        azienda.ReaProvinciaSigla = ReadNullableString(reader, "rea_provincia_sigla");
        return azienda;
    }

    private void AddCommandParameters(NpgsqlCommand command, Azienda entity)
    {
        command.Parameters.AddWithValue("ragioneSociale", entity.RagioneSociale);
        command.Parameters.AddWithValue("formaGiuridica", entity.FormaGiuridica);
        command.Parameters.AddWithValue("dataCostituzione", (object?)entity.DataCostituzione ?? DBNull.Value);
        command.Parameters.AddWithValue("dataInizioAttivita", (object?)entity.DataInizioAttivita ?? DBNull.Value);
        command.Parameters.AddWithValue("capitaleSociale", (object?)entity.CapitaleSociale ?? DBNull.Value);
        command.Parameters.AddWithValue("socioUnico", entity.SocioUnico);
        command.Parameters.AddWithValue("inLiquidazione", entity.InLiquidazione);
        command.Parameters.AddWithValue("partitaIva", entity.PartitaIva);
        command.Parameters.AddWithValue("codiceFiscale", (object?)entity.CodiceFiscale ?? DBNull.Value);
        command.Parameters.AddWithValue("reaProvinciaFk", (object?)entity.ReaProvinciaFk ?? DBNull.Value);
        command.Parameters.AddWithValue("reaNumero", (object?)entity.ReaNumero ?? DBNull.Value);
        command.Parameters.AddWithValue("reaDataIscrizione", (object?)entity.ReaDataIscrizione ?? DBNull.Value);
        command.Parameters.AddWithValue("codiceDestinatarioSdi", entity.CodiceDestinatarioSdi);
        command.Parameters.AddWithValue("pec", (object?)entity.Pec ?? DBNull.Value);
        command.Parameters.AddWithValue("sitoWeb", (object?)entity.SitoWeb ?? DBNull.Value);
        command.Parameters.AddWithValue("telefonoPrincipale", entity.TelefonoPrincipale);
        command.Parameters.AddWithValue("attivo", entity.Attivo);
    }

}
