namespace GestioneViaggi.Services.Session;
using GestioneViaggi.Models;

/// <summary>
/// Interfaccia per gestire il contesto multi-tenant dell'applicazione.
/// Fornisce accesso al company_id dell'utente corrente e verifica permessi cross-company.
/// </summary>
public interface ITenantContext
{
    /// <summary>
    /// Restituisce l'AziendaId dell'utente corrente.
    /// NULL se l'utente è SuperAdmin (accesso cross-tenant).
    /// </summary>
    Task<int?> GetCurrentAziendaIdAsync();
    
    /// <summary>
    /// Restituisce l'AziendaId corrente. Se non disponibile (es. SuperAdmin senza contesto o utente senza azienda), solleva un'eccezione.
    /// </summary>
    Task<int> GetRequiredAziendaIdAsync();

    /// <summary>
    /// Verifica se l'utente corrente è SuperAdmin (accesso globale).
    /// </summary>
    Task<bool> IsSuperAdminAsync();

    /// <summary>
    /// Verifica se l'utente può accedere ai dati di una specifica azienda.
    /// SuperAdmin: true per qualsiasi aziendaId
    /// Altri ruoli: true solo se aziendaId == UserInfo.AziendaId
    /// </summary>
    Task<bool> CanAccessAziendaAsync(int aziendaId);

    /// <summary>
    /// Ottiene la clausola WHERE SQL per filtrare i dati in base al tenant.
    /// SuperAdmin: stringa vuota (nessun filtro)
    /// Altri ruoli: "WHERE azienda_id_fk = {aziendaId}"
    /// </summary>
    /// <param name="columnName">Nome della colonna FK (default: azienda_id_fk)</param>
    /// <param name="includeWhereKeyword">Se true, include "WHERE", altrimenti solo la condizione</param>
    Task<string> GetTenantFilterSqlAsync(string columnName = "azienda_id_fk", bool includeWhereKeyword = true);

    /// <summary>
    /// Restituisce le informazioni dell'utente corrente.
    /// </summary>
    Task<UserInfo?> GetCurrentUserAsync();

    /// <summary>
    /// Valida l'accesso e solleva UnauthorizedAccessException se l'utente non può accedere.
    /// </summary>
    Task ValidateAccessAsync(int aziendaId);
}
