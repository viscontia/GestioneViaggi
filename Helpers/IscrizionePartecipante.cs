using GestioneViaggi.Components.Shared;
using GestioneViaggi.Models;
using GestioneViaggi.Services.CRUD;
using MudBlazor;

namespace GestioneViaggi.Helpers;

/// <summary>
/// Il pezzo di interazione condiviso fra i due punti da cui si iscrive un partecipante
/// (<c>QuickAddParticipantDialog</c> e <c>ViaggioPartecipantiManagerDialog</c>).
///
/// Sta qui e non in uno dei due perché è esattamente il genere di cosa che, copiata,
/// diverge: fra sei mesi una delle due form chiederebbe l'email e l'altra no.
/// </summary>
public static class IscrizionePartecipante
{
    /// <summary>
    /// Fa passare l'iscrizione dalla validazione del database e, se l'unico ostacolo è
    /// l'email mancante di chi guida, la chiede e la salva in anagrafica.
    /// </summary>
    /// <returns>
    /// <c>true</c> se si può procedere a scrivere; <c>false</c> se c'è un motivo di
    /// rifiuto (già mostrato all'utente) o se l'utente ha rinunciato.
    /// </returns>
    public static async Task<bool> PuoProcedereAsync(
        MovClientiViaggi entity,
        bool modifica,
        MovClientiViaggiService movService,
        IClienteService clienteService,
        IDialogService dialogService,
        ISnackbar snackbar)
    {
        var esiti = await movService.ValidaAsync(entity, modifica);

        // L'email mancante è l'unico rifiuto che si può risolvere senza uscire da qui.
        var senzaEmail = esiti.FirstOrDefault(e => e.Esito == "PILOTA_SENZA_EMAIL");
        if (senzaEmail is not null && senzaEmail.Riferimento is int clienteId)
        {
            if (await ChiediESalvaEmailAsync(clienteId, senzaEmail.Messaggio, clienteService, dialogService, snackbar))
                esiti = await movService.ValidaAsync(entity, modifica);   // risolto: si rivaluta tutto
            else
                return false;                                            // rinuncia, o salvataggio fallito
        }

        var errori = esiti.Where(e => e.Gravita == "ERRORE").ToList();
        if (errori.Count > 0)
        {
            foreach (var e in errori) snackbar.Add(e.Messaggio, Severity.Error);
            return false;
        }

        foreach (var e in esiti.Where(e => e.Gravita == "AVVISO"))
            snackbar.Add(e.Messaggio, Severity.Warning);

        return true;
    }

    private static async Task<bool> ChiediESalvaEmailAsync(
        int clienteId, string messaggio,
        IClienteService clienteService, IDialogService dialogService, ISnackbar snackbar)
    {
        var cliente = await clienteService.GetDetailAsync(clienteId);
        if (cliente is null) return false;

        var parametri = new DialogParameters<ChiediEmailDialog>
        {
            { x => x.Messaggio, messaggio },
            { x => x.NomeCliente, $"{cliente.Cognome} {cliente.Nome}".Trim() }
        };
        var dialogo = await dialogService.ShowAsync<ChiediEmailDialog>("Manca l'email", parametri,
            new DialogOptions { MaxWidth = MaxWidth.ExtraSmall, FullWidth = true, CloseOnEscapeKey = true });

        var risultato = await dialogo.Result;
        if (risultato is null || risultato.Canceled || risultato.Data is not string email || string.IsNullOrWhiteSpace(email))
            return false;

        cliente.Email = email.Trim();
        try
        {
            // Passa dal salvataggio normale: l'email finisce in anagrafica solo se supera
            // gli stessi controlli di sempre. Non è una porta di servizio.
            await clienteService.UpdateAsync(cliente);
            snackbar.Add($"Email salvata in anagrafica per {cliente.Cognome} {cliente.Nome}.", Severity.Success);
            return true;
        }
        catch (Exception ex)
        {
            snackbar.Add($"Email non salvata: {ex.Message}", Severity.Error);
            return false;
        }
    }
}
