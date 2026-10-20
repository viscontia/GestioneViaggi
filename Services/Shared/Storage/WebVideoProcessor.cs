namespace GestioneViaggi.Services.Shared.Storage;

/// <summary>
/// Il video d'apertura della home del sito (script 698; disegno della Tappa 4 del sito, §8): dal file
/// così com'è (anche quello del telefono) alle due versioni per il web — primi <see cref="MaxSecondi"/>
/// secondi, senza audio, H.264 in MP4, lato lungo <see cref="LatoComputer"/> per il computer e
/// <see cref="LatoTelefono"/> per il telefono.
/// </summary>
/// <remarks>
/// ⚠️ Con i convertitori DEL SISTEMA (Mac: AVFoundation; Windows: Media Foundation), non con ffmpeg:
/// ffmpeg pesa ~80 MB e il suo codificatore H.264 è sotto GPL, un problema per un prodotto venduto a
/// più tour operator (decisione del 2026-10-20). I file preparati stanno in una cartella temporanea:
/// vanno allo Storage solo all'«Aggiorna» della scheda «Sito web».
/// </remarks>
public static class WebVideoProcessor
{
    public const double MaxSecondi = 20;
    public const int LatoComputer = 1920;
    public const int LatoTelefono = 960;
    /// <summary>Bit al secondo: ~5 MB per 20 s al computer, ~2 MB al telefono (video muto, apertura).</summary>
    public const int BitrateComputer = 2_000_000;
    public const int BitrateTelefono = 800_000;
    public const string Mime = "video/mp4";
    /// <summary>
    /// La copertina è un JPEG, non un WebP: il codificatore WebP di ImageSharp impiegava 16 s per un fotogramma
    /// (misurato il 2026-10-20), quello JPEG del sistema pochi millisecondi. Ai visitatori la riconverte il sito.
    /// </summary>
    public const string MimeCopertina = "image/jpeg";
    /// <summary>Qualità della copertina: si vede un istante, prima del video; più leggera = meno attesa.</summary>
    public const float QualitaCopertina = 0.5f;   // scala di Apple: 0,7 dava 1 MB per 1744×1308, 0,5 circa la metà

    /// <summary>
    /// Le due versioni pronte e la COPERTINA (il primo fotogramma, in JPEG: il sito la mostra finché il video non
    /// parte, e il passaggio non si vede — script 699), su file temporanei, con le misure della versione computer.
    /// </summary>
    public sealed record VideoPreparato(
        string FileComputer, string FileTelefono, string FileCopertina, int Larghezza, int Altezza,
        double DurataOriginale, double Durata)
    {
        /// <summary>Il video era più lungo: se ne usano solo i primi <see cref="MaxSecondi"/> secondi.</summary>
        public bool Accorciato => DurataOriginale > Durata + 0.05;

        /// <summary>Cancella i file temporanei (scheda chiusa senza aggiornare, video tolto, caricato).</summary>
        public void Cancella()
        {
            foreach (var f in new[] { FileComputer, FileTelefono, FileCopertina })
                try { if (File.Exists(f)) File.Delete(f); } catch { /* temporaneo: lo pulisce il sistema */ }
        }
    }

    public const string MessaggioNonLetto =
        "Il video non si riesce a leggere: provare con un MP4 o un MOV (come quelli del telefono).";

    /// <summary>
    /// Le misure di una versione: lato lungo al massimo <paramref name="lato"/> (mai ingrandire), stesse
    /// proporzioni, numeri PARI (il codificatore H.264 lavora a blocchi di 2 pixel).
    /// </summary>
    public static (int Larghezza, int Altezza) Misure(int larghezza, int altezza, int lato)
    {
        if (larghezza <= 0 || altezza <= 0) throw new ArgumentOutOfRangeException(nameof(larghezza));
        var scala = Math.Min(1.0, (double)lato / Math.Max(larghezza, altezza));
        static int Pari(double x) => Math.Max(2, (int)Math.Round(x / 2) * 2);
        return (Pari(larghezza * scala), Pari(altezza * scala));
    }

    /// <summary>Quanti secondi si tengono di un video lungo <paramref name="durata"/>.</summary>
    public static double DurataTenuta(double durata) => Math.Min(durata, MaxSecondi);

    /// <summary>Prepara le due versioni. Errore leggibile se il file non è un video che il sistema sa aprire.</summary>
    /// <remarks>Non tocca l'interfaccia: le attese non tornano sul filo principale (<c>ConfigureAwait(false)</c>).</remarks>
    public static async Task<VideoPreparato> PreparaAsync(string sorgente, CancellationToken ct = default)
    {
        var cartella = Path.Combine(Path.GetTempPath(), "GestioneViaggi-video");
        Directory.CreateDirectory(cartella);
        var nome = Guid.NewGuid().ToString("N");
        var computer = Path.Combine(cartella, $"{nome}.mp4");
        var telefono = Path.Combine(cartella, $"{nome}-telefono.mp4");
        var copertina = Path.Combine(cartella, $"{nome}-copertina.jpg");
        try
        {
#if MACCATALYST || IOS
            var (w, h, durata) = await Mac.ConvertiAsync(sorgente, computer, LatoComputer, BitrateComputer, ct).ConfigureAwait(false);
            await Mac.ConvertiAsync(sorgente, telefono, LatoTelefono, BitrateTelefono, ct).ConfigureAwait(false);
            await File.WriteAllBytesAsync(copertina, Mac.PrimoFotogramma(sorgente), ct).ConfigureAwait(false);
#elif WINDOWS
            var (w, h, durata) = await Win.ConvertiAsync(sorgente, computer, LatoComputer, BitrateComputer, ct).ConfigureAwait(false);
            await Win.ConvertiAsync(sorgente, telefono, LatoTelefono, BitrateTelefono, ct).ConfigureAwait(false);
            await using (var fotogramma = await Win.PrimoFotogrammaAsync(sorgente).ConfigureAwait(false))
            {
                // su Windows il fotogramma arriva come immagine da ricomprimere: JPEG (veloce anche con ImageSharp)
                using var img = await SixLabors.ImageSharp.Image.LoadAsync(fotogramma, ct).ConfigureAwait(false);
                await SixLabors.ImageSharp.ImageExtensions.SaveAsJpegAsync(img, copertina,
                    new SixLabors.ImageSharp.Formats.Jpeg.JpegEncoder { Quality = (int)(QualitaCopertina * 100) }, ct).ConfigureAwait(false);
            }
#else
            int w = 0, h = 0; double durata = 0;
            await Task.CompletedTask;
            throw new PlatformNotSupportedException("Video: solo Mac e Windows.");
#endif
            return new VideoPreparato(computer, telefono, copertina, w, h, durata, DurataTenuta(durata));
        }
        catch
        {
            new VideoPreparato(computer, telefono, copertina, 0, 0, 0, 0).Cancella();
            throw;
        }
    }


#if MACCATALYST || IOS
    /// <summary>AVFoundation: si legge solo la traccia video (niente audio) per i primi 20 s e la si riscrive.</summary>
    private static class Mac
    {
        public static async Task<(int W, int H, double Durata)> ConvertiAsync(
            string sorgente, string destinazione, int lato, int bitrate, CancellationToken ct)
        {
            using var asset = AVFoundation.AVAsset.FromUrl(Foundation.NSUrl.FromFilename(sorgente));
            // ⚠️ TracksWithMediaType è «superata» da macOS 15, ma l'alternativa in .NET (LoadTracksWithMediaTypeAsync)
            // è legata al tipo sbagliato (NSArray<AVMutableCompositionTrack>): resta la classica, che funziona ovunque.
#pragma warning disable CA1422
            var traccia = asset.TracksWithMediaType(AVFoundation.AVMediaTypesExtensions.GetConstant(AVFoundation.AVMediaTypes.Video)!).FirstOrDefault()
                          ?? throw new InvalidOperationException(MessaggioNonLetto);
#pragma warning restore CA1422
            var durata = asset.Duration.Seconds;
            if (double.IsNaN(durata) || durata <= 0) throw new InvalidOperationException(MessaggioNonLetto);

            // Le misure nel verso in cui si guarda (un video girato in verticale ha la rotazione nella trasformazione)
            var naturale = traccia.NaturalSize;
            var ruotata = traccia.PreferredTransform.TransformSize(naturale);
            var (wVista, hVista) = Misure((int)Math.Abs(Math.Round(ruotata.Width)), (int)Math.Abs(Math.Round(ruotata.Height)), lato);
            var (wScritta, hScritta) = Misure((int)Math.Round(naturale.Width), (int)Math.Round(naturale.Height), lato);

            using var lettore = AVFoundation.AVAssetReader.FromAsset(asset, out var errL)
                                ?? throw new InvalidOperationException(errL?.LocalizedDescription ?? MessaggioNonLetto);
            lettore.TimeRange = new CoreMedia.CMTimeRange
            {
                Start = CoreMedia.CMTime.Zero,
                Duration = CoreMedia.CMTime.FromSeconds(DurataTenuta(durata), 600),
            };
            var uscita = new AVFoundation.AVAssetReaderTrackOutput(traccia,
                new AVFoundation.AVVideoSettingsUncompressed { PixelFormatType = CoreVideo.CVPixelFormatType.CV420YpCbCr8BiPlanarVideoRange }.Dictionary)
            { AlwaysCopiesSampleData = false };
            lettore.AddOutput(uscita);

            if (File.Exists(destinazione)) File.Delete(destinazione);
            using var scrittore = AVFoundation.AVAssetWriter.FromUrl(Foundation.NSUrl.FromFilename(destinazione),
                                      AVFoundation.AVFileTypesExtensions.GetConstant(AVFoundation.AVFileTypes.Mpeg4)!, out var errS)
                                  ?? throw new InvalidOperationException(errS?.LocalizedDescription ?? "Video: file di uscita non creato.");
            scrittore.ShouldOptimizeForNetworkUse = true;   // l'indice in testa: il sito può partire prima di averlo tutto
            var impostazioni = new AVFoundation.AVVideoSettingsCompressed
            {
                CodecType = AVFoundation.AVVideoCodecType.H264,
                Width = wScritta,
                Height = hScritta,
                ScalingMode = AVFoundation.AVVideoScalingMode.ResizeAspect,
                CodecSettings = new AVFoundation.AVVideoCodecSettings
                {
                    AverageBitRate = bitrate,
                    MaxKeyFrameInterval = 60,   // un fotogramma chiave ogni ~2 s: il video si può far partire da qualunque punto
                    ProfileLevelH264 = AVFoundation.AVVideoProfileLevelH264.HighAutoLevel,
                },
            };
            var ingresso = AVFoundation.AVAssetWriterInput.Create(AVFoundation.AVMediaTypesExtensions.GetConstant(AVFoundation.AVMediaTypes.Video)!, impostazioni);
            ingresso.ExpectsMediaDataInRealTime = false;
            ingresso.Transform = traccia.PreferredTransform;
            scrittore.AddInput(ingresso);

            if (!lettore.StartReading()) throw new InvalidOperationException(lettore.Error?.LocalizedDescription ?? MessaggioNonLetto);
            if (!scrittore.StartWriting()) throw new InvalidOperationException(scrittore.Error?.LocalizedDescription ?? "Video: scrittura non partita.");
            scrittore.StartSessionAtSourceTime(CoreMedia.CMTime.Zero);
            // Il metodo raccomandato da Apple: lo scrittore chiama quando è pronto, su una coda sua. (Un ciclo che
            // aspetta «pronto» da fuori restava fermo per sempre: provato il 2026-10-20 sul video d'esempio.)
            var fatto = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var coda = new CoreFoundation.DispatchQueue("gestioneviaggi.video");
            ingresso.RequestMediaData(coda, () =>
            {
                while (ingresso.ReadyForMoreMediaData)
                {
                    if (ct.IsCancellationRequested)
                    {
                        lettore.CancelReading(); ingresso.MarkAsFinished(); fatto.TrySetCanceled(ct); return;
                    }
                    using var campione = uscita.CopyNextSampleBuffer();
                    if (campione is null) { ingresso.MarkAsFinished(); fatto.TrySetResult(); return; }
                    if (!ingresso.AppendSampleBuffer(campione))
                    {
                        fatto.TrySetException(new InvalidOperationException(
                            scrittore.Error?.LocalizedDescription ?? "Video: conversione interrotta."));
                        return;
                    }
                }
            });
            await fatto.Task.ConfigureAwait(false);
            if (lettore.Status == AVFoundation.AVAssetReaderStatus.Failed)
                throw new InvalidOperationException(lettore.Error?.LocalizedDescription ?? MessaggioNonLetto);
            await scrittore.FinishWritingAsync().ConfigureAwait(false);
            if (scrittore.Status != AVFoundation.AVAssetWriterStatus.Completed)
                throw new InvalidOperationException(scrittore.Error?.LocalizedDescription ?? "Video: conversione non completata.");
            return (wVista, hVista, durata);
        }

        /// <summary>Il primo fotogramma, nel verso in cui si guarda, in JPEG (codificatore del sistema).</summary>
        public static byte[] PrimoFotogramma(string sorgente)
        {
            using var asset = AVFoundation.AVAsset.FromUrl(Foundation.NSUrl.FromFilename(sorgente));
            using var generatore = new AVFoundation.AVAssetImageGenerator(asset)
            {
                AppliesPreferredTrackTransform = true,   // un video verticale dà una copertina verticale
                RequestedTimeToleranceBefore = CoreMedia.CMTime.Zero,
                RequestedTimeToleranceAfter = CoreMedia.CMTime.Zero,
            };
#pragma warning disable CA1422   // la versione asincrona non serve qui: un fotogramma, una volta
            using var immagine = generatore.CopyCGImageAtTime(CoreMedia.CMTime.Zero, out _, out var errore)
                                 ?? throw new InvalidOperationException(errore?.LocalizedDescription ?? MessaggioNonLetto);
#pragma warning restore CA1422
            using var ui = new UIKit.UIImage(immagine);
            using var jpeg = ui.AsJPEG(QualitaCopertina) ?? throw new InvalidOperationException("Video: copertina non creata.");
            return jpeg.ToArray();
        }
    }
#endif

#if WINDOWS
    /// <summary>Media Foundation (Windows.Media.Transcoding): profilo MP4 senza audio, tagliato a 20 s.</summary>
    private static class Win
    {
        public static async Task<(int W, int H, double Durata)> ConvertiAsync(
            string sorgente, string destinazione, int lato, int bitrate, CancellationToken ct)
        {
            Windows.Storage.StorageFile file;
            Windows.Storage.FileProperties.VideoProperties prop;
            try
            {
                file = await Windows.Storage.StorageFile.GetFileFromPathAsync(sorgente).AsTask().ConfigureAwait(false);
                prop = await file.Properties.GetVideoPropertiesAsync().AsTask().ConfigureAwait(false);
            }
            catch (Exception ex) { throw new InvalidOperationException(MessaggioNonLetto, ex); }
            var durata = prop.Duration.TotalSeconds;
            if (prop.Width == 0 || prop.Height == 0 || durata <= 0) throw new InvalidOperationException(MessaggioNonLetto);

            // Un video girato in verticale ha la rotazione a parte: le misure si scambiano
            var ruotato = prop.Orientation is Windows.Storage.FileProperties.VideoOrientation.Rotate90
                                           or Windows.Storage.FileProperties.VideoOrientation.Rotate270;
            var (w, h) = Misure((int)(ruotato ? prop.Height : prop.Width), (int)(ruotato ? prop.Width : prop.Height), lato);

            var profilo = Windows.Media.MediaProperties.MediaEncodingProfile.CreateMp4(
                Windows.Media.MediaProperties.VideoEncodingQuality.HD1080p);
            profilo.Audio = null;                       // niente audio
            profilo.Video!.Width = (uint)w;
            profilo.Video.Height = (uint)h;
            profilo.Video.Bitrate = (uint)bitrate;

            var tieni = TimeSpan.FromSeconds(DurataTenuta(durata));
            var convertitore = new Windows.Media.Transcoding.MediaTranscoder
            {
                HardwareAccelerationEnabled = true,
                TrimStartTime = TimeSpan.Zero,
                TrimStopTime = prop.Duration > tieni ? prop.Duration - tieni : TimeSpan.Zero,   // quanto togliere in fondo
            };

            if (File.Exists(destinazione)) File.Delete(destinazione);
            var cartella = await Windows.Storage.StorageFolder.GetFolderFromPathAsync(Path.GetDirectoryName(destinazione)!).AsTask().ConfigureAwait(false);
            var uscita = await cartella.CreateFileAsync(Path.GetFileName(destinazione),
                                                        Windows.Storage.CreationCollisionOption.ReplaceExisting).AsTask().ConfigureAwait(false);
            var preparato = await convertitore.PrepareFileTranscodeAsync(file, uscita, profilo).AsTask().ConfigureAwait(false);
            if (!preparato.CanTranscode)
                throw new InvalidOperationException($"{MessaggioNonLetto} ({preparato.FailureReason})");
            await preparato.TranscodeAsync().AsTask(ct).ConfigureAwait(false);
            return (w, h, durata);
        }

        /// <summary>Il primo fotogramma (Windows.Media.Editing), come immagine da convertire poi con ImageSharp.</summary>
        public static async Task<Stream> PrimoFotogrammaAsync(string sorgente)
        {
            var file = await Windows.Storage.StorageFile.GetFileFromPathAsync(sorgente).AsTask().ConfigureAwait(false);
            var clip = await Windows.Media.Editing.MediaClip.CreateFromFileAsync(file).AsTask().ConfigureAwait(false);
            var composizione = new Windows.Media.Editing.MediaComposition();
            composizione.Clips.Add(clip);
            var prop = await file.Properties.GetVideoPropertiesAsync().AsTask().ConfigureAwait(false);
            var (w, h) = Misure((int)prop.Width, (int)prop.Height, LatoComputer);
            var immagine = await composizione.GetThumbnailAsync(TimeSpan.Zero, w, h,
                Windows.Media.Editing.VideoFramePrecision.NearestFrame).AsTask().ConfigureAwait(false);
            var copia = new MemoryStream();
            await immagine.AsStreamForRead().CopyToAsync(copia).ConfigureAwait(false);
            copia.Position = 0;
            return copia;
        }
    }
#endif
}
