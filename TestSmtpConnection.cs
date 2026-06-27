using System.Text.Json;
using Npgsql;
using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

class TestSmtpConnection
{
    static async Task Main()
    {
        const string dbHost = "127.0.0.1";
        const int dbPort = 5432;
        const string dbName = "gestione_viaggi";
        const string dbUser = "postgres";
        const string dbPassword = "postgres";
        const int aziendaId = 2;
        const string toEmail = "visconti.adriano@gmail.com";

        var connectionString = $"Host={dbHost};Port={dbPort};Database={dbName};Username={dbUser};Password={dbPassword}";

        try
        {
            Console.WriteLine("🔌 Connessione al database PostgreSQL...");
            await using var connection = new NpgsqlConnection(connectionString);
            await connection.OpenAsync();
            Console.WriteLine("✅ Connessione database riuscita!");

            Console.WriteLine($"\n📋 Recupero configurazione SMTP per azienda {aziendaId}...");
            await using var cmd = new NpgsqlCommand("SELECT fn_get_smtp_config_for_email(@AziendaId)", connection);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);
            var configJson = await cmd.ExecuteScalarAsync() as string;

            if (string.IsNullOrEmpty(configJson))
            {
                Console.WriteLine("❌ Nessuna configurazione SMTP trovata per questa azienda!");
                return;
            }

            Console.WriteLine("✅ Configurazione SMTP recuperata dal database");

            var config = JsonSerializer.Deserialize<SmtpConfig>(configJson, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            if (config == null)
            {
                Console.WriteLine("❌ Errore nella deserializzazione della configurazione SMTP");
                return;
            }

            Console.WriteLine($"\n📧 Parametri SMTP:");
            Console.WriteLine($"  Host: {config.Host}");
            Console.WriteLine($"  Port: {config.Port}");
            Console.WriteLine($"  Username: {config.Username}");
            Console.WriteLine($"  Security: {config.SecurityMethod}");
            Console.WriteLine($"  From: {config.FromEmail} ({config.FromName})");

            Console.WriteLine($"\n📤 Invio email a {toEmail}...");
            var message = new MimeMessage();
            message.From.Add(new MailboxAddress(config.FromName, config.FromEmail));
            message.To.Add(new MailboxAddress("Test", toEmail));
            message.Subject = "Test SMTP Connection";
            message.Body = new TextPart("html")
            {
                Text = "<h1>Test SMTP</h1><p>Email di test per verificare la configurazione SMTP.</p>"
            };

            using var client = new SmtpClient();
            client.Timeout = 30_000; // 30 secondi

            Console.WriteLine($"🔐 Connessione al server SMTP {config.Host}:{config.Port}...");
            var secureSocketOptions = config.SecurityMethod?.ToLower() switch
            {
                "ssl" or "tls" => SecureSocketOptions.SslOnConnect,
                "starttls" => SecureSocketOptions.StartTls,
                "none" => SecureSocketOptions.None,
                _ => SecureSocketOptions.Auto
            };

            try
            {
                await client.ConnectAsync(config.Host, config.Port, secureSocketOptions);
                Console.WriteLine("✅ Connessione SMTP stabilita");

                Console.WriteLine("🔑 Autenticazione...");
                await client.AuthenticateAsync(config.Username, config.Password);
                Console.WriteLine("✅ Autenticazione riuscita");

                Console.WriteLine("📮 Invio messaggio...");
                await client.SendAsync(message);
                Console.WriteLine("✅ Email inviata con successo!");

                await client.DisconnectAsync(true);
                Console.WriteLine("✅ Disconnessione completata");
            }
            catch (OperationCanceledException ex)
            {
                Console.WriteLine($"⏱️  TIMEOUT: {ex.Message}");
                Console.WriteLine("La connessione ha superato il timeout di 30 secondi.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Errore SMTP: {ex.GetType().Name}");
                Console.WriteLine($"   Messaggio: {ex.Message}");
                if (ex.InnerException != null)
                {
                    Console.WriteLine($"   Inner: {ex.InnerException.Message}");
                }
            }
        }
        catch (NpgsqlException ex)
        {
            Console.WriteLine($"❌ Errore database: {ex.Message}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"❌ Errore: {ex.Message}");
        }
    }

    private class SmtpConfig
    {
        public string Host { get; set; } = string.Empty;
        public int Port { get; set; }
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public bool UseTls { get; set; }
        public bool UseStarttls { get; set; }
        public string? SecurityMethod { get; set; }
        public string FromName { get; set; } = string.Empty;
        public string FromEmail { get; set; } = string.Empty;
    }
}
