namespace GestioneViaggi.Models.DTOs;

/// <summary>
/// DTO per i dati del calendario viaggi
/// </summary>
public class CalendarTravelDTO
{
    public int DataViaggioId { get; set; }
    public int ViaggioId { get; set; }
    public string DescrizioneViaggio { get; set; } = string.Empty;
    public DateTime DataInizio { get; set; }
    public DateTime DataFine { get; set; }
    public int TotClienti { get; set; }

    /// <summary>
    /// Mezzi impegnati sulla partenza: uno per pilota.
    /// </summary>
    /// <remarks>
    /// Non è un doppione dei partecipanti: su un tour offroad le persone si ridistribuiscono fra i
    /// mezzi, i mezzi no — ed è il numero che decide quante guide servono e quanto è pieno il
    /// gruppo. Il conteggio vive nella funzione DB, lo stesso usato dal bilancio viaggi, per non
    /// avere due definizioni di «mezzo».
    /// </remarks>
    public int TotMezzi { get; set; }
    /// <summary>
    /// Spunta "Viaggio Effettuato" (<c>ana_date_viaggi.data_viaggio_effettuato_sino</c> = 'Y').
    /// </summary>
    /// <remarks>
    /// Si porta il <b>dato grezzo</b> e non uno stato gia' interpretato: come si presenta una
    /// partenza lo decide <see cref="GestioneViaggi.Models.Web.StatoPartenzaRules"/>, che incrocia
    /// il flag con la data di <b>fine</b>. Il calcolo che stava qui usava invece la data di
    /// <b>inizio</b>, e dava un vocabolario diverso da quello del resto dell'applicazione.
    /// </remarks>
    public bool Effettuato { get; set; }
    public int AziendaId { get; set; }
    public string AziendaNome { get; set; } = string.Empty;
}
