namespace GestioneViaggi.Models.Web;

/// <summary>Fatti grezzi per le verifiche non bloccanti, letti da <c>fn_web_tour_verifiche</c>.</summary>
public record WebTourVerificheFatti(
    int NumeroGiornate,
    int GiornateSenzaPassi,
    int GiornateSenzaFoto,
    int GiornateSenzaMappa,
    bool HaMappaInsieme,
    int NumeroImmagini,
    bool HaMetaTitle,
    bool HaMetaDescription,
    bool HaIncluso,
    bool HaEscluso,
    bool HaCapienza);

public enum LivelloVerifica
{
    /// <summary>Probabile dimenticanza: sul sito si vedrebbe.</summary>
    Segnalazione,
    /// <summary>Migliorabile, ma il sito funziona lo stesso.</summary>
    Suggerimento
}

public record Verifica(LivelloVerifica Livello, string Messaggio);

/// <summary>
/// Controlli <b>non bloccanti</b> sui contenuti web: nessun vincolo DB può intercettarli, perché non
/// sono dati incoerenti ma dimenticanze (5 giornate e 4 con foto, 6 giornate e 2 con mappa). Servono a
/// far fare al software il controllo che l'utente, di fretta, non fa. Non impediscono mai la pubblicazione.
/// I fatti arrivano da <c>fn_web_tour_verifiche</c>; qui stanno soglie e testi.
/// </summary>
public static class WebVerificheRules
{
    public static List<Verifica> Analizza(WebTourVerificheFatti f, int coppieAttese, int coppieTradotte)
    {
        var esiti = new List<Verifica>();
        void Segnala(string m) => esiti.Add(new Verifica(LivelloVerifica.Segnalazione, m));
        void Suggerisci(string m) => esiti.Add(new Verifica(LivelloVerifica.Suggerimento, m));

        // --- Foto: conta più la copertura per giornata che il numero totale ---
        if (f.NumeroImmagini == 0)
            Segnala("La galleria è vuota: il tour verrebbe pubblicato senza foto.");

        if (f.NumeroGiornate > 0 && f.GiornateSenzaFoto > 0)
            Segnala(f.GiornateSenzaFoto == f.NumeroGiornate
                ? "Nessuna giornata ha una foto nei passaggi."
                : $"{Giornate(f.GiornateSenzaFoto, f.NumeroGiornate)} {Hanno(f.GiornateSenzaFoto)} foto nei passaggi.");

        // --- Contenuti delle giornate ---
        if (f.GiornateSenzaPassi > 0)
            Segnala(f.GiornateSenzaPassi == 1
                ? "1 giornata non ha ancora contenuti."
                : $"{f.GiornateSenzaPassi} giornate non hanno ancora contenuti.");

        // --- Mappe ---
        if (f.NumeroGiornate > 0 && f.GiornateSenzaMappa > 0)
            Segnala(f.GiornateSenzaMappa == f.NumeroGiornate
                ? "Nessuna giornata ha una mappa."
                : $"{Giornate(f.GiornateSenzaMappa, f.NumeroGiornate)} {Hanno(f.GiornateSenzaMappa)} una mappa.");

        if (!f.HaMappaInsieme)
            Segnala("Manca la mappa dell'intero viaggio.");

        // --- Suggerimenti: il sito funziona lo stesso, ma è meno ricco ---
        if (!f.HaMetaTitle || !f.HaMetaDescription)
            Suggerisci("Meta title o description non compilati: il sito userà titolo e sottotitolo come ripiego.");

        if (!f.HaIncluso || !f.HaEscluso)
            Suggerisci("\"Incluso\" o \"Escluso\" non compilati: sono fra le prime cose che il cliente cerca.");

        if (!f.HaCapienza)
            Suggerisci("Capienza non impostata: il sito non potrà mostrare \"ultimi posti\" o \"esaurito\".");

        if (coppieAttese > 0 && coppieTradotte < coppieAttese)
            Suggerisci($"Traduzioni incomplete: {coppieTradotte} su {coppieAttese}.");

        return esiti;
    }

    public static int ContaSegnalazioni(IEnumerable<Verifica> v) => v.Count(x => x.Livello == LivelloVerifica.Segnalazione);

    // Concordanza singolare/plurale: "1 giornata su 5 non ha", "3 giornate su 5 non hanno".
    private static string Giornate(int quante, int totale) => $"{quante} {(quante == 1 ? "giornata" : "giornate")} su {totale}";
    private static string Hanno(int quante) => quante == 1 ? "non ha" : "non hanno";
}
