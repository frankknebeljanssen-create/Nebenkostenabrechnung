# NebenkostenApp

Kommerzielle iOS-App für die Nebenkostenabrechnung deutscher Kleinvermieter.

**Ziel:** App Store, Deutschland, iOS 26+, Jahresabo 49-99 €/Jahr.
**Zielgruppe:** Vermieter mit 1-10 Einheiten ohne Hausverwaltung.
**USP:** Mobile-first mit Foto-KI-Extraktion (Rechnungen scannen → Abrechnung generieren).

## Status

**Phase 0 (MVP):** Repo-Gerüst, Datenmodell, Berechnungs-Engine, Tab-Bar-UI,
manuelle Dateneingabe, DSGVO-Compliance, auf Basis realer Daten der
Testimmobilie Bahnhofstr. 37, 12207 Berlin.

## Tech-Stack

- Swift 6.3, strict concurrency
- SwiftUI (iOS 26.3+ Deployment Target, Xcode 26.4.1)
- SwiftData + CloudKit (privater Container pro User)
- Foundation Models Framework (on-device LLM, iOS 26)
- VisionKit `DataScannerViewController` für Dokument-Scans
- AVFoundation + Vision für Zählerstand-Fotos
- PDFKit via WKWebView + HTML-Template (Mustache-Platzhalter)
- StoreKit 2 (Subscription, ab Phase 1)
- Swift Testing (`@Test` macros)

**Kein Backend** außer einem minimalen Cloudflare Worker als Claude-API-Proxy
(Phase 1). CloudKit übernimmt User-Daten, Sync und DSGVO-Infrastruktur.

## Architektur

### Projektstruktur

```
NebenkostenApp/
├── App/              — SwiftUI App-Entry, Root-TabView, Environment
├── Models/           — SwiftData @Model-Klassen (KEINE Business-Logik)
├── Calc/             — Reine Berechnungs-Logik (NUR Foundation)
├── Services/         — CloudKit, KI-Extraktion, PDF, Privacy-Utils
├── Features/
│   ├── Onboarding/   — User-Stammdaten + DSGVO-Zustimmung + erstes Objekt
│   ├── Objekt/       — Tab 1: Dashboard, Mieter, Zähler, Kostenarten
│   ├── Dokumente/    — Tab 2: Scan, Archiv, Suche
│   ├── Abrechnungen/ — Tab 3: Perioden, Erstellung, Versand
│   └── Einstellungen/— Tab 4: Stammdaten, Abo, DSGVO-Export/Löschung
├── Templates/        — HTML-Templates für PDF-Generierung
└── Common/           — Hilfstypen, Formatters, Extensions
```

### Kritische Regel: Calc-Layer ist pur

Die Calc-Layer (`Calc/`) rechnet auf Input-Structs und liefert Output-Structs.
Sie darf NICHTS aus SwiftData, SwiftUI, CloudKit, UIKit oder ähnlichen
Frameworks importieren — nur `Foundation`.

**Warum:** Steuerrechtliche Nachvollziehbarkeit (jeder Rechenschritt
reproduzierbar), 100 % Test-Abdeckung möglich, Portierbarkeit.

```swift
// ❌ NEIN — darf nicht im Calc-Layer sein
import SwiftData
struct HeizkostenRechner {
    let wohneinheit: Wohneinheit  // SwiftData-Typ!
}

// ✅ JA — reine Input-Structs aus Foundation
struct HeizkostenInput {
    let gesamtflaecheM2: Decimal
    let wohneinheitFlaecheM2: Decimal
    let wmzGesamt: Decimal
    let wmzWohneinheit: Decimal
    let gesamtkostenEuro: Decimal
}

struct HeizkostenRechner {
    static func berechne(_ input: HeizkostenInput) -> HeizkostenErgebnis { ... }
}
```

Die Brücke zwischen @Model-Klassen und Calc-Structs baut der Service-Layer
(z.B. `Services/AbrechnungsService.swift`).

---

## UX-Architektur

### Navigation: Tab Bar mit 4 Tabs

Root-Navigation: `TabView` mit vier festen Tabs.

1. **Objekt** — Dashboard des aktuellen Objekts, Hauptarbeitsbereich
2. **Dokumente** — Scan-Zentrale, Dokument-Archiv, Suche über alle Belege
3. **Abrechnungen** — Liste aller Abrechnungsperioden, Erstellung, Versand
4. **Einstellungen** — User-Stammdaten, Abo, DSGVO, Legal

Der Scan-Button ist in Tab 2 prominent und zusätzlich als Schnellzugriff
auf dem Objekt-Dashboard erreichbar.

### Multi-Objekt im MVP

User können bis zu **4 Objekte** anlegen. Der aktuell gewählte Objekt-Kontext
ist permanent sichtbar als **Objekt-Picker oben** in Tab 1 und Tab 3.
Tab 2 (Dokumente) und Tab 4 (Einstellungen) sind objektübergreifend.

Beim Objektwechsel: alle Listen in Tab 1 und Tab 3 wechseln auf den neuen
Objekt-Kontext. Das aktive Objekt wird pro Device in UserDefaults gespeichert
(nicht über CloudKit gesynct — jedes Device kann eigene Ansicht haben).

### Objekt-Dashboard (Tab 1)

Kachelbasiert. Oben: **Completion-Ring** "Abrechnung 2025: 80 %" mit Liste
der Top-3 fehlenden Dinge. Darunter Kacheln:

- **Mieter** (Anzahl, aktive Verträge)
- **Zähler** (letzte Ablesung, offene Stände)
- **Rechnungen** (Anzahl erfasst dieses Jahr, Ampel pro Kostenart)
- **Kostenarten** (aktive Anzahl, Konfiguration)

Jede Kachel zeigt einen Status-Indikator (grün/gelb/rot). Tap öffnet den
Detail-Screen.

### Scan-Workflow

Zwei Scan-Modi, je nach Aufgabe:

**Dokument-Scan** (Rechnungen, Bescheide): VisionKit
`DataScannerViewController` mit `.document` Recognition Type. Multi-Page,
automatische Entzerrung, Kantenerkennung. Ergebnis: PDF (Original) +
erkannter Text.

**Zählerstand-Foto** (Phase 1): Custom AVFoundation-Kamera-View mit
Tap-to-Focus, Long-Press-to-Lock, Pinch-Zoom, Blitz-Toggle, Guide-Rahmen.
Nach Auslösen: Vision Text Recognition auf den Rahmen-Ausschnitt. Foto +
Wert verknüpft gespeichert.

### KI-Extraktion: 4-Stufen-Pipeline

Nach jedem Scan läuft automatisch:

**Stufe 1 — Klassifikation** (Foundation Models, on-device):
Dokumenttyp? Passt zu diesem Objekt? Welche Kostenart? Zeitraum?

**Stufe 2 — Extraktion** (Foundation Models first, Claude API Fallback):
Konkrete Zahlen (Betrag, Lohnanteil, Menge). Lieferant, Rechnungsnummer,
Datum. Claude-Fallback nur bei niedriger Foundation-Models-Konfidenz
oder unbekannten Dokumentformaten.

**Stufe 3 — User-Vorschlag**: Card mit allen Feldern, User bestätigt,
korrigiert oder verwirft. Kein stilles Speichern — erst nach "Bestätigen".

**Stufe 4 — Archiv**: Original als CloudKit Asset in `Rechnung.anhang`,
Extraktion in `Rechnung.extraktionsNotizen`. Auf jeder Abrechnungs-Position
Referenz zurück zum Quelldokument.

### Completion-Tracking

Pro Objekt und pro Abrechnungsperiode:

- Pro Kostenart: Erwartete Inputs definiert (enum-basiert in MVP)
- Status pro Kostenart: grün (alle Inputs da), gelb (teilweise), rot (nichts)
- Gesamt-Completion: Durchschnitt der Kostenart-Status, gewichtet nach
  Betrag-Relevanz

Berechnet in `Services/CompletionService.swift`. User-Konfigurierbarkeit
der Erwartungen: Phase 2.

### Abrechnung erstellen — drei Modi

1. **Final** — nur bei Completion 100 %. Erzeugt offizielle PDFs,
   Periode wird `abgeschlossen`.
2. **Vorschau** — immer möglich. Schätzt Fehlendes, PDF mit rotem
   Watermark "Vorschau — nicht zur Versendung".
3. **Prognose** — Hochrechnung vor Periodenende. Nur Info-Screen, kein PDF.

### Fehlerprüfung — zweischichtig

**Beim Speichern** (Plausibilität, Calc-Layer):
Zählerstand < Vorstand → Warnung. Rechnungsbetrag > 3× historischer
Durchschnitt → Hinweis. Überschneidung mit abgeschlossener Periode →
Fehler. Summe Einheitsflächen > Gesamtfläche → Fehler.

**Beim Abrechnen** (Konsistenz):
Summe WMZ-Einheiten vs. Hauptzähler (Toleranz 5 %). Wasser: Trinkwasser
vs. Verbrauch pro Einheit. Umlage-Summe pro Kostenart 100 %
(Rundungstoleranz 0,01 €).

Fehler blocken nicht zwingend — User kann "trotzdem fortfahren" wählen.
Warnungen werden in der Abrechnung protokolliert.

---

## Scope-Konzept

Die App kennt zwei Scopes — Anzeigeperspektiven, zwischen denen der User
in jedem Tab per Titel-Picker wechseln kann:

- `AbrechnungsScope.objekt` — Gesamt-Objekt-Sicht (Default).
- `AbrechnungsScope.einheit(id: String)` — Sicht einer einzelnen
  Wohneinheit. ID ist die menschenlesbare Bezeichnung ("KG", "EG", "OG").

### Grundsätze

1. **Scope ist reine Anzeige-Ebene, nicht Berechnungs-Ebene.** Der
   AbrechnungsService rechnet immer objektweit. Filter (Zähler,
   Abrechnungen) greifen erst in den Views.
2. **Scope wird App-weit persistiert** (`UserDefaults`-Key
   `currentScope.v1`, `ScopeManager` als `@Observable` injiziert).
3. **Scope-Wechsel ist explizit, nicht implizit.** Das Öffnen einer
   Einheit-Detailansicht (Drill-Down) wechselt nicht automatisch den
   Scope.
4. Bei Objekten mit nur einer Einheit wird der Picker ausgeblendet.
5. Wenn die persistierte Einheit-ID in der aktuellen Immobilie nicht
   (mehr) existiert, setzt `ScopeManager.bereinige(...)` den Scope
   automatisch auf `.objekt` zurück.

### UI-Elemente

- **ScopePickerToolbar** — `ToolbarContent`, das den Navigation-Title
  durch ein tappbares Label ersetzt. Titel-Format:
  - Objekt-Scope: "Gesamtes Objekt"
  - Einheit-Scope: "<ID> · <abgekürzter Mieter>", z.B.
    "OG · Fam. Pfaffenbach" (siehe `ScopeTexte.abkuerzungName`).
- **ScopeIndicatorBar** — 32pt-Leiste direkt unter der NavigationBar,
  mit einheit-spezifischer Farbe (`ScopeFarbe`). Nicht interaktiv.
  Angehängt per `.scopeIndicator(immobilie:)`.

### Filter-Semantik pro View

- Zähler: im Einheit-Scope nur die Einheit-Zähler + Hauptzähler
  (objektweit relevant).
- Rechnungen: alle Rechnungen bleiben sichtbar; pro Zeile wird
  "davon <ID> ca. X,XX €" angezeigt (Flächen-Näherung als
  Orientierungshilfe — kein echter Abrechnungswert).
- Abrechnungen: im Einheit-Scope nur die eine Mieterabrechnung.
- Dashboard-Kacheln: im Einheit-Scope andere Kachel-Garnitur
  (Saldo + Mieter statt Mieter-Zähler-Kostenarten).
- Wohneinheiten-Sektion im Dashboard: nur im Objekt-Scope sichtbar.

### Wiederverwendung

Die reine Filter-Logik liegt in `Core/ScopeFilter.swift` als freie
`static`-Funktionen — Views rufen das als Wrapper auf, Tests treffen
die Funktionen direkt.

---

## Scan-Architektur

Dokumente werden auf drei Wegen in die App gebracht: **Kamera**,
**Mediathek**, **Datei**. Persistierung + Anzeige folgen einem
einheitlichen Pfad — OCR und KI-Extraktion sind davon strikt getrennt
und kommen erst in Task 1.2.

### Grundsatz

Apples `VNDocumentCameraViewController` (VisionKit) macht
Kantenerkennung, Perspektivkorrektur und Multi-Page-Session bereits
stabil. **Ein eigener Kamera-Scanner ist verboten.** Die App liefert
nur SwiftUI-Wrapper (`DokumentScannerView`).

### Entry-Points

Bundle unter `Services/ScanService.swift`:
- `ScanService.kameraScanner(onFertig:)` → `DokumentScannerView`
- `ScanService.mediathekButton(maxAuswahl:, label:)` →
  `GalerieImportButton` (PhotosPicker)
- `.scanDateiImporter(isPresented:, onFertig:)` → `.fileImporter`-
  Modifier für PDFs und Bilder

### Persistierung

- **Alle Dokumente werden als PDF gespeichert.** Kamera-Scans →
  PDF (Multi-Page), Mediathek-Bilder → PDF (auch Einzelbilder),
  Datei-Importe: PDFs 1:1, Bilder → PDF konvertiert.
- Ablage: `Documents/Scans/<YYYY>/<dateiname>.pdf`. Jahres-
  Unterordner wird on demand angelegt.
- Parallel: 300×300-JPG-Thumbnail unter `Documents/Scans/Thumbnails/`.

### Dateinamens-Schema

`DateinameBuilder.build(from: Eingabe)` — deterministisch, rein:

```
YYYY-MM-DD_<Typ>_<Versorger>_<Kontext>[_<Betrag>EUR].pdf
```

Regeln: Umlaute → ae/oe/ue/ss, Whitespace → `_`, Sonderzeichen →
`_`, Doppel-`_` eingedampft. Betrag: `245EUR` / `1234-56EUR` (Punkt/
Komma → Dash). Leere Optional-Felder werden ausgelassen. Fallback
(nur Datum + Typ .sonstiges): `YYYY-MM-DD_Dokument_<UUID-4>.pdf`.
Kollision: 4-Chars-UUID-Suffix.

### Strikte-Daten-Regel im Scan

Im Nach-Scan-Sheet (`DokumentErfassungView`) ist **Dokumenttyp das
einzige Pflichtfeld**. Versorger, Kontext, Betrag, Einheit sind
optional. Die App macht **keine Pre-Fills und keine Vermutungen** —
konsistent zur Abrechnungs-Pre-Flight-Regel.

### Was in Task 1.1 NICHT gemacht wird

- Kein OCR — kommt in 1.2.
- Keine KI-Extraktion — kommt in 1.2.
- Keine automatische Verknüpfung zu Rechnung/Zählerstand — kommt
  separat in 1.2 via `rechnungId` an `GespeichertesDokument`.
- Keine Bild-Nachbearbeitung, kein eigener Kamera-Code.

---

## Datenschutz & DSGVO

### Rollen

- **App-User (Vermieter)** = Verantwortlicher im Sinne der DSGVO
- **Wir (App-Anbieter)** = Auftragsverarbeiter
- **Apple iCloud** = Unterauftragsverarbeiter

### Pflichten im MVP

**Onboarding:**
- Datenschutzerklärung, scrollbar, explizite Zustimmung
- Auftragsverarbeitungsvertrag (AVV), scrollbar, explizite Zustimmung
- Beide Zustimmungen mit Zeitstempel in SwiftData speichern

**Einstellungen-Tab:**
- "Meine Daten exportieren" → ZIP mit SwiftData-JSON + allen PDF-Assets
- "Alle Daten löschen" → zerstört SwiftData + iCloud Container (doppelte
  Bestätigung)
- "Einzelnen Mieter löschen" → pseudonymisiert Mieter in bestehenden
  Abrechnungen, löscht Kontaktdaten. Historie bleibt (§ 257 HGB: 10 Jahre)

### Claude-API-Privacy — Dual-Mode

**Mode A (Default): PII schwärzen vor Claude-Call**
- Foundation Models on-device erkennt Personennamen, Adressen, IBANs,
  Telefonnummern
- Entsprechende Regionen im Bild werden geblurrt
- Nur geblurrtes Bild + geschwärzter Text gehen an Claude
- Langsamer, aber maximaler Schutz

**Mode B (Opt-in in Einstellungen): Volle Dokumente an Claude**
- Schnellere Extraktion, bessere Konfidenz
- UI zeigt pro Scan: "Dieses Dokument wird vollständig an Anthropic (USA)
  übermittelt. Fortfahren?"
- Default-Opt-Out, User muss aktiv einschalten

Implementierung in `Services/ClaudeProxy.swift` als
`PrivacyMode: .geschwaerzt | .vollstaendig`. Bei Mode B wird jeder Call
mit User-Accept-Flag versehen, landet im Audit-Log.

### Claude-API-Nutzung generell

Der Anthropic-API-Key ist **NIEMALS** im App-Binary. Alle Claude-Calls über
Cloudflare Worker Proxy. Proxy-Endpunkt in `Services/ClaudeProxy.swift`.
Auf Device: nur Public-Proxy-URL, kein Token.

**Aufruf-Reihenfolge:**
1. Foundation Models (on-device) zuerst
2. Bei niedriger Konfidenz oder unbekanntem Format: Claude via Proxy
3. Bei Proxy-Fehler: Graceful Fallback auf "manuelle Eingabe"

---

## Gesetzliche Grundlagen

- **BetrKV** (Betriebskostenverordnung): 17 umlagefähige Kostenarten.
  Nicht genannte Kosten sind nicht umlagefähig.
- **HeizkostenV**: Min. 50 %, max. 70 % Verbrauchsanteil. Default: 30/70.
- **§ 35a EStG:** Haushaltsnahe Dienstleistungen (20 % Lohnanteil,
  max. 4.000 €/Jahr) und Handwerkerleistungen (20 %, max. 1.200 €/Jahr)
  separat ausweisen.
- **CO2KostAufG:** Stufenmodell CO₂-Kostenaufteilung.
- **DSGVO:** siehe oben.
- **§ 257 HGB:** Aufbewahrungspflicht 10 Jahre für Handelsunterlagen.

## Swift-Konventionen

- Keine Force-Unwraps (`!`) außer Asset-Zugriffen mit Compiler-Vertrag
- Keine Force-Casts (`as!`)
- Async/await, Combine vermeiden
- Strict Concurrency: public APIs sendable oder `@MainActor`
- Klassen nur wo nötig (SwiftData, Observable Objects), sonst structs
- `Decimal` statt `Double` für Geldbeträge und m²-Werte
- Domain-Terminologie auf Deutsch. Property-Namen camelCase mit deutschem
  Stamm: `wohneinheitFlaecheM2`
- SwiftData: Default-Werte überall, Relationships optional, keine `.unique`

## Testing

Alle Calc-Logik muss Swift-Testing-Coverage haben. Tests verwenden reale
Zahlen aus Bahnhofstr. 37.

```swift
// Skizziertes Beispiel mit ALTER naiver 30/70-API (vor §9-Split-Umbau).
// Die konkreten Zahlen stammen aus der Bahnhofstr. 37, Periode 11/2024–
// 10/2025. wmzWohneinheit = 8_319 kWh ist aus Testdaten-JSON abgeleitet
// (Zählerstand-Differenz 24,741 MWh − 16,422 MWh).
//
// Aktueller Rechner (Task 0.4 v3): konfigurierbarer §9-HeizkostenV-Split
// auf Heizungs- und Warmwasser-Topf, Stromzuschlag, getrennte Neben-
// kosten-Töpfe. Siehe Calc/HeizkostenRechner.swift.

import Testing
@testable import NebenkostenApp

struct HeizkostenRechnerTests {
    @Test("Heizkosten 30/70: realer Fall Bahnhofstr 37 KG (skizziert)")
    func bahnhofstr37_kg() {
        let input = HeizkostenInput(
            gesamtflaecheM2: 528,
            wohneinheitFlaecheM2: 160,
            wmzGesamt: 32_257,
            wmzWohneinheit: 8_319,   // aus Testdaten-JSON abgeleitet
            gesamtkostenEuro: 3_554.95
        )
        let ergebnis = HeizkostenRechner.berechne(input)
        #expect(ergebnis.flaechenanteilEuro.gerundet(auf: 2) == 323.18)
        #expect(ergebnis.verbrauchsanteilEuro.gerundet(auf: 2) == 641.77)
        #expect(ergebnis.gesamtEuro.gerundet(auf: 2) == 964.95)
    }
}
```

Referenzdaten in `Testdaten/Bahnhofstr37_2025.json`.

## Was NICHT zum MVP gehört

- Mieter-Portal / Mieter-Login (**Phase 3**)
- Mietverwaltung: Staffelmieten, Kündigungsfristen (**Phase 2+**)
- Android / Web (niemals geplant, iOS-only)
- Mehrere User pro Apple-ID (SwiftData + privater CloudKit = 1 User)
- Zählerstand-Foto mit Custom-Kamera (**Phase 1**)
- Vollwertige KI-Extraktion via Scan (**Phase 1** — MVP: manuelle Eingabe)
- StoreKit 2 Subscription-Fluss aktiv (**Phase 1** — Architektur steht,
  aber während Beta Vollzugriff)

## CloudKit-Regeln

- Keine Unique-Constraints auf @Model-Properties
- Alle Relationships optional
- Alle Properties haben Default-Werte
- Schema-Migrationen nur additiv
- Große Binärdaten als `@Attribute(.externalStorage) var foo: Data?`

## Claude Code Arbeitsweise

- Bei jeder neuen Kostenart-Logik: erst Test mit realen Zahlen aus
  Bahnhofstr. 37 schreiben, dann Implementierung.
- Bei UI: kein Premature Polishing. Erst funktionaler Fluss, dann Polish.
- Bei Schema-Änderungen: CloudKit-Kompatibilität prüfen, auf echtem Gerät
  testen (Simulator reicht für CloudKit nicht).
- Bei rechtlichen Feinheiten: niemals raten. Nachfragen oder Gesetzestext
  zitieren.
- Privacy: In Logs niemals Mieter-Namen, Adressen oder Beträge.
  `os_log`-Levels: `.debug` für Dev, `.info` höchstens für Counters.
- Nach jeder abgeschlossenen Task: commit mit Conventional Commits Format
  (`feat:`, `fix:`, `refactor:`, `test:`), Subject auf Deutsch.
