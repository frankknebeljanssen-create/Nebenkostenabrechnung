// Realistic example data for NebenkostenApp
// Bahnhofstr. 37, 12207 Berlin — 3 Einheiten

const OBJEKT = {
  id: 'bhf37',
  address: 'Bahnhofstr. 37',
  city: '12207 Berlin',
  period: '01.01.2025 – 31.12.2025',
  periodShort: '2025',
  totalSqm: 284,
};

const UNITS = [
  {
    id: 'kg', scope: 'kg', label: 'KG Gewerbe',
    short: 'KG', longLabel: 'Kellergeschoss · Gewerbe',
    tenant: 'Büro Wagner & Söhne GmbH',
    tenantShort: 'Wagner GmbH',
    sqm: 62, persons: 2,
    vorauszahlung: 180.00,
    vorauszahlungMonths: 12,
    moveIn: '01.05.2021',
  },
  {
    id: 'eg', scope: 'eg', label: 'EG Wohnung',
    short: 'EG', longLabel: 'Erdgeschoss · Wohnung',
    tenant: 'Heike & Martin Lehmann',
    tenantShort: 'Lehmann',
    sqm: 94, persons: 2,
    vorauszahlung: 215.00,
    vorauszahlungMonths: 12,
    moveIn: '01.09.2019',
  },
  {
    id: 'og', scope: 'og', label: 'OG Wohnung',
    short: 'OG', longLabel: 'Obergeschoss · Wohnung',
    tenant: 'Familie Pfaffenbach',
    tenantShort: 'Pfaffenbach',
    sqm: 128, persons: 4,
    vorauszahlung: 290.00,
    vorauszahlungMonths: 12,
    moveIn: '15.03.2022',
  },
];

const METERS = [
  // Wärme / Heizung
  { id: 'm1', medium: 'Wärme', type: 'Wärmemengenzähler zentral', location: 'Heizraum KG', unit_scope: 'objekt', 
    numStart: '382.471', numEnd: '417.892', unitMeas: 'kWh', 
    dateStart: '02.01.2025', dateEnd: '30.12.2025', statusStart: 'ok', statusEnd: 'ok' },
  
  // Warmwasser
  { id: 'm2', medium: 'Warmwasser', type: 'WW-Zähler', location: 'KG Gewerbe', unit_scope: 'kg',
    numStart: '128,4', numEnd: '142,7', unitMeas: 'm³',
    dateStart: '02.01.2025', dateEnd: '30.12.2025', statusStart: 'ok', statusEnd: 'ok' },
  { id: 'm3', medium: 'Warmwasser', type: 'WW-Zähler', location: 'EG Wohnung', unit_scope: 'eg',
    numStart: '256,8', numEnd: '291,3', unitMeas: 'm³',
    dateStart: '02.01.2025', dateEnd: '30.12.2025', statusStart: 'ok', statusEnd: 'ok' },
  { id: 'm4', medium: 'Warmwasser', type: 'WW-Zähler', location: 'OG Wohnung', unit_scope: 'og',
    numStart: '384,1', numEnd: '436,7', unitMeas: 'm³',
    dateStart: '02.01.2025', dateEnd: null, statusStart: 'ok', statusEnd: 'missing' },
  
  // Kaltwasser
  { id: 'm5', medium: 'Kaltwasser', type: 'KW-Zähler', location: 'KG Gewerbe', unit_scope: 'kg',
    numStart: '312,5', numEnd: '339,8', unitMeas: 'm³',
    dateStart: '02.01.2025', dateEnd: '30.12.2025', statusStart: 'ok', statusEnd: 'ok' },
  { id: 'm6', medium: 'Kaltwasser', type: 'KW-Zähler', location: 'EG Wohnung', unit_scope: 'eg',
    numStart: '487,2', numEnd: '561,4', unitMeas: 'm³',
    dateStart: '02.01.2025', dateEnd: '30.12.2025', statusStart: 'ok', statusEnd: 'ok' },
  { id: 'm7', medium: 'Kaltwasser', type: 'KW-Zähler', location: 'OG Wohnung', unit_scope: 'og',
    numStart: '712,9', numEnd: '821,5', unitMeas: 'm³',
    dateStart: '02.01.2025', dateEnd: null, statusStart: 'ok', statusEnd: 'missing' },
  { id: 'm8', medium: 'Kaltwasser', type: 'Hauptzähler', location: 'KG Technikraum', unit_scope: 'objekt',
    numStart: '4.812,6', numEnd: '5.023,9', unitMeas: 'm³',
    dateStart: '02.01.2025', dateEnd: '30.12.2025', statusStart: 'ok', statusEnd: 'ok' },
  
  // Allgemeinstrom
  { id: 'm9', medium: 'Allgemeinstrom', type: 'Stromzähler Treppenhaus', location: 'Flur EG', unit_scope: 'objekt',
    numStart: '8.231', numEnd: '9.147', unitMeas: 'kWh',
    dateStart: '02.01.2025', dateEnd: '30.12.2025', statusStart: 'ok', statusEnd: 'ok' },
];

// Rechnungen — grouped by BetrKV Kostenart
const BILLS = [
  // Heizung & WW (§2 Nr. 4 BetrKV)
  { id: 'r1', issuer: 'GASAG AG', category: 'Heizung & Warmwasser',
    amount: 4127.84, date: '18.01.2026', period: '01.01.2025 – 31.12.2025',
    umlage: 'ok', confidence: 'validated', scope: 'objekt', docNr: 'GA-2025-9847123' },
  
  // Wasser & Entwässerung
  { id: 'r2', issuer: 'Berliner Wasserbetriebe', category: 'Wasser & Entwässerung',
    amount: 1842.17, date: '12.02.2026', period: '01.01.2025 – 31.12.2025',
    umlage: 'ok', confidence: 'validated', scope: 'objekt', docNr: 'BWB-74-918277' },
  
  // Müllabfuhr
  { id: 'r3', issuer: 'BSR Berliner Stadtreinigung', category: 'Müllabfuhr',
    amount: 687.20, date: '08.03.2025', period: '01.01.2025 – 31.12.2025',
    umlage: 'ok', confidence: 'validated', scope: 'objekt', docNr: 'BSR-2025-Q1' },
  { id: 'r3b', issuer: 'BSR Berliner Stadtreinigung', category: 'Müllabfuhr',
    amount: 687.20, date: '07.09.2025', period: '01.07.2025 – 31.12.2025',
    umlage: 'ok', confidence: 'suggested', scope: 'objekt', docNr: 'BSR-2025-Q3' },
  
  // Grundsteuer
  { id: 'r4', issuer: 'Finanzamt Steglitz', category: 'Grundsteuer',
    amount: 1284.00, date: '15.02.2025', period: '01.01.2025 – 31.12.2025',
    umlage: 'ok', confidence: 'validated', scope: 'objekt', docNr: 'FA-St-2025-Grdst' },
  
  // Gebäudeversicherung
  { id: 'r5', issuer: 'Allianz Versicherungs-AG', category: 'Gebäudeversicherung',
    amount: 892.44, date: '03.01.2025', period: '01.01.2025 – 31.12.2025',
    umlage: 'ok', confidence: 'validated', scope: 'objekt', docNr: 'V-2025-887-441' },
  
  // Schornsteinfeger
  { id: 'r6', issuer: 'Bezirksschornsteinfeger Klemm', category: 'Schornsteinfeger',
    amount: 142.80, date: '22.04.2025', period: '2025',
    umlage: 'ok', confidence: 'validated', scope: 'objekt', docNr: 'Klemm-2025-04' },
  
  // Hausreinigung
  { id: 'r7', issuer: 'Reinigung Yıldız', category: 'Hausreinigung & Gartenpflege',
    amount: 1440.00, date: '31.12.2025', period: '01.01.2025 – 31.12.2025',
    umlage: 'ok', confidence: 'validated', scope: 'objekt', docNr: 'RY-2025-Jahr' },
  
  // Allgemeinstrom
  { id: 'r8', issuer: 'Vattenfall Europe Sales', category: 'Allgemeinstrom',
    amount: 312.47, date: '28.01.2026', period: '01.01.2025 – 31.12.2025',
    umlage: 'ok', confidence: 'suggested', scope: 'objekt', docNr: 'VF-2025-4471' },
  
  // Nicht umlagefähig
  { id: 'r9', issuer: 'Dachdeckerei Schmidt', category: 'Reparatur (nicht umlagefähig)',
    amount: 1847.00, date: '14.08.2025', period: '08.2025',
    umlage: 'no', confidence: 'validated', scope: 'objekt', docNr: 'DS-2025-Aug' },
  
  { id: 'r10', issuer: 'Hausmeisterservice Özdemir', category: 'Hauswart',
    amount: 2160.00, date: '31.12.2025', period: '01.01.2025 – 31.12.2025',
    umlage: 'ok', confidence: 'validated', scope: 'objekt', docNr: 'HÖ-Jahr-2025' },
];

const BETRKV_ORDER = [
  'Heizung & Warmwasser',
  'Wasser & Entwässerung',
  'Müllabfuhr',
  'Grundsteuer',
  'Gebäudeversicherung',
  'Schornsteinfeger',
  'Hausreinigung & Gartenpflege',
  'Hauswart',
  'Allgemeinstrom',
  'Reparatur (nicht umlagefähig)',
];

// Documents (scanned)
const DOCS = [
  { id: 'd1', fileName: 'GASAG_Jahresrechnung_2025.pdf', date: '18.01.2026', month: '2026-01',
    type: 'Rechnung', linkedBill: 'r1', status: 'validated', pages: 4,
    confidence: { issuer: 0.98, amount: 0.99, period: 0.95, date: 0.97 } },
  { id: 'd2', fileName: 'BWB_Jahresabrechnung.pdf', date: '12.02.2026', month: '2026-02',
    type: 'Rechnung', linkedBill: 'r2', status: 'validated', pages: 3,
    confidence: { issuer: 0.96, amount: 0.98, period: 0.91, date: 0.99 } },
  { id: 'd3', fileName: 'BSR_Q3_2025.pdf', date: '07.09.2025', month: '2025-09',
    type: 'Rechnung', linkedBill: 'r3b', status: 'suggested', pages: 2,
    confidence: { issuer: 0.88, amount: 0.94, period: 0.58, date: 0.91 } },
  { id: 'd4', fileName: 'Vattenfall_2025.pdf', date: '28.01.2026', month: '2026-01',
    type: 'Rechnung', linkedBill: 'r8', status: 'suggested', pages: 2,
    confidence: { issuer: 0.92, amount: 0.86, period: 0.79, date: 0.94 } },
  { id: 'd5', fileName: 'Allianz_Gebäude_2025.pdf', date: '03.01.2025', month: '2025-01',
    type: 'Rechnung', linkedBill: 'r5', status: 'validated', pages: 2,
    confidence: { issuer: 0.99, amount: 0.97, period: 0.92, date: 0.98 } },
  { id: 'd6', fileName: 'IMG_4471.jpg', date: '14.10.2025', month: '2025-10',
    type: 'Unbekannt', linkedBill: null, status: 'raw', pages: 1,
    confidence: {} },
];

// Completeness checks for Objekt-Scope Abrechnung 2025
const COMPLETENESS = [
  { id: 'c1', label: 'Anfangsstände aller Zähler erfasst', status: 'ok', 
    group: 'Zähler', detail: '9 von 9 Zählern' },
  { id: 'c2', label: 'Endstände aller Zähler erfasst', status: 'error',
    group: 'Zähler', detail: '7 von 9 — Warmwasser OG und Kaltwasser OG fehlen',
    link: { tab: 'meters' } },
  { id: 'c3', label: 'GASAG Jahresrechnung 2025', status: 'ok',
    group: 'Rechnungen', detail: '4.127,84 € validiert' },
  { id: 'c4', label: 'BWB Jahresabrechnung 2025', status: 'ok',
    group: 'Rechnungen', detail: '1.842,17 € validiert' },
  { id: 'c5', label: 'BSR Abrechnung Q3 ausstehend', status: 'warn',
    group: 'Rechnungen', detail: 'AI-Vorschlag nicht validiert',
    link: { tab: 'docs' } },
  { id: 'c6', label: 'Vattenfall Allgemeinstrom 2025', status: 'warn',
    group: 'Rechnungen', detail: 'AI-Vorschlag nicht validiert',
    link: { tab: 'docs' } },
  { id: 'c7', label: 'Grundsteuer-Bescheid 2025', status: 'ok',
    group: 'Rechnungen', detail: '1.284,00 € validiert' },
  { id: 'c8', label: 'Mietverträge aller Einheiten', status: 'ok',
    group: 'Stammdaten', detail: '3 von 3 hinterlegt' },
  { id: 'c9', label: 'Vorauszahlungen aller Mieter', status: 'ok',
    group: 'Stammdaten', detail: '3 von 3 erfasst' },
  { id: 'c10', label: 'Umlageschlüssel für alle Kostenarten', status: 'ok',
    group: 'Stammdaten', detail: '10 von 10 Kostenarten zugeordnet' },
];

// Computed Abrechnung for OG Pfaffenbach
const ABRECHNUNG_OG = {
  unitId: 'og',
  period: '01.01.2025 – 31.12.2025',
  sqm: 128,
  totalSqm: 284,
  persons: 4,
  totalPersons: 8,
  positions: [
    { label: 'Heizung (§7 HeizkostenV)', schluessel: '70% Verbrauch / 30% Fläche', base: 4127.84, unitShare: 1956.47, method: 'verbrauch' },
    { label: 'Warmwasser (§8 HeizkostenV)', schluessel: '70% Verbrauch / 30% Fläche', base: 0, unitShare: 0, method: 'inkl' },
    { label: 'Kaltwasser & Entwässerung', schluessel: 'Verbrauch (m³)', base: 1842.17, unitShare: 834.12, method: 'verbrauch' },
    { label: 'Müllabfuhr', schluessel: 'Personen', base: 1374.40, unitShare: 687.20, method: 'personen' },
    { label: 'Grundsteuer', schluessel: 'Wohnfläche', base: 1284.00, unitShare: 578.70, method: 'flaeche' },
    { label: 'Gebäudeversicherung', schluessel: 'Wohnfläche', base: 892.44, unitShare: 402.21, method: 'flaeche' },
    { label: 'Schornsteinfeger', schluessel: 'Wohnfläche', base: 142.80, unitShare: 64.35, method: 'flaeche' },
    { label: 'Hausreinigung & Gartenpflege', schluessel: 'Wohnfläche', base: 1440.00, unitShare: 648.99, method: 'flaeche' },
    { label: 'Hauswart', schluessel: 'Wohnfläche', base: 2160.00, unitShare: 973.48, method: 'flaeche' },
    { label: 'Allgemeinstrom', schluessel: 'Wohnfläche', base: 312.47, unitShare: 140.83, method: 'flaeche' },
  ],
  vorauszahlung: 3480.00, // 290 × 12
};

Object.assign(window, { 
  OBJEKT, UNITS, METERS, BILLS, BETRKV_ORDER, DOCS, COMPLETENESS, ABRECHNUNG_OG 
});
