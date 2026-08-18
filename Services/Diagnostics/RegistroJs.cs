using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.JSInterop;

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
/// messaggio inviato in quel momento non arriverebbe mai. Per questo la parte JavaScript accoda
/// prima in <c>localStorage</c>, che al ricaricamento sopravvive, e svuota la coda appena il
/// canale c'e': la riga scritta un istante prima della morte si legge un istante dopo.</para>
/// <para>Solo diagnostica: non cambia il comportamento di niente.</para>
/// </remarks>
public static class RegistroJs
{
    private static ILogger? _log;

    public static void Configura(ILogger log) => _log = log;

    private sealed record Riga(string? Q, string? Tipo, string? Messaggio, string? Dettaglio);

    /// <summary>Riceve la coda accumulata dalla parte JavaScript. Il nome e' invocato da registroErrori.js.</summary>
    [JSInvokable]
    public static void RegistraErroriJs(string json)
    {
        if (_log is null) return;

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
