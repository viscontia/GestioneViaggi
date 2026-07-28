namespace GestioneViaggi.Services.Security;

/// <summary>
/// Fornisce la master key per cifrare/decifrare i segreti (SMTP/ESP/Claude) via pgcrypto.
/// La key vive nell'ambiente (env var GV_SECRET_KEY), fuori dal binario e da git, e DEVE essere
/// la stessa su tutte le installazioni che condividono lo stesso DB. Vedi Documents/2026-07-11-Cifratura_Segreti_design.md.
/// </summary>
public interface ISecretKeyProvider
{
    /// <summary>
    /// true se la master key è disponibile. Controllo <b>non distruttivo</b>, da usare prima di
    /// operazioni di sola lettura: chiedere "esiste un segreto configurato?" non deve poter far
    /// fallire una pagina intera solo perché l'ambiente non è configurato.
    /// </summary>
    bool IsConfigured { get; }

    /// <summary>Master key. Lancia se non configurata (fail-fast, niente crash silenzioso).</summary>
    string GetMasterKey();
}

public sealed class SecretKeyProvider : ISecretKeyProvider
{
    public const string EnvVarName = "GV_SECRET_KEY";

    // NB: le app lanciate da Finder/IDE su macOS NON ereditano gli export di ~/.zshrc: qui la
    // variabile risulta assente anche quando è definita nel profilo della shell.
    private readonly string? _key = Environment.GetEnvironmentVariable(EnvVarName);

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_key);

    public string GetMasterKey()
        => string.IsNullOrWhiteSpace(_key)
            ? throw new InvalidOperationException(
                $"Master key dei segreti mancante: impostare la variabile d'ambiente {EnvVarName} " +
                "(stessa su tutte le installazioni) per poter cifrare/decifrare SMTP/ESP/Claude.")
            : _key;
}
