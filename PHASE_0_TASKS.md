# Phase 0 — MVP Task-Liste

Reihenfolge ist wichtig: jede Task baut auf den vorigen auf. Jede Task
ist so geschrieben, dass sie direkt als Prompt an Claude Code gegeben
werden kann.

**Die Phase-0-Tasks teilen sich in vier Phasen:**

- **Phase 0.A — Foundation:** Projekt, Datenmodell, Calc-Layer (Tasks 0.1–0.9)
- **Phase 0.B — Core UI:** Onboarding, Tab-Bar, Dashboard (Tasks 0.10–0.13)
- **Phase 0.C — Feature-Screens:** Daten erfassen und bearbeiten (Tasks 0.14–0.18)
- **Phase 0.D — Compliance & Verifizierung:** DSGVO, Tests, End-to-End (Tasks 0.19–0.22)

---

## PHASE 0.A — Foundation

### 0.1 Xcode-Projekt anlegen

**Ziel:** Kompilierbares leeres iOS-Projekt mit finaler Ordnerstruktur.

Setup:
- Xcode 26.4.1, Swift 6.3
- Template: App, SwiftUI-Lifecycle, Swift Testing
- Deployment Target: iOS 26.3
- Bundle-ID: `com.example.NebenkostenApp` (Platzhalter)
- Capabilities: iCloud (CloudKit-Container + Key-value storage),
  In-App Purchase

Ordnerstruktur im Projekt-Navigator:
```
NebenkostenApp/
├── App/
├── Models/
├── Calc/
├── Services/
├── Features/
│   ├── Onboarding/
│   ├── Objekt/
│   ├── Dokumente/
│   ├── Abrechnungen/
│   └── Einstellungen/
├── Templates/
└── Common/
NebenkostenAppTests/
└── CalcTests/
```

**Akzeptanzkriterium:** App startet im Simulator mit leerem Screen,
Tests laufen durch.

### 0.2 Core Data Models einbauen

`DataModel.swift` und `ModelContainer+App.swift` aus Repo-Root in `Models/`
einfügen. In App-Entry (`NebenkostenAppApp.swift`) Container setzen:

```swift
@main
struct NebenkostenAppApp: App {
    let container: ModelContainer
    init() {
        do { container = try ModelContainer.app() }
        catch { fatalError("ModelContainer: \(error)") }
    }
    var body: some Scene {
        WindowGroup { ContentView().modelContainer(container) }
    }
}
```

In Apple Developer Portal: iCloud-Container
`iCloud.com.example.NebenkostenApp` anlegen.

**Akzeptanzkriterium:** Compile grün, App startet ohne Crash.

### 0.3 Calc-Layer Grundstruktur

Datei `Calc/Basis.swift`, KEIN Import außer Foundation:
- `typealias Euro = Decimal`
- `typealias Flaeche = Decimal`
- `typealias Verbrauch = Decimal`
- Extension `Decimal.gerundet(auf stellen: Int, modus: Rundungsmodus) -> Decimal`
- Enum `Rundungsmodus { case kaufmaennisch, abrunden, aufrunden }`
- Struct `AbrechnungsKontext` (Stammdaten für alle Rechner)

Test `BasisTests.swift` validiert Rundungs-Extension.

**Akzeptanzkriterium:** Test grün, keine Framework-Imports in `Calc/`.

### 0.4 Heizkostenrechner

`Calc/HeizkostenRechner.swift` mit 30/70-Aufteilung (HeizkostenV-konform).

```swift
struct HeizkostenInput {
    let gesamtflaecheM2: Flaeche
    let wohneinheitFlaecheM2: Flaeche
    let wmzGesamt: Verbrauch
    let wmzWohneinheit: Verbrauch
    let gesamtkostenEuro: Euro
    let flaechenanteilProzent: Decimal  // default 30
}

struct HeizkostenErgebnis {
    let flaechenanteilEuro: Euro
    let verbrauchsanteilEuro: Euro
    let gesamtEuro: Euro
    let verteilerschluesselText: String
}
```

`CalcTests/HeizkostenRechnerTests.swift`: drei Tests mit realen Zahlen KG
(160 m²), EG (181 m²), OG (187 m²) aus Bahnhofstr. 37, Periode 11/2024–10/2025.
Referenzwerte aus `2025_NK_Berechnung_Heizung_u_Warmwasser.docx`.

**Akzeptanzkriterium:** Tests grün, Abweichung zu Referenz < 0,01 €.

### 0.5 Wasserkostenrechner

`Calc/WasserkostenRechner.swift`: Trinkwasser + Schmutzwasser inkl.
Gartenzwischenzähler.

Test mit BWB-Realdaten: 434 m³ Trinkwasser, 243 m³ Schmutzwasser (191 m³
Garten-Abzug), 866,74 € Trinkwasser, 561,09 € Schmutzwasser.

**Akzeptanzkriterium:** Mieteranteile stimmen mit User-Excel 2025 überein.

### 0.6 Flächenumlage-Rechner

`Calc/FlaechenRechner.swift`: generische m²-Umlage für Grundsteuer,
Versicherung, BSR.

Test mit 528 Gesamt / 160 KG / 181 EG / 187 OG und Grundsteuer 3.355,89 €.

**Akzeptanzkriterium:** Summe der Anteile = Gesamtbetrag (Toleranz 0,01 €).

### 0.7 Zeitraum-Abgrenzung

`Calc/Zeitraumabgrenzung.swift` — tagesanteilige Kostenverteilung bei
überlappenden Perioden (z.B. BSR-Kalenderjahr vs. NK-Jahr 11/24–10/25).

```swift
static func anteil(
    rechnungVon: Date,
    rechnungBis: Date,
    periodeVon: Date,
    periodeBis: Date,
    gesamtbetrag: Euro
) -> Euro
```

Test mit BSR 2024 + 2025 Bescheiden für NK-Jahr 11/2024–10/2025.

**Akzeptanzkriterium:** Korrekter anteiliger Betrag.

### 0.8 Abrechnungsaggregator

`Calc/AbrechnungsAggregator.swift` — führt alle Einzelrechner zusammen,
erzeugt `[Abrechnungsposition]` pro Wohneinheit.

**Integrationstest:** Komplette KG-Abrechnung Bahnhofstr. 37 für 2025.
Die bestehende User-Excel KG 2025 hat einen Fehler — der Test muss die
KORREKTE Erstattung zeigen (~1.300–1.400 €), nicht die fehlerhafte
935,21 € aus der User-Excel.

**Akzeptanzkriterium:** EG- und OG-Abrechnung stimmen mit User-Excel
überein (< 0,50 €). KG-Abrechnung zeigt korrigierte Werte.

### 0.9 PDF-Template einbinden

`Templates/abrechnung.html` aus Repo-Root als Bundle-Resource.
`Services/PDFGenerator.swift`:
- Nimmt `AbrechnungsErgebnis`
- Lädt Template aus Bundle
- Simple-Mustache-Replacement (kein CocoaPod)
- Rendert via `WKWebView` in iOS 26
- Exportiert als PDF-Data

**Akzeptanzkriterium:** Generiertes PDF für OG-Mieter Pfaffenbach sieht
optisch ähnlich zum User-Vorjahres-PDF aus.

---

## PHASE 0.B — Core UI

### 0.10 Tab-Bar Skeleton

Vier Tabs: Objekt, Dokumente, Abrechnungen, Einstellungen — jeder mit
NavigationStack und Platzhalter-Screen ("Noch nicht implementiert"). App
startet direkt in die Tab-Bar. Onboarding-Gate kommt später (Task 0.13).

**Akzeptanzkriterium:** App startet, alle vier Tabs antippbar, jeder zeigt
den eigenen Platzhalter.

### 0.13 Onboarding mit DSGVO-Zustimmung

`Features/Onboarding/` mit Screen-Sequence:

1. **WillkommenView** — Begrüßung, "Los geht's"-Button
2. **DatenschutzView** — scrollbarer Text (`Common/LegalTexts.swift`
   als Platzhalter, finaler Text später), Checkbox "Ich akzeptiere die
   Datenschutzerklärung", Weiter-Button nur aktiv bei Haken
3. **AvvView** — scrollbarer AVV-Text, Checkbox, Weiter nur bei Haken
4. **UserStammdatenView** — Name, Anschrift, E-Mail, Steuer-ID (opt.),
   Rolle (Privat/Unternehmer), Bank-IBAN (opt.)
5. **ErstesObjektView** — Adresse, Gesamtfläche, Abrechnungsstart
   (Monat + Tag), Heizungsart (enum), Warmwasser-Bereitung (enum)
6. **WohneinheitenView** — 1 bis N Wohneinheiten (Bezeichnung, Fläche,
   Nutzungsart)
7. **FertigView** — "Alles angelegt", Weiterleitung zum Dashboard

Zustimmungen mit Zeitstempel in SwiftData (`User.datenschutzZustimmungAm`,
`User.avvZustimmungAm`).

**Akzeptanzkriterium:** User kann Bahnhofstr. 37 + 3 Einheiten komplett
anlegen. Daten persistieren nach App-Neustart.

### 0.11 Objekt-Dashboard mit Kacheln

`Features/Objekt/ObjektDashboardView.swift`:

Oberer Bereich:
- **Objekt-Picker** (Menu) oben: aktuelles Objekt + "Objekt wechseln" +
  "Neues Objekt"
- **Completion-Ring** (custom `Shape`) mit großer Prozentzahl in der Mitte
- Darunter: Top-3 fehlende Items als kompakte Liste

Kachel-Grid (2 Spalten):
- Mieter-Kachel (Anzahl aktiv / Ampel)
- Zähler-Kachel (Anzahl / letzte Ablesung)
- Rechnungen-Kachel (Anzahl dieses Jahr / Ampel)
- Kostenarten-Kachel (aktive Anzahl)

Jede Kachel ist `NavigationLink` auf die jeweilige Detail-View.

**Akzeptanzkriterium:** Dashboard zeigt echte Zahlen, Tap öffnet Details.

### 0.12 Multi-Objekt-Switcher

Im Objekt-Picker:
- Liste aller Objekte mit Adresse
- Aktuelles Objekt markiert
- "Neues Objekt anlegen" führt durch ErstesObjektView + WohneinheitenView
  aus Onboarding (als Sheet)
- Maximum 4 Objekte (bei Versuch eines 5. Objekts: Info-Sheet
  "Limit erreicht — in Version 1.1 werden mehr Objekte möglich sein")

Aktives Objekt persistiert in `UserDefaults.standard.aktivesObjektID`
(UUID-String), nicht in CloudKit.

**Akzeptanzkriterium:** User kann 2 Objekte anlegen und zwischen ihnen
wechseln, Dashboard-Inhalt wechselt korrekt.

---

## PHASE 0.C — Feature-Screens

### 0.14 Mieter-Verwaltung

`Features/Objekt/Mieter/`:

- **MieterListeView**: alle Mietverhältnisse des aktuellen Objekts,
  gruppiert nach Wohneinheit
- **MieterDetailView**: Name, Anschrift, E-Mail, Einzug/Auszug,
  Vorauszahlung, Personen
- **MieterEditView**: Erstellen / Bearbeiten
- Inline-Validierung (E-Mail-Format, Einzug <= Auszug)

**Akzeptanzkriterium:** 3 Mieter für Bahnhofstr. 37 anlegen
(Knebel-Janßen KG, Janßen EG selbst, Pfaffenbach OG).

### 0.15 Zählerstände manuell

`Features/Objekt/Zaehler/`:

- **ZaehlerListeView**: alle Zähler des Objekts, gruppiert nach Medium
  und Typ (Haupt/Wohnung)
- **ZaehlerDetailView**: Stammdaten + History aller Zählerstände
- **ZaehlerstandEditView**: Ablesedatum + Wert manuell eingeben
- Plausibilität: neuer Stand >= letzter Stand (sonst Warnung)

**Akzeptanzkriterium:** Alle Bahnhofstr.-37-Zähler (3 Strom, 4 Wasser,
3 Warmwasser, 3 WMZ) anlegen mit Ablesungen 10/2024 und 10/2025.

### 0.16 Rechnungen manuell

`Features/Objekt/Rechnungen/`:

- **RechnungListeView**: alle Rechnungen des aktuellen Objekts,
  filterbar nach Kostenart
- **RechnungEditView**: Lieferant, Nummer, Datum, Leistungszeitraum,
  Betrag, Lohnanteil, Kostenart-Zuordnung
- Anhang: PDF-Datei aus Dateimanager importieren (noch KEIN Scan, das
  ist Phase 1)

**Akzeptanzkriterium:** Alle 2025er Rechnungen der Bahnhofstr. 37
eingeben (GASAG, BWB, BSR, Grundsteuer, Allianz, Gartenpflege,
Reinigung, Schornsteinfeger, Wartung).

### 0.17 Completion-Tracking

`Services/CompletionService.swift`:

```swift
struct CompletionService {
    static func statusFuer(
        objekt: Immobilie,
        periode: Abrechnungsperiode
    ) -> CompletionStatus
}

struct CompletionStatus {
    let prozent: Decimal  // 0.0 bis 1.0
    let proKostenart: [UUID: KostenartStatus]
    let fehlendeTop3: [String]  // Beschreibungen
}

enum KostenartStatus { case gruen, gelb, rot }
```

"Erwartete Inputs"-Config: hartkodiert per Kostenart (enum-basiert).
Beispiel: Wasser erwartet 1 Jahresrechnung + N Warmwasser-Zählerstände.

Im Objekt-Dashboard anzeigen.

**Akzeptanzkriterium:** Bei voll ausgefüllter Bahnhofstr.-37-Periode
2025 zeigt Dashboard 100 %. Bei gelöschter Grundsteuer-Rechnung zeigt
es ~92 % mit Hinweis "Grundsteuer fehlt".

### 0.18 Abrechnung erstellen

`Features/Abrechnungen/AbrechnungErstellenFlow.swift`:

Drei Entrypoints aus Abrechnungen-Tab:
- **Final erstellen** — nur aktiv bei 100 % Completion
- **Vorschau** — immer aktiv, PDF mit rotem Watermark
- **Prognose anzeigen** — Info-Screen, kein PDF

Flow:
1. Periode wählen (Default: letzte geschlossene)
2. Modus wählen (Final/Vorschau/Prognose)
3. Für jeden Mieter Abrechnungsposition-Liste erzeugen
   (via `AbrechnungsAggregator`)
4. Preview-Screen mit Mieter-Namen und Saldo-Vorschau
5. Bei "Final": PDF generieren, `versandtAm` nil setzen
6. Versand-Optionen: iOS Share-Sheet (Mail, Messages, Speichern)

**Akzeptanzkriterium:** Kompletter End-to-End-Flow funktioniert für
Bahnhofstr. 37 Pfaffenbach OG 2025.

---

## PHASE 0.D — Compliance & Verifizierung

### 0.19 DSGVO Export und Löschung

`Features/Einstellungen/DSGVOView.swift`:

**Export:**
- Button "Meine Daten exportieren"
- Erzeugt ZIP: `nebenkosten_export_YYYY-MM-DD.zip`
- Inhalt: `daten.json` (alle SwiftData als JSON), `dokumente/` Ordner
  mit allen PDFs und Zählerfotos
- Share-Sheet zum Speichern

**Vollständige Löschung:**
- Button "Alle Daten löschen"
- Erste Bestätigung: Modal mit Warntext
- Zweite Bestätigung: Tippen von "LÖSCHEN" in Textfeld
- Bei OK: alle SwiftData-Inhalte + iCloud Private Database leeren
- App kehrt zurück zum Onboarding

**Mieter-Pseudonymisierung:**
- In MieterDetailView: Button "Mieter DSGVO-löschen"
- Ersetzt Name durch "Gelöscht-[Hash]", Anschrift/E-Mail durch leer
- Abrechnungen bleiben (mit pseudonymisiertem Namen)
- Hinweis im UI: "Historie bleibt wegen § 257 HGB erhalten"

**Akzeptanzkriterium:** Export-ZIP öffnet sich in Files-App, enthält
lesbares JSON. Löschung entfernt alle Daten. Pseudonymisierung
erhält Rechnungsbezug ohne Klarnamen.

### 0.20 Fehlerprüfung

`Calc/Validierung.swift`:

```swift
struct Validierung {
    static func pruefe(_ kontext: AbrechnungsKontext, 
                       daten: AbrechnungsInput) -> [Warnung]
}

struct Warnung {
    let stufe: Stufe  // .hinweis, .warnung, .fehler
    let nachricht: String
    let kostenart: UUID?
}
```

Checks:
- Zählerstand < Vorstand
- Rechnungsbetrag > 3× historischer Durchschnitt
- Überschneidung mit abgeschlossener Periode
- Summe Einheitsflächen > Gesamtfläche
- WMZ-Summe vs. Hauptzähler (Toleranz 5 %)
- Umlage-Summe != Gesamtbetrag (Toleranz 0,01 €)

Im Abrechnen-Flow: Warnungen als Liste vor PDF-Generierung. User
kann "Trotzdem fortfahren" (Fehler protokolliert) oder abbrechen.

**Akzeptanzkriterium:** Bei absichtlich fehlerhaften Eingaben
(z.B. 529 m² statt 528) erscheint Warnung. User kann fortfahren.

### 0.21 CloudKit-Sync verifizieren

Manueller Test auf zwei Geräten mit derselben Apple-ID:
- Gerät A: Immobilie anlegen → Gerät B: sieht sie nach ~30 s
- Gerät B: Mieter hinzufügen → Gerät A: sieht ihn

Edge-Cases:
- Offline-Edit auf A, dann Online-Sync → Konflikt-Resolution OK
- Parallele Edits → Last-write-wins, keine Crashes

**Akzeptanzkriterium:** Basis-Sync funktioniert, Konflikte führen nicht
zu Datenverlust.

### 0.22 End-to-End-Test Bahnhofstr. 37

Vollständiger Fluss, alles in der App:

1. Bahnhofstr. 37 + 3 Einheiten anlegen (oder aus Phase 0.14 übernehmen)
2. 3 Mietverhältnisse anlegen (Phase 0.14)
3. Alle 2025er Rechnungen manuell (Phase 0.16)
4. Zählerstände manuell (Phase 0.15)
5. "Abrechnung erstellen" für OG-Mieter Pfaffenbach (Phase 0.18)
6. PDF öffnet sich

**Akzeptanzkriterium:** PDF-Abrechnung OG-Pfaffenbach weicht < 1,00 €
vom User-Vorjahres-PDF ab. Bei > 1 € Abweichung: Investigation, wo die
Differenz herkommt (App-Fehler oder User-Fehler in Vorjahres-Excel).

---

## Phase 1 (nach MVP)

- VisionKit Document Scanner für Rechnungs-Upload
- Foundation Models On-Device-OCR-Nachbearbeitung
- Claude-API-Proxy (Cloudflare Worker)
- PII-Schwärzung vor Claude-Call (Default) + Dual-Mode-Switch
- StoreKit 2 Subscription-Fluss (Jahresabo, 14 Tage Free-Trial)
- Custom AVFoundation-Kamera für Zählerstand-Fotos mit OCR
- Privacy Policy + AVV in finaler juristischer Fassung
- App-Store-Submission-Vorbereitung (Screenshots, Beschreibung,
  Privacy-Declaration, App-Icon)

## Phase 2 (nach Launch)

- Multi-Objekt-Limit aufheben (aktuell 4 → unbegrenzt, Pricing-Tier)
- Multi-Jahres-Vergleich und Visualisierungen
- User-konfigurierbare "erwartete Inputs" pro Kostenart
- Export nach WISO / Buchhaltungsprogramme (CSV, DATEV)
- Erweiterte §35a-Hinweise mit Steuer-Tipps
- iPad-optimiertes Layout
