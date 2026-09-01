using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging;
using Npgsql;
using NpgsqlTypes;

namespace GestioneViaggi.Services.CRUD;

public class ContropartiService : BaseCrudService<AnaControparte>
{
    protected override string TableName => "ana_controparti";
    protected override string IdColumnName => "controparte_id";

    public ContropartiService(
        IDatabaseService databaseService,
        ILogger<ContropartiService> logger,
        ITenantContext tenantContext)
        : base(databaseService, logger, tenantContext)
    {
    }

    /// <summary>
    /// Recupera i dati di inizializzazione per il dialog controparte (FAT INIT)
    /// </summary>
    public async Task<GestioneViaggi.Models.DTOs.ControparteInitData> GetControparteInitDataAsync(int? controparteId = null)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            using (var cmd = new NpgsqlCommand("SELECT fn_get_controparte_init_data(@p_controparte_id)", conn))
            {
                cmd.Parameters.AddWithValue("p_controparte_id", (object?)controparteId ?? DBNull.Value);
                var result = await cmd.ExecuteScalarAsync();
                var jsonResult = result?.ToString() ?? "{}";

                return System.Text.Json.JsonSerializer.Deserialize<GestioneViaggi.Models.DTOs.ControparteInitData>(jsonResult, new System.Text.Json.JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                }) ?? new GestioneViaggi.Models.DTOs.ControparteInitData();
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore Fat Init Controparte per ID {ControparteId}", controparteId);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// GetAllAsync con filtro multitenant e JOIN per descrizioni.
    /// Supporta filtro opzionale per tipo (fornitore/cliente).
    /// </summary>
    /// <param name="searchText">
    /// Testo cercato, oppure null per l'elenco intero. Cercare nel database e non filtrare
    /// la lista gia' letta e' cio' che permette di trovare un fornitore appena inserito da
    /// un altro utente: l'inserimento massivo lo fanno in piu' persone insieme.
    /// </param>
    public async Task<List<AnaControparte>> GetAllAsync(int? aziendaIdFilter = null, bool? soloFornitori = null, bool? soloClienti = null, string? searchText = null)
    {
        try
        {
            var currentAziendaId = await GetCurrentAziendaIdAsync();
            await using var connection = await _databaseService.GetConnectionAsync();

            // La query stava qui, costruita concatenando stringhe — filtro azienda compreso:
            //     sql += $" AND c.azienda_fk = {currentAziendaId.Value}";
            // Il confine fra i silos scritto con un'interpolazione. Ora e' un parametro di
            // fn_ana_controparti_get_all (SqlScripts/571), dove sta il resto delle regole.
            //
            // Un utente normale vede solo la propria azienda; il SuperAdmin passa il filtro
            // che ha scelto, e NULL vale "tutte".
            var aziendaDaUsare = currentAziendaId ?? (aziendaIdFilter > 0 ? aziendaIdFilter : null);

            await using var command = new NpgsqlCommand(
                "SELECT * FROM fn_ana_controparti_get_all(@azienda, @soloFornitori, @soloClienti, @searchText::VARCHAR)",
                connection);
            command.Parameters.Add(new NpgsqlParameter("azienda", NpgsqlDbType.Integer)
            {
                Value = (object?)aziendaDaUsare ?? DBNull.Value,
                IsNullable = true
            });
            command.Parameters.Add(new NpgsqlParameter("soloFornitori", NpgsqlDbType.Boolean)
            {
                Value = (object?)soloFornitori ?? DBNull.Value,
                IsNullable = true
            });
            command.Parameters.Add(new NpgsqlParameter("soloClienti", NpgsqlDbType.Boolean)
            {
                Value = (object?)soloClienti ?? DBNull.Value,
                IsNullable = true
            });
            command.Parameters.Add(new NpgsqlParameter("searchText", NpgsqlDbType.Varchar)
            {
                Value = string.IsNullOrWhiteSpace(searchText) ? DBNull.Value : searchText.Trim(),
                IsNullable = true
            });

            await using var reader = await command.ExecuteReaderAsync();

            var list = new List<AnaControparte>();
            while (await reader.ReadAsync())
            {
                list.Add(MapFromReaderWithJoins(reader));
            }
            return list;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento delle controparti");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<AnaControparte> CreateAsync(AnaControparte entity)
    {
        // Create Logic: Respect explicit AziendaFk (e.g. from SuperAdmin selection)
        // If not set (0), try to use current user's context.
        if (entity.AziendaFk == 0)
        {
            var currentAziendaId = await GetCurrentAziendaIdAsync();
            if (currentAziendaId.HasValue)
            {
                entity.AziendaFk = currentAziendaId.Value;
            }
            else
            {
                throw new UnauthorizedAccessException("Operazione non consentita: Nessuna azienda specificata per la nuova controparte.");
            }
        }
        // Else use provided entity.AziendaFk

        await PopulateAuditFieldsAsync(entity, true);
        NormalizeEntityBeforeSave(entity);
        await ValidateDuplicatesAsync(entity, isUpdate: false);

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                INSERT INTO ana_controparti (
                    azienda_fk,
                    ragione_sociale,
                    nome_breve,
                    is_fornitore,
                    is_cliente,
                    indirizzo,
                    comune_fk,
                    telefono_prefisso,
                    telefono_numero,
                    email,
                    pec,
                    sito_web,
                    fornitore_estero,
                    codice_destinatario_sdi,
                    partita_iva,
                    codice_fiscale,
                    tipo_fornitore_fk,
                    attivo,
                    priorita,
                    note,
                    created_by,
                    created_at,
                    updated_by,
                    updated_at
                )
                VALUES (
                    @aziendaFk,
                    @ragioneSociale,
                    @nomeBreve,
                    @isFornitore,
                    @isCliente,
                    @indirizzo,
                    @comuneFk,
                    @telefonoPrefisso,
                    @telefonoNumero,
                    @email,
                    @pec,
                    @sitoWeb,
                    @fornitoreEstero,
                    @codiceDestinatarioSdi,
                    @partitaIva,
                    @codiceFiscale,
                    @tipoFornitoreFk,
                    @attivo,
                    @priorita,
                    @note,
                    @createdBy,
                    @createdAt,
                    @updatedBy,
                    @updatedAt
                )
                RETURNING *";

            await using var command = new NpgsqlCommand(sql, connection);
            AddCommandParameters(command, entity);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }
            throw new Exception("Impossibile creare la controparte");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della controparte");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    public override async Task<AnaControparte> UpdateAsync(AnaControparte entity)
    {
        // Validazione tenant: verifica accesso all'azienda
        await ValidateTenantAccessAsync(entity.AziendaFk);
        await PopulateAuditFieldsAsync(entity, false);
        NormalizeEntityBeforeSave(entity);
        await ValidateDuplicatesAsync(entity, isUpdate: true);

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_controparti
                SET
                    ragione_sociale = @ragioneSociale,
                    nome_breve = @nomeBreve,
                    is_fornitore = @isFornitore,
                    is_cliente = @isCliente,
                    indirizzo = @indirizzo,
                    comune_fk = @comuneFk,
                    telefono_prefisso = @telefonoPrefisso,
                    telefono_numero = @telefonoNumero,
                    email = @email,
                    pec = @pec,
                    sito_web = @sitoWeb,
                    fornitore_estero = @fornitoreEstero,
                    codice_destinatario_sdi = @codiceDestinatarioSdi,
                    partita_iva = @partitaIva,
                    codice_fiscale = @codiceFiscale,
                    tipo_fornitore_fk = @tipoFornitoreFk,
                    attivo = @attivo,
                    priorita = @priorita,
                    note = @note,
                    updated_by = @updatedBy,
                    updated_at = @updatedAt
                WHERE controparte_id = @id
                RETURNING *";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", entity.Id);
            AddCommandParameters(command, entity);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }
            throw new Exception($"Controparte con ID {entity.Id} non trovata");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della controparte");
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    /// <summary>
    /// Override di GetById per includere anche le descrizioni tramite JOIN (utile per View)
    /// </summary>
    public override async Task<AnaControparte?> GetByIdAsync(int id)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            // Prima recupero l'azienda_fk per validare l'accesso tenant
            var sqlAziendaCheck = "SELECT azienda_fk FROM ana_controparti WHERE controparte_id = @id";
            await using var cmdCheck = new NpgsqlCommand(sqlAziendaCheck, connection);
            cmdCheck.Parameters.AddWithValue("id", id);

            var aziendaFk = await cmdCheck.ExecuteScalarAsync();
            if (aziendaFk == null || aziendaFk == DBNull.Value)
            {
                return null; // Controparte non trovata
            }

            // Validazione tenant: verifica accesso all'azienda
            await ValidateTenantAccessAsync((int)aziendaFk);

            // Ora posso fare la query completa con i JOIN
            var sql = @"
                SELECT
                    c.*,
                    tf.descrizione as tipo_fornitore_desc,
                    co.comune_descrizione,
                    p.provincia_sigla
                FROM ana_controparti c
                LEFT JOIN ana_tipo_fornitore tf ON c.tipo_fornitore_fk = tf.tipo_fornitore_id
                LEFT JOIN ana_geo_comuni co ON c.comune_fk = co.comune_id
                LEFT JOIN ana_geo_province p ON co.comune_provincia_fk = p.provincia_id
                WHERE c.controparte_id = @id";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", id);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReaderWithJoins(reader);
            }
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore GetByIdAsync controparte {Id}", id);
            throw Helpers.DatabaseExceptionHelper.WrapException(ex, TableName);
        }
    }

    protected override AnaControparte MapFromReader(NpgsqlDataReader reader)
    {
        return new AnaControparte
        {
            Id = ReadInt(reader, "controparte_id"),
            AziendaFk = ReadInt(reader, "azienda_fk"),
            RagioneSociale = reader.GetString(reader.GetOrdinal("ragione_sociale")),
            NomeBreve = ReadNullableString(reader, "nome_breve"),
            IsFornitore = reader.GetBoolean(reader.GetOrdinal("is_fornitore")),
            IsCliente = reader.GetBoolean(reader.GetOrdinal("is_cliente")),
            Indirizzo = ReadNullableString(reader, "indirizzo"),
            ComuneFk = ReadNullableInt(reader, "comune_fk"),
            TelefonoPrefisso = ReadNullableString(reader, "telefono_prefisso"),
            TelefonoNumero = ReadNullableString(reader, "telefono_numero"),
            Email = ReadNullableString(reader, "email"),
            Pec = ReadNullableString(reader, "pec"),
            SitoWeb = ReadNullableString(reader, "sito_web"),
            FornitoreEstero = reader.GetBoolean(reader.GetOrdinal("fornitore_estero")),
            CodiceSdi = ReadNullableString(reader, "codice_destinatario_sdi"),
            PartitaIva = ReadNullableString(reader, "partita_iva"),
            CodiceFiscale = ReadNullableString(reader, "codice_fiscale"),
            TipoFornitoreFk = ReadNullableInt(reader, "tipo_fornitore_fk"),
            Attivo = reader.GetBoolean(reader.GetOrdinal("attivo")),
            Priorita = reader.GetInt32(reader.GetOrdinal("priorita")),
            Note = ReadNullableString(reader, "note"),
            Created = ReadNullableDateTime(reader, "created_at"),
            CreatedBy = ReadNullableString(reader, "created_by"),
            Updated = ReadNullableDateTime(reader, "updated_at"),
            UpdatedBy = ReadNullableString(reader, "updated_by")
        };
    }

    private AnaControparte MapFromReaderWithJoins(NpgsqlDataReader reader)
    {
        var entity = MapFromReader(reader);
        entity.TipoFornitoreDescrizione = ReadNullableString(reader, "tipo_fornitore_desc");
        entity.ComuneDescrizione = ReadNullableString(reader, "comune_descrizione");
        entity.ProvinciaSigla = ReadNullableString(reader, "provincia_sigla");
        return entity;
    }

    private void AddCommandParameters(NpgsqlCommand command, AnaControparte entity)
    {
        command.Parameters.AddWithValue("aziendaFk", entity.AziendaFk);
        command.Parameters.AddWithValue("ragioneSociale", entity.RagioneSociale);

        // Parametri nullable - specifica il tipo per evitare errore "could not determine data type"
        AddNullableStringParameter(command, "nomeBreve", entity.NomeBreve);

        // I due flag
        command.Parameters.AddWithValue("isFornitore", entity.IsFornitore);
        command.Parameters.AddWithValue("isCliente", entity.IsCliente);

        AddNullableStringParameter(command, "indirizzo", entity.Indirizzo);

        if (entity.ComuneFk.HasValue)
            command.Parameters.AddWithValue("comuneFk", entity.ComuneFk.Value);
        else
            command.Parameters.Add(new NpgsqlParameter("comuneFk", NpgsqlTypes.NpgsqlDbType.Integer) { Value = DBNull.Value });

        AddNullableStringParameter(command, "telefonoPrefisso", entity.TelefonoPrefisso);
        AddNullableStringParameter(command, "telefonoNumero", entity.TelefonoNumero);
        AddNullableStringParameter(command, "email", entity.Email);
        AddNullableStringParameter(command, "pec", entity.Pec);
        AddNullableStringParameter(command, "sitoWeb", entity.SitoWeb);

        command.Parameters.AddWithValue("fornitoreEstero", entity.FornitoreEstero);

        AddNullableStringParameter(command, "codiceDestinatarioSdi", entity.CodiceSdi);
        AddNullableStringParameter(command, "partitaIva", entity.PartitaIva);
        AddNullableStringParameter(command, "codiceFiscale", entity.CodiceFiscale);

        if (entity.TipoFornitoreFk.HasValue)
            command.Parameters.AddWithValue("tipoFornitoreFk", entity.TipoFornitoreFk.Value);
        else
            command.Parameters.Add(new NpgsqlParameter("tipoFornitoreFk", NpgsqlTypes.NpgsqlDbType.Integer) { Value = DBNull.Value });

        command.Parameters.AddWithValue("attivo", entity.Attivo);
        command.Parameters.AddWithValue("priorita", entity.Priorita);

        AddNullableStringParameter(command, "note", entity.Note);

        // Audit parameters
        command.Parameters.AddWithValue("createdBy", (object?)entity.CreatedBy ?? DBNull.Value);
        command.Parameters.AddWithValue("createdAt", (object?)entity.Created ?? DBNull.Value);
        command.Parameters.AddWithValue("updatedBy", (object?)entity.UpdatedBy ?? DBNull.Value);
        command.Parameters.AddWithValue("updatedAt", (object?)entity.Updated ?? DBNull.Value);
    }

    /// <summary>
    /// Helper per aggiungere parametri string nullable con tipo esplicito.
    /// Evita l'errore PostgreSQL "could not determine data type of parameter".
    /// </summary>
    private static void AddNullableStringParameter(NpgsqlCommand command, string paramName, string? value)
    {
        if (!string.IsNullOrEmpty(value))
            command.Parameters.AddWithValue(paramName, value);
        else
            command.Parameters.Add(new NpgsqlParameter(paramName, NpgsqlTypes.NpgsqlDbType.Varchar) { Value = DBNull.Value });
    }

    /// <summary>
    /// Normalizza i dati della controparte prima del salvataggio.
    /// - Gestione automatica Codice SDI in base al tipo
    /// - Uppercase/Lowercase appropriati
    /// - Trim e conversione empty string → NULL
    /// </summary>
    private new void NormalizeEntityBeforeSave(AnaControparte entity)
    {
        // ===== GESTIONE AUTOMATICA CODICE SDI =====
        if (entity.FornitoreEstero)
        {
            // Controparte estera: SDI fisso
            entity.CodiceSdi = "XXXXXXX";
        }
        else
        {
            // Controparte italiana: default se non specificato
            if (string.IsNullOrWhiteSpace(entity.CodiceSdi))
            {
                entity.CodiceSdi = "0000000";
            }
        }

        // ===== NORMALIZZAZIONE CAMPI TESTO =====
        entity.RagioneSociale = entity.RagioneSociale?.Trim().ToUpperInvariant() ?? string.Empty;
        entity.NomeBreve = NormalizeToUpperOrNull(entity.NomeBreve);
        entity.Indirizzo = NormalizeToUpperOrNull(entity.Indirizzo);
        entity.Note = NormalizeToUpperOrNull(entity.Note);

        // ===== NORMALIZZAZIONE CAMPI FISCALI =====
        entity.PartitaIva = NormalizeToUpperOrNull(entity.PartitaIva);
        entity.CodiceFiscale = NormalizeToUpperOrNull(entity.CodiceFiscale);
        entity.CodiceSdi = NormalizeToUpperOrNull(entity.CodiceSdi);

        // ===== NORMALIZZAZIONE CONTATTI =====
        entity.Email = NormalizeToLowerOrNull(entity.Email);
        entity.Pec = NormalizeToLowerOrNull(entity.Pec);
        entity.SitoWeb = NormalizeToLowerOrNull(entity.SitoWeb);

        entity.TelefonoPrefisso = NormalizeTrimOrNull(entity.TelefonoPrefisso);
        entity.TelefonoNumero = NormalizeTrimOrNull(entity.TelefonoNumero);
    }

    /// <summary>
    /// Valida unicità P.IVA/CF/VAT Number prima di INSERT/UPDATE.
    /// </summary>
    private async Task ValidateDuplicatesAsync(AnaControparte entity, bool isUpdate)
    {
        int? excludeId = isUpdate ? entity.Id : null;

        await using var connection = await _databaseService.GetConnectionAsync();

        // ===== CONTROPARTI ITALIANE =====
        if (!entity.FornitoreEstero)
        {
            // Verifica P.IVA italiana duplicata
            if (!string.IsNullOrWhiteSpace(entity.PartitaIva))
            {
                var sqlPiva = @"
                    SELECT COUNT(*)
                    FROM ana_controparti
                    WHERE azienda_fk = @aziendaFk
                      AND partita_iva = @partitaIva
                      AND fornitore_estero = FALSE
                      AND (@excludeId IS NULL OR controparte_id != @excludeId)";

                await using var cmdPiva = new NpgsqlCommand(sqlPiva, connection);
                cmdPiva.Parameters.AddWithValue("aziendaFk", entity.AziendaFk);
                cmdPiva.Parameters.AddWithValue("partitaIva", entity.PartitaIva);
                AddNullableIntParameter(cmdPiva, "excludeId", excludeId);

                var count = (long)(await cmdPiva.ExecuteScalarAsync() ?? 0L);
                if (count > 0)
                {
                    throw new InvalidOperationException(
                        $"Partita IVA {entity.PartitaIva} già presente per un'altra controparte italiana di questa azienda"
                    );
                }
            }

            // Verifica CF duplicato
            if (!string.IsNullOrWhiteSpace(entity.CodiceFiscale))
            {
                var sqlCf = @"
                    SELECT COUNT(*)
                    FROM ana_controparti
                    WHERE azienda_fk = @aziendaFk
                      AND codice_fiscale = @codiceFiscale
                      AND fornitore_estero = FALSE
                      AND (@excludeId IS NULL OR controparte_id != @excludeId)";

                await using var cmdCf = new NpgsqlCommand(sqlCf, connection);
                cmdCf.Parameters.AddWithValue("aziendaFk", entity.AziendaFk);
                cmdCf.Parameters.AddWithValue("codiceFiscale", entity.CodiceFiscale);
                AddNullableIntParameter(cmdCf, "excludeId", excludeId);

                var count = (long)(await cmdCf.ExecuteScalarAsync() ?? 0L);
                if (count > 0)
                {
                    throw new InvalidOperationException(
                        $"Codice Fiscale {entity.CodiceFiscale} già presente per un'altra controparte italiana di questa azienda"
                    );
                }
            }
        }
        // ===== CONTROPARTI ESTERE =====
        else
        {
            // Verifica VAT Number duplicato
            if (!string.IsNullOrWhiteSpace(entity.PartitaIva))
            {
                var sqlVat = @"
                    SELECT COUNT(*)
                    FROM ana_controparti
                    WHERE azienda_fk = @aziendaFk
                      AND partita_iva = @vatNumber
                      AND fornitore_estero = TRUE
                      AND (@excludeId IS NULL OR controparte_id != @excludeId)";

                await using var cmdVat = new NpgsqlCommand(sqlVat, connection);
                cmdVat.Parameters.AddWithValue("aziendaFk", entity.AziendaFk);
                cmdVat.Parameters.AddWithValue("vatNumber", entity.PartitaIva);
                AddNullableIntParameter(cmdVat, "excludeId", excludeId);

                var count = (long)(await cmdVat.ExecuteScalarAsync() ?? 0L);
                if (count > 0)
                {
                    throw new InvalidOperationException(
                        $"VAT Number {entity.PartitaIva} già presente per un'altra controparte estera di questa azienda"
                    );
                }
            }
        }
    }

    /// <summary>
    /// Helper per aggiungere parametri int nullable con tipo esplicito.
    /// </summary>
    private static void AddNullableIntParameter(NpgsqlCommand command, string paramName, int? value)
    {
        if (value.HasValue)
            command.Parameters.AddWithValue(paramName, value.Value);
        else
            command.Parameters.Add(new NpgsqlParameter(paramName, NpgsqlTypes.NpgsqlDbType.Integer) { Value = DBNull.Value });
    }

    // Helper methods per normalizzazione
    private static string? NormalizeToUpperOrNull(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim().ToUpperInvariant();

    private static string? NormalizeToLowerOrNull(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim().ToLowerInvariant();

    private static string? NormalizeTrimOrNull(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
