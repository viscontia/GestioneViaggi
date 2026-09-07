using GestioneViaggi.Models;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.JSInterop;
using MudBlazor;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Validation.Business;
using GestioneViaggi.Validation.Exceptions;
using GestioneViaggi.Validation.Fiscal;
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.Components.Forms;
using GestioneViaggi.Validation.Semantic;
using GestioneViaggi.Helpers;

namespace GestioneViaggi.Components.Shared;

public partial class ClienteDialog : ComponentBase, IDisposable
{
    [CascadingParameter] IMudDialogInstance? MudDialog { get; set; }


    [Inject] public IClienteService ClienteService { get; set; } = default!;
    [Inject] public ComuneService ComuneService { get; set; } = default!;
    [Inject] public TipoDocumentoService TipoDocumentoService { get; set; } = default!;
    [Inject] public ISnackbar Snackbar { get; set; } = default!;
    [Inject] public IDialogService DialogService { get; set; } = default!;
    [Inject] public ILogger<ClienteDialog> Logger { get; set; } = default!;
    [Inject] public ClienteLinguaService ClienteLinguaService { get; set; } = default!;
    [Inject] public ClienteConsensoService ClienteConsensoService { get; set; } = default!;

    [Parameter] public Cliente Entity { get; set; } = new();
    [Parameter] public bool IsEditMode { get; set; }

    /// <summary>
    /// L'etichetta del codice fiscale.
    ///
    /// ⚠️ Non porta piu' l'asterisco. Dal 2026-09-07 (SqlScripts/634) la SCHEDA non
    /// pretende il codice fiscale: lo pretende l'ISCRIZIONE, e solo a chi guida —
    /// e' a lui che si emette la fattura. Qui il ruolo non si conosce: una scheda
    /// anagrafica non sa se quella persona guidera'.
    ///
    /// Segnarlo obbligatorio sarebbe una promessa che il salvataggio non mantiene,
    /// e chiederebbe un dato inutile ai passeggeri — che sono 75 su 185 in PROD.
    /// Il rifiuto arriva all'iscrizione, con il messaggio che spiega perche'.
    /// </summary>
    private string EtichettaCodiceFiscale => "Codice Fiscale";
    [Parameter] public int AziendaFk { get; set; }

    /// <summary>Lingua preferita del cliente per la newsletter (side-field, Blocco 11). null = auto dalla nazione.</summary>
    private string? _lingua;

    /// <summary>Consenso marketing (side-field, Blocco 11-B): è il flag che filtra i destinatari newsletter.</summary>
    private bool _consenso;
    /// <summary>Com'era il consenso all'apertura: distingue «acceso adesso» da «era gia' acceso».</summary>
    private bool _consensoIniziale;
    /// <summary>L'indirizzo con cui la scheda e' stata aperta: serve a sapere se e' cambiato.</summary>
    private string? _emailIniziale;
    /// <summary>Data e provenienza dell'ultimo cambio di consenso, mostrate in sola lettura.</summary>
    private DateTime? _consensoData;
    private string? _consensoFonte;

    private bool IsSuperAdmin => AziendaFk == 0;

    private MudForm? _form;
    private TitoloPersonaSelect? _titoloField;
    private ComuneSelect? _comuneResidenzaField;
    private MudTextField<string>? _cognomeField, _nomeField;
    private MudDatePicker? _dataNascitaField;
    
    // Tab 2
    private MudTextField<string>? _indirizzoField, _emailField, _telefonoField;

    // Tab 3
    private MudSelect<string>? _tipoDocField;

    /// <summary>I tipi di documento, dal database: vedi TipoDocumentoService.</summary>
    private List<(string Codice, string Descrizione)> _tipiDocumento = new();
    private MudTextField<string>? _docNumeroField, _docRilDaField, _cfField, _ibanField;
    private MudDatePicker? _docRilDataField, _docScadenzaField;



    // Tab 4
    private MudTextField<string>? _intolleranzaField, _noteField;

    private string? _photoPreviewUrl;
    private const long MaxFileSize = 1024 * 1024 * 5; // 5MB

    private GestioneViaggi.Models.DTOs.ClienteInitData _initData = new();

    private bool _isSaving = false;
    private bool _validationRequested = false;

    // NOTA (2026-09-01): la DateMask e' stata TOLTA da tutti i campi data, sostituita da
    // ConvertitoreDataFlessibile — si continua a digitare 15031990, ma la conversione avviene
    // sul testo finito invece che a ogni tasto.
    //
    // Il commento che stava qui diceva: «in MAUI Blazor Hybrid il rendering e' client-side
    // quindi l'esperienza e' fluida, il bug #6796 affligge Blazor Server con alta latenza».
    // Era proprio il contrario, ed e' per questo che il difetto e' rimasto in piedi: MudBlazor
    // in MAUI Hybrid si crede LATO SERVER (RuntimeLocation.IsServerSide guarda
    // OSDescription != "Browser") e su MacCatalyst ogni messaggio verso JS e' una
    // evaluateJavaScript a se'. Eravamo nel caso peggiore, non in quello migliore.

    // Comune helpers per conversione int <-> int?
    private int? ComuneNascitaIdProxy
    {
        get => Entity.ComuneNascitaFk == 0 ? null : Entity.ComuneNascitaFk;
        set => Entity.ComuneNascitaFk = value ?? 0;
    }

    private int? ComuneResidenzaIdProxy
    {
        get => Entity.ComuneResidenzaFk == 0 ? null : Entity.ComuneResidenzaFk;
        set => Entity.ComuneResidenzaFk = value ?? 0;
    }

    protected override void OnInitialized()
    {
        // Inizializza azienda_fk se non in edit mode
        if (!IsEditMode)
        {
            Entity.AziendaFk = AziendaFk;
            Entity.Sesso = 'M'; // Default
        }
    }

    private bool _confermeAccettate;

    /// <summary>
    /// Le segnalazioni bloccanti arrivate dal database, tenute sul campo che le riguarda.
    ///
    /// Serve perche' le regole non stanno piu' in C# (script 541-552): il database le
    /// applica per tutti — gestionale e sito — ma le sue risposte arrivavano solo come
    /// messaggio a video, e il campo sbagliato restava indistinguibile dagli altri.
    /// Si spengono da sole appena quel valore cambia: e' il motivo per cui qui si
    /// conserva anche il valore che le ha prodotte, non il solo messaggio.
    /// </summary>
    private readonly Dictionary<string, (string? Valore, string Messaggio)> _erroriDb = new();

    /// <summary>
    /// Le segnalazioni non bloccanti del database (AVVISO e CONFERMA), mostrate mentre si
    /// compila. Restavano invisibili fino al salvataggio: sapere che il codice fiscale non
    /// corrisponde e' utile mentre si guarda il documento, non quando si e' gia' finito.
    ///
    /// Non colorano il campo: rosso vuol dire "non si passa", e qui si passa eccome —
    /// il codice emesso con nome e cognome invertiti esiste, e va registrabile.
    /// </summary>
    private readonly Dictionary<string, string> _avvisiDb = new();

    /// <summary>Quale campo illuminare per ogni esito del database. Gli esiti non elencati restano solo a video.</summary>
    private static readonly Dictionary<string, string> CampoPerEsito = new()
    {
        ["COGNOME_MINIMO"] = "cognome",
        ["NOME_MINIMO"] = "nome",
        ["EMAIL_FORMATO"] = "email",
        ["IBAN_FORMATO"] = "iban",
        ["NASCITA_FUTURA"] = "nascita",
        ["RILASCIO_FUTURO"] = "rilascio",
        ["FORMA"] = "cf",
        ["CARATTERE_CONTROLLO"] = "cf",
        ["STESSO_CF"] = "cf",
        // Non bloccanti, ma appartengono al codice fiscale: servono a mostrarli accanto a lui.
        ["NON_CORRISPONDE"] = "cf",
        ["INVERTITI"] = "cf",
        // I dati che devono esserci (script 563). Titolo e comuni non sono qui:
        // li segnalano gia' i loro componenti, che hanno un Required proprio.
        ["MANCA_COGNOME"] = "cognome",
        ["MANCA_NOME"] = "nome",
        ["MANCA_DATA_NASCITA"] = "nascita",
        ["MANCA_INDIRIZZO_RESIDENZA"] = "indirizzo",
        ["MANCA_DOC_TIPO"] = "tipodoc",
        ["MANCA_DOC_NUMERO"] = "docnumero",
        ["MANCA_DOC_ENTE"] = "docente",
        ["MANCA_DOC_RILASCIO"] = "rilascio",
        ["MANCA_DOC_SCADENZA"] = "scadenza",
        ["CONSENSO_SENZA_EMAIL"] = "email",
    };

    private static string? Chiave(DateTime? data) => data?.ToString("yyyy-MM-dd");

    /// <summary>Il valore corrente del campo, per riconoscere quando l'utente ha corretto.</summary>
    private string? ValoreCampo(string campo) => campo switch
    {
        "cognome" => Entity.Cognome,
        "nome" => Entity.Nome,
        "email" => Entity.Email,
        "iban" => Entity.Iban,
        "cf" => Entity.CodiceFiscale,
        "nascita" => Chiave(Entity.DataNascita),
        "rilascio" => Chiave(Entity.DocumentoRilasciatoData),
        "scadenza" => Chiave(Entity.DocumentoRilasciatoScadenza),
        "indirizzo" => Entity.IndirizzoResidenza,
        "tipodoc" => Entity.TipoDocIdentita,
        "docnumero" => Entity.DocumentoNumero,
        "docente" => Entity.DocumentoRilasciatoDa,
        _ => null
    };

    /// <summary>
    /// Chiede al database cosa non va e aggiorna l'errore <b>solo</b> dei campi indicati.
    ///
    /// Serve a far comparire le segnalazioni quando si lascia il campo, e non piu' soltanto
    /// premendo Salva: scoprire da un messaggio in fondo che il cognome e' troppo corto, con
    /// tre schede da riattraversare, non e' un controllo — e' un indovinello.
    ///
    /// Aggiorna solo i campi indicati per un motivo preciso: gli esiti arrivano tutti insieme,
    /// e accendere l'intera scheda dopo il primo campo compilato direbbe all'utente che ha
    /// sbagliato tutto quando non ha ancora finito di scrivere.
    /// </summary>
    private async Task ControllaAlVolo(params string[] campi)
    {
        List<EsitoValidazione> esiti;
        try
        {
            esiti = await ClienteService.ValidaAsync(Entity, IsEditMode ? Entity.ClienteId : null);
        }
        catch (Exception ex)
        {
            // Un controllo anticipato che non riesce non deve impedire di scrivere:
            // al salvataggio si rifara' comunque, e li' l'esito conta davvero.
            Console.WriteLine($"Controllo anticipato non riuscito: {ex.Message}");
            return;
        }

        // Piu' esiti possono riguardare lo stesso campo — sul codice fiscale, per dire,
        // «gia' registrato» e «non corrisponde» arrivano insieme — e un campo puo'
        // mostrare un messaggio solo: si tiene il primo, che e' il piu' grave nell'ordine
        // in cui il database li emette. Raggruppare e non indicizzare: con ToDictionary
        // la seconda segnalazione sullo stesso campo faceva saltare tutto.
        var attivi = esiti.Where(e => e.Blocca)
                          .Where(e => CampoPerEsito.TryGetValue(e.Esito, out var c) && campi.Contains(c))
                          .GroupBy(e => CampoPerEsito[e.Esito])
                          .ToDictionary(g => g.Key, g => g.First().Messaggio);

        foreach (var campo in campi)
        {
            if (attivi.TryGetValue(campo, out var messaggio))
                _erroriDb[campo] = (ValoreCampo(campo), messaggio);
            else
                _erroriDb.Remove(campo);
        }

        // Avvisi e richieste di conferma: si dicono subito, ma senza colorare nulla.
        var segnalati = esiti.Where(e => !e.Blocca && e.Gravita != "OK")
                             .Where(e => CampoPerEsito.TryGetValue(e.Esito, out var c) && campi.Contains(c))
                             .GroupBy(e => CampoPerEsito[e.Esito])
                             .ToDictionary(g => g.Key, g => g.First().Messaggio);

        foreach (var campo in campi)
        {
            if (segnalati.TryGetValue(campo, out var messaggio))
                _avvisiDb[campo] = messaggio;
            else
                _avvisiDb.Remove(campo);
        }

        await RivalidaCampi(campi);
    }

    /// <summary>Rivalida i campi indicati, senza toccare quelli che l'utente non ha ancora aperto.</summary>
    private async Task RivalidaCampi(params string[] campi)
    {
        foreach (var campo in campi)
        {
            switch (campo)
            {
                case "cognome": await RivalidaSeToccato(_cognomeField); break;
                case "nome": await RivalidaSeToccato(_nomeField); break;
                case "email": await RivalidaSeToccato(_emailField); break;
                case "iban": await RivalidaSeToccato(_ibanField); break;
                case "cf": await RivalidaSeToccato(_cfField); break;
                case "nascita": await RivalidaSeToccato(_dataNascitaField); break;
                case "rilascio": await RivalidaSeToccato(_docRilDataField); break;
                case "scadenza": await RivalidaSeToccato(_docScadenzaField); break;
                case "indirizzo": await RivalidaSeToccato(_indirizzoField); break;
                case "tipodoc": await RivalidaSeToccato(_tipoDocField); break;
                case "docnumero": await RivalidaSeToccato(_docNumeroField); break;
                case "docente": await RivalidaSeToccato(_docRilDaField); break;
            }
        }
        StateHasChanged();
    }

    /// <summary>
    /// Le tre date si giudicano a vicenda: il rilascio dev'essere dopo la nascita e prima
    /// della scadenza. MudBlazor pero' rivalida solo il campo che cambia, e cosi' l'errore
    /// restava acceso sul campo gia' corretto finche' non lo si toccava di nuovo — con la
    /// causa vera che stava nell'altra data.
    ///
    /// Solo i campi gia' toccati: rivalidarli tutti farebbe comparire «obbligatoria» su una
    /// data che l'utente non ha ancora nemmeno guardato.
    /// </summary>
    private async Task RivalidaDate()
    {
        await RivalidaSeToccato(_dataNascitaField);
        await RivalidaSeToccato(_docRilDataField);
        await RivalidaSeToccato(_docScadenzaField);
        StateHasChanged();
    }

    private static async Task RivalidaSeToccato(MudBlazor.MudFormComponent<string, string>? campo)
    {
        if (campo is not null && campo.Touched) await campo.Validate();
    }

    private static async Task RivalidaSeToccato(MudDatePicker? campo)
    {
        if (campo is not null && campo.Touched) await campo.Validate();
    }

    /// <summary>L'errore del database ancora valido per questo campo, oppure null se il valore e' cambiato.</summary>
    private string? ErroreDb(string campo, string? valoreCorrente)
    {
        if (!_erroriDb.TryGetValue(campo, out var e)) return null;
        if (!string.Equals(e.Valore, valoreCorrente, StringComparison.Ordinal))
        {
            _erroriDb.Remove(campo);
            return null;
        }
        return e.Messaggio;
    }

    /// <summary>
    /// Chiede al database le sue segnalazioni e, dove serve, chiede conferma all'utente.
    /// Restituisce false se il salvataggio non deve proseguire.
    ///
    /// Le regole non sono qui: qui c'e' solo il modo di presentarle. La stessa
    /// validazione la chiama il sito di iscrizione, che le presentera' a modo suo.
    /// </summary>
    /// <summary>
    /// Chiede al database tutte le sue segnalazioni e le riporta sui campi.
    /// Restituisce false se ce n'e' almeno una bloccante.
    ///
    /// Si fa <b>sempre</b>, anche quando la form ha gia' errori suoi: altrimenti i campi
    /// respinti dal database resterebbero non segnalati fino a quando non si e' corretto
    /// tutto il resto, e si scoprirebbero un errore alla volta.
    /// </summary>
    private async Task<bool> ValidaSuiCampiAsync()
    {
        _erroriDb.Clear();
        _avvisiDb.Clear();
        _esitiUltimaValidazione.Clear();

        List<EsitoValidazione> esiti;
        try
        {
            esiti = await ClienteService.ValidaAsync(Entity, IsEditMode ? Entity.ClienteId : null);
        }
        catch (Exception ex)
        {
            // Se la verifica non si puo' fare non si tira a indovinare: si prosegue e
            // sara' il salvataggio a rifiutare, con il suo messaggio.
            Console.WriteLine($"Validazione cliente non riuscita: {ex.Message}");
            return true;
        }

        _esitiUltimaValidazione.AddRange(esiti);

        foreach (var e in esiti.Where(e => !e.Blocca && e.Gravita != "OK"))
            if (CampoPerEsito.TryGetValue(e.Esito, out var campoAvviso))
                _avvisiDb[campoAvviso] = e.Messaggio;

        var errori = esiti.Where(e => e.Blocca).ToList();
        foreach (var e in errori)
        {
            Snackbar.Add(e.Messaggio, Severity.Error);
            if (CampoPerEsito.TryGetValue(e.Esito, out var campo))
                _erroriDb[campo] = (ValoreCampo(campo), e.Messaggio);
        }

        // Il messaggio da solo non dice DOVE: senza questo giro il campo respinto
        // dal database resta indistinguibile da quelli accettati.
        if (_form is not null) await _form.Validate();

        return errori.Count == 0;
    }

    private readonly List<EsitoValidazione> _esitiUltimaValidazione = new();

    private async Task<bool> ConfermeOttenuteAsync()
    {
        _confermeAccettate = false;

        var esiti = _esitiUltimaValidazione;

        foreach (var a in esiti.Where(e => e.Gravita == "AVVISO"))
            Snackbar.Add(a.Messaggio, Severity.Info);

        var daConfermare = esiti.Where(e => e.RichiedeConferma).ToList();
        if (daConfermare.Count == 0) return true;

        var parametri = new DialogParameters
        {
            { "Title", "Confermi?" },
            { "ContentText", string.Join("\n\n", daConfermare.Select(e => e.Messaggio)) },
            // Qui non si cancella niente: il dialogo condiviso nasce per le eliminazioni
            // e senza questi tre parametri offrirebbe un pulsante rosso «Elimina».
            { "ButtonText", "Conferma" },
            { "Color", MudBlazor.Color.Primary },
            { "Icon", Icons.Material.Filled.Check }
        };
        var dialog = await DialogService.ShowAsync<DeleteConfirmationDialog>("Conferma", parametri,
            new DialogOptions { BackdropClick = false, CloseButton = true, MaxWidth = MaxWidth.Small });
        var esito = await dialog.Result;

        if (esito!.Canceled) return false;

        _confermeAccettate = true;
        return true;
    }

    /// <summary>Il titolo porta il sesso: lo si copia nell'entita' appena viene scelto.</summary>
    private async Task OnTitoloScelto(AnaTitoloPersone? titolo)
    {
        if (titolo is not null) Entity.Sesso = titolo.Sesso;
        await AggiornaAvvisoNomeSesso();

        // Scelto il titolo non c'e' piu' niente da fare li': il campo dopo e' il cognome,
        // e chi compila a tastiera non deve prendere il mouse per arrivarci.
        if (titolo is not null && _cognomeField is not null)
            await _cognomeField.FocusAsync();
        // Il sesso e' una lettera del codice fiscale: cambiando il titolo, la verifica va rifatta.
        if (!string.IsNullOrWhiteSpace(Entity.CodiceFiscale)) await ControllaAlVolo("cf");
    }

    private string? AvvisoNomeSesso;

    /// <summary>
    /// Sospetto di titolo sbagliato, dedotto dal nome. La regola sta nel database
    /// (<c>fn_nome_sesso_avviso</c>), non piu' in C#: e' la stessa che applica il sito di
    /// iscrizione, e la lista dei nomi maschili in -a si aggiorna senza ricompilare nulla.
    ///
    /// Si ricalcola quando si sceglie il titolo e quando si lascia il campo Nome — non a
    /// ogni tasto: e' un giro al database, e il momento utile e' quando il nome e' finito.
    /// </summary>
    private async Task AggiornaAvvisoNomeSesso()
    {
        // Maiuscolo qui e non solo a video: il maiuscolo dei campi e' CSS, il valore vero
        // resta com'e' stato digitato fino a NormalizeEntity, e finiva nel messaggio.
        AvvisoNomeSesso = Entity.TitoloFk == 0
            ? null
            : await ClienteService.AvvisoNomeSessoAsync(Entity.Nome?.Trim().ToUpperInvariant(), Entity.Sesso);
        StateHasChanged();
    }

    /// <summary>
    /// L'indirizzo e' cambiato sotto un consenso che era gia' attivo.
    ///
    /// Non si spegne niente: il consenso lo da' una persona, non una casella, e cambiare
    /// recapito non revoca nulla. Spegnerlo costringerebbe a riaccenderlo, e riaccenderlo
    /// riscrive data e fonte — sostituendo la prova vera con una falsa, di oggi.
    ///
    /// Si avvisa e basta, perche' il caso da intercettare e' l'altro: un errore di
    /// digitazione sull'indirizzo, che manderebbe la newsletter a un estraneo con un
    /// consenso che quell'estraneo non ha mai dato.
    /// </summary>
    private bool EmailCambiataConConsensoAttivo =>
        IsEditMode && _consensoIniziale && _consenso
        && !string.Equals(Entity.Email?.Trim(), _emailIniziale?.Trim(), StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// C'e' un indirizzo, ed e' scritto bene. Non basta che ci sia: un consenso dato su
    /// un'email malformata non e' un consenso, e' una riga che al primo invio risultera'
    /// irraggiungibile. Prima si guardava solo se il campo fosse pieno, quindi «pippo@»
    /// bastava ad accendere la spunta.
    /// </summary>
    private bool EmailUtilizzabile =>
        !string.IsNullOrWhiteSpace(Entity.Email) && _emailField?.Error != true;

    /// <summary>Sesso a video: vuoto finche' non c'e' un titolo, perche' prima non e' un dato ma un default.</summary>
    private string SessoDescrizione =>
        Entity.TitoloFk == 0 ? string.Empty : (Entity.Sesso == 'F' ? "F — Femminile" : "M — Maschile");

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            try
            {
                await JS.InvokeVoidAsync("dialogFormHelper.setupTabNavigation");
            }
            catch { }

            if (_titoloField != null)
            {
                await Task.Delay(300);
                await _titoloField.FocusAsync();
            }

            if (IsEditMode) await ControllaAllApertura();
        }
    }

    /// <summary>Cosa manca a questa scheda, detto all'apertura e non al salvataggio.</summary>
    private string? _avvisoIncompleta;

    /// <summary>
    /// Le schede nate prima che i dati fossero obbligatori non sono mai passate da un
    /// salvataggio con le regole di oggi, e sono molte. Chi ne apre una
    /// la trova gia' segnalata, campo per campo, invece di scoprirlo premendo Salva —
    /// o, peggio, alla reception dell'albergo, dove i documenti di tutti gli occupanti
    /// si presentano per legge.
    /// </summary>
    private async Task ControllaAllApertura()
    {
        List<EsitoValidazione> esiti;
        try
        {
            esiti = await ClienteService.ValidaAsync(Entity, Entity.ClienteId);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Controllo all'apertura non riuscito: {ex.Message}");
            return;
        }

        // Solo i dati mancanti: gli altri esiti (duplicati, codice fiscale) riguardano
        // cio' che c'e' scritto, e vanno detti a chi scrive, non a chi apre.
        var mancanti = esiti.Where(e => e.Blocca && e.Esito.StartsWith("MANCA_", StringComparison.Ordinal)).ToList();
        if (mancanti.Count == 0) return;

        foreach (var e in mancanti)
            if (CampoPerEsito.TryGetValue(e.Esito, out var campo))
                _erroriDb[campo] = (ValoreCampo(campo), e.Messaggio);

        _avvisoIncompleta = string.Join(" ", mancanti.Select(e => e.Messaggio));

        if (_form is not null) await _form.Validate();
        StateHasChanged();
    }



    protected override async Task OnInitializedAsync()
    {
        try
        {
            _tipiDocumento = await TipoDocumentoService.GetAllAsync();

            // FAT INIT: Carica comuni, aziende e dettagli geografici in un unico colpo
            _initData = await ClienteService.GetClienteInitDataAsync(IsEditMode ? Entity.ClienteId : null);

            if (IsEditMode)
            {
                // Popola gli oggetti Comune se presenti nei dati di init
                if (Entity.ComuneNascitaFk > 0)
                    Entity.ComuneNascita = _initData.ComuneNascita;
                
                if (Entity.ComuneResidenzaFk > 0)
                    Entity.ComuneResidenza = _initData.ComuneResidenza;

                _lingua = await ClienteLinguaService.GetAsync(Entity.ClienteId);

                var consenso = await ClienteConsensoService.GetAsync(Entity.ClienteId);
                _consenso = consenso.Consenso;
                _consensoIniziale = consenso.Consenso;
                _emailIniziale = Entity.Email;
                _consensoData = consenso.Data;
                _consensoFonte = consenso.Fonte;
            }
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "Errore durante il caricamento dei dati di inizializzazione cliente");
            Snackbar.Add("Errore caricamento dati iniziali", Severity.Error);
        }
    }

    protected override void OnParametersSet()
    {
        if (Entity.Foto != null && Entity.Foto.Length > 0)
        {
            var format = Entity.FotoMimeType ?? "image/jpeg";
            var base64 = Convert.ToBase64String(Entity.Foto);
            _photoPreviewUrl = $"data:{format};base64,{base64}";
        }
        else
        {
            _photoPreviewUrl = null;
        }
    }

    private async Task OnTabChanged(int index)
    {
        // Rilancia il setup della navigazione TAB quando cambi scheda
        // Necessario perché i campi delle tab nascoste non erano visibili al primo caricamento
        try
        {
            await Task.Delay(200); // Dai tempo al render
            await JS.InvokeVoidAsync("dialogFormHelper.setupTabNavigation", ".mud-dialog-content", true);
        }
        catch { }

        await FuocoSulPrimoCampo(index);
    }

    /// <summary>
    /// Il primo campo della scheda appena aperta, senza doverci cliccare sopra.
    /// L'ordine e' quello che si legge — in alto a sinistra — non quello dei riferimenti
    /// nel codice: chi compila a tastiera si aspetta di ripartire da dove guarda.
    /// </summary>
    private async Task FuocoSulPrimoCampo(int index)
    {
        try
        {
            switch (index)
            {
                case 0: if (_titoloField is not null) await _titoloField.FocusAsync(); break;
                case 1: if (_comuneResidenzaField is not null) await _comuneResidenzaField.FocusAsync(); break;
                case 2: if (_tipoDocField is not null) await _tipoDocField.FocusAsync(); break;
                case 3: if (_intolleranzaField is not null) await _intolleranzaField.FocusAsync(); break;
            }
        }
        catch { }
    }

    private async Task Submit()
    {
        if (_form == null) return;

        _isSaving = true;

        // Controllo SuperAdmin: Azienda obbligatoria
        if (IsSuperAdmin && Entity.AziendaFk == 0)
        {
            Snackbar.Add("Selezionare un'azienda per continuare", Severity.Warning);
            _isSaving = false;
            return;
        }

        StateHasChanged();

        try
        {
            _validationRequested = true;

            // Normalizza i campi prima di ogni verifica: il database giudica i valori
            // come verranno scritti, non come sono stati digitati.
            NormalizeEntity();

            // Si chiede al database cosa non va PRIMA di scrivere. E' l'unico modo
            // per poter chiedere conferma: se si scoprisse solo al salvataggio,
            // all'utente resterebbe un errore e nessuna via d'uscita.
            // Lingua e consenso viaggiano CON il cliente, non con due chiamate
            // dopo il salvataggio: il consenso va registrato nel momento in cui
            // l'anagrafica nasce, altrimenti la data che lo dimostra non e' quella.
            Entity.Lingua = string.IsNullOrWhiteSpace(_lingua) ? "IT" : _lingua!.Trim().ToUpperInvariant();
            Entity.Consenso = _consenso;
            // La fonte dice DOVE il consenso e' stato raccolto, ed e' meta' della prova:
            // senza, resta un flag acceso da chissa' chi. Un consenso dato qui adesso
            // porta il nome di questa porta; uno che c'era gia' conserva la sua origine,
            // che e' quella vera e non va riscritta a ogni salvataggio.
            if (_consenso)
                Entity.ConsensoFonte = _consensoIniziale && !string.IsNullOrWhiteSpace(_consensoFonte)
                    ? _consensoFonte
                    : "GESTIONALE";

            // ValidaSuiCampiAsync rivalida gia' la form dopo aver riportato gli esiti:
            // rifarlo qui vorrebbe dire validare due volte lo stesso stato.
            var databaseOk = await ValidaSuiCampiAsync();

            if (!_form.IsValid || !databaseOk)
            {
                // «Ci sono errori» non dice quali: chi salva da una scheda diversa da
                // quella del campo respinto non ha modo di sapere dove tornare.
                foreach (var errore in _form.Errors.Distinct().Take(8))
                    Snackbar.Add(errore, Severity.Error);
                if (_form.Errors.Length == 0 && databaseOk)
                    Snackbar.Add("Impossibile salvare: ci sono errori di validazione.", Severity.Error);

                _isSaving = false;
                return;
            }

            if (!await ConfermeOttenuteAsync())
            {
                _isSaving = false;
                return;
            }

            if (IsEditMode)
            {
                var updated = await ClienteService.UpdateAsync(Entity, _confermeAccettate);
                Snackbar.Add("Cliente aggiornato con successo", Severity.Success);
                MudDialog?.Close(DialogResult.Ok(updated));
            }
            else
            {
                var created = await ClienteService.CreateAsync(Entity, _confermeAccettate);
                Snackbar.Add("Cliente creato con successo", Severity.Success);
                MudDialog?.Close(DialogResult.Ok(created));
            }
        }
        catch (UniqueConstraintViolationException ex)
        {
            // Gestione specifica per duplicati: mostra messaggio e tieni aperto il dialog
            Snackbar.Add(ex.Message, Severity.Warning);

            // Logica opzionale: potremmo evidenziare il campo specifico se necessario
            // ma il messaggio Toast è già molto esplicito
        }
        catch (Exception ex)
        {
            Snackbar.Add($"Errore durante il salvataggio: {ex.Message}", Severity.Error);
        }
        finally
        {
            _isSaving = false;
            StateHasChanged();
        }
    }

    private void Cancel()
    {
        MudDialog?.Cancel();
    }

    /// <summary>
    /// Validazione asincrona del codice fiscale (formato + unicità)
    /// </summary>
    /// <summary>
    /// Azienda su cui cercare i duplicati, oppure null se non si sa.
    ///
    /// Serviva a evitare un buco silenzioso: i chiamanti passano AziendaFk con un `?? 0`
    /// (DashboardAdmin, Clienti), e lo zero non e' un'azienda — e' "non lo so". Trattandolo come
    /// un'azienda vera la ricerca girava a vuoto, non trovava nulla e APPROVAVA. Il salvataggio
    /// falliva comunque sulla chiave esterna, ma con un errore tecnico invece che con
    /// "email gia' presente".
    /// </summary>
    private int? AziendaDaControllare()
    {
        var azienda = IsSuperAdmin ? Entity.AziendaFk : AziendaFk;
        return azienda > 0 ? azienda : null;
    }

    private async Task<IEnumerable<string>> ValidateCodiceFiscaleAsync(string cf)
    {
        cf = cf?.Trim() ?? string.Empty;

        var db = ErroreDb("cf", Entity.CodiceFiscale);
        if (db is not null) return [db];

        if (string.IsNullOrWhiteSpace(cf))
        {
            // Verifica se estero (se null, assume italiano per sicurezza)
            bool isEstero = Entity.ComuneResidenza?.ComuneEstero ?? false;

            if (!isEstero)
                return ["Il Codice Fiscale è obbligatorio per i clienti italiani"];
            else
                return [];
        }

        // 1. Validazione Formato (Veloce)
        var formatResult = CodiceFiscaleValidator.ValidateCodiceFiscale(cf);
        if (!formatResult.IsValid)
            return [formatResult.Message];

        // 2. Validazione Unicità (DB)
        try
        {
            int? excludeId = IsEditMode ? Entity.ClienteId : null;
            // Se AziendaFk (dal parametro) è 0 (es. SuperAdmin), controlla l'azienda selezionata.
            var aziendaCheck = AziendaDaControllare();

            // Azienda ignota: non si approva in silenzio. Vedi AziendaDaControllare.
            if (aziendaCheck is null)
                return IsSuperAdmin ? [] : ["Impossibile verificare l'unicità del codice fiscale: azienda non determinata."];

            bool exists = await ClienteService.CheckCodiceFiscaleEsistenzaAsync(cf, aziendaCheck, excludeId);

            if (exists)
                return ["Codice Fiscale già presente in Anagrafica Clienti: impossibile procedere"];
        }
        catch (Exception ex)
        {
            // In caso di errore server, non blocchiamo l'UI ma logghiamo (o mostriamo errore generico)
            Console.WriteLine($"Errore validazione CF: {ex.Message}");
            return ["Impossibile verificare l'unicità del codice fiscale"];
        }

        return [];
    }

    private string? ValidateDataNascita(DateTime? date)
    {
        return ErroreDb("nascita", Chiave(date));
    }

    private string? ValidateIndirizzo(string? v) => ErroreDb("indirizzo", v);

    private string? ValidateTipoDoc(string? v) => ErroreDb("tipodoc", v);

    private string? ValidateDocNumero(string? v) => ErroreDb("docnumero", v);

    private string? ValidateDocEnte(string? v) => ErroreDb("docente", v);

    private string? ValidateIban(string? iban) => ErroreDb("iban", iban);

    private string? ValidateCognome(string? cognome) => ErroreDb("cognome", cognome);

    private string? ValidateNome(string? nome) => ErroreDb("nome", nome);

    private string? ValidateDataRilascio(DateTime? date)
    {
        var db = ErroreDb("rilascio", Chiave(date));
        if (db is not null) return db;

        // L'obbligo non si ripete qui: lo dice fn_ana_clienti_campi_mancanti, e vale
        // anche per il sito. Restano le regole incrociate, che sono solo di questa form.
        if (!date.HasValue)
            return null;

        var result = ClienteValidator.ValidateDocumentoDataRilascio(date, Entity.DocumentoRilasciatoScadenza, Entity.DataNascita);
        return result.IsValid ? null : result.Message;
    }

    private string? ValidateDataScadenza(DateTime? date)
    {
        var db = ErroreDb("scadenza", Chiave(date));
        if (db is not null) return db;

        if (!date.HasValue)
            return null;

        var result = ClienteValidator.ValidateDocumentoDataScadenza(date, Entity.DocumentoRilasciatoData);
        return result.IsValid ? null : result.Message;
    }

    /// <summary>
    /// Normalizza i dati del cliente prima del salvataggio
    /// </summary>
    private void NormalizeEntity()
    {
        // Trim e Uppercase per campi testo
        Entity.Cognome = Entity.Cognome?.Trim().ToUpperInvariant() ?? string.Empty;
        Entity.Nome = Entity.Nome?.Trim().ToUpperInvariant() ?? string.Empty;
        Entity.IndirizzoResidenza = Entity.IndirizzoResidenza?.Trim().ToUpperInvariant();
        Entity.CodiceFiscale = Entity.CodiceFiscale?.Trim().ToUpperInvariant();
        Entity.Iban = Entity.Iban?.Trim().ToUpperInvariant();
        Entity.TipoDocIdentita = Entity.TipoDocIdentita?.Trim().ToUpperInvariant();
        Entity.DocumentoNumero = Entity.DocumentoNumero?.Trim().ToUpperInvariant();
        Entity.DocumentoRilasciatoDa = Entity.DocumentoRilasciatoDa?.Trim().ToUpperInvariant();

        // Lowercase per email
        Entity.Email = Entity.Email?.Trim().ToLowerInvariant();

        // Trim semplice per altri campi
        Entity.PrefTelInt = Entity.PrefTelInt?.Trim();
        Entity.Telefono = Entity.Telefono?.Trim();
        Entity.Note = Entity.Note?.Trim().ToUpperInvariant();
        Entity.Intolleranza = Entity.Intolleranza?.Trim().ToUpperInvariant();
    }

    public void Dispose()
    {
        try { ((IJSInProcessRuntime)JS).InvokeVoid("dialogFormHelper.cleanup"); } catch { }
        GC.SuppressFinalize(this);
    }

    // ValidatePrefisso è stato rimosso con il campo digitabile: controllava la FORMA
    // di ciò che veniva battuto («comincia con +», «solo cifre»), e da un elenco chiuso
    // quella forma non può più essere sbagliata. La regola su QUANDO il prefisso è
    // obbligatorio non stava qui e non cambia: è nel database (SqlScripts/563), che lo
    // pretende per chi guida.

    private static IEnumerable<string> ValidateTelefono(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            yield break;
        }

        var result = ClienteValidator.ValidateTelefono(value);
        if (!result.IsValid)
        {
            yield return result.Message;
        }
    }

    /// <summary>
    /// Validazione asincrona dell'email (formato + unicità)
    /// </summary>
    private async Task<IEnumerable<string>> ValidateEmailAsync(string email)
    {
        email = email?.Trim() ?? string.Empty;

        // Solo la forma: e' immediata e va detta mentre si scrive.
        // L'unicita' NON si controlla piu' qui. E' un AVVISO, non un divieto —
        // condividere la casella e' prassi legittima (moglie e marito) — e un
        // validatore di campo puo' solo dipingere di rosso, cioe' vietare.
        // Il riscontro arriva al salvataggio, con la sua gravita' vera.
        var db = ErroreDb("email", Entity.Email);
        if (db is not null) return [db];

        // Vuota si puo': l'obbligo dipende dal ruolo e si applica all'iscrizione
        // (fn_mov_clienti_viaggi_valida), non all'anagrafica.
        if (string.IsNullOrWhiteSpace(email))
            return [];

        var formatResult = ClienteValidator.ValidateEmail(email);
        return formatResult.IsValid ? [] : [formatResult.Message];

    }



    /// <summary>
    /// Foto del cliente. Limite di dimensione, apertura e chiusura dello stream li gestisce
    /// <c>FileUploader</c>: qui resta solo cio' che e' proprio della scheda cliente.
    /// </summary>
    private async Task UploadPhoto(FileUploader.FileDaCaricare f)
    {
        try
        {
            // Il controllo e' sul tipo dichiarato dal browser e non sull'estensione: un .jpg
            // rinominato .txt qui verrebbe rifiutato, che e' cio' che si vuole per una foto.
            if (!f.File.ContentType.StartsWith("image/"))
            {
                Snackbar.Add("È possibile caricare solo immagini", Severity.Warning);
                return;
            }

            using var memoryStream = new MemoryStream();
            await f.Contenuto.CopyToAsync(memoryStream);

            Entity.Foto = memoryStream.ToArray();
            Entity.FotoMimeType = f.File.ContentType;
            Entity.FotoFilename = f.Nome;
            Entity.FotoUpdDate = DateTime.Now;

            // Update preview
            var base64 = Convert.ToBase64String(Entity.Foto);
            _photoPreviewUrl = $"data:{Entity.FotoMimeType};base64,{base64}";

            await InvokeAsync(StateHasChanged);
        }
        catch (Exception ex)
        {
            Snackbar.Add($"Errore durante il caricamento della foto: {ex.Message}", Severity.Error);
        }
    }

    private void DeletePhoto()
    {
        Entity.Foto = null;
        Entity.FotoMimeType = null;
        Entity.FotoFilename = null;
        Entity.FotoUpdDate = null;
        _photoPreviewUrl = null;
    }

    private async Task DownloadPhoto()
    {
        if (Entity.Foto == null || Entity.Foto.Length == 0) return;

        try
        {
            // Crea un link temporaneo per il download
            var fileName = Entity.FotoFilename ?? $"foto_cliente_{Entity.ClienteId}.jpg";
            var contentType = Entity.FotoMimeType ?? "image/jpeg";
            var base64 = Convert.ToBase64String(Entity.Foto);
            var fileUrl = $"data:{contentType};base64,{base64}";

            await JS.InvokeVoidAsync("triggerDownload", fileName, fileUrl);
        }
        catch (Exception ex)
        {
            Snackbar.Add($"Errore durante il download: {ex.Message}", Severity.Error);
        }
    }

    private MudBlazor.Color GetTabColor(string tabName)
    {
        bool hasError = false;

        switch (tabName)
        {
            case "Generale":
                hasError = (_validationRequested && Entity.TitoloFk == 0)
                           || CheckFields(_cognomeField, _nomeField) 
                           || CheckDatePickers(_dataNascitaField)
                           || (IsSuperAdmin && _validationRequested && Entity.AziendaFk == 0)
                           || (_validationRequested && ComuneNascitaIdProxy == null);
                break;
            case "Residenza":
                hasError = CheckFields(_indirizzoField, _emailField, _telefonoField)
                           || (_validationRequested && ComuneResidenzaIdProxy == null);
                break;
            case "Documenti":
                hasError = CheckFields(_docNumeroField, _docRilDaField, _cfField, _ibanField)
                           || CheckSelects(_tipoDocField)
                           || CheckDatePickers(_docRilDataField, _docScadenzaField);
                break;
            case "Altro":
                hasError = CheckFields(_intolleranzaField, _noteField);
                break;
        }

        return hasError ? MudBlazor.Color.Error : MudBlazor.Color.Default;
    }

    private static bool CheckFields(params MudTextField<string>?[] fields)
    {
        foreach (var f in fields)
        {
            if (f != null && f.Error) return true;
        }
        return false;
    }

    private static bool CheckDatePickers(params MudDatePicker?[] fields)
    {
        foreach (var f in fields)
        {
            if (f != null && f.Error) return true;
        }
        return false;
    }

    private static bool CheckSelects(params MudSelect<string>?[] fields)
    {
        foreach (var f in fields)
        {
            if (f != null && f.Error) return true;
        }
        return false;
    }
}
