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

namespace GestioneViaggi.Components.Shared;

public partial class ClienteDialog : ComponentBase, IDisposable
{
    [CascadingParameter] IMudDialogInstance? MudDialog { get; set; }


    [Inject] public IClienteService ClienteService { get; set; } = default!;
    [Inject] public ComuneService ComuneService { get; set; } = default!;
    [Inject] public ISnackbar Snackbar { get; set; } = default!;
    [Inject] public IDialogService DialogService { get; set; } = default!;
    [Inject] public ILogger<ClienteDialog> Logger { get; set; } = default!;
    [Inject] public ClienteLinguaService ClienteLinguaService { get; set; } = default!;
    [Inject] public ClienteConsensoService ClienteConsensoService { get; set; } = default!;

    [Parameter] public Cliente Entity { get; set; } = new();
    [Parameter] public bool IsEditMode { get; set; }
    [Parameter] public int AziendaFk { get; set; }

    /// <summary>Lingua preferita del cliente per la newsletter (side-field, Blocco 11). null = auto dalla nazione.</summary>
    private string? _lingua;

    /// <summary>Consenso marketing (side-field, Blocco 11-B): è il flag che filtra i destinatari newsletter.</summary>
    private bool _consenso;
    /// <summary>Data e provenienza dell'ultimo cambio di consenso, mostrate in sola lettura.</summary>
    private DateTime? _consensoData;
    private string? _consensoFonte;

    private bool IsSuperAdmin => AziendaFk == 0;

    private MudForm? _form;
    private TitoloPersonaSelect? _titoloField;
    private MudTextField<string>? _cognomeField, _nomeField;
    private MudDatePicker? _dataNascitaField;
    
    // Tab 2
    private MudTextField<string>? _indirizzoField, _emailField, _prefTelField, _telefonoField;

    // Tab 3
    private MudSelect<string>? _tipoDocField;
    private MudTextField<string>? _docNumeroField, _docRilDaField, _cfField, _ibanField;
    private MudDatePicker? _docRilDataField, _docScadenzaField;

    // Tab 4
    private MudTextField<string>? _intolleranzaField, _noteField;

    private string? _photoPreviewUrl;
    private const long MaxFileSize = 1024 * 1024 * 5; // 5MB

    private GestioneViaggi.Models.DTOs.ClienteInitData _initData = new();

    private bool _isSaving = false;
    private bool _validationRequested = false;

    // NOTA: DateMask configurato con formato dd/MM/yyyy
    // Permette input da tastiera (es: digitare 15031990 auto-formatta in 15/03/1990)
    // In MAUI Blazor Hybrid, il rendering è client-side quindi l'esperienza è fluida
    // (il bug #6796 affligge principalmente Blazor Server con alta latenza)

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
    /// Chiede al database le sue segnalazioni e, dove serve, chiede conferma all'utente.
    /// Restituisce false se il salvataggio non deve proseguire.
    ///
    /// Le regole non sono qui: qui c'e' solo il modo di presentarle. La stessa
    /// validazione la chiama il sito di iscrizione, che le presentera' a modo suo.
    /// </summary>
    private async Task<bool> ConfermeOttenuteAsync()
    {
        _confermeAccettate = false;

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

        var errori = esiti.Where(e => e.Blocca).ToList();
        if (errori.Count > 0)
        {
            foreach (var e in errori) Snackbar.Add(e.Messaggio, Severity.Error);
            return false;
        }

        foreach (var a in esiti.Where(e => e.Gravita == "AVVISO"))
            Snackbar.Add(a.Messaggio, Severity.Info);

        var daConfermare = esiti.Where(e => e.RichiedeConferma).ToList();
        if (daConfermare.Count == 0) return true;

        var parametri = new DialogParameters
        {
            { "Title", "Confermi?" },
            { "ContentText", string.Join("\n\n", daConfermare.Select(e => e.Messaggio)) }
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
        AvvisoNomeSesso = Entity.TitoloFk == 0
            ? null
            : await ClienteService.AvvisoNomeSessoAsync(Entity.Nome, Entity.Sesso);
        StateHasChanged();
    }

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
        }
    }



    protected override async Task OnInitializedAsync()
    {
        try
        {
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
            await _form.Validate();

            if (!_form.IsValid)
            {
                Snackbar.Add("Impossibile salvare: ci sono errori di validazione. Controlla i campi evidenziati.", Severity.Error);
                _isSaving = false;
                return;
            }

            if (_form.IsValid)
            {
                // Normalizza i campi prima del salvataggio
                NormalizeEntity();

                // Si chiede al database cosa non va PRIMA di scrivere. E' l'unico modo
                // per poter chiedere conferma: se si scoprisse solo al salvataggio,
                // all'utente resterebbe un errore e nessuna via d'uscita.
                // Lingua e consenso viaggiano CON il cliente, non con due chiamate
                // dopo il salvataggio: il consenso va registrato nel momento in cui
                // l'anagrafica nasce, altrimenti la data che lo dimostra non e' quella.
                Entity.Lingua = string.IsNullOrWhiteSpace(_lingua) ? "IT" : _lingua!.Trim().ToUpperInvariant();
                Entity.Consenso = _consenso;
                if (_consenso && !string.IsNullOrWhiteSpace(_consensoFonte))
                    Entity.ConsensoFonte = _consensoFonte;

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

    private string? ValidateDataRilascio(DateTime? date)
    {
        if (!date.HasValue)
            return "La data di rilascio è obbligatoria";

        var result = ClienteValidator.ValidateDocumentoDataRilascio(date, Entity.DocumentoRilasciatoScadenza, Entity.DataNascita);
        return result.IsValid ? null : result.Message;
    }

    private string? ValidateDataScadenza(DateTime? date)
    {
        if (!date.HasValue)
            return "La data di scadenza è obbligatoria";

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

    /// <summary>
    /// Il prefisso internazionale e' obbligatorio SE c'e' un numero di telefono: senza, il numero
    /// e' inutilizzabile per un destinatario estero (e la newsletter lo mostra monco).
    /// Un cliente senza telefono non deve essere bloccato da un campo che non lo riguarda.
    /// </summary>
    private IEnumerable<string> ValidatePrefisso(string value)
    {
        if (string.IsNullOrWhiteSpace(Entity.Telefono))
            yield break;

        var result = ClienteValidator.ValidatePrefissoTelefono(value);
        if (!result.IsValid)
            yield return result.Message;
    }

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

        if (string.IsNullOrWhiteSpace(email))
            return [];

        // Solo la forma: e' immediata e va detta mentre si scrive.
        // L'unicita' NON si controlla piu' qui. E' un AVVISO, non un divieto —
        // condividere la casella e' prassi legittima (moglie e marito) — e un
        // validatore di campo puo' solo dipingere di rosso, cioe' vietare.
        // Il riscontro arriva al salvataggio, con la sua gravita' vera.
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
                hasError = CheckFields(_indirizzoField, _emailField, _prefTelField, _telefonoField)
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
