'use strict';
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  ImageRun, Footer, AlignmentType, BorderStyle, WidthType, ShadingType,
  PageNumber, PageBreak, LevelFormat, UnderlineType,
} = require('docx');
const fs = require('fs');
const path = require('path');

// ─── Colori (dal logo: blu navy + verde bussola) ───────────────────────────
const C = {
  PRIMARY   : '1B2F55',
  ACCENT    : '27AE60',
  WHITE     : 'FFFFFF',
  LIGHT_GRAY: 'F5F5F5',
  MED_GRAY  : 'CCCCCC',
  DARK_GRAY : '555555',
  WARN_BG   : 'FFF8E1',
  WARN_BORDER: 'E6910A',
  TIP_BG    : 'E8F4FF',
  TIP_BORDER: '1976D2',
  OK_BG     : 'E8F5E9',
  OK_BORDER : '27AE60',
  CODE_BG   : 'F0F0F0',
};

// ─── Dimensioni pagina A4 ──────────────────────────────────────────────────
const PAGE_W      = 11906;
const PAGE_H      = 16838;
const MARGIN_H    = 1020;   // ~1.8 cm
const MARGIN_V    = 1080;   // ~1.9 cm
const CONTENT_W   = PAGE_W - MARGIN_H * 2;  // 9866

// ─── Risorse ──────────────────────────────────────────────────────────────
const BASE    = path.join(__dirname, '..');
const logoData = fs.readFileSync(path.join(BASE, 'wwwroot/images/logo-gestione-viaggi.png'));

// ─── Gestione numerazione dinamica ────────────────────────────────────────
let _numRef = 0;
let _lastWasNum = false;
let _currentNumRef = '';
const numberingConfigs = [];

function newNumList() {
  _numRef++;
  _currentNumRef = `num${_numRef}`;
  _lastWasNum = false;
  numberingConfigs.push({
    reference: _currentNumRef,
    levels: [{
      level: 0, format: LevelFormat.DECIMAL, text: '%1.',
      alignment: AlignmentType.LEFT,
      style: { paragraph: { indent: { left: 520, hanging: 280 } } },
    }],
  });
  return _currentNumRef;
}

function resetNum() { _lastWasNum = false; }

// ─── Helper: parse inline markdown → TextRun[] ────────────────────────────
function parseInline(text, base = {}) {
  text = text.replace(/!\[.*?\]\(img_placeholder\)/g, '').trim();
  if (!text) return [new TextRun({ text: '' })];

  const runs = [];
  const re = /(\*\*[^*]+\*\*|`[^`]+`)/g;
  let last = 0, m;
  while ((m = re.exec(text)) !== null) {
    if (m.index > last) runs.push(new TextRun({ text: text.slice(last, m.index), ...base }));
    const tok = m[0];
    if (tok.startsWith('**')) {
      runs.push(new TextRun({ text: tok.slice(2, -2), bold: true, ...base }));
    } else {
      runs.push(new TextRun({
        text: tok.slice(1, -1),
        font: 'Consolas',
        size: Math.max(16, (base.size || 20) - 2),
        shading: { type: ShadingType.CLEAR, fill: C.CODE_BG },
        ...base, bold: false, italics: false,
      }));
    }
    last = m.index + tok.length;
  }
  if (last < text.length) runs.push(new TextRun({ text: text.slice(last), ...base }));
  return runs.length ? runs : [new TextRun({ text, ...base })];
}

// ─── Helper: callout box ──────────────────────────────────────────────────
function callout(raw, type = 'tip') {
  const cfg = {
    warn: { bg: C.WARN_BG, border: C.WARN_BORDER, pfx: '⚠  ' },
    tip : { bg: C.TIP_BG,  border: C.TIP_BORDER,  pfx: '💡  ' },
    ok  : { bg: C.OK_BG,   border: C.OK_BORDER,   pfx: '✅  ' },
  }[type] || { bg: C.TIP_BG, border: C.TIP_BORDER, pfx: '💡  ' };

  const text = raw.replace(/^[>*\s]*[⚠️✅💡⚠]\s*/u, '').trim();
  resetNum();
  return new Paragraph({
    spacing: { before: 100, after: 100 },
    indent: { left: 160, right: 160 },
    keepLines: true,
    border: { left: { style: BorderStyle.THICK, size: 12, color: cfg.border, space: 8 } },
    shading: { type: ShadingType.CLEAR, fill: cfg.bg },
    children: [
      new TextRun({ text: cfg.pfx, bold: true, size: 18, font: 'Segoe UI' }),
      ...parseInline(text, { size: 18, font: 'Segoe UI' }),
    ],
  });
}

// ─── Helper: banner sezione ───────────────────────────────────────────────
function sectionBanner(num, title, firstPage = false) {
  resetNum();
  return new Paragraph({
    pageBreakBefore: false,
    spacing: { before: firstPage ? 0 : 400, after: 320 },
    keepNext: true,
    shading: { type: ShadingType.CLEAR, fill: C.PRIMARY },
    border: { bottom: { style: BorderStyle.SINGLE, size: 8, color: C.ACCENT, space: 0 } },
    children: [
      new TextRun({ text: `  ${num}  `, bold: true, size: 30, color: C.ACCENT, font: 'Segoe UI' }),
      new TextRun({ text: title, bold: true, size: 30, color: C.WHITE, font: 'Segoe UI' }),
      new TextRun({ text: '  ' }),
    ],
  });
}

// ─── Helper: intestazione sottosezione ───────────────────────────────────
function subHead(title) {
  resetNum();
  return new Paragraph({
    spacing: { before: 280, after: 100 },
    keepNext: true,
    border: { bottom: { style: BorderStyle.SINGLE, size: 2, color: 'DDDDDD', space: 4 } },
    children: [new TextRun({ text: title, bold: true, size: 22, color: C.PRIMARY, font: 'Segoe UI' })],
  });
}

// ─── Helper: paragrafo normale ────────────────────────────────────────────
function para(text, opts = {}) {
  resetNum();
  return new Paragraph({
    spacing: { before: 60, after: 100 },
    keepLines: true,
    children: parseInline(text, { size: 20, font: 'Segoe UI' }),
    ...opts,
  });
}

// ─── Helper: elemento lista numerata (auto-restart per ogni gruppo) ───────
function numItem(text) {
  if (!_lastWasNum) newNumList();
  _lastWasNum = true;
  return new Paragraph({
    spacing: { before: 60, after: 60 },
    keepLines: true,
    numbering: { reference: _currentNumRef, level: 0 },
    children: parseInline(text, { size: 20, font: 'Segoe UI' }),
  });
}

// ─── Helper: elemento lista puntata ──────────────────────────────────────
function bullet(text) {
  resetNum();
  return new Paragraph({
    spacing: { before: 60, after: 60 },
    keepLines: true,
    numbering: { reference: 'bullets', level: 0 },
    children: parseInline(text, { size: 20, font: 'Segoe UI' }),
  });
}

// ─── Helper: blocco codice/URL ────────────────────────────────────────────
function codeBlock(text) {
  resetNum();
  return new Paragraph({
    spacing: { before: 80, after: 80 },
    indent: { left: 440 },
    shading: { type: ShadingType.CLEAR, fill: C.CODE_BG },
    border: { left: { style: BorderStyle.SINGLE, size: 6, color: C.MED_GRAY, space: 8 } },
    children: [new TextRun({ text, font: 'Consolas', size: 17, color: '333333' })],
  });
}

// ─── Helper: separatore ───────────────────────────────────────────────────
function sep() {
  resetNum();
  return new Paragraph({
    spacing: { before: 80, after: 80 },
    border: { bottom: { style: BorderStyle.SINGLE, size: 1, color: 'E8E8E8', space: 1 } },
    children: [new TextRun({ text: '' })],
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// CONTENUTO DOCUMENTO
// ═══════════════════════════════════════════════════════════════════════════
const ch = [];  // children array

// ──────────────── COPERTINA ───────────────────────────────────────────────
ch.push(
  // Spazio superiore + logo
  new Paragraph({
    spacing: { before: 2000, after: 400 },
    alignment: AlignmentType.CENTER,
    children: [new ImageRun({
      type: 'png', data: logoData,
      transformation: { width: 150, height: 150 },
      altText: { title: 'Logo', description: 'Gestione Viaggi', name: 'logo' },
    })],
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 200, after: 60 },
    children: [new TextRun({ text: 'Gestione Viaggi', bold: true, size: 60, color: C.PRIMARY, font: 'Segoe UI' })],
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 0, after: 40 },
    children: [new TextRun({ text: 'Manuale di Installazione', size: 36, color: C.DARK_GRAY, font: 'Segoe UI' })],
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 0, after: 600 },
    children: [new TextRun({ text: 'per Windows', size: 30, color: C.ACCENT, bold: true, font: 'Segoe UI' })],
  }),
  // Striscia colorata
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 0, after: 0 },
    shading: { type: ShadingType.CLEAR, fill: C.ACCENT },
    children: [new TextRun({ text: '  ', size: 14 })],
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 0, after: 0 },
    shading: { type: ShadingType.CLEAR, fill: C.PRIMARY },
    children: [new TextRun({ text: '  ', size: 10 })],
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 400, after: 60 },
    children: [new TextRun({ text: 'Versione 1.25  ·  Aprile 2026', size: 20, color: C.DARK_GRAY, font: 'Segoe UI' })],
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 0, after: 60 },
    children: [new TextRun({ text: 'Guida per utenti finali — nessuna conoscenza tecnica richiesta', size: 18, italics: true, color: C.DARK_GRAY, font: 'Segoe UI' })],
  }),
  new Paragraph({ children: [new PageBreak()] }),
);

// ──────────────── INDICE ──────────────────────────────────────────────────
resetNum();
ch.push(
  new Paragraph({
    spacing: { before: 0, after: 400 },
    shading: { type: ShadingType.CLEAR, fill: C.PRIMARY },
    border: { bottom: { style: BorderStyle.SINGLE, size: 8, color: C.ACCENT, space: 0 } },
    children: [new TextRun({ text: '  Indice', bold: true, size: 32, color: C.WHITE, font: 'Segoe UI' })],
  })
);

[
  ['1', 'Prima di iniziare — Verifica i requisiti del tuo PC'],
  ['2', 'Passo 1 — Controlla la tua email'],
  ['3', 'Passo 2 — Scarica il file da WeTransfer'],
  ['4', 'Passo 3 — Avvia l\'installazione'],
  ['5', 'Passo 4 — Segui il wizard di installazione'],
  ['6', 'Passo 5 — Primo avvio e accesso'],
  ['7', 'Portale Web Iscrizioni'],
  ['8', 'Risoluzione Problemi'],
  ['',  'Contatti per Assistenza'],
].forEach(([n, t]) => {
  ch.push(new Paragraph({
    spacing: { before: 120, after: 120 },
    children: [
      ...(n ? [new TextRun({ text: `${n}.  `, bold: true, size: 22, color: C.ACCENT, font: 'Segoe UI' })] : [new TextRun({ text: '     ', size: 22 })]),
      new TextRun({ text: t, size: 22, color: C.PRIMARY, font: 'Segoe UI' }),
    ],
  }));
});

ch.push(new Paragraph({ children: [new PageBreak()] }));

// ──────────────── SEZ. 1: VERIFICA REQUISITI ──────────────────────────────
ch.push(sectionBanner('1', 'Prima di iniziare — Verifica i requisiti del tuo PC', true));
ch.push(para('Prima di installare il programma, controlla che il tuo computer soddisfi i requisiti minimi.'));
ch.push(para('**Non preoccuparti: ti spieghiamo come verificarlo passo dopo passo.**'));
ch.push(sep());

// Verifica 1
ch.push(subHead('✅  Verifica 1 — Versione di Windows'));
ch.push(para('Il programma richiede **Windows 10 aggiornato** (versione maggio 2020 o successiva) oppure **Windows 11**.'));
ch.push(para('**Come verificarlo:**'));
ch.push(numItem('Premi i tasti **Windows** + **R** sulla tastiera contemporaneamente *(il tasto Windows è quello con il simbolo della bandiera di Windows, di solito in basso a sinistra)*'));
ch.push(numItem('Si apre una piccola finestra. Digita `winver` e premi **Invio**'));
ch.push(numItem('Appare una finestra con la versione di Windows installata'));
ch.push(para('**Cosa cercare:**'));

// Tabella compatibilità
const brd = { style: BorderStyle.SINGLE, size: 1, color: 'DDDDDD' };
const brds = { top: brd, bottom: brd, left: brd, right: brd };
const cW1 = 6000, cW2 = 3866;
ch.push(new Table({
  width: { size: CONTENT_W, type: WidthType.DXA },
  columnWidths: [cW1, cW2],
  rows: [
    // Header
    new TableRow({ tableHeader: true, children: [
      new TableCell({ borders: brds, width: { size: cW1, type: WidthType.DXA }, shading: { type: ShadingType.CLEAR, fill: C.PRIMARY }, margins: { top: 80, bottom: 80, left: 160, right: 80 }, children: [new Paragraph({ children: [new TextRun({ text: 'Quello che vedi', bold: true, size: 18, color: C.WHITE, font: 'Segoe UI' })] })] }),
      new TableCell({ borders: brds, width: { size: cW2, type: WidthType.DXA }, shading: { type: ShadingType.CLEAR, fill: C.PRIMARY }, margins: { top: 80, bottom: 80, left: 160, right: 80 }, children: [new Paragraph({ children: [new TextRun({ text: 'È compatibile?', bold: true, size: 18, color: C.WHITE, font: 'Segoe UI' })] })] }),
    ]}),
    ...[
      ['Windows 11 (qualsiasi versione)',              '✅  Sì',                               C.OK_BG, ''],
      ['Windows 10, versione 21H1 o successiva',       '✅  Sì',                               C.OK_BG, ''],
      ['Windows 10, versione 2004 o successiva',       '✅  Sì',                               C.OK_BG, ''],
      ['Windows 10, versione 1909 o precedente',       '❌  No — aggiornare Windows prima di procedere', 'FFF0F0', C.PRIMARY],
      ['Windows 8 o Windows 7',                        '❌  No — non supportato',              'FFF0F0', C.PRIMARY],
    ].map(([v, c, bg]) => new TableRow({ children: [
      new TableCell({ borders: brds, width: { size: cW1, type: WidthType.DXA }, shading: { type: ShadingType.CLEAR, fill: 'FAFAFA' }, margins: { top: 60, bottom: 60, left: 160, right: 80 }, children: [new Paragraph({ children: [new TextRun({ text: v, size: 18, font: 'Segoe UI' })] })] }),
      new TableCell({ borders: brds, width: { size: cW2, type: WidthType.DXA }, shading: { type: ShadingType.CLEAR, fill: bg }, margins: { top: 60, bottom: 60, left: 160, right: 80 }, children: [new Paragraph({ children: [new TextRun({ text: c, size: 18, font: 'Segoe UI' })] })] }),
    ]})),
  ],
}));
ch.push(callout('💡 Se non sei sicuro, guarda il numero di build tra parentesi: deve essere **19041 o superiore**.', 'tip'));
ch.push(sep());

// Verifica 2
ch.push(subHead('✅  Verifica 2 — Memoria RAM disponibile'));
ch.push(para('Il programma richiede almeno **4 GB di RAM** (8 GB consigliati).'));
ch.push(para('**Come verificarlo:**'));
ch.push(numItem('Premi i tasti **Ctrl** + **Shift** + **Esc** contemporaneamente *(si apre il Task Manager — il "pannello di controllo" del PC)*'));
ch.push(numItem('Se vedi una finestra piccola con pochi dettagli, clicca su **"Più dettagli"** in basso'));
ch.push(numItem('Clicca sulla scheda **"Prestazioni"**'));
ch.push(numItem('Clicca su **"Memoria"** nel pannello di sinistra'));
ch.push(numItem('In alto a destra vedi la memoria totale, ad esempio **"8,0 GB"**'));
ch.push(callout('✅ Se il numero è 4 GB o superiore, sei a posto.', 'ok'));
ch.push(sep());

// Verifica 3
ch.push(subHead('✅  Verifica 3 — Spazio libero sul disco'));
ch.push(para('Il programma occupa circa **500 MB** sul disco C:.'));
ch.push(para('**Come verificarlo:**'));
ch.push(numItem('Apri **Esplora file** (la cartella gialla nella barra delle applicazioni)'));
ch.push(numItem('Clicca su **"Questo PC"** nel pannello di sinistra'));
ch.push(numItem('Sotto **"Dispositivi e unità"** vedi il disco **C:** con una barra colorata'));
ch.push(numItem('Guarda quanto spazio è indicato come libero'));
ch.push(callout('✅ Se hai almeno **1 GB libero** sul disco C:, sei a posto.', 'ok'));
ch.push(sep());

// Verifica 4
ch.push(subHead('✅  Verifica 4 — Connessione internet'));
ch.push(para('Il programma richiede una connessione internet attiva per funzionare (si connette al database online).'));
ch.push(para('**Come verificarla:** Se stai leggendo questo documento online, la connessione funziona! 😊'));

// ──────────────── SEZ. 2: EMAIL ───────────────────────────────────────────
ch.push(sectionBanner('2', 'Passo 1 — Controlla la tua email'));
ch.push(para('Hai ricevuto un\'email con un link di **WeTransfer** per scaricare il programma di installazione.'));
ch.push(numItem('Apri la tua casella email'));
ch.push(numItem('Cerca un\'email con oggetto simile a **"Gestione Viaggi"** o proveniente dall\'amministratore di sistema'));
ch.push(numItem('Nell\'email trovi un pulsante o link blu per scaricare il file'));
ch.push(callout('⚠️ **Il link WeTransfer scade dopo 3 giorni** dalla ricezione. Se è scaduto, contatta l\'amministratore per ricevere un nuovo link.', 'warn'));
ch.push(callout('⚠️ **Controlla anche la cartella Spam** (posta indesiderata) se non trovi l\'email nella posta in arrivo.', 'warn'));

// ──────────────── SEZ. 3: DOWNLOAD ───────────────────────────────────────
ch.push(sectionBanner('3', 'Passo 2 — Scarica il file da WeTransfer'));
ch.push(numItem('Clicca sul link nell\'email — si apre il sito WeTransfer nel tuo browser'));
ch.push(numItem('Clicca sul pulsante verde **"Download"** (o **"Scarica"**)'));
ch.push(numItem('Se ti viene chiesto dove salvare il file, scegli la cartella **Download** (è la scelta predefinita, va benissimo)'));
ch.push(numItem('Attendi che il download completi. Nella barra in basso del browser vedrai l\'avanzamento del download.'));
ch.push(numItem('Al termine trovi **un solo file** nella cartella Download, chiamato **`GestioneViaggi_Setup_1.25.exe`**'));
ch.push(callout('✅ **Ricevi un unico file `.exe`** — non una cartella, non uno ZIP. È sufficiente questo file per installare tutto il programma.', 'ok'));
ch.push(callout('💡 Per aprire la cartella Download, clicca sulla cartella gialla nella barra delle applicazioni, poi su **"Download"** nel pannello di sinistra.', 'tip'));

// ──────────────── SEZ. 4: AVVIA INSTALLAZIONE ─────────────────────────────
ch.push(sectionBanner('4', 'Passo 3 — Avvia l\'installazione'));
ch.push(numItem('Vai nella cartella **Download**'));
ch.push(numItem('Trova il file **`GestioneViaggi_Setup_1.25.exe`** (ha un\'icona con uno schermo o un ingranaggio)'));
ch.push(numItem('Fai **doppio clic** su questo file per avviare l\'installazione'));
ch.push(subHead('⚠️  Avviso di Windows SmartScreen — cosa fare'));
ch.push(para('È molto probabile che Windows mostri un avviso di sicurezza simile a questo:'));
ch.push(new Paragraph({
  spacing: { before: 100, after: 100 },
  indent: { left: 360, right: 200 },
  shading: { type: ShadingType.CLEAR, fill: 'F8F8F8' },
  border: { left: { style: BorderStyle.SINGLE, size: 6, color: C.MED_GRAY, space: 8 } },
  children: [new TextRun({ text: '"Windows ha protetto il PC — Microsoft Defender SmartScreen ha impedito l\'avvio di un\'app non riconosciuta..."', size: 18, italics: true, color: '555555', font: 'Segoe UI' })],
}));
ch.push(para('**Non preoccuparti: questo è normale** per i programmi nuovi non ancora "conosciuti" da Microsoft. Il programma è sicuro.'));
ch.push(para('**Ecco cosa fare:**'));
ch.push(numItem('Clicca su **"Altre informazioni"** (il testo blu/grigio in piccolo)'));
ch.push(numItem('Appare il pulsante **"Esegui comunque"** — clicca su di esso'));
ch.push(numItem('L\'installazione parte normalmente'));
ch.push(callout('💡 Se invece compare una finestra **"Controllo account utente"** che chiede "Vuoi consentire a questa app di apportare modifiche al dispositivo?", clicca **"Sì"**. È necessario per installare il programma.', 'tip'));

// ──────────────── SEZ. 5: WIZARD ──────────────────────────────────────────
ch.push(sectionBanner('5', 'Passo 4 — Segui il wizard di installazione'));
ch.push(para('Una volta avviato il programma di installazione, appare una serie di schermate guidate (il "wizard"). Seguile nell\'ordine:'));
ch.push(subHead('Schermata 1 — Benvenuto'));
ch.push(para('Clicca **"Avanti"** (o **"Next"**) per iniziare.'));
ch.push(subHead('Schermata 2 — Cartella di installazione'));
ch.push(para('Qui ti viene chiesto dove installare il programma.'));
ch.push(callout('⚠️ **IMPORTANTE**: **Non modificare** la cartella proposta. La cartella di default è `C:\\GestioneViaggi\\` — deve rimanere così. Se la cambi in `C:\\Programmi\\` o `C:\\Program Files\\` il programma **non funzionerà** (schermata nera all\'avvio).', 'warn'));
ch.push(para('Lascia la cartella com\'è e clicca **"Avanti"**.'));
ch.push(subHead('Schermata 3 — Icona sul Desktop'));
ch.push(para('Ti viene chiesto se vuoi creare un\'icona sul desktop. La casella è già spuntata di default — lasciala così e clicca **"Avanti"**.'));
ch.push(subHead('Schermata 4 — Pronto per l\'installazione'));
ch.push(para('Clicca **"Installa"** per avviare la copia dei file.'));
ch.push(subHead('Installazione in corso'));
ch.push(para('Vedrai una barra di avanzamento. Attendi senza chiudere la finestra.'));
ch.push(callout('💡 Se durante l\'installazione compare una finestra per **installare WebView2**, clicca **"Installa"** e attendi. WebView2 è un componente Microsoft necessario per il funzionamento del programma — è gratuito e sicuro.', 'tip'));
ch.push(subHead('Schermata finale — Completato'));
ch.push(para('Clicca **"Fine"**. Il programma si avvia automaticamente.'));

// ──────────────── SEZ. 6: PRIMO AVVIO ────────────────────────────────────
ch.push(sectionBanner('6', 'Passo 5 — Primo avvio e accesso'));
ch.push(para('Al primo avvio appare la schermata di login.'));
ch.push(numItem('Inserisci il **nome utente** fornito dall\'amministratore di sistema'));
ch.push(numItem('Inserisci la **password** fornita dall\'amministratore di sistema'));
ch.push(numItem('Clicca **"Accedi"**'));
ch.push(callout('💡 Le stesse credenziali funzionano anche sulla versione Mac se la utilizzi.', 'tip'));
ch.push(callout('💡 I **documenti PDF** generati dal programma (preventivi, fatture, ecc.) vengono salvati automaticamente nella cartella `C:\\Users\\TuoNome\\Downloads\\` — la stessa cartella dove scarichi i file da internet. Per aprirli è necessario **Adobe Reader** oppure **joPDF**.', 'tip'));
// Banner completato
resetNum();
ch.push(new Paragraph({
  spacing: { before: 300, after: 120 },
  alignment: AlignmentType.CENTER,
  shading: { type: ShadingType.CLEAR, fill: C.ACCENT },
  children: [new TextRun({ text: '  🎉  Installazione completata! Il programma è ora pronto all\'uso.  ', bold: true, size: 22, color: C.WHITE, font: 'Segoe UI' })],
}));

// ──────────────── SEZ. 7: PORTALE WEB ────────────────────────────────────
ch.push(sectionBanner('7', 'Portale Web Iscrizioni'));
ch.push(para('Oltre al programma installato sul PC, esiste anche un **portale web** dove i tuoi clienti possono compilare il modulo di iscrizione direttamente da browser — senza installare nulla.'));
ch.push(subHead('Indirizzo del portale (Azienda Sardegna Fuori Traccia)'));
// URL box
ch.push(new Paragraph({
  spacing: { before: 160, after: 160 },
  alignment: AlignmentType.CENTER,
  shading: { type: ShadingType.CLEAR, fill: C.PRIMARY },
  border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: C.ACCENT }, top: { style: BorderStyle.SINGLE, size: 4, color: C.ACCENT } },
  children: [
    new TextRun({ text: '👉  ', size: 24, font: 'Segoe UI' }),
    new TextRun({ text: 'https://iscrizioni.sardegnafuoritraccia.it/2-976f2734/', bold: true, size: 20, color: C.ACCENT, font: 'Consolas' }),
  ],
}));
ch.push(para('Questo indirizzo funziona su qualsiasi browser (Chrome, Edge, Firefox, Safari) e da qualsiasi dispositivo: PC, tablet, smartphone.'));
ch.push(sep());
ch.push(subHead('⚠️  Se il tuo sito web ha un bottone che rimanda alle iscrizioni'));
ch.push(para('Molti siti aziendali hanno un pulsante del tipo **"Iscriviti"**, **"Prenota"** o **"Compila il modulo"** che porta direttamente alla pagina di iscrizione.'));
ch.push(para('Se quel pulsante rimandava a un vecchio indirizzo, **deve essere aggiornato** con il nuovo link indicato sopra.'));
ch.push(para('**Se gestisci il sito web in autonomia** (hai accesso al pannello di amministrazione del sito):'));
ch.push(numItem('Accedi al pannello del tuo sito (WordPress, Wix, Squarespace, ecc.)'));
ch.push(numItem('Trova il pulsante o il link che porta alle iscrizioni'));
ch.push(numItem('Sostituisci il vecchio indirizzo con il nuovo:'));
ch.push(codeBlock('https://iscrizioni.sardegnafuoritraccia.it/2-976f2734/'));
ch.push(numItem('Salva le modifiche e verifica che il link funzioni correttamente'));
ch.push(para('**Se il sito è gestito da un webmaster o agenzia web:**'));
ch.push(para('Contatta il tuo webmaster **con urgenza** e forniscigli queste informazioni:'));
ch.push(new Paragraph({
  spacing: { before: 120, after: 120 },
  indent: { left: 400, right: 200 },
  shading: { type: ShadingType.CLEAR, fill: 'F8F8F8' },
  border: { left: { style: BorderStyle.SINGLE, size: 6, color: C.MED_GRAY, space: 8 } },
  children: [new TextRun({ text: '"Devo aggiornare il link al modulo di iscrizione sul sito. Il nuovo indirizzo è: https://iscrizioni.sardegnafuoritraccia.it/2-976f2734/ — Puoi aggiornarlo il prima possibile?"', size: 18, italics: true, color: '444444', font: 'Segoe UI' })],
}));
ch.push(callout('⚠️ Finché il link non viene aggiornato, i clienti che cliccano sul vecchio pulsante potrebbero arrivare su una pagina errata o inesistente — le nuove iscrizioni andrebbero perse.', 'warn'));

// ──────────────── SEZ. 8: RISOLUZIONE PROBLEMI ───────────────────────────
ch.push(sectionBanner('8', 'Risoluzione Problemi'));

const problems = [
  { q: 'Non trovo l\'email di WeTransfer', bullets: [
    'Controlla la cartella **Spam** o **Posta indesiderata** della tua email',
    'Il link scade dopo 3 giorni — se è passato più tempo, contatta l\'amministratore',
  ]},
  { q: 'Il download da WeTransfer è molto lento o si interrompe', bullets: [
    'Prova a riavviare il download cliccando di nuovo sul link nell\'email',
    'Assicurati di avere una connessione stabile (evita il Wi-Fi se possibile, usa il cavo di rete)',
    'Se il download si interrompe continuamente, contatta l\'amministratore per ricevere il file in altro modo',
  ]},
  { q: 'Windows mi dice "Windows ha protetto il PC" e non trovo "Esegui comunque"',
    intro: 'Alcuni PC con impostazioni di sicurezza molto restrittive potrebbero bloccare completamente il programma.',
    label: 'Soluzione:', steps: [
      'Nella stessa finestra di avviso, clicca su **"Altre informazioni"**',
      'Se ancora non compare "Esegui comunque", prova a fare clic destro sul file `.exe` → **"Proprietà"**',
      'In fondo alla scheda **"Generale"** cerca la voce **"Sblocca"** e metti la spunta',
      'Clicca **"OK"** e riprova ad aprire il file',
    ],
    footer: 'Se il problema persiste, contatta l\'amministratore di sistema.',
  },
  { q: 'Schermata nera o bianca all\'avvio del programma',
    intro: '**Causa più comune**: il programma è stato installato in una cartella sbagliata (con spazi nel percorso).',
    label: 'Verifica:', steps: [
      'Vai in `C:\\` (il disco principale)',
      'Controlla che esista la cartella `C:\\GestioneViaggi\\`',
      'Se invece trovi il programma in `C:\\Program Files\\` o `C:\\Programmi\\`, disinstallalo e reinstallalo scegliendo la cartella corretta `C:\\GestioneViaggi\\`',
    ],
    label2: 'Come disinstallare:', steps2: [
      'Clicca sul menu **Start** → **Impostazioni** (ingranaggio) → **App**',
      'Cerca **"GestioneViaggi"** nell\'elenco',
      'Cliccaci sopra → **"Disinstalla"**',
      'Poi reinstalla seguendo questo manuale dall\'inizio',
    ],
  },
  { q: 'Errore di connessione al database all\'avvio',
    intro: 'Il programma richiede internet per funzionare. Se compare un errore di connessione:',
    steps: [
      'Verifica di essere connesso a internet (apri un sito qualsiasi nel browser)',
      'Se sei in **ufficio o in azienda**, la rete potrebbe bloccare alcune connessioni. Chiedi al responsabile IT di aprire la **porta 6543** verso Supabase, oppure prova con un hotspot del telefono per verificare se il problema è la rete aziendale',
      'Se la connessione funziona con l\'hotspot ma non con la rete aziendale, contatta l\'amministratore di sistema',
    ],
  },
  { q: 'I PDF generati non si aprono',
    intro: 'Il programma crea i PDF nella cartella Download, ma per aprirli serve un lettore PDF dedicato.',
    label: 'Lettori consigliati:', bullets: [
      '**Adobe Reader** — scaricabile gratuitamente da adobe.com/acrobat/pdf-reader',
      '**joPDF** — scaricabile gratuitamente da jo.my/jopdf',
    ],
    label2: 'Soluzione:', steps: [
      'Installa uno dei lettori consigliati qui sopra',
      'Vai nella cartella Download e fai doppio clic sul file PDF — si aprirà automaticamente con il lettore installato',
      'Se si apre con il programma sbagliato: clic destro sul file → **"Apri con"** → scegli Adobe Reader o joPDF',
    ],
  },
  { q: 'Il programma non si avvia dopo l\'installazione', bullets: [
    'Prova a riavviare il PC e poi ad aprire il programma dall\'icona sul desktop',
    'Verifica che Windows sia aggiornato: Start → Impostazioni → Windows Update → Verifica aggiornamenti',
    'Se il problema persiste, contatta l\'amministratore di sistema',
  ]},
];

problems.forEach((p, i) => {
  if (i > 0) ch.push(sep());
  // Intestazione problema
  ch.push(new Paragraph({
    spacing: { before: 220, after: 100 },
    keepNext: true,
    shading: { type: ShadingType.CLEAR, fill: 'F7F7F7' },
    border: { left: { style: BorderStyle.THICK, size: 10, color: C.WARN_BORDER, space: 8 } },
    children: [new TextRun({ text: '❓  ' + p.q, bold: true, size: 20, color: C.PRIMARY, font: 'Segoe UI' })],
  }));
  resetNum();
  if (p.intro) ch.push(para(p.intro));
  if (p.label) ch.push(para('**' + p.label + '**'));
  if (p.bullets) p.bullets.forEach(b => ch.push(bullet(b)));
  if (p.steps)  p.steps.forEach(s => ch.push(numItem(s)));
  if (p.footer) ch.push(para(p.footer));
  if (p.label2) ch.push(para('**' + p.label2 + '**'));
  if (p.steps2) p.steps2.forEach(s => ch.push(numItem(s)));
});

// ──────────────── CONTATTI ────────────────────────────────────────────────
ch.push(sep());
resetNum();
ch.push(new Paragraph({
  spacing: { before: 300, after: 200 },
  shading: { type: ShadingType.CLEAR, fill: C.PRIMARY },
  border: { bottom: { style: BorderStyle.SINGLE, size: 8, color: C.ACCENT, space: 0 } },
  children: [new TextRun({ text: '  Contatti per Assistenza', bold: true, size: 28, color: C.WHITE, font: 'Segoe UI' })],
}));
ch.push(para('Per qualsiasi problema non risolto con questo manuale, contatta l\'**amministratore di sistema** che ti ha fornito il programma.'));
ch.push(para('Quando lo contatti, cerca di descrivere:'));
ch.push(bullet('Che cosa stavi facendo quando si è verificato il problema'));
ch.push(bullet('Quale messaggio di errore è comparso (se possibile, fai uno screenshot con il tasto **Stamp** o **PrtScn** sulla tastiera)'));
ch.push(bullet('Il tuo sistema operativo (Windows 10 o Windows 11)'));
ch.push(sep());
ch.push(new Paragraph({
  spacing: { before: 200, after: 100 },
  alignment: AlignmentType.CENTER,
  children: [new TextRun({ text: 'Manuale realizzato per Gestione Viaggi v1.25 — Aprile 2026', size: 16, italics: true, color: '888888', font: 'Segoe UI' })],
}));

// ═══════════════════════════════════════════════════════════════════════════
// COSTRUZIONE DOCUMENTO
// ═══════════════════════════════════════════════════════════════════════════
const doc = new Document({
  numbering: {
    config: [
      {
        reference: 'bullets',
        levels: [{ level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 520, hanging: 260 } } } }],
      },
      ...numberingConfigs,
    ],
  },
  styles: {
    default: { document: { run: { font: 'Segoe UI', size: 20, color: '222222' } } },
  },
  sections: [{
    properties: {
      page: {
        size: { width: PAGE_W, height: PAGE_H },
        margin: { top: MARGIN_V, right: MARGIN_H, bottom: MARGIN_V, left: MARGIN_H },
      },
    },
    footers: {
      default: new Footer({
        children: [new Paragraph({
          alignment: AlignmentType.CENTER,
          border: { top: { style: BorderStyle.SINGLE, size: 2, color: 'DDDDDD', space: 4 } },
          children: [
            new TextRun({ text: 'Gestione Viaggi — Manuale di Installazione  |  pag. ', size: 16, color: '999999', font: 'Segoe UI' }),
            new TextRun({ children: [PageNumber.CURRENT], size: 16, color: '999999', font: 'Segoe UI' }),
          ],
        })],
      }),
    },
    children: ch,
  }],
});

const outPath = path.join(BASE, 'Documents/Manuale_Installazione_Utente.docx');
Packer.toBuffer(doc)
  .then(buf => { fs.writeFileSync(outPath, buf); console.log('✅  Creato:', outPath); })
  .catch(err => { console.error('❌  Errore:', err.message); process.exit(1); });
