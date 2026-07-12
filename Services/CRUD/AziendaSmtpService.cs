using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using GestioneViaggi.Validation.Syntax;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class SmtpTestResult
{
    public bool IsSuccess { get; set; }
    public string Message { get; set; } = string.Empty;
    public string? ErrorMessage { get; set; }
    public DateTime TestDate { get; set; }
    public TimeSpan Duration { get; set; }
    /// <summary>Fase in cui si è verificato l'errore: "Connect" o "Authenticate". Null se successo.</summary>
    public string? FailedPhase { get; set; }
}

public class AziendaSmtpService
{
    protected readonly IDatabaseService _databaseService;
    protected readonly ILogger<AziendaSmtpService> _logger;
    protected readonly ITenantContext _tenantContext;
    protected readonly GestioneViaggi.Services.Security.ISecretKeyProvider _secretKey;

    public AziendaSmtpService(
        IDatabaseService databaseService,
        ILogger<AziendaSmtpService> logger,
        ITenantContext tenantContext,
        GestioneViaggi.Services.Security.ISecretKeyProvider secretKey)
    {
        _databaseService = databaseService;
        _logger = logger;
        _tenantContext = tenantContext;
        _secretKey = secretKey;
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

    protected void NormalizeEntityBeforeSave(AziendaSmtp entity)
    {
        if (string.IsNullOrWhiteSpace(entity.Description))
            entity.Description = null;
    }

    protected void ValidateEntity(AziendaSmtp entity)
    {
        // Validazione Host SMTP (Outbound - obbligatorio)
        var hostValidation = SmtpServerValidator.CheckSmtpHost(entity.Host);
        if (!hostValidation.IsValid)
        {
            throw new ArgumentException($"Host SMTP: {hostValidation.ErrorMessage}");
        }

        // Validazione Porta SMTP (Outbound - obbligatorio)
        var portValidation = SmtpServerValidator.CheckSmtpPort(entity.Port);
        if (!portValidation.IsValid)
        {
            throw new ArgumentException($"Porta SMTP: {portValidation.ErrorMessage}");
        }

        // Validazione Username SMTP (Outbound - obbligatorio)
        var usernameValidation = SmtpServerValidator.CheckSmtpUsername(entity.Username);
        if (!usernameValidation.IsValid)
        {
            throw new ArgumentException($"Username SMTP: {usernameValidation.ErrorMessage}");
        }

        // Validazione Password SMTP (Outbound - obbligatorio)
        var passwordValidation = SmtpServerValidator.CheckSmtpPassword(entity.Password);
        if (!passwordValidation.IsValid)
        {
            throw new ArgumentException($"Password SMTP: {passwordValidation.ErrorMessage}");
        }

        // Validazione Email Mittente (FromEmail - obbligatorio)
        var fromEmailValidation = EmailValidator.CheckEmail(entity.FromEmail);
        if (!fromEmailValidation.IsValid)
        {
            throw new ArgumentException($"Email mittente: {fromEmailValidation.ErrorMessage}");
        }

        // Validazione Email Reply-To (obbligatorio)
        var replyToValidation = EmailValidator.CheckEmail(entity.ReplyTo);
        if (!replyToValidation.IsValid)
        {
            throw new ArgumentException($"Reply-To: {replyToValidation.ErrorMessage}");
        }

        // Validazione Inbound Host (opzionale, ma se presente deve essere valido)
        if (!string.IsNullOrWhiteSpace(entity.InboundHost))
        {
            var inboundHostValidation = SmtpServerValidator.CheckSmtpHost(entity.InboundHost);
            if (!inboundHostValidation.IsValid)
            {
                throw new ArgumentException($"Host Inbound: {inboundHostValidation.ErrorMessage}");
            }
        }

        // Validazione Inbound Port (opzionale, ma se presente deve essere valida)
        if (entity.InboundPort.HasValue)
        {
            var inboundPortValidation = SmtpServerValidator.CheckSmtpPort(entity.InboundPort.Value);
            if (!inboundPortValidation.IsValid)
            {
                throw new ArgumentException($"Porta Inbound: {inboundPortValidation.ErrorMessage}");
            }
        }

        // Validazione Inbound Username (opzionale, ma se presente deve essere valido)
        if (!string.IsNullOrWhiteSpace(entity.InboundUsername))
        {
            var inboundUsernameValidation = SmtpServerValidator.CheckSmtpUsername(entity.InboundUsername);
            if (!inboundUsernameValidation.IsValid)
            {
                throw new ArgumentException($"Username Inbound: {inboundUsernameValidation.ErrorMessage}");
            }
        }

        // Validazione Inbound Password (opzionale, ma se presente deve essere valida)
        if (!string.IsNullOrWhiteSpace(entity.InboundPassword))
        {
            var inboundPasswordValidation = SmtpServerValidator.CheckSmtpPassword(entity.InboundPassword);
            if (!inboundPasswordValidation.IsValid)
            {
                throw new ArgumentException($"Password Inbound: {inboundPasswordValidation.ErrorMessage}");
            }
        }

        // Validazione Bounce Email (opzionale, ma se presente deve essere valida)
        if (!string.IsNullOrWhiteSpace(entity.BounceEmail))
        {
            var bounceEmailValidation = EmailValidator.CheckEmail(entity.BounceEmail);
            if (!bounceEmailValidation.IsValid)
            {
                throw new ArgumentException($"Email Bounce: {bounceEmailValidation.ErrorMessage}");
            }
        }

        // Validazione Webhook URL (opzionale, ma se presente deve essere valido)
        if (!string.IsNullOrWhiteSpace(entity.WebhookUrl))
        {
            var webhookUrlValidation = WebsiteValidator.CheckWebsite(entity.WebhookUrl);
            if (!webhookUrlValidation.IsValid)
            {
                throw new ArgumentException($"Webhook URL: {webhookUrlValidation.ErrorMessage}");
            }
        }
    }

    public async Task<AziendaSmtp> CreateAsync(AziendaSmtp entity)
    {
        // Validazione tenant: verifica accesso all'azienda
        await _tenantContext.ValidateAccessAsync(entity.AziendaIdFk);

        // Validazione sintattica campi
        ValidateEntity(entity);

        // Normalizza stringhe nullable (converte "" in NULL)
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            // Cifratura reale via pgcrypto (pgp_sym_encrypt nel SQL). Master key dall'ambiente (GV_SECRET_KEY).
            var master = _secretKey.GetMasterKey();

            var sql = @"
                INSERT INTO ana_aziende_smtp (
                    azienda_fk, config_name, config_type, host, port, username, password_enc,
                    use_tls, use_starttls, from_name, from_email, reply_to, is_active,
                    protocol, security_method, connection_timeout, read_timeout, max_connections,
                    rate_limit_per_hour, priority, description, status, test_frequency_hours,
                    auto_failover, failover_smtp_id,
                    inbound_host, inbound_port, inbound_protocol, inbound_username, inbound_password_enc,
                    inbound_use_ssl, inbound_folder, bounce_handling, bounce_email,
                    tracking_enabled, dkim_enabled, dkim_selector, dkim_private_key,
                    custom_headers, webhook_url, webhook_events
                )
                VALUES (
                    @aziendaFk, @configName, @configType, @host, @port, @username, pgp_sym_encrypt(@password::text, @master::text),
                    @useTls, @useStartTls, @fromName, @fromEmail, @replyTo, @isActive,
                    @protocol, @securityMethod, @connectionTimeout, @readTimeout, @maxConnections,
                    @rateLimitPerHour, @priority, @description, @status, @testFrequencyHours,
                    @autoFailover, @failoverSmtpId,
                    @inboundHost, @inboundPort, @inboundProtocol, @inboundUsername, CASE WHEN @inboundPassword IS NULL THEN NULL ELSE pgp_sym_encrypt(@inboundPassword::text, @master::text) END,
                    @inboundUseSsl, @inboundFolder, @bounceHandling, @bounceEmail,
                    @trackingEnabled, @dkimEnabled, @dkimSelector, @dkimPrivateKey,
                    @customHeaders::jsonb, @webhookUrl, @webhookEvents
                )
                RETURNING smtp_id, azienda_fk, config_name, config_type, host, port, username,
                          use_tls, use_starttls, from_name, from_email, reply_to, is_active,
                          protocol, security_method, connection_timeout, read_timeout, max_connections,
                          rate_limit_per_hour, priority, description, status, last_test_date,
                          last_test_result, last_error_message, test_frequency_hours, auto_failover,
                          failover_smtp_id, inbound_host, inbound_port, inbound_protocol, inbound_username,
                          inbound_use_ssl, inbound_folder, bounce_handling, bounce_email,
                          tracking_enabled, dkim_enabled, dkim_selector, dkim_private_key,
                          custom_headers, webhook_url, webhook_events,
                          created_at, updated_at";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaFk", entity.AziendaIdFk);
            command.Parameters.AddWithValue("configName", entity.ConfigName);
            command.Parameters.AddWithValue("configType", entity.ConfigType);
            command.Parameters.AddWithValue("host", entity.Host);
            command.Parameters.AddWithValue("port", entity.Port);
            command.Parameters.AddWithValue("username", entity.Username);
            command.Parameters.AddWithValue("password", entity.Password);
            command.Parameters.AddWithValue("master", master);
            command.Parameters.AddWithValue("useTls", entity.UseTls);
            command.Parameters.AddWithValue("useStartTls", entity.UseStartTls);
            command.Parameters.AddWithValue("fromName", entity.FromName);
            command.Parameters.AddWithValue("fromEmail", entity.FromEmail);
            command.Parameters.AddWithValue("replyTo", entity.ReplyTo);
            command.Parameters.AddWithValue("isActive", entity.IsActive);
            command.Parameters.AddWithValue("protocol", entity.Protocol);
            command.Parameters.AddWithValue("securityMethod", entity.SecurityMethod);
            command.Parameters.AddWithValue("connectionTimeout", (object?)entity.ConnectionTimeout ?? DBNull.Value);
            command.Parameters.AddWithValue("readTimeout", (object?)entity.ReadTimeout ?? DBNull.Value);
            command.Parameters.AddWithValue("maxConnections", (object?)entity.MaxConnections ?? DBNull.Value);
            command.Parameters.AddWithValue("rateLimitPerHour", (object?)entity.RateLimitPerHour ?? DBNull.Value);
            command.Parameters.AddWithValue("priority", (object?)entity.Priority ?? DBNull.Value);
            command.Parameters.AddWithValue("description", (object?)entity.Description ?? DBNull.Value);
            command.Parameters.AddWithValue("status", entity.Status);
            command.Parameters.AddWithValue("testFrequencyHours", (object?)entity.TestFrequencyHours ?? DBNull.Value);
            command.Parameters.AddWithValue("autoFailover", entity.AutoFailover);
            command.Parameters.AddWithValue("failoverSmtpId", (object?)entity.FailoverSmtpId ?? DBNull.Value);
            command.Parameters.AddWithValue("inboundHost", (object?)entity.InboundHost ?? DBNull.Value);
            command.Parameters.AddWithValue("inboundPort", (object?)entity.InboundPort ?? DBNull.Value);
            command.Parameters.AddWithValue("inboundProtocol", (object?)entity.InboundProtocol ?? DBNull.Value);
            command.Parameters.AddWithValue("inboundUsername", (object?)entity.InboundUsername ?? DBNull.Value);
            command.Parameters.AddWithValue("inboundPassword", (object?)(string.IsNullOrWhiteSpace(entity.InboundPassword) ? null : entity.InboundPassword) ?? DBNull.Value);
            command.Parameters.AddWithValue("inboundUseSsl", (object?)entity.InboundUseSsl ?? DBNull.Value);
            command.Parameters.AddWithValue("inboundFolder", (object?)entity.InboundFolder ?? DBNull.Value);
            command.Parameters.AddWithValue("bounceHandling", entity.BounceHandling);
            command.Parameters.AddWithValue("bounceEmail", (object?)entity.BounceEmail ?? DBNull.Value);
            command.Parameters.AddWithValue("trackingEnabled", entity.TrackingEnabled);
            command.Parameters.AddWithValue("dkimEnabled", entity.DkimEnabled);
            command.Parameters.AddWithValue("dkimSelector", (object?)entity.DkimSelector ?? DBNull.Value);
            command.Parameters.AddWithValue("dkimPrivateKey", (object?)entity.DkimPrivateKey ?? DBNull.Value);
            command.Parameters.AddWithValue("customHeaders", (object?)entity.CustomHeaders ?? DBNull.Value);
            command.Parameters.AddWithValue("webhookUrl", (object?)entity.WebhookUrl ?? DBNull.Value);
            command.Parameters.AddWithValue("webhookEvents", (object?)entity.WebhookEvents ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception("Impossibile creare la configurazione SMTP");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante la creazione della configurazione SMTP");
            throw;
        }
    }

    public async Task<AziendaSmtp> UpdateAsync(AziendaSmtp entity)
    {
        // Validazione tenant: verifica accesso all'azienda
        await _tenantContext.ValidateAccessAsync(entity.AziendaIdFk);

        // Validazione sintattica campi
        ValidateEntity(entity);

        // Normalizza stringhe nullable (converte "" in NULL)
        NormalizeEntityBeforeSave(entity);

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();

            // Cifratura reale via pgcrypto. Password mascherata (***) = non sovrascrivere.
            var master = _secretKey.GetMasterKey();
            var passwordMasked = entity.Password == "***";
            var inboundPasswordMasked = entity.InboundPassword == "***";

            var sql = $@"
                UPDATE ana_aziende_smtp
                SET config_name = @configName,
                    config_type = @configType,
                    host = @host,
                    port = @port,
                    username = @username,
                    password_enc = {(passwordMasked ? "password_enc" : "pgp_sym_encrypt(@password::text, @master::text)")},
                    use_tls = @useTls,
                    use_starttls = @useStartTls,
                    from_name = @fromName,
                    from_email = @fromEmail,
                    reply_to = @replyTo,
                    is_active = @isActive,
                    protocol = @protocol,
                    security_method = @securityMethod,
                    connection_timeout = @connectionTimeout,
                    read_timeout = @readTimeout,
                    max_connections = @maxConnections,
                    rate_limit_per_hour = @rateLimitPerHour,
                    priority = @priority,
                    description = @description,
                    status = @status,
                    test_frequency_hours = @testFrequencyHours,
                    auto_failover = @autoFailover,
                    failover_smtp_id = @failoverSmtpId,
                    inbound_host = @inboundHost,
                    inbound_port = @inboundPort,
                    inbound_protocol = @inboundProtocol,
                    inbound_username = @inboundUsername,
                    inbound_password_enc = {(inboundPasswordMasked ? "inbound_password_enc" : "CASE WHEN @inboundPassword IS NULL THEN NULL ELSE pgp_sym_encrypt(@inboundPassword::text, @master::text) END")},
                    inbound_use_ssl = @inboundUseSsl,
                    inbound_folder = @inboundFolder,
                    bounce_handling = @bounceHandling,
                    bounce_email = @bounceEmail,
                    tracking_enabled = @trackingEnabled,
                    dkim_enabled = @dkimEnabled,
                    dkim_selector = @dkimSelector,
                    dkim_private_key = @dkimPrivateKey,
                    custom_headers = @customHeaders::jsonb,
                    webhook_url = @webhookUrl,
                    webhook_events = @webhookEvents
                WHERE smtp_id = @id
                RETURNING smtp_id, azienda_fk, config_name, config_type, host, port, username,
                          use_tls, use_starttls, from_name, from_email, reply_to, is_active,
                          protocol, security_method, connection_timeout, read_timeout, max_connections,
                          rate_limit_per_hour, priority, description, status, last_test_date,
                          last_test_result, last_error_message, test_frequency_hours, auto_failover,
                          failover_smtp_id, inbound_host, inbound_port, inbound_protocol, inbound_username,
                          inbound_use_ssl, inbound_folder, bounce_handling, bounce_email,
                          tracking_enabled, dkim_enabled, dkim_selector, dkim_private_key,
                          custom_headers, webhook_url, webhook_events,
                          created_at, updated_at";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("id", Guid.Parse(entity.Id.ToString()));
            command.Parameters.AddWithValue("configName", entity.ConfigName);
            command.Parameters.AddWithValue("configType", entity.ConfigType);
            command.Parameters.AddWithValue("host", entity.Host);
            command.Parameters.AddWithValue("port", entity.Port);
            command.Parameters.AddWithValue("username", entity.Username);
            if (!passwordMasked)
                command.Parameters.AddWithValue("password", entity.Password);
            command.Parameters.AddWithValue("master", master);
            command.Parameters.AddWithValue("useTls", entity.UseTls);
            command.Parameters.AddWithValue("useStartTls", entity.UseStartTls);
            command.Parameters.AddWithValue("fromName", entity.FromName);
            command.Parameters.AddWithValue("fromEmail", entity.FromEmail);
            command.Parameters.AddWithValue("replyTo", entity.ReplyTo);
            command.Parameters.AddWithValue("isActive", entity.IsActive);
            command.Parameters.AddWithValue("protocol", entity.Protocol);
            command.Parameters.AddWithValue("securityMethod", entity.SecurityMethod);
            command.Parameters.AddWithValue("connectionTimeout", (object?)entity.ConnectionTimeout ?? DBNull.Value);
            command.Parameters.AddWithValue("readTimeout", (object?)entity.ReadTimeout ?? DBNull.Value);
            command.Parameters.AddWithValue("maxConnections", (object?)entity.MaxConnections ?? DBNull.Value);
            command.Parameters.AddWithValue("rateLimitPerHour", (object?)entity.RateLimitPerHour ?? DBNull.Value);
            command.Parameters.AddWithValue("priority", (object?)entity.Priority ?? DBNull.Value);
            command.Parameters.AddWithValue("description", (object?)entity.Description ?? DBNull.Value);
            command.Parameters.AddWithValue("status", entity.Status);
            command.Parameters.AddWithValue("testFrequencyHours", (object?)entity.TestFrequencyHours ?? DBNull.Value);
            command.Parameters.AddWithValue("autoFailover", entity.AutoFailover);
            command.Parameters.AddWithValue("failoverSmtpId", (object?)entity.FailoverSmtpId ?? DBNull.Value);
            command.Parameters.AddWithValue("inboundHost", (object?)entity.InboundHost ?? DBNull.Value);
            command.Parameters.AddWithValue("inboundPort", (object?)entity.InboundPort ?? DBNull.Value);
            command.Parameters.AddWithValue("inboundProtocol", (object?)entity.InboundProtocol ?? DBNull.Value);
            command.Parameters.AddWithValue("inboundUsername", (object?)entity.InboundUsername ?? DBNull.Value);
            if (!inboundPasswordMasked)
                command.Parameters.AddWithValue("inboundPassword", (object?)(string.IsNullOrWhiteSpace(entity.InboundPassword) ? null : entity.InboundPassword) ?? DBNull.Value);
            command.Parameters.AddWithValue("inboundUseSsl", (object?)entity.InboundUseSsl ?? DBNull.Value);
            command.Parameters.AddWithValue("inboundFolder", (object?)entity.InboundFolder ?? DBNull.Value);
            command.Parameters.AddWithValue("bounceHandling", entity.BounceHandling);
            command.Parameters.AddWithValue("bounceEmail", (object?)entity.BounceEmail ?? DBNull.Value);
            command.Parameters.AddWithValue("trackingEnabled", entity.TrackingEnabled);
            command.Parameters.AddWithValue("dkimEnabled", entity.DkimEnabled);
            command.Parameters.AddWithValue("dkimSelector", (object?)entity.DkimSelector ?? DBNull.Value);
            command.Parameters.AddWithValue("dkimPrivateKey", (object?)entity.DkimPrivateKey ?? DBNull.Value);
            command.Parameters.AddWithValue("customHeaders", (object?)entity.CustomHeaders ?? DBNull.Value);
            command.Parameters.AddWithValue("webhookUrl", (object?)entity.WebhookUrl ?? DBNull.Value);
            command.Parameters.AddWithValue("webhookEvents", (object?)entity.WebhookEvents ?? DBNull.Value);

            await using var reader = await command.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                return MapFromReader(reader);
            }

            throw new Exception($"Configurazione SMTP con ID {entity.Id} non trovata");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante l'aggiornamento della configurazione SMTP");
            throw;
        }
    }

    protected AziendaSmtp MapFromReader(NpgsqlDataReader reader)
    {
        // Nota: per semplicità, non decifriamo la password qui
        return new AziendaSmtp
        {
            Id = reader.GetGuid(reader.GetOrdinal("smtp_id")),
            AziendaIdFk = ReadInt(reader, "azienda_fk"),
            ConfigName = reader.GetString(reader.GetOrdinal("config_name")),
            ConfigType = reader.GetString(reader.GetOrdinal("config_type")),
            Host = reader.GetString(reader.GetOrdinal("host")),
            Port = reader.GetInt32(reader.GetOrdinal("port")),
            Username = reader.GetString(reader.GetOrdinal("username")),
            Password = "***", // Non mostriamo la password
            UseTls = reader.GetBoolean(reader.GetOrdinal("use_tls")),
            UseStartTls = reader.GetBoolean(reader.GetOrdinal("use_starttls")),
            FromName = reader.GetString(reader.GetOrdinal("from_name")),
            FromEmail = reader.GetString(reader.GetOrdinal("from_email")),
            ReplyTo = reader.GetString(reader.GetOrdinal("reply_to")),
            IsActive = reader.GetBoolean(reader.GetOrdinal("is_active")),
            Protocol = reader.GetString(reader.GetOrdinal("protocol")),
            SecurityMethod = reader.GetString(reader.GetOrdinal("security_method")),
            ConnectionTimeout = ReadNullableInt(reader, "connection_timeout"),
            ReadTimeout = ReadNullableInt(reader, "read_timeout"),
            MaxConnections = ReadNullableInt(reader, "max_connections"),
            RateLimitPerHour = ReadNullableInt(reader, "rate_limit_per_hour"),
            Priority = ReadNullableInt(reader, "priority"),
            Description = ReadNullableString(reader, "description"),
            Status = reader.GetString(reader.GetOrdinal("status")),
            LastTestDate = ReadNullableDateTime(reader, "last_test_date"),
            LastTestResult = ReadNullableString(reader, "last_test_result"),
            LastErrorMessage = ReadNullableString(reader, "last_error_message"),
            TestFrequencyHours = ReadNullableInt(reader, "test_frequency_hours"),
            AutoFailover = reader.GetBoolean(reader.GetOrdinal("auto_failover")),
            FailoverSmtpId = ReadNullableGuid(reader, "failover_smtp_id"),
            InboundHost = ReadNullableString(reader, "inbound_host"),
            InboundPort = ReadNullableInt(reader, "inbound_port"),
            InboundProtocol = ReadNullableString(reader, "inbound_protocol"),
            InboundUsername = ReadNullableString(reader, "inbound_username"),
            InboundPassword = "***", // Non mostriamo la password inbound
            InboundUseSsl = ReadNullableBool(reader, "inbound_use_ssl"),
            InboundFolder = ReadNullableString(reader, "inbound_folder"),
            BounceHandling = reader.GetBoolean(reader.GetOrdinal("bounce_handling")),
            BounceEmail = ReadNullableString(reader, "bounce_email"),
            TrackingEnabled = reader.GetBoolean(reader.GetOrdinal("tracking_enabled")),
            DkimEnabled = reader.GetBoolean(reader.GetOrdinal("dkim_enabled")),
            DkimSelector = ReadNullableString(reader, "dkim_selector"),
            DkimPrivateKey = ReadNullableString(reader, "dkim_private_key"),
            CustomHeaders = ReadNullableString(reader, "custom_headers"),
            WebhookUrl = ReadNullableString(reader, "webhook_url"),
            WebhookEvents = ReadNullableString(reader, "webhook_events"),
            CreatedAt = reader.GetDateTime(reader.GetOrdinal("created_at")),
            UpdatedAt = reader.GetDateTime(reader.GetOrdinal("updated_at"))
        };
    }

    private bool? ReadNullableBool(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetBoolean(ordinal);
    }

    private Guid? ReadNullableGuid(NpgsqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetGuid(ordinal);
    }

    /// <summary>
    /// Ottiene tutte le configurazioni SMTP di una specifica azienda
    /// </summary>
    public async Task<List<AziendaSmtp>> GetByAziendaIdAsync(int aziendaId)
    {
        // Validazione tenant: verifica accesso all'azienda
        await _tenantContext.ValidateAccessAsync(aziendaId);

        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                SELECT smtp_id, azienda_fk, config_name, config_type, host, port, username,
                       use_tls, use_starttls, from_name, from_email, reply_to, is_active,
                       protocol, security_method, connection_timeout, read_timeout, max_connections,
                       rate_limit_per_hour, priority, description, status, last_test_date,
                       last_test_result, last_error_message, test_frequency_hours, auto_failover,
                       failover_smtp_id, inbound_host, inbound_port, inbound_protocol, inbound_username,
                       inbound_use_ssl, inbound_folder, bounce_handling, bounce_email,
                       tracking_enabled, dkim_enabled, dkim_selector, dkim_private_key,
                       custom_headers, webhook_url, webhook_events,
                       created_at, updated_at
                FROM ana_aziende_smtp
                WHERE azienda_fk = @aziendaId
                ORDER BY priority ASC, config_name ASC";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("aziendaId", aziendaId);
            await using var reader = await command.ExecuteReaderAsync();

            var configs = new List<AziendaSmtp>();
            while (await reader.ReadAsync())
            {
                configs.Add(MapFromReader(reader));
            }

            return configs;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore durante il caricamento delle configurazioni SMTP per azienda {AziendaId}", aziendaId);
            throw;
        }
    }

    /// <summary>
    /// Testa la connessione SMTP: Connect + Authenticate con MailKit, senza inviare email.
    /// </summary>
    public async Task<SmtpTestResult> TestConnectionAsync(AziendaSmtp config)
    {
        var startTime = DateTime.Now;
        var result = new SmtpTestResult { TestDate = startTime };
        var timeout = config.ConnectionTimeout ?? 30;

        // Se la password è mascherata (modalità edit) e l'entità ha un ID valido,
        // recuperare la password reale dal DB prima di procedere con il test.
        var effectivePassword = config.Password;
        if (effectivePassword == "***" && config.Id != Guid.Empty)
        {
            effectivePassword = await GetRealPasswordAsync(config.Id);
            if (effectivePassword == null)
            {
                result.IsSuccess = false;
                result.Message = "Impossibile recuperare la password dal database";
                result.ErrorMessage = "Password non recuperabile. Salvare la configurazione con la password aggiornata e riprovare.";
                result.Duration = DateTime.Now - startTime;
                return result;
            }
        }

        _logger.LogInformation("Inizio test SMTP verso {Host}:{Port} (security={Security})",
            config.Host, config.Port, config.SecurityMethod);

        var secureSocketOptions = config.SecurityMethod?.ToLower() switch
        {
            "ssl" or "tls" => SecureSocketOptions.SslOnConnect,
            "starttls"     => SecureSocketOptions.StartTls,
            "none"         => SecureSocketOptions.None,
            _              => SecureSocketOptions.Auto
        };

        using var client = new SmtpClient();
        client.Timeout = timeout * 1000;
        client.ServerCertificateValidationCallback = (s, c, h, e) => true;

        // Fase 1: Connect
        result.FailedPhase = "Connect";
        try
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(timeout));
            await client.ConnectAsync(config.Host, config.Port, secureSocketOptions, cts.Token);
        }
        catch (OperationCanceledException)
        {
            result.IsSuccess = false;
            result.ErrorMessage = $"Timeout durante la connessione al server ({timeout}s)";
            result.Message = "Connessione fallita: timeout";
            result.Duration = DateTime.Now - startTime;
            return result;
        }
        catch (Exception ex)
        {
            result.IsSuccess = false;
            result.ErrorMessage = ex.Message;
            result.Message = $"Connessione al server fallita ({config.Host}:{config.Port})";
            result.Duration = DateTime.Now - startTime;
            _logger.LogError(ex, "Errore Connect SMTP a {Host}:{Port}", config.Host, config.Port);
            return result;
        }

        // Fase 2: Authenticate
        result.FailedPhase = "Authenticate";
        try
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(timeout));
            await client.AuthenticateAsync(config.Username, effectivePassword, cts.Token);
        }
        catch (AuthenticationException ex)
        {
            result.IsSuccess = false;
            result.ErrorMessage = $"Credenziali non valide: {ex.Message}";
            result.Message = "Autenticazione fallita: username o password errati";
            result.Duration = DateTime.Now - startTime;
            _logger.LogWarning("Autenticazione SMTP fallita per {Username} su {Host}", config.Username, config.Host);
            try { await client.DisconnectAsync(true); } catch { }
            return result;
        }
        catch (Exception ex)
        {
            result.IsSuccess = false;
            result.ErrorMessage = ex.Message;
            result.Message = "Autenticazione fallita";
            result.Duration = DateTime.Now - startTime;
            _logger.LogError(ex, "Errore autenticazione SMTP per {Username} su {Host}", config.Username, config.Host);
            try { await client.DisconnectAsync(true); } catch { }
            return result;
        }

        // Tutto OK: disconnetti senza inviare email
        try { await client.DisconnectAsync(true); } catch { }

        result.IsSuccess = true;
        result.FailedPhase = null;
        result.Message = $"Connessione e autenticazione riuscite ({config.Host}:{config.Port}, utente: {config.Username})";
        result.Duration = DateTime.Now - startTime;

        _logger.LogInformation("Test SMTP completato con successo verso {Host}:{Port} in {Duration}ms",
            config.Host, config.Port, result.Duration.TotalMilliseconds);
        return result;
    }

    /// <summary>
    /// Salva il risultato dell'ultimo test SMTP nel database.
    /// </summary>
    public async Task SaveTestResultAsync(Guid smtpId, SmtpTestResult testResult)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = @"
                UPDATE ana_aziende_smtp
                SET last_test_date   = @lastTestDate,
                    last_test_result = @lastTestResult,
                    last_error_message = @lastErrorMessage
                WHERE smtp_id = @smtpId";

            await using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("smtpId", smtpId);
            cmd.Parameters.AddWithValue("lastTestDate", testResult.TestDate);
            cmd.Parameters.AddWithValue("lastTestResult", testResult.IsSuccess ? "success" : "failed");
            cmd.Parameters.AddWithValue("lastErrorMessage", (object?)testResult.ErrorMessage ?? DBNull.Value);
            await cmd.ExecuteNonQueryAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore salvataggio risultato test SMTP per smtp_id {SmtpId}", smtpId);
        }
    }

    /// <summary>
    /// Recupera la password reale (in chiaro) dal DB per una configurazione SMTP esistente.
    /// La password è salvata come JSONB nel campo password_enc: {"value": "plaintext"}.
    /// </summary>
    private async Task<string?> GetRealPasswordAsync(Guid smtpId)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            var sql = "SELECT password_enc->>'value' FROM ana_aziende_smtp WHERE smtp_id = @smtpId";
            await using var cmd = new NpgsqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("smtpId", smtpId);
            var result = await cmd.ExecuteScalarAsync();
            return result as string;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore recupero password per smtp_id {SmtpId}", smtpId);
            return null;
        }
    }
}
