# Nebenkostenabrechnung

Mobile-first iOS-App, die deutschen Kleinvermietern (1–10 Einheiten,
ohne Hausverwaltung) die jährliche Betriebs- und Heizkostenabrechnung
nach **BetrKV** und **HeizkostenV** abnimmt — vom Belegscan bis zur
versandfertigen PDF-Abrechnung.

> Status: **Phase 0 (MVP-Gerüst)** — Datenmodell, Berechnungs-Engine,
> Tab-Bar-UI, Onboarding und DSGVO-Compliance stehen. Entwicklung auf
> Basis realer Daten der Testimmobilie Bahnhofstr. 37, Berlin.

## Warum

Vermieter mit ein bis zehn Einheiten haben für eine Hausverwaltung zu
wenig Volumen und für Excel zu viel rechtliche Komplexität: 17
umlagefähige Kostenarten in der BetrKV, der 30/70-Split aus der
HeizkostenV, der §35a-EStG-Lohnanteil, das CO₂KostAufG-Stufenmodell,
und die Pflicht zur belegbasierten Nachvollziehbarkeit.

Die App macht den Weg von der gescannten Rechnung bis zur fertigen,
gerichtsfesten Abrechnung mobil, in deutscher Sprache und ohne
Schreibtisch.

## Highlights

- **Foto-KI-Pipeline** — Rechnungen scannen → on-device-OCR (Apple
  Vision) → typ-spezifische KI-Extraktion → validierter Vorschlag.
  Drei strikt getrennte Datenebenen: Rohdaten · Vorschlag · Validiert.
  Nur validierte Daten fließen in die Abrechnung.
- **Strikte Daten, keine Schätzungen.** Die App rechnet nur, wenn jeder
  Pflichtwert aktiv bestätigt ist. Keine stillen Null-Fallbacks, kein
  Vorjahres-Übernehmen, kein verstecktes Default. Lücken werden mit
  sprungfähigen Hinweisen sichtbar gemacht.
- **§35a EStG ausweisbar** — haushaltsnahe Dienstleistungen und
  Handwerkerleistungen werden separat dokumentiert.
- **DSGVO-konform** — privater iCloud-Container pro User, expliziter
  AVV im Onboarding, Daten-Export als ZIP, vollständige Löschung
  zweistufig bestätigt. PII-Schwärzung vor jedem KI-Call ist Pflicht.
- **Multi-Objekt** — bis zu vier Immobilien, Scope-Wechsel pro Tab
  zwischen Gesamt-Objekt und Einzel-Einheit.
- **Berechnungskern ist pur** — die Calc-Layer kennt nur `Foundation`,
  rechnet auf Input-Structs und ist zu 100 % testbar gegen reale Zahlen.

## Tech-Stack

- **Swift 6.3** mit strict concurrency
- **SwiftUI**, Deployment Target iOS 26.3+ (Xcode 26.4.1)
- **SwiftData + CloudKit** (privater Container pro User)
- **Foundation Models Framework** für on-device-KI (iOS 26)
- **VisionKit `DataScannerViewController`** für Dokument-Scans
- **AVFoundation + Vision** für Zählerstand-Fotos
- **PDFKit** via HTML-Template (Mustache-Platzhalter)
- **StoreKit 2** für das Jahresabo (ab Phase 1)
- **Swift Testing** (`@Test` Macros)

Kein Backend — bis auf einen schmalen Cloudflare-Worker-Proxy für
Claude-API-Calls (Phase 1). Der Anthropic-Key ist niemals im App-
Binary.

## Architektur

```
NebenkostenApp/
├── App/              SwiftUI App-Entry, Root-TabView, Environment
├── Models/           SwiftData @Model-Klassen (keine Business-Logik)
├── Calc/             Reine Berechnungs-Logik (nur Foundation)
├── Services/         CloudKit, KI-Extraktion, PDF, Privacy-Utils
├── Features/
│   ├── Onboarding/   User-Stammdaten + DSGVO + erstes Objekt
│   ├── Objekt/       Tab 1: Dashboard, Mieter, Zähler, Kostenarten
│   ├── Dokumente/    Tab 2: Scan, Archiv, Suche
│   ├── Abrechnungen/ Tab 3: Perioden, Erstellung, Versand
│   └── Einstellungen/Tab 4: Stammdaten, Abo, DSGVO, Legal
├── Templates/        HTML-Templates für PDF-Generierung
└── Common/           Hilfstypen, Formatters, Extensions
```

**Kritische Regel:** Die Calc-Layer importiert ausschließlich
`Foundation`. Keine SwiftData-, SwiftUI-, CloudKit- oder UIKit-Typen
darin — die Brücke baut der Service-Layer. Das hält jeden Rechen­
schritt nachvollziehbar und vollständig testbar.

## Design-System

Eigenes Design-System auf Basis eines Claude-Design-Handoffs in
`design_handoff_nebenkosten_app/`:

- **Farben** zentral in `Core/Design/DesignTokens.swift` (Single
  Source of Truth, 1:1 mit der Typografie-Spec)
- **Typografie** verbindlich in `design_handoff/typografie-spec.html`
  — IBM Plex Sans für Text, IBM Plex Mono für Zahlen, niemals mischen
  innerhalb einer Zeile
- **Komponenten** unter `UI/Components/` (Card, Row, StatusPill,
  CollapsibleSection, ProgressRail …)
- **Light-Mode-only** in Phase 1, Dark-Mode-Overrides folgen

## Rechtliche Grundlagen

- **BetrKV** — 17 umlagefähige Kostenarten
- **HeizkostenV** — 30 / 70 oder konfigurierbarer §9-Split mit
  Heizung/Warmwasser-Trennung, Stromzuschlag, separaten
  Nebenkosten-Töpfen
- **§35a EStG** — Lohnanteile aus Handwerker- und haushaltsnahen
  Dienstleistungen werden separat ausgewiesen
- **CO₂KostAufG** — Stufenmodell zur CO₂-Kostenaufteilung
- **DSGVO** — Vermieter ist Verantwortlicher, App-Anbieter ist
  Auftragsverarbeiter, Apple iCloud Unterauftragsverarbeiter
- **§257 HGB** — 10 Jahre Aufbewahrung für Handelsunterlagen

## Roadmap

- **Phase 0 — MVP-Gerüst** *(aktuell)*: Datenmodell, Calc-Engine,
  Tab-Bar-UI, manuelle Dateneingabe, Onboarding, DSGVO
- **Phase 1**: Foto-KI-Pipeline scharfstellen, Zählerstand-Foto
  mit Custom-Kamera, Cloudflare-Proxy für Claude, StoreKit-Abo
- **Phase 2**: User-konfigurierbare Erwartungen, vollwertige
  Inspektor-Logik, Dark-Mode, PDF-Builder finalisieren
- **Phase 3**: Mieter-Portal mit eigenem Login

## Was bewusst nicht zum Scope gehört

- Mietverwaltung (Staffelmieten, Kündigungsfristen)
- Android / Web — iOS-only by design
- Mehrere User pro Apple-ID
- Backend mit eigener User-Verwaltung — CloudKit übernimmt das

## Vertrieb

Kommerzielle App, geplant für den deutschen App Store, Jahresabo im
Bereich 49–99 €.

## Lizenz

Quelltext öffentlich einsehbar zu Demonstrations- und Bewerbungs­
zwecken. Alle Rechte vorbehalten. Keine Lizenz zur kommerziellen
Nutzung, Weiterverbreitung oder Vervielfältigung. Für Anfragen:
frankknebeljanssen@gmail.com.
