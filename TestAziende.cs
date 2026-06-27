using System;
using System.Threading.Tasks;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Configuration;
using System.Collections.Generic;

class Program
{
    static async Task Main(string[] args)
    {
        Console.WriteLine("Avvio test connessione db e recupero aziende...");
        var config = new ConfigurationBuilder()
            .AddJsonFile("appsettings.json")
            .Build();

        var dbService = new SupabaseDatabaseService(config, NullLogger<SupabaseDatabaseService>.Instance);
        var tenantContext = new FakeTenantContext();
        
        var service = new AziendaService(dbService, NullLogger<AziendaService>.Instance, tenantContext);

        try
        {
            var aziende = await service.GetAllAsync();
            Console.WriteLine($"Trovate {aziende.Count} aziende");
            foreach (var a in aziende)
            {
                Console.WriteLine($"{a.Id} - {a.RagioneSociale} - {a.PartitaIva}");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Errore: {ex.Message}");
            Console.WriteLine(ex.StackTrace);
        }
    }
}

class FakeTenantContext : ITenantContext
{
    public Task<bool> CanAccessAziendaAsync(int aziendaId) => Task.FromResult(true);
    public Task<int?> GetCurrentAziendaIdAsync() => Task.FromResult<int?>(null);
    public Task<GestioneViaggi.Models.UserInfo?> GetCurrentUserAsync() => Task.FromResult<GestioneViaggi.Models.UserInfo?>(null);
    public Task<int> GetRequiredAziendaIdAsync() => Task.FromResult(0);
    public Task<string> GetTenantFilterSqlAsync(string columnName = "azienda_id_fk", bool includeWhereKeyword = true) => Task.FromResult("");
    public Task<bool> IsSuperAdminAsync() => Task.FromResult(true);
    public Task ValidateAccessAsync(int aziendaId) => Task.CompletedTask;
}
