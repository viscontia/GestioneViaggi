# PDF Library Alternatives for MAUI - Technical Analysis

## Current Issue: QuestPDF 2024.3.0 Incompatibility

### Root Cause
QuestPDF 2024.x removed support for MAUI platforms (MacCatalyst, iOS, Android) when they switched from SkiaSharp to a custom Skia build. The library now only supports:
- win-x64, linux-x64, linux-arm64, linux-musl-x64, osx-x64, osx-arm64

MacCatalyst uses iOS-based runtime identifiers, causing TypeInitializationException in QuestPDF.Settings static constructor.

---

## Solution 1: QuestPDF 2023.12.6 (IMPLEMENTED)

**Status**: Active solution
**Version**: 2023.12.6 (last version with MAUI support)
**License**: MIT + Community License

### Pros
- Maintains existing code structure
- Minimal migration effort
- Proven compatibility with MAUI/MacCatalyst
- Includes embedded Lato fonts
- Good performance and API

### Cons
- Stuck on older version (no access to 2024+ features)
- No future mobile platform updates
- May miss security patches in newer versions

### Implementation Status
✅ GestioneViaggi.csproj updated to QuestPDF 2023.12.6
✅ DatabaseDocumentationService.cs optimized for 2023.12.6
✅ Font registration simplified (uses embedded fonts as fallback)

---

## Solution 2: Syncfusion PDF Library

**License**: Commercial (Free for individual developers &lt; $1M revenue)
**NuGet**: `Syncfusion.Pdf.Net.Core`

### Pros
- Native MAUI support (officially supported)
- Comprehensive documentation
- Active development and support
- Includes Word, Excel, PowerPoint libraries
- Enterprise-grade features

### Cons
- Commercial license required for production
- Larger package size
- Different API (requires code rewrite)

### Sample Code
```csharp
using Syncfusion.Pdf;
using Syncfusion.Pdf.Graphics;
using Syncfusion.Drawing;

public async Task<string> GeneratePdfWithSyncfusion(string outputPath)
{
    using (PdfDocument document = new PdfDocument())
    {
        PdfPage page = document.Pages.Add();
        PdfGraphics graphics = page.Graphics;

        PdfFont font = new PdfStandardFont(PdfFontFamily.Helvetica, 20);
        graphics.DrawString("Database Documentation", font,
            PdfBrushes.Black, new PointF(0, 0));

        using (MemoryStream stream = new MemoryStream())
        {
            document.Save(stream);
            await File.WriteAllBytesAsync(outputPath, stream.ToArray());
        }
    }
    return outputPath;
}
```

### Integration Steps
1. Install NuGet: `dotnet add package Syncfusion.Pdf.Net.Core`
2. Register license in MauiProgram.cs: `Syncfusion.Licensing.SyncfusionLicenseProvider.RegisterLicense("YOUR-KEY");`
3. Rewrite DatabaseDocumentationService using Syncfusion API

---

## Solution 3: PdfSharp.Maui

**License**: MIT
**NuGet**: `PdfSharp.Maui` (v1.0.5)

### Pros
- Native MAUI integration
- Converts MAUI Views to PDF
- Free and open source
- Active MAUI community support
- Good for UI-based PDF generation

### Cons
- Less mature than QuestPDF
- Limited table/layout features
- Requires MAUI Views (not ideal for data-driven reports)
- Different paradigm (view-based vs code-based)

### Sample Code
```csharp
using PdfSharp.Maui;

public class DatabaseDocumentationService
{
    private readonly IPdfManager _pdfManager;

    public async Task<string> GeneratePdfWithPdfSharp(View documentView, string outputPath)
    {
        // Create PDF from MAUI View
        var pdf = await _pdfManager.GeneratePdfFromView(
            documentView,
            PageOrientation.Landscape,
            PageSize.A4,
            PdfStyleUniversal
        );

        // Save PDF
        await PdfSave.Save(pdf, Path.GetFileName(outputPath), Path.GetDirectoryName(outputPath));
        return outputPath;
    }
}
```

### Integration Steps
1. Install NuGet: `dotnet add package PdfSharp.Maui`
2. Create Razor component for PDF layout
3. Render component to View
4. Convert View to PDF

### Limitations for Our Use Case
- Requires creating MAUI Views/Razor components for PDF content
- Not ideal for server-side data processing
- Better suited for printing app UI screens

---

## Solution 4: iText7

**License**: AGPL (requires commercial license for proprietary apps)
**NuGet**: `itext7` + `itext7.bouncy-castle-adapter`

### Pros
- Enterprise-grade, industry standard
- Advanced features (digital signatures, forms, encryption)
- Excellent documentation
- MAUI compatible
- 30M+ downloads

### Cons
- AGPL license (viral - requires open source or commercial license)
- Commercial license expensive (~$1,500+/year)
- More complex API
- Larger package size

### Sample Code
```csharp
using iText.Kernel.Pdf;
using iText.Layout;
using iText.Layout.Element;
using iText.Layout.Properties;

public async Task<string> GeneratePdfWithIText(string outputPath)
{
    using (var writer = new PdfWriter(outputPath))
    using (var pdf = new PdfDocument(writer))
    using (var document = new Document(pdf))
    {
        document.Add(new Paragraph("Database Documentation")
            .SetFontSize(20)
            .SetBold());

        Table table = new Table(UnitValue.CreatePercentArray(new float[] {3, 3, 3, 2}));
        table.SetWidth(UnitValue.CreatePercentValue(100));

        table.AddHeaderCell("Nome Function");
        table.AddHeaderCell("Scopo");
        table.AddHeaderCell("Input");
        table.AddHeaderCell("Output");

        foreach (var func in await GetFunctionsAsync())
        {
            table.AddCell(func.Name);
            table.AddCell(func.Description);
            table.AddCell(func.Arguments);
            table.AddCell(func.ResultType);
        }

        document.Add(table);
    }
    return outputPath;
}
```

### Integration Steps
1. Install NuGet packages
2. Handle AGPL licensing requirements
3. Rewrite DatabaseDocumentationService with iText7 API

---

## Solution 5: Server-Side PDF Generation

**Architecture**: Offload PDF generation to backend service

### Pros
- Use any PDF library on server (no mobile constraints)
- Better performance (server resources)
- Centralized PDF generation logic
- Version updates easier

### Cons
- Requires network connectivity
- Additional backend infrastructure
- Not suitable for offline scenarios
- Adds latency

### Implementation
1. Create ASP.NET Core API endpoint: `/api/database-documentation/pdf`
2. Use QuestPDF 2024.x on server (Windows/Linux support)
3. MAUI app calls API and downloads PDF
4. Cache PDFs on device for offline viewing

---

## Recommendation Matrix

| Requirement | Recommended Solution |
|------------|---------------------|
| **Minimal changes, quick fix** | ✅ QuestPDF 2023.12.6 (current) |
| **Long-term support, budget available** | Syncfusion PDF |
| **Free, open source, future-proof** | PdfSharp.Maui (if view-based OK) |
| **Enterprise features needed** | iText7 (if AGPL acceptable) |
| **Offline not required** | Server-side generation |

---

## Current Implementation: QuestPDF 2023.12.6

### Verification Steps
1. Clean and rebuild project: `dotnet clean && dotnet build`
2. Test PDF generation on MacCatalyst
3. Monitor for initialization exceptions
4. Verify font rendering

### Expected Outcome
- No TypeInitializationException
- Successful QuestPDF.Settings initialization
- PDF generation works on MacCatalyst and Windows

### If Issues Persist
1. Check inner exception details: wrap initialization in try-catch with full exception logging
2. Verify SkiaSharp version compatibility (should be handled by QuestPDF 2023.12.6)
3. Consider Solution 2 (Syncfusion) or Solution 5 (Server-side) as fallback

---

## Migration Path to Future Solutions

If QuestPDF 2023.12.6 becomes problematic (security, features, etc.):

### Short-term (3-6 months)
Continue with QuestPDF 2023.12.6, monitor for critical issues

### Medium-term (6-12 months)
Evaluate:
- Syncfusion PDF (if budget approved)
- Server-side generation (if always-online acceptable)

### Long-term (12+ months)
Watch for:
- QuestPDF team re-adding MAUI support
- PdfSharp.Maui maturity improvements
- New MAUI-native PDF libraries

---

## Additional Notes

### Package Version Constraints
- QuestPDF 2023.12.6 compatible with SkiaSharp 2.88.x
- Current project uses SkiaSharp 2.88.8 (compatible)
- No additional version conflicts expected

### Testing Checklist
- [ ] MacCatalyst (Debug mode)
- [ ] MacCatalyst (Release mode)
- [ ] Windows target (when enabled)
- [ ] Font rendering quality
- [ ] Table layout correctness
- [ ] File system permissions
- [ ] PDF viewer compatibility

---

**Last Updated**: January 11, 2026
**Author**: Technical Analysis for GestioneViaggi MAUI Project
