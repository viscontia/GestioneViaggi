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

namespace GestioneViaggi.Components.Shared;

public partial class ClienteDialog : ComponentBase, IDisposable
{
    [CascadingParameter] IMudDialogInstance? MudDialog { get; set; }


    [Inject] public IClienteService ClienteService { get; set; } = default!;
    [Inject] public ComuneService ComuneService { get; set; } = default!;
    [Inject] public ISnackbar Snackbar { get; set; } = default!;
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
    private MudSelect<string>? _titoloField;
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

    private MudFileUpload<IBrowserFile>? _fileUpload;
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

                if (IsEditMode)
                {
                    var updated = await ClienteService.UpdateAsync(Entity);
                    await ClienteLinguaService.SetAsync(Entity.ClienteId, _lingua);
                    await ClienteConsensoService.SetAsync(Entity.ClienteId, _consenso);
                    Snackbar.Add("Cliente aggiornato con successo", Severity.Success);
                    MudDialog?.Close(DialogResult.Ok(updated));
                }
                else
                {
                    var created = await ClienteService.CreateAsync(Entity);
                    await ClienteLinguaService.SetAsync(created.ClienteId, _lingua);
                    await ClienteConsensoService.SetAsync(created.ClienteId, _consenso);
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
            int? aziendaCheck = IsSuperAdmin ? (Entity.AziendaFk == 0 ? null : Entity.AziendaFk) : AziendaFk;

            if (aziendaCheck == null) return []; // Non validare se azienda non selezionata

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
        Entity.Titolo = Entity.Titolo?.Trim().ToUpperInvariant();
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

        // 1. Validazione Formato (Veloce)
        var formatResult = ClienteValidator.ValidateEmail(email);
        if (!formatResult.IsValid)
            return [formatResult.Message];

        // 2. Validazione Unicità (DB)
        try
        {
            int? excludeId = IsEditMode ? Entity.ClienteId : null;
            // Se AziendaFk è 0, usa Entity.AziendaFk (selezionata)
            int? aziendaCheck = IsSuperAdmin ? (Entity.AziendaFk == 0 ? null : Entity.AziendaFk) : AziendaFk;

            if (aziendaCheck == null) return []; // Non validare se azienda non selezionata

            bool exists = await ClienteService.VerificaClienteEsistenteAsync(email, aziendaCheck, excludeId);

            if (exists)
                return ["Mail già presente in Anagrafica Clienti: impossibile proseguire"];
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Errore validazione Email: {ex.Message}");
            return ["Impossibile verificare l'unicità dell'email"];
        }

        return [];
    }



    private async Task UploadPhoto(IBrowserFile? file)
    {
        try
        {
            if (file == null)
            {
                return;
            }

            if (file.Size > MaxFileSize)
            {
                Snackbar.Add("La dimensione massima del file è 5MB", Severity.Warning);
                return;
            }

            if (!file.ContentType.StartsWith("image/"))
            {
                Snackbar.Add("È possibile caricare solo immagini", Severity.Warning);
                return;
            }

            using var stream = file.OpenReadStream(MaxFileSize);
            using var memoryStream = new MemoryStream();
            await stream.CopyToAsync(memoryStream);

            Entity.Foto = memoryStream.ToArray();
            Entity.FotoMimeType = file.ContentType;
            Entity.FotoFilename = file.Name;
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
                hasError = CheckSelects(_titoloField)
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
