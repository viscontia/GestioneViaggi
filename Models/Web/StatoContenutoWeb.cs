namespace GestioneViaggi.Models.Web;

/// <summary>Come sta messa la scheda web di una partenza. Ordine = quanto è avanti nel percorso editoriale.</summary>
public enum LivelloContenutoWeb
{
    /// <summary>Nessuna scheda web per questa partenza.</summary>
    Assente,
    /// <summary>Scheda esistente ma non online.</summary>
    Bozza,
    /// <summary>Scheda archiviata: per il sito è identica a una bozza, la differenza è solo editoriale.</summary>
    Archiviata,
    /// <summary>Scheda online.</summary>
    Pubblicata
}

public sealed record EsitoContenutoWeb(LivelloContenutoWeb Livello, string Etichetta, string Tooltip);

/// <summary>
/// Lettura dello stato web di una partenza, con i testi. Componente a sé (come StatoPartenzaRules)
/// perché la stessa informazione serve in due posti che non si conoscono fra loro: la griglia delle
/// date e il selettore edizione dei contenuti web. Se le due letture divergessero, la stessa icona
/// finirebbe per significare cose diverse nelle due schermate.
/// </summary>
public static class ContenutoWebRules
{
    /// <param name="statoPubblicazione">Valore di <c>web_tour_contenuti.stato_pubblicazione</c>, null se non c'è scheda.</param>
    /// <param name="clonabile">Esiste almeno un'altra partenza dello stesso viaggio con una scheda da copiare.</param>
    public static EsitoContenutoWeb Valuta(string? statoPubblicazione, bool clonabile = false) => statoPubblicazione switch
    {
        "pubblicato" => new(LivelloContenutoWeb.Pubblicata, "Pubblicata sul sito",
            "La scheda web di questa partenza è online. Sparisce dal sito da sola il giorno in cui la partenza inizia, senza che lo stato cambi."),

        "archiviato" => new(LivelloContenutoWeb.Archiviata, "Scheda archiviata",
            "La scheda web esiste ma non è visibile sul sito, esattamente come una bozza: la differenza è solo editoriale (finita e da non toccare)."),

        "bozza" => new(LivelloContenutoWeb.Bozza, "Scheda in bozza",
            "La scheda web esiste ma non è ancora online. Si completa e si pubblica dalla scheda \"Contenuti Web\" del viaggio."),

        // Qualsiasi altro valore non nullo è uno stato che non conosciamo: meglio dirlo che fingere.
        not null => new(LivelloContenutoWeb.Bozza, $"Stato \"{statoPubblicazione}\"",
            $"La scheda web è in uno stato non previsto (\"{statoPubblicazione}\"): verificarla nella scheda \"Contenuti Web\"."),

        null when clonabile => new(LivelloContenutoWeb.Assente, "Senza scheda web",
            "Questa partenza non ha una scheda web. Clicca per crearla da zero oppure per clonarla da un'altra partenza dello stesso viaggio."),

        null => new(LivelloContenutoWeb.Assente, "Senza scheda web",
            "Questa partenza non ha una scheda web. Clicca per crearla.")
    };

    /// <summary>
    /// Il messaggio dopo il salvataggio della scheda (voce L23): ciò che tocca il sito non compare subito,
    /// ma al giro successivo del programma della coda di rigenerazione. Si dice «1–2 minuti» per restare
    /// larghi. Anche il ritorno automatico a bozza di una scheda pubblicata va detto: sparisce dal sito.
    /// </summary>
    /// <param name="statoPrima">Stato com'era salvato prima, null se non noto.</param>
    /// <param name="statoDopo">Stato appena salvato.</param>
    public static string MessaggioSalvataggio(string? statoPrima, string statoDopo) =>
        (statoPrima == "pubblicato", statoDopo == "pubblicato") switch
        {
            (false, true) => "Scheda pubblicata: comparirà sul sito entro 1–2 minuti.",
            (true, true) => "Modifiche salvate: saranno sul sito entro 1–2 minuti.",
            (true, false) => "Scheda tolta dal sito: sparirà entro 1–2 minuti.",
            (false, false) => "Contenuti web salvati con successo"
        };
}
