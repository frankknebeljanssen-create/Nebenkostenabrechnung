// Design tokens for NebenkostenApp
// Warm-professional: gedecktes Blau mit Papier-Ton

const TOKENS = {
  // Backgrounds
  bgApp: '#F5F1E8',         // warm paper off-white
  bgAppCompact: '#EFEAE0',
  bgSurface: '#FBF8F1',     // card surface
  bgSurfaceAlt: '#F1ECDF',  // secondary surface
  bgSheet: '#F5F1E8',
  separator: 'rgba(60, 50, 40, 0.12)',
  separatorStrong: 'rgba(60, 50, 40, 0.22)',
  
  // Text
  text: '#1F2937',
  textSecondary: '#5B6472',
  textTertiary: '#8A8578',
  textQuaternary: '#B8B0A0',
  
  // Primary accent — muted slate
  accent: '#4B5563',
  accentHover: '#3F4852',
  accentSoft: 'rgba(75, 85, 99, 0.12)',
  accentText: '#FBF8F1',
  
  // Unit colors (palette #3 — earthy)
  unitKG: '#B08968',      // KG Gewerbe — ocker
  unitEG: '#7A9070',      // EG Wohnung — grün
  unitOG: '#506E8C',      // OG Wohnung — blau
  unitObjekt: '#4B5563',  // Objekt scope — neutral slate
  
  // Soft backgrounds for unit tints
  unitKGSoft: 'rgba(176, 137, 104, 0.12)',
  unitEGSoft: 'rgba(122, 144, 112, 0.12)',
  unitOGSoft: 'rgba(80, 110, 140, 0.12)',
  unitObjektSoft: 'rgba(75, 85, 99, 0.10)',
  
  // Status
  statusOk: '#3F7A5B',      // validated / complete
  statusOkSoft: 'rgba(63, 122, 91, 0.14)',
  statusWarn: '#B8841F',    // in progress / pending
  statusWarnSoft: 'rgba(184, 132, 31, 0.15)',
  statusError: '#A63D2A',   // missing / problem
  statusErrorSoft: 'rgba(166, 61, 42, 0.12)',
  statusMuted: '#8A8578',   // not relevant
  statusMutedSoft: 'rgba(138, 133, 120, 0.14)',
  
  // AI suggestion states
  aiRaw: '#8A8578',
  aiSuggest: '#B8841F',
  aiSuggestBg: 'rgba(184, 132, 31, 0.10)',
  aiValidated: '#3F7A5B',
  aiValidatedBg: 'rgba(63, 122, 91, 0.10)',
  aiLowConfidence: '#A63D2A',
  aiLowConfidenceBg: 'rgba(166, 61, 42, 0.10)',
  
  // Typography
  fontSans: '"IBM Plex Sans", -apple-system, system-ui, sans-serif',
  fontMono: '"IBM Plex Mono", ui-monospace, "SF Mono", Menlo, monospace',
};

// Helper: unit color by id
const UNIT_COLOR = {
  objekt: { fg: TOKENS.unitObjekt, soft: TOKENS.unitObjektSoft, label: 'Objekt' },
  kg: { fg: TOKENS.unitKG, soft: TOKENS.unitKGSoft, label: 'KG Gewerbe' },
  eg: { fg: TOKENS.unitEG, soft: TOKENS.unitEGSoft, label: 'EG Wohnung' },
  og: { fg: TOKENS.unitOG, soft: TOKENS.unitOGSoft, label: 'OG Wohnung' },
};

// Format euros (German locale)
const fmtEuro = (n, opts = {}) => {
  const { sign = false, decimals = 2 } = opts;
  const v = Math.abs(n).toLocaleString('de-DE', {
    minimumFractionDigits: decimals, maximumFractionDigits: decimals
  });
  if (sign) return (n >= 0 ? '+' : '−') + ' ' + v + ' €';
  return (n < 0 ? '− ' : '') + v + ' €';
};

const fmtNumber = (n, d = 0) => n.toLocaleString('de-DE', {
  minimumFractionDigits: d, maximumFractionDigits: d
});

// Icon component (outlined line icons)
function Icon({ name, size = 20, color = 'currentColor', stroke = 1.75 }) {
  const paths = {
    home: 'M3 10.5L12 3l9 7.5V20a1 1 0 01-1 1h-5v-7h-6v7H4a1 1 0 01-1-1v-9.5z',
    gauge: 'M3 12a9 9 0 1118 0M12 12l4-3M12 17v2M7 17v2M17 17v2',
    receipt: 'M5 3h14v18l-3-2-3 2-3-2-3 2-2-1.5V3zM8 8h8M8 12h8M8 16h5',
    doc: 'M7 3h8l4 4v14H7V3zM15 3v4h4',
    calc: 'M5 3h14v18H5V3zM8 7h8M8 11h2M12 11h2M16 11h.01M8 15h2M12 15h2M16 15h.01M8 18h2M12 18h2M16 18h.01',
    settings: 'M12 9a3 3 0 100 6 3 3 0 000-6zM19.4 15l1.6-2.5-1.6-2.5-2.8.4-1.8-2.2L14 5h-4l-.8 3.2-1.8 2.2-2.8-.4L3 12.5 4.6 15l-.4 2.8 2.2 1.8L7 23h4l.8-2.4 1.8-2.2 2.8.4',
    chevronDown: 'M5 9l7 7 7-7',
    chevronRight: 'M9 5l7 7-7 7',
    chevronLeft: 'M15 5l-7 7 7 7',
    chevronUp: 'M5 15l7-7 7 7',
    check: 'M5 13l4 4L19 7',
    checkCircle: 'M12 22a10 10 0 100-20 10 10 0 000 20zM8 12l3 3 5-6',
    x: 'M6 6l12 12M18 6l-12 12',
    plus: 'M12 5v14M5 12h14',
    search: 'M11 18a7 7 0 100-14 7 7 0 000 14zM21 21l-4.35-4.35',
    camera: 'M4 8h3l2-2h6l2 2h3a1 1 0 011 1v10a1 1 0 01-1 1H4a1 1 0 01-1-1V9a1 1 0 011-1zM12 17a4 4 0 100-8 4 4 0 000 8z',
    flash: 'M13 2L4 14h7l-1 8 9-12h-7l1-8z',
    info: 'M12 22a10 10 0 100-20 10 10 0 000 20zM12 8v.01M11 12h1v4h1',
    warn: 'M12 3l10 18H2L12 3zM12 10v5M12 18v.01',
    question: 'M12 22a10 10 0 100-20 10 10 0 000 20zM9 9a3 3 0 116 1c0 2-3 2-3 4M12 17v.01',
    alert: 'M12 8v5M12 16v.01M12 22a10 10 0 100-20 10 10 0 000 20z',
    mail: 'M3 7l9 6 9-6M3 7v10a1 1 0 001 1h16a1 1 0 001-1V7M3 7a1 1 0 011-1h16a1 1 0 011 1',
    printer: 'M6 9V3h12v6M6 18H4a1 1 0 01-1-1v-7a1 1 0 011-1h16a1 1 0 011 1v7a1 1 0 01-1 1h-2M6 14h12v7H6v-7z',
    download: 'M12 3v14M5 12l7 7 7-7M4 21h16',
    share: 'M4 12v8a1 1 0 001 1h14a1 1 0 001-1v-8M16 6l-4-4-4 4M12 2v13',
    building: 'M3 21V6l6-3 6 3v15M3 21h18M9 21v-4h3v4M6 9h.01M6 12h.01M6 15h.01M12 9h.01M12 12h.01M15 9v12M15 9h6v12M18 12h.01M18 15h.01M18 18h.01',
    user: 'M12 12a4 4 0 100-8 4 4 0 000 8zM4 21a8 8 0 0116 0',
    water: 'M12 3s6 6 6 11a6 6 0 11-12 0c0-5 6-11 6-11z',
    flame: 'M12 3s4 4 4 9a4 4 0 01-8 0c0-2 1-3 2-4 1 2 2 1 2-1 0-2 0-3 0-4z',
    bolt: 'M13 2L5 14h7l-1 8 9-12h-7l2-8z',
    trash: 'M4 7h16M9 7V4h6v3M6 7v13a1 1 0 001 1h10a1 1 0 001-1V7M10 11v6M14 11v6',
    filter: 'M3 5h18M6 12h12M10 19h4',
    refresh: 'M21 12a9 9 0 11-3-6.7M21 4v5h-5',
    eye: 'M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12zM12 15a3 3 0 100-6 3 3 0 000 6z',
    pencil: 'M4 20h4L20 8l-4-4L4 16v4zM14 6l4 4',
    swap: 'M7 16h14m-4-4l4 4-4 4M17 8H3m4-4L3 8l4 4',
    lock: 'M5 10V7a7 7 0 0114 0v3M4 10h16v11H4z',
    folder: 'M3 6a1 1 0 011-1h5l2 2h9a1 1 0 011 1v11a1 1 0 01-1 1H4a1 1 0 01-1-1V6z',
    calendar: 'M5 5h14v16H5V5zM5 9h14M8 3v4M16 3v4',
    dot: 'M12 12m-3 0a3 3 0 106 0 3 3 0 10-6 0',
  };
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round">
      <path d={paths[name] || paths.dot} />
    </svg>
  );
}

Object.assign(window, { TOKENS, UNIT_COLOR, fmtEuro, fmtNumber, Icon });
