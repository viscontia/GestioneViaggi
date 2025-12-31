using System.ComponentModel.DataAnnotations;

namespace GestioneViaggi.Models;

/// <summary>
/// Rappresenta una configurazione SMTP aziendale (tabella ana_aziende_smtp)
/// </summary>
public class AziendaSmtp
{
    public Guid Id { get; set; }

    [Required(ErrorMessage = "L'azienda è obbligatoria")]
    public int AziendaIdFk { get; set; }

    [Required(ErrorMessage = "Il nome della configurazione è obbligatorio")]
    [StringLength(100, ErrorMessage = "Il nome configurazione non può superare i 100 caratteri")]
    public string ConfigName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Il tipo di configurazione è obbligatorio")]
    [StringLength(50, ErrorMessage = "Il tipo configurazione non può superare i 50 caratteri")]
    public string ConfigType { get; set; } = "outbound";

    [Required(ErrorMessage = "L'host è obbligatorio")]
    [StringLength(255, ErrorMessage = "L'host non può superare i 255 caratteri")]
    public string Host { get; set; } = string.Empty;

    [Required(ErrorMessage = "La porta è obbligatoria")]
    [Range(1, 65535, ErrorMessage = "La porta deve essere tra 1 e 65535")]
    public int Port { get; set; } = 587;

    [Required(ErrorMessage = "Lo username è obbligatorio")]
    [StringLength(255, ErrorMessage = "Lo username non può superare i 255 caratteri")]
    public string Username { get; set; } = string.Empty;

    [Required(ErrorMessage = "La password è obbligatoria")]
    // Nota: password_enc è jsonb nel DB, qui gestiamo la password in chiaro per il form
    public string Password { get; set; } = string.Empty;

    public bool UseTls { get; set; } = true;
    public bool UseStartTls { get; set; } = false;

    [Required(ErrorMessage = "Il nome mittente è obbligatorio")]
    [StringLength(255, ErrorMessage = "Il nome mittente non può superare i 255 caratteri")]
    public string FromName { get; set; } = string.Empty;

    [Required(ErrorMessage = "L'email mittente è obbligatoria")]
    [StringLength(255, ErrorMessage = "L'email mittente non può superare i 255 caratteri")]
    public string FromEmail { get; set; } = string.Empty;

    [Required(ErrorMessage = "L'email di risposta è obbligatoria")]
    [StringLength(255, ErrorMessage = "L'email di risposta non può superare i 255 caratteri")]
    public string ReplyTo { get; set; } = string.Empty;

    public bool IsActive { get; set; } = true;

    [Required(ErrorMessage = "Il protocollo è obbligatorio")]
    [StringLength(10, ErrorMessage = "Il protocollo non può superare i 10 caratteri")]
    public string Protocol { get; set; } = "smtp";

    [Required(ErrorMessage = "Il metodo di sicurezza è obbligatorio")]
    [StringLength(20, ErrorMessage = "Il metodo di sicurezza non può superare i 20 caratteri")]
    public string SecurityMethod { get; set; } = "starttls";

    [Range(1, 300, ErrorMessage = "Il timeout di connessione deve essere tra 1 e 300 secondi")]
    public int? ConnectionTimeout { get; set; } = 30;

    [Range(1, 600, ErrorMessage = "Il timeout di lettura deve essere tra 1 e 600 secondi")]
    public int? ReadTimeout { get; set; } = 60;

    [Range(1, 100, ErrorMessage = "Il numero massimo di connessioni deve essere tra 1 e 100")]
    public int? MaxConnections { get; set; } = 10;

    public int? RateLimitPerHour { get; set; }

    [Range(1, 10, ErrorMessage = "La priorità deve essere tra 1 e 10")]
    public int? Priority { get; set; } = 1;

    public string? Description { get; set; }

    [Required(ErrorMessage = "Lo stato è obbligatorio")]
    [StringLength(20, ErrorMessage = "Lo stato non può superare i 20 caratteri")]
    public string Status { get; set; } = "active";

    public DateTime? LastTestDate { get; set; }

    public string? LastTestResult { get; set; }

    public string? LastErrorMessage { get; set; }

    public int? TestFrequencyHours { get; set; } = 24;

    public bool AutoFailover { get; set; } = false;

    public Guid? FailoverSmtpId { get; set; }

    // Campi per configurazione INBOUND (ricezione email IMAP/POP3)
    [StringLength(255, ErrorMessage = "L'host inbound non può superare i 255 caratteri")]
    public string? InboundHost { get; set; }

    [Range(1, 65535, ErrorMessage = "La porta inbound deve essere tra 1 e 65535")]
    public int? InboundPort { get; set; }

    [StringLength(10, ErrorMessage = "Il protocollo inbound non può superare i 10 caratteri")]
    public string? InboundProtocol { get; set; } // imap, pop3

    [StringLength(255, ErrorMessage = "Lo username inbound non può superare i 255 caratteri")]
    public string? InboundUsername { get; set; }

    public string? InboundPassword { get; set; }

    public bool? InboundUseSsl { get; set; }

    [StringLength(100, ErrorMessage = "La cartella inbound non può superare i 100 caratteri")]
    public string? InboundFolder { get; set; } // es: INBOX

    // Campi per gestione bounce
    public bool BounceHandling { get; set; } = false;

    [StringLength(255, ErrorMessage = "L'email bounce non può superare i 255 caratteri")]
    public string? BounceEmail { get; set; }

    // Campi per tracking e DKIM
    public bool TrackingEnabled { get; set; } = false;

    public bool DkimEnabled { get; set; } = false;

    [StringLength(100, ErrorMessage = "Il selettore DKIM non può superare i 100 caratteri")]
    public string? DkimSelector { get; set; }

    public string? DkimPrivateKey { get; set; }

    // Campi per configurazioni avanzate
    public string? CustomHeaders { get; set; } // JSON string

    [StringLength(500, ErrorMessage = "L'URL webhook non può superare i 500 caratteri")]
    public string? WebhookUrl { get; set; }

    public string? WebhookEvents { get; set; } // JSON array convertito in string

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    /// <summary>
    /// Crea una copia dell'entità per evitare modifiche accidentali all'oggetto originale
    /// </summary>
    public AziendaSmtp Clone()
    {
        return new AziendaSmtp
        {
            Id = this.Id,
            AziendaIdFk = this.AziendaIdFk,
            ConfigName = this.ConfigName,
            ConfigType = this.ConfigType,
            Host = this.Host,
            Port = this.Port,
            Username = this.Username,
            Password = this.Password,
            UseTls = this.UseTls,
            UseStartTls = this.UseStartTls,
            FromName = this.FromName,
            FromEmail = this.FromEmail,
            ReplyTo = this.ReplyTo,
            IsActive = this.IsActive,
            Protocol = this.Protocol,
            SecurityMethod = this.SecurityMethod,
            ConnectionTimeout = this.ConnectionTimeout,
            ReadTimeout = this.ReadTimeout,
            MaxConnections = this.MaxConnections,
            RateLimitPerHour = this.RateLimitPerHour,
            Priority = this.Priority,
            Description = this.Description,
            Status = this.Status,
            LastTestDate = this.LastTestDate,
            LastTestResult = this.LastTestResult,
            LastErrorMessage = this.LastErrorMessage,
            TestFrequencyHours = this.TestFrequencyHours,
            AutoFailover = this.AutoFailover,
            FailoverSmtpId = this.FailoverSmtpId,
            InboundHost = this.InboundHost,
            InboundPort = this.InboundPort,
            InboundProtocol = this.InboundProtocol,
            InboundUsername = this.InboundUsername,
            InboundPassword = this.InboundPassword,
            InboundUseSsl = this.InboundUseSsl,
            InboundFolder = this.InboundFolder,
            BounceHandling = this.BounceHandling,
            BounceEmail = this.BounceEmail,
            TrackingEnabled = this.TrackingEnabled,
            DkimEnabled = this.DkimEnabled,
            DkimSelector = this.DkimSelector,
            DkimPrivateKey = this.DkimPrivateKey,
            CustomHeaders = this.CustomHeaders,
            WebhookUrl = this.WebhookUrl,
            WebhookEvents = this.WebhookEvents,
            CreatedAt = this.CreatedAt,
            UpdatedAt = this.UpdatedAt
        };
    }
}
