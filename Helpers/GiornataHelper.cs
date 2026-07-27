using System.Globalization;

namespace GestioneViaggi.Helpers;

/// <summary>
/// Data reale di una giornata dell'itinerario. Le giornate non memorizzano una data: la si deriva
/// dalla partenza a cui il contenuto web appartiene (Blocco 13: il contenuto è figlio di viaggio+data).
/// La corrispondenza è esatta perché il trigger DB <c>trg_validate_date_viaggio_duration</c> rifiuta
/// ogni edizione la cui durata non coincida con <c>ana_viaggi.viaggio_numero_giorni</c>.
/// Derivare invece di memorizzare evita che le date restino indietro se si sposta la partenza,
/// e fa sì che un contenuto clonato su un'altra edizione mostri subito le date giuste.
/// </summary>
public static class GiornataHelper
{
    private static readonly CultureInfo It = CultureInfo.GetCultureInfo("it-IT");

    /// <summary>
    /// Data della giornata, oppure null se non calcolabile. L'app consente di descrivere più giornate
    /// di quelle previste dal viaggio (con avviso): quelle in eccesso non hanno una data di calendario.
    /// </summary>
    public static DateTime? Data(DateTime? dataInizio, int giornoNumero, int numeroGiorni)
    {
        if (dataInizio == null || giornoNumero < 1) return null;
        if (numeroGiorni > 0 && giornoNumero > numeroGiorni) return null;
        return dataInizio.Value.Date.AddDays(giornoNumero - 1);
    }

    /// <summary>
    /// Data per esteso, "Sabato 2 Maggio 2026", oppure null se non calcolabile.
    /// È il testo mostrato come informazione non editabile accanto alla giornata: il titolo può
    /// restare indietro dopo un riordino (lo corregge l'utente), la data no — deve essere sempre giusta.
    /// </summary>
    public static string? Estesa(DateTime? dataInizio, int giornoNumero, int numeroGiorni)
    {
        var data = Data(dataInizio, giornoNumero, numeroGiorni);
        return data == null ? null : It.TextInfo.ToTitleCase(data.Value.ToString("dddd d MMMM yyyy", It));
    }

    /// <summary>
    /// Nome proposto per la mappa di una giornata: <c>"GIORNO 1 : Olbia - Monte Limbara (Sabato 2 Maggio 2026)"</c>.
    /// Si parte dal titolo della giornata — che già contiene il numero e va lasciato all'utente — e si
    /// aggiunge solo la data fra parentesi. Comporre anche "Giorno N" davanti produrrebbe una doppia
    /// intestazione ("Giorno 1 — … — GIORNO 1 : …"). Senza data si usa il solo titolo.
    /// </summary>
    public static string DescrizioneMappa(string? titoloGiornata, DateTime? dataInizio, int giornoNumero, int numeroGiorni)
    {
        var titolo = (titoloGiornata ?? string.Empty).Trim();
        if (titolo.Length == 0) titolo = $"Giorno {giornoNumero}";

        var estesa = Estesa(dataInizio, giornoNumero, numeroGiorni);
        return estesa == null ? titolo : $"{titolo} ({estesa})";
    }

    /// <summary>"Giorno 1 — Sabato 2 Maggio 2026", o solo "Giorno 1" se la data non è calcolabile.</summary>
    public static string Etichetta(DateTime? dataInizio, int giornoNumero, int numeroGiorni)
    {
        var estesa = Estesa(dataInizio, giornoNumero, numeroGiorni);
        return estesa == null ? $"Giorno {giornoNumero}" : $"Giorno {giornoNumero} — {estesa}";
    }
}
