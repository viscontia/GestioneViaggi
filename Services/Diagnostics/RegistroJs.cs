using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Diagnostics;

/// <summary>
/// Porta nel registro su file quello che succede dalla parte JavaScript.
/// </summary>
/// <remarks>
/// Meta' del programma gira dentro una WebView, e di quella meta' non sapevamo niente: un errore
/// in JavaScript non compare da nessuna parte, e la sua console non esiste sulla macchina di chi
/// usa il programma. Diagnosticando la chiusura improvvisa abbiamo visto solo effetti lato .NET —
/// un'attesa di JavaScript completata due volte — mai la causa.
/// <para>Conta soprattutto per un guasto come quello: quando il canale fra le due parti muore, i
/// clic non arrivano piu' ("Chiudi" che non chiude) e subito dopo la pagina si ricarica. Un
/// messaggio inviato in quel momento non arriverebbe mai. Per questo la parte JavaScript non
/// spedisce niente: scrive in <c>localStorage</c>, che al ricaricamento e al riavvio sopravvive, e
/// la coda se la viene a prendere .NET. La riga scritta un istante prima della morte si legge un
/// istante dopo.</para>
/// <para>La direzione della chiamata non e' un dettaglio. Nella prima versione era JavaScript a
/// chiamare .NET, e partiva subito all'avvio: un messaggio inviato prima che Blazor abbia
/// agganciato la pagina da' «Cannot receive IPC messages when no page is attached» e l'avvio non si
/// completa. Il programma restava sullo schermo nero. Chiedendo da .NET il caso non esiste: se .NET
/// puo' chiedere, la pagina c'e'.</para>
/// <para>Solo diagnostica: non cambia il comportamento di niente.</para>
/// </remarks>
public static class RegistroJs
{
    private static ILogger? _log;

    public static void Configura(ILogger log) => _log = log;

    private sealed record Riga(string? Q, string? Tipo, string? Messaggio, string? Dettaglio);

    /// <summary>Scrive nel registro la coda prelevata da <c>registroErrori.preleva()</c>.</summary>
    public static void Registra(string? json)
    {
        if (_log is null || string.IsNullOrWhiteSpace(json)) return;

        try
        {
            var righe = JsonSerializer.Deserialize<List<Riga>>(
                json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            if (righe is null) return;

            foreach (var r in righe)
            {
                // Livello Error: e' la soglia da cui il registro su file scrive davvero.
                // "quando" lo mette la parte JavaScript, e non coincide con adesso — la coda puo'
                // arrivare dopo un ricaricamento, cioe' minuti dopo il fatto.
                _log.LogError("JavaScript [{Tipo}] {Quando} — {Messaggio}\n{Dettaglio}",
                              r.Tipo, r.Q, r.Messaggio, r.Dettaglio);
            }
        }
        catch (Exception ex)
        {
            // Non deve poter far cadere niente: e' lo strumento che serve a spiegare le cadute.
            _log.LogWarning(ex, "Coda degli errori JavaScript illeggibile");
        }
    }
}
