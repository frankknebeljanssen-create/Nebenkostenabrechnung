# Handoff: NebenkostenApp (iOS)

## Overview

Eine native iOS-App für deutsche Kleinvermieter, die jährliche Nebenkostenabrechnungen für ihre Mieter erstellen. Die App deckt den kompletten Workflow ab: Daten sammeln (Zähler, Rechnungen, Verträge), Belege scannen (OCR + KI-Extraktion mit User-Validierung), gesetzlich korrekte Abrechnung rechnen (BetrKV, §7/§9 HeizkostenV, §556 BGB), und Abrechnungen als PDF ausgeben.

**Zielgruppe:** Privatvermieter mit 1–10 Einheiten, typischerweise 50+ Jahre alt, heute Excel-/Papier-Nutzer.

**Leitprinzipien:**
- Belastbarkeit vor Geschwindigkeit — lieber nichts rechnen als falsch rechnen
- Keine stillen Annahmen, keine Schätzungen der App
- User behält immer die Kontrolle; die KI liefert nur Vorschläge
- Rechtssicherheit vor Bequemlichkeit

---

## About the Design Files

Das beiliegende Bundle enthält einen **HTML/React-Prototyp** als Design-Referenz — **nicht** Produktions-Code zum 1:1-Übernehmen. Der Prototyp zeigt das intendierte Aussehen und Verhalten aller Kern-Screens und Interaktionen. Die eigentliche Aufgabe besteht darin, diese Designs in der **Ziel-Codebasis (SwiftUI / iOS Native)** mit dort etablierten Patterns und Libraries zu implementieren.

Falls noch kein Codebase existiert, ist **SwiftUI (iOS 17+)** die empfohlene Wahl — es matcht die iOS-native Ästhetik des Designs am besten (NavigationStack, sheet-presentation, List, Form, TabView).

---

## Fidelity

**High-fidelity.** Der Prototyp ist pixel-genau mit finalen Farben, Typografie, Spacing und Interaktionen. Entwickler:innen sollten Hex-Werte, Schriftgrößen, Paddings und Status-Logik exakt übernehmen. Einzige Ausnahme: Icons sind im Prototyp stark reduzierte SVGs — in der iOS-App **SF Symbols** verwenden (semantische Mapping-Tabelle unten).

---

## Die zwei Grundmodi: Objekt-Scope und Einheit-Scope

Das ist das zentrale UI-Konzept der App. Nicht wegdesignen.

- **Objekt-Scope** = Gesamtsicht aufs Haus. „Was kostet das Haus? Welche Rechnungen sind da? Sind alle Zähler abgelesen?"
- **Einheit-Scope** = Sicht aus Mieter-Perspektive. „Was zahlt Familie Pfaffenbach? Welche Belege betreffen das OG? Ist ihre Abrechnung fertig?"

**Scope-Wechsel:** Der aktuelle Scope-Name in der Navigation-Bar ist tappbar (Chevron rechts). Tap öffnet ein Sheet mit Objekt + allen Einheiten, jede mit ihrer Kennfarbe.

**Scope-Indikator:** Direkt unter der NavigationBar eine dünne farbige Leiste (32pt hoch). Objekt-Scope zeigt neutrales Slate, jede Einheit ihre Kennfarbe. Leiste zeigt: Farbbalken links, Label („Objekt-Sicht · Alle 3 Einheiten" oder „OG Wohnung · Familie Pfaffenbach"), Swap-Icon rechts.

**Persistenz:** Der gewählte Scope überlebt App-Neustart (UserDefaults / @AppStorage).

---

## Visual Reference

Alle 12 Kern-Screens als Screenshots liegen in `screenshots/`. Dateinamen sind nach den Screen-Nummern unten sortiert:

| # | Screen | File |
|---|---|---|
| 1 | Dashboard · Objekt-Scope | `screenshots/01-dashboard-objekt.jpg` |
| 2 | Dashboard · Einheit-Scope (OG) | `screenshots/02-dashboard-einheit-og.jpg` |
| 3 | Zähler | `screenshots/03-zaehler.jpg` |
| 4 | Rechnungen | `screenshots/04-rechnungen.jpg` |
| 5 | Dokumente | `screenshots/05-dokumente.jpg` |
| 6 | Dokument-Validierung (Sheet) | `screenshots/06-dokument-validierung.jpg` |
| 7 | Abrechnungen-Liste | `screenshots/07-abrechnungen-liste.jpg` |
| 8 | Abrechnung · Detail | `screenshots/08-abrechnung-detail.jpg` |
| 9 | PDF-Vorschau (Sheet) | `screenshots/09-pdf-vorschau.jpg` |
| 10 | Einstellungen | `screenshots/10-einstellungen.jpg` |
| 11 | Scan-Flow (Vollbild) | `screenshots/11-scan-flow.jpg` |
| 12 | Vollständigkeits-Inspektor (Sheet) | `screenshots/12-vollstaendigkeits-inspektor.jpg` |

Die Screenshots sind visueller Truth-Source. Bei Widersprüchen zwischen Prototyp-Code und Screenshot gewinnt der Screenshot.

---

## Screens / Views

### 1. Dashboard — Objekt-Scope

**Purpose:** Startseite. User sieht auf einen Blick, wo die aktuelle Abrechnungsperiode steht.

**Layout (top to bottom, padding 16pt horizontal):**
1. **Periodenkarte** (Card, radius 14pt, background `bgSurface`, 0.5pt border `separator`, padding 14/16pt)
   - Top row: Label „ABRECHNUNGSPERIODE" (12pt, weight 600, `textTertiary`, uppercase, letter-spacing 0.6) links · Jahr „2025" (mono, 11pt, `textSecondary`) rechts
   - Stats row: zwei gleichgroße Blöcke getrennt durch 0.5pt vertical rule
     - StatBlock 1: Label „Umlagefähige Kosten" (11pt, `textTertiary`) · Value fmtEuro(totalCosts) (mono, 19pt, weight 600, letter-spacing -0.3) · Sub „X Rechnungen" (11pt, `textTertiary`)
     - StatBlock 2: „Vorauszahlungen" · fmtEuro(totalVorauszahlung) · „X Einheiten"
   - Divider (0.5pt, marginTop 14)
   - Row: links Label „Validiert & bereit" (13pt, `textSecondary`) + Value „X € ∕ Y €" (mono, 12pt, weight 600, color `statusOk`) · rechts Prozentzahl (mono, 22pt, weight 600)
   - Progress rail: 4pt hoch, radius 2, bg `separator`, fill `statusOk` in Prozentbreite

2. **Offene Punkte** (Section)
   - SectionHeader: „Offene Punkte" (11pt, weight 600, uppercase, letter-spacing 0.6, `textTertiary`) + Button rechts „Alle 10 prüfen →" (12pt, `accent`)
   - Card mit Rows. Jede Row: StatusDot (8pt, color nach Status) + Label (15pt, weight 500) / Detail (12pt, `textSecondary`) + ChevronRight
   - Status: `ok`=grün, `warn`=gelb, `error`=rot, `muted`=grau
   - Tap-Target: Row springt direkt zum relevanten Tab

3. **Einheiten** (Section mit 3 Cards)
   - Jede Card: 4pt farbiger Balken links (Unit-Farbe) · Label „KG Gewerbe" (15pt, weight 600) + „62 m²" (mono, 11pt, `textTertiary`) · Tenant-Short (13pt, `textSecondary`) · Rechts: Vorauszahlung (mono, 14pt, weight 600) + Sub „Vorauszahlung / Monat" (10pt, `textTertiary`)
   - `minWidth: 0` auf Text-Spalte, `flexShrink: 0` auf rechter Spalte, `whiteSpace: nowrap` + ellipsis auf tenantShort — Overlap-Vermeidung ist kritisch

4. **Schnellaktionen** (2×2 Grid, 8pt gap)
   - Primary (accent bg, accentText): „Beleg scannen" (camera icon)
   - „Zählerstand erfassen" (gauge), „Rechnung manuell" (plus), „Abrechnung rechnen" (calc) — alle `bgSurface` mit 0.5pt border

### 2. Dashboard — Einheit-Scope (z. B. OG Pfaffenbach)

**Layout:**
1. **Tenant-Card**: 4pt farbiger Balken links in Unit-Farbe, Tenant-Name (17pt, weight 600), Meta-Zeile „OG Wohnung · 128 m² · 4 Personen" (13pt, `textSecondary`)
2. **Abrechnungs-Status-Karte**: Großer Saldo-Betrag (mono, 28pt, weight 600), color `statusOk` wenn Guthaben, `statusError` wenn Nachzahlung. Label „Guthaben" / „Nachzahlung". Darunter: Vorauszahlung (3.480 €) vs. Ist-Kosten (3.266 €) als zwei Zahlen mit Pfeil.
3. **Fehlende Dokumente** (falls vorhanden): Card mit Rows im gleichen Stil wie Objekt-Scope „Offene Punkte", aber gefiltert nach dieser Einheit
4. **Schnellaktionen**

### 3. Zähler

**Purpose:** Alle Zähler gruppiert nach Medium (Wärme, Warmwasser, Kaltwasser, Allgemeinstrom). Status auf einen Blick.

**Layout:**
- Quick-Action oben: Full-width Button „Endstand für alle offenen erfassen" (`accent` bg, 14pt weight 500, radius 12, padding 12/14)
- Pro Medium-Gruppe: SectionHeader + Card mit Rows
- Jede Zähler-Row: Icon (water/flame/bolt) in soft-bg-circle · Location „Heizraum KG" (15pt weight 500) + Type „Wärmemengenzähler zentral" (12pt, `textSecondary`) · **Zwei Status-Dots rechts**: einer für Anfangsstand, einer für Endstand, jeweils mit Datum darunter (mono, 10pt)
- Tap öffnet Detail (im Prototyp als Sheet, in Production eigener Screen mit Navigation-push)

### 4. Rechnungen

**Purpose:** Alle Rechnungen gruppiert nach BetrKV-Kostenart. Jede Rechnung hat Umlagefähigkeits-Status.

**BetrKV-Reihenfolge (FIX, nicht alphabetisch sortieren):**
1. Heizung & Warmwasser
2. Wasser & Entwässerung
3. Müllabfuhr
4. Grundsteuer
5. Gebäudeversicherung
6. Schornsteinfeger
7. Hausreinigung & Gartenpflege
8. Hauswart
9. Allgemeinstrom
10. Reparatur (nicht umlagefähig) — separate Gruppe, grau

**Layout:**
- Search-Bar oben (iOS-native SearchBar)
- Pro Kostenart: Collapsible Section (Toggle via Tap auf Header). Header zeigt Kostenart + Summe + Anzahl Rechnungen + Chevron.
- Row pro Rechnung: Issuer + Doc-Nr · Datum · Betrag (mono, rechts) · Status-Pill („Validiert"/„KI-Vorschlag"/„Problem")
- Row-Tap öffnet Rechnungs-Detail (Sheet im Prototyp)

### 5. Dokumente (zentraler Screen)

**Purpose:** Alle gescannten Belege, gruppiert nach Jahr/Monat. Dreistufige Validierungs-Logik.

**Liste-View:**
- **Scan-Button** oben: full-width, primary accent, „Beleg scannen" + Sub „Foto → OCR → KI-Extraktion → Validierung" + ChevronRight
- **Legend-Row**: 3 Items in einer Zeile, `space-between`, je `whiteSpace: nowrap` + `flexShrink: 0`: grauer Dot „Roh" · gelber Dot „KI-Vorschlag" · grüner Dot „Validiert"
- Pro Monat: SectionHeader „Januar 2026" + Card mit Doc-Rows
- Doc-Row: Icon-square (bgSurfaceAlt) · Filename + Type · Datum · Status-Pill rechts + Chevron

**Dokument-Detail — 3-Ebenen-Validierung (KRITISCH):**
- **Ebene 1 — Rohdaten:** Collapsed-by-default Accordion. Label „EBENE 1 · ROHDATEN (OCR-VOLLTEXT)" (12pt weight 600 uppercase, `textSecondary`). Expand zeigt monospaced OCR-Text.
- **Ebene 2 — KI-Vorschlag:** Header mit Label „EBENE 2 · KI-VORSCHLAG" (color `statusWarn`). Pro extrahiertem Feld (Issuer, Betrag, Datum, Zeitraum, …): Feld-Label + Value mit **Konfidenz-Indikator** + „Bestätigen"-Tap-Zone
  - Konfidenz ≥ 0.85: gelber Hintergrund `aiSuggestBg`, gelber Border, small text „95%" rechts
  - Konfidenz 0.60–0.85: gelber Hintergrund, Warnhinweis
  - Konfidenz < 0.60: roter Hintergrund `aiLowConfidenceBg`, „Bitte prüfen"-Label
  - Validiert: grüner Hintergrund `aiValidatedBg`, grüner Haken
  - **Tap auf Feld:** Wechselt von gelb → grün. State-Transition muss animiert sein (200ms ease-out).
- **Ebene 3 — Validiert:** Bottom button „Alle Felder bestätigen & einlesen" — enabled wenn alle Felder grün, disabled sonst

### 6. Abrechnungen

**Liste-View:**
- Pro Einheit eine große Card (farbiger Balken 4pt links in Unit-Farbe, padding großzügig)
- Inhalt: Unit-Label + Tenant · Status-Badge („In Arbeit" gelb / „Fertig" grün / „Verschickt" blau) · großer Saldo-Betrag (mono, 24pt)
- Tap öffnet Detail

**Detail-View:**
- Hero-Card: Unit-Info + Tenant + Periode
- Position-Tabelle: Jede Zeile = eine Kostenart. Zeigt: Label (z. B. „Heizung (§7 HeizkostenV)") · Umlageschlüssel („70% Verbrauch / 30% Fläche") · Base-Betrag · Unit-Anteil (mono, right-aligned)
- Divider · Summe Nebenkosten (mono, 18pt weight 600)
- Vorauszahlungen · Saldo (Guthaben/Nachzahlung) prominent in grün oder rot
- Action-Bar unten: „PDF-Vorschau" (Primary) · „Per Mail senden" · „Drucken"

### 7. PDF-Vorschau

Sheet/Modal, zeigt die eigentliche Abrechnungs-PDF in realistischem Papier-Format (A4, 8.5/11 Verhältnis, schlichtes Print-Layout):
- Briefkopf: Vermieter-Adresse
- Empfänger: Mieter-Adresse
- Überschrift: „Nebenkostenabrechnung 2025"
- Tabelle mit Positionen
- Saldo-Zeile
- Gesetzestext-Hinweise klein unten
- Monospace-Zahlen, Serif-Body (Charter / Times)

Action-Bar: „Drucken" / „Per Mail" / „Als PDF speichern"

### 8. Einstellungen

**iOS-native Form/Sections:**
- **Objekt**: Adresse, Abrechnungsperiode, Gesamtwohnfläche, Heizungs-Verbrauchsanteil (70/30 HeizkostenV)
- **Einheiten**: NavigationLink pro Einheit — öffnet Detail mit Tenant, sqm, persons, Vorauszahlung, Vertragsdaten, moveIn
- **Kostenarten & Umlageschlüssel**: Liste aller BetrKV-Positionen mit aktuellem Schlüssel
- **Vermieter-Stammdaten**: Name, Adresse, USt-ID, IBAN
- **Über die App**: Version, DSGVO, Gesetzestexte

### 9. Scope-Picker Sheet

Bottom-Sheet (detents: medium). Zeigt 4 Optionen als Cards:
- „Gesamtes Haus" (Objekt, Slate-Farbe) — Subtitle „Bahnhofstr. 37 · 284 m²"
- Je Einheit eine Card in Unit-Farbe mit Label + Tenant + sqm + persons

Aktueller Scope hat Check-Icon rechts.

### 10. Vollständigkeits-Inspektor Sheet

Globales Sheet, erreichbar über ?-Button im Footer. Listet **alle** Prüfregeln (10 Items, nicht nur die offenen), gruppiert nach Kategorie („Zähler", „Rechnungen", „Stammdaten"). Jede Regel: StatusDot + Label + Detail. Tap → Direktsprung zum Erfassungsort.

### 11. Scan-Flow

Mehrstufiges Sheet:
1. **Kamera-View**: Kamera-Sucher mit Rahmen-Guide („Beleg ins Rechteck positionieren")
2. **OCR-Stage**: Gescanntes Bild mit Loading-Indikator „OCR läuft…" (2s simulation)
3. **KI-Extraktion-Stage**: „KI analysiert Rechnung…" (2s)
4. **Dokumenttyp-Picker**: „Was ist das?" — Segmented: Rechnung · Bescheid · Vertrag · Sonstiges
5. **Optionale Felder**: Kategorie-Zuordnung, manuelle Eingabe falls nötig
6. **Fertig** → springt zu Dokument-Detail mit gelben KI-Vorschlägen

---

## Interactions & Behavior

- **Scope-Wechsel:** Tap auf NavigationBar-Adresse → Bottom-Sheet öffnet (medium detent). Auswahl ersetzt scope, Sheet dismiss. Scope persistent in UserDefaults.
- **TabBar:** 6 Tabs (Dashboard / Zähler / Rechnungen / Dokumente / Abrechnungen / Einstellungen). Mittig im Footer zusätzlich ein „?"-Button der den Vollständigkeits-Inspektor öffnet.
- **Sektion-Toggle (Rechnungen):** Kostenart-Header tap → Chevron rotiert 90°, Rows slide-in (200ms ease-out)
- **Validierung (Dokumente):** Feld-Tap → animierter Farbwechsel gelb → grün (background-color transition 200ms)
- **Scan-Flow:** Sequenzielle Stage-Übergänge mit fade (150ms)
- **PDF-Preview:** Full-screen modal sheet, ScrollView mit A4-Aspect-Ratio

---

## State Management

### Globaler App-State
```
@AppStorage("scope") var scope: String = "objekt"   // "objekt" | "kg" | "eg" | "og"
@AppStorage("activeTab") var activeTab: String = "dashboard"
```

### Feature-State (für die spätere Implementation)
- `Objekt`: Stammdaten (Adresse, Perioden, Gesamtfläche)
- `[Unit]`: je mit tenant, sqm, persons, vorauszahlung, moveIn
- `[Meter]`: zentrale oder einheitbezogene Zähler, numStart/numEnd + Datum + Status
- `[Bill]`: Rechnungen mit amount, category (BetrKV), umlage, confidence, linkedDoc
- `[Document]`: gescannte Belege mit fileName, OCR-raw, KI-extracted fields mit confidences, status
- `Abrechnung(period, unit)`: berechnet aus den obigen Eingabedaten — **Pure Function**, keine gespeicherten Summen
- `[CompletenessCheck]`: Regel-basierte Prüfungen, laufen reaktiv bei Daten-Änderung

### KI-Validierungs-State pro Dokument-Feld
```swift
enum FieldStatus { case raw, suggested(confidence: Double), validated, rejected }
```

---

## Design Tokens

Alle Tokens sind in `assets/tokens.jsx` als Source-of-Truth. Hier die Werte für direkte Übernahme in Swift:

### Colors — Backgrounds
| Token | Hex / Value |
|---|---|
| bgApp | `#F5F1E8` (warm paper) |
| bgAppCompact | `#EFEAE0` |
| bgSurface | `#FBF8F1` (card) |
| bgSurfaceAlt | `#F1ECDF` |
| bgSheet | `#F5F1E8` |
| separator | `rgba(60, 50, 40, 0.12)` |
| separatorStrong | `rgba(60, 50, 40, 0.22)` |

### Colors — Text
| Token | Hex |
|---|---|
| text | `#1F2937` |
| textSecondary | `#5B6472` |
| textTertiary | `#8A8578` |
| textQuaternary | `#B8B0A0` |

### Colors — Accent
| Token | Hex |
|---|---|
| accent | `#4B5563` (muted slate) |
| accentHover | `#3F4852` |
| accentSoft | `rgba(75, 85, 99, 0.12)` |
| accentText | `#FBF8F1` |

**Tweakable Akzent-Varianten** (User hat `blue` gewählt):
- Slate `#4B5563`
- Blue `#3A5578` ← **aktuelle User-Wahl**
- Ink `#2C3E50`

### Colors — Unit Codes (earthy palette)
| Unit | Solid | Soft Background |
|---|---|---|
| KG Gewerbe (Ocker) | `#B08968` | `rgba(176, 137, 104, 0.12)` |
| EG Wohnung (Salbei) | `#7A9070` | `rgba(122, 144, 112, 0.12)` |
| OG Wohnung (Taubenblau) | `#506E8C` | `rgba(80, 110, 140, 0.12)` |
| Objekt (Slate) | `#4B5563` | `rgba(75, 85, 99, 0.10)` |

### Colors — Status
| Token | Hex | Soft-bg |
|---|---|---|
| statusOk (validiert/fertig) | `#3F7A5B` | `rgba(63, 122, 91, 0.14)` |
| statusWarn (in Arbeit/KI-Vorschlag) | `#B8841F` | `rgba(184, 132, 31, 0.15)` |
| statusError (fehlt/Problem) | `#A63D2A` | `rgba(166, 61, 42, 0.12)` |
| statusMuted (nicht relevant/roh) | `#8A8578` | `rgba(138, 133, 120, 0.14)` |

### Typography
- **Sans**: `IBM Plex Sans` (fallback `-apple-system`) — alle UI-Texte
- **Mono**: `IBM Plex Mono` (fallback `SF Mono`) — alle Zahlen, Zählerstände, Euro-Beträge, Doc-Nummern

**Scale (übernehmen in SwiftUI Font-Extensions):**
| Use | Size | Weight | Letter-spacing |
|---|---|---|---|
| Navigation title | 30pt | 600 | -0.6 |
| Navigation title compact | 26pt | 600 | -0.6 |
| Large display (Saldo) | 28pt | 600 | -0.3 |
| StatBlock value | 19pt | 600 | -0.3 |
| Body | 15pt | 400/500/600 | 0 |
| Subtitle | 13pt | 400 | -0.1 |
| Caption | 12pt | 400/500 | 0 |
| Small caption | 11pt | 400/600 | 0 |
| Uppercase label | 12pt | 600 | 0.6, uppercase |
| Micro | 10pt | 400 | 0.2 |

### Spacing
- Card-Padding: `14pt` vertical, `16pt` horizontal
- Screen-Padding: `16pt` horizontal, `130pt` bottom (TabBar-Space)
- Section-Gap: `20pt` zwischen Sections, `10pt` zwischen Header und Content
- Row-Padding: `12–13pt` vertical, `14pt` horizontal

### Radii
- Card: `14pt`
- Small card / Pill: `12pt`
- Legend / Input: `10pt`
- StatusDot: immer perfekter Kreis (`size/2`)

### Borders
- Alle Borders: `0.5pt` (Retina-hairline)
- Color: `separator` token

### Shadows
**Keine.** Design-Direktive: „Keine starken Schatten, keine Gradients-Spielereien."

---

## Icon Mapping — SVG → SF Symbols

Im Prototyp wurden custom-gezeichnete Line-Icons benutzt. In iOS-Production stattdessen SF Symbols:

| Prototyp | SF Symbol |
|---|---|
| home | `house.fill` |
| gauge | `gauge.medium` |
| receipt | `doc.text` |
| doc | `doc` |
| calc | `function` oder `equal.square` |
| settings | `gearshape` |
| camera | `camera` |
| flash | `bolt` |
| info | `info.circle` |
| warn | `exclamationmark.triangle` |
| question | `questionmark.circle` |
| alert | `exclamationmark.circle` |
| mail | `envelope` |
| printer | `printer` |
| download | `arrow.down.to.line` |
| share | `square.and.arrow.up` |
| building | `building.2` |
| user | `person` |
| water | `drop` |
| flame | `flame` |
| bolt | `bolt.fill` |
| trash | `trash` |
| filter | `line.3.horizontal.decrease` |
| refresh | `arrow.clockwise` |
| eye | `eye` |
| pencil | `pencil` |
| swap | `arrow.left.arrow.right` |
| lock | `lock` |
| folder | `folder` |
| calendar | `calendar` |
| check | `checkmark` |
| checkCircle | `checkmark.circle.fill` |
| chevron* | `chevron.{up,down,left,right}` |
| plus | `plus` |
| x | `xmark` |

---

## Formatierung (de-DE)

- Euro: `#.###,## €` (z. B. `4.127,84 €`). Nutze `NumberFormatter` mit `.currency` und `de_DE` Locale.
- Datum: `dd.MM.yyyy` (z. B. `18.01.2026`)
- Perioden: `01.01.2025 – 31.12.2025` (en-dash, nicht minus)
- Prozent: ganze Zahlen für Status (`93%`), Nachkommastellen nur bei Anteilen

---

## Ton

- Deutsch, sachlich, knapp
- Fachbegriffe werden benutzt (Umlage, Abrechnungsperiode, §35a, Heizkostenverordnung) — Zielgruppe kennt sie
- Nie putzig, nie verspielt, **keine Emoji**
- Eher Finanz-/Behörden-Ästhetik als Social-App-Ton

---

## Light vs. Dark Mode

- Light Mode ist **Default** für Zielgruppe 50+
- Dark Mode muss funktionieren, aber ist nicht Prio #1
- Bei Dark: bgApp `#1A1814`, bgSurface `#24221C`, text `#F5F1E8`, Accents bleiben (Unit-Farben brighten +10% L)

---

## Was das Design explizit NICHT ist

- **Kein** Onboarding-Wizard-Look
- **Keine** Gamification (keine Streaks, keine Badges, keine Confetti)
- **Keine** Chat-/AI-Assistant-Optik — die KI arbeitet im Hintergrund, ist kein Gesprächspartner
- **Keine** Marketing-Landingpage-Vibes (keine Hero-Sections, keine Gradients)
- **Kein** Dark-Mode-only

---

## Assets

- **Fonts**: IBM Plex Sans + IBM Plex Mono (Open Font License, Google Fonts / ibm.com/plex). Bei iOS als Custom Fonts im Bundle einbetten oder `UIFont.systemFont` mit `.monospaced` als Fallback.
- **Icons**: SF Symbols (keine Custom-Assets nötig)
- **Imagery**: keine (Design-Direktive — sachlich, keine Stock-Fotos)

---

## Files in this bundle

| File | Beschreibung |
|---|---|
| `README.md` | Dieses Dokument |
| `assets/Nebenkosten Prototyp.html` | Interaktiver Prototyp-Einstiegspunkt |
| `assets/tokens.jsx` | **Source of Truth** für Colors, Typography, Icons |
| `assets/data.jsx` | Realistische Beispieldaten (Bahnhofstr. 37, 3 Einheiten, 10 Rechnungen, 9 Zähler, 6 Dokumente, 10 Prüfregeln) |
| `assets/shell.jsx` | NavBar, ScopeStrip, TabBar, ScopePickerSheet |
| `assets/dashboard.jsx` | Objekt- + Einheit-Scope-Dashboards |
| `assets/meters-bills.jsx` | Zähler-Liste, Rechnungen-Liste mit Sektions-Toggle |
| `assets/docs.jsx` | Dokumente-Liste, 3-Ebenen-Validierungs-Screen |
| `assets/abrechnung-settings.jsx` | Abrechnung-Liste + Detail, Einstellungen |
| `assets/sheets.jsx` | Vollständigkeits-Inspektor, Scan-Flow, PDF-Preview |
| `assets/ios-frame.jsx` | iPhone-Frame-Komponente (nur fürs Prototyping — in Production irrelevant) |
| `screenshots/01-…` bis `12-…jpg` | Screenshots aller Haupt-Screens (visueller Truth-Source) |

### Prototyp lokal laufen lassen

```bash
cd design_handoff_nebenkosten_app/assets
python3 -m http.server 8000
# öffne http://localhost:8000/Nebenkosten Prototyp.html
```

---

## Empfohlene iOS-Implementation

- **iOS 17+** (für neue Charts, Inspector-APIs, NavigationStack)
- **SwiftUI** als primäres UI-Framework
- **Core Data** oder **SwiftData** für lokale Persistenz
- **Vision** (VNRecognizeTextRequest) für OCR
- **Apple Intelligence / OpenAI API** für Feld-Extraktion
- **PDFKit** für PDF-Generierung
- **MessageUI** / ShareSheet für Mail-Versand
- **@AppStorage** für Scope- und Tab-Persistenz
- Typografie: Custom Fonts (IBM Plex) + SF Symbols

Pure-Function-Berechnungslogik in einem separaten Swift-Package (`NebenkostenKit`) — testbar, keine UI-Abhängigkeiten. Alle §7/§9 HeizkostenV- und BetrKV-Regeln dort mit Unit-Tests gegen echte Beispiel-Abrechnungen.

---

## Fragen an Dev-Team

1. Multi-User / iCloud-Sync geplant oder single-device?
2. Export-Formate neben PDF (GoBD-konform, CSV für Steuerberater)?
3. Mietvertrags-Scan auch durch KI oder nur manuelle Eingabe?
4. Offline-first? (Wichtig wegen OCR-Größe; Cloud-OCR vs. on-device Vision)
5. Soll die KI-Extraktion on-device laufen (Apple Intelligence) oder über API? Datenschutz-Implikationen für Rechnungs-Uploads.
