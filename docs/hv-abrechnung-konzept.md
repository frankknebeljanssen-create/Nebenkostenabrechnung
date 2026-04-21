# HV-Abrechnungs-Konzept — Scan-Flow & Datenmodell

Stand: 2026-04-21 · Status: Stufe 1 (Konzept, keine Code-Änderungen)

## Ausgangspunkt

Der typische Fall für `StandardKostenarten.Typ = .einzelneWE`: der
User besitzt eine einzelne Eigentumswohnung in einer WEG. Die
Hausverwaltung (HV) schickt ihm einmal im Jahr die WEG-Abrechnung
mit Umlagespiegel. Der Eigentümer muss daraus
- den **umlagefähigen Teil** an seinen Mieter weiterreichen,
- den **nicht umlagefähigen Teil** selbst tragen,
- den **§35a-Teil** in seiner eigenen Einkommensteuer geltend machen.

Die App kennt heute bereits die summarische Kostenart
„Hausgeld-Abrechnung (WEG)" (`StandardKostenarten.einzelneWEKatalog`
`:132`), hat aber keine Vorkehrung für die Detail-Aufgliederung
einer HV-Abrechnung. Der Scan-Flow stuft dieses Dokument heute
bestenfalls als `.sonstiges` oder `.bescheid` ein, ohne strukturierte
Extraktion.

Dieses Dokument legt fest, wie ein neuer Dokumenttyp
`hvAbrechnung` in die bestehende Pipeline eingehängt wird.

---

## 1. Neuer Dokumenttyp

### Enum-Ergänzung

`DokumentTyp` (in `Services/DokumentAnalyse.swift`) bekommt einen
neuen Case `.hvAbrechnung` mit `anzeige = "Hausverwaltungs-
Abrechnung"` und `icon = "building.2.crop.circle"`.

Die Claude-Antwort-Enum-Werte `dokumentTyp`
(in `Services/MietvertragsExtraktion.swift` User-Prompt) werden
um `"hvAbrechnung"` ergänzt. `typVon(_:)` mapt darauf.

### Erkennungsmerkmale für Claude

Der System-Prompt erweitert sich um die Regel „erkenne
HV-Abrechnungen anhand":

- Absender ist eine Hausverwaltung / Verwaltungsgesellschaft.
- Das Dokument enthält „Eigentümergemeinschaft", „WEG",
  „Wohnungseigentümergemeinschaft" oder „Hausgeld".
- Es wird ein MEA-Umlageschlüssel verwendet (z.B. Bruch
  „21297/1000000" oder Prozentsatz).
- Es gibt gegliederte Abschnitte „umlagefähig" / „nicht
  umlagefähig" bzw. „Betriebskosten" / „Eigentümerkosten".

---

## 2. Was Claude extrahieren muss

Fünf Blöcke im Response-Schema:

### STAMMDATEN (einmalig pro WEG)
- `hausverwaltung`: `{ name, anschrift, email?, telefon? }`
- `wegName`: String (z.B. „WEG Bahnhofstraße 37")
- `gebaeudeAdresse`: String (kann von eingetragener Objekt-
  Adresse abweichen, dient der Plausibilitätsprüfung)
- `meaAnteilZaehler`: Int (z.B. 21297)
- `meaAnteilNenner`: Int (z.B. 1000000)
- `abrechnungZeitraumVon`, `abrechnungZeitraumBis`: Date

### UMLAGEFÄHIGE KOSTEN (an Mieter weiter)
Pro Position:
- `bezeichnung`: String (z.B. „Wasser Haus", „Müllabfuhr")
- `gesamtkostenGebaeudeEuro`: Decimal
- `deinAnteilEuro`: Decimal
- `betrKvVorschlag`: String (z.B. „2", „8") — Claude-Heuristik
  für das Mapping auf die BetrKV-Kategorien der App. Nur Vorschlag,
  der User bestätigt.

Plus:
- `summeUmlagefaehigEuro`: Decimal (Summe `deinAnteilEuro`).

### NICHT UMLAGEFÄHIGE KOSTEN (nur Eigentümer)
Pro Position:
- `bezeichnung`: String (z.B. „Instandhaltungsrücklage",
  „Verwaltungskosten")
- `deinAnteilEuro`: Decimal

Plus:
- `summeNichtUmlagefaehigEuro`: Decimal.

### §35A ESTG (steuerlich absetzbar — separat ausgewiesen)
- `handwerkerleistungenEuro`: Decimal
- `haushaltsnaheDienstleistungenEuro`: Decimal

### ERGEBNIS
- `abrechnungsspitzeEuro`: Decimal — **positiv** = Nachzahlung
  vom Eigentümer an die HV, **negativ** = Guthaben der HV an
  den Eigentümer.
- `vorauszahlungenLtWirtschaftsplanEuro`: Decimal — was der
  Eigentümer laut Wirtschaftsplan bereits gezahlt hat.
- `erhaltungsruecklageAnteilEuro`: Decimal — dein Beitrag zur
  Rücklage (geht nie an den Mieter weiter).

Konfidenzen pro Top-Level-Feld analog zum bestehenden Mietvertrags-
Prompt, plus `hinweise: [String]`.

---

## 3. Wie die Daten in die App fließen

### Umlagefähige Positionen → Rechnungen (automatisch)
Pro umlagefähiger Position wird beim „Übernehmen" eine
`Rechnung`-Entity angelegt:
- `lieferant = hausverwaltung.name + " / " + position.bezeichnung`
  (z.B. „HV Meier / Wasser Haus"), oder schlicht
  `position.bezeichnung`.
- `betragBruttoEuro = position.deinAnteilEuro`
- `rechnungsdatum = abrechnungZeitraumBis`
- `leistungVon = abrechnungZeitraumVon`
- `leistungBis = abrechnungZeitraumBis`
- `kostenart = passende Kostenart` (aus `Immobilie.kostenarten`
  über `betrKvVorschlag` + User-Bestätigung im Analyse-Screen).
- `validierungsStatus = .validiert` (User hat die
  Übernahme-Card explizit bestätigt).
- Neues Feld `hvAbrechnungID: UUID?` auf Rechnung als
  Rückverweis (optional, für Nachvollziehbarkeit).

Alternative ohne Hvabrechnung-ID-Feld: die bestehende
`extraktionsNotizen`-Spalte kann den Link textuell halten
(„Aus HV-Abrechnung 2024, Position Wasser Haus"). Dann ist
aber keine saubere Deletion-Kaskade möglich.

### Nicht-umlagefähige Positionen → eigene Eigentümer-Kosten-Entity
Diese Positionen gehören **nicht** in den BetrKV-Kostenart-Katalog
(dort nur Umlagefähiges laut §2 BetrKV). Vorschlag: neues
`@Model HVEigentuemerKosten` mit:
- `id, bezeichnung, betragEuro, hvAbrechnung: HVAbrechnung?`

Darstellung: separater Bereich in den Einstellungen (oder auf
dem Abrechnungs-Tab als eigener Block „Eigentümer-Kosten")
— sichtbar nur dem Vermieter, niemals Teil der Mieter-
Abrechnung.

### §35A-Teil → Feld auf HVAbrechnung
Wird im Analyse-Screen prominent angezeigt („Dies kannst du
in deiner Einkommensteuer absetzen: 2 HV-Positionen,
zusammen 450 €"). Hat keine Auswirkung auf die Mieter-
Abrechnung — es ist Eigentümer-Information.

Technisch: `HVAbrechnung.handwerkerleistungen35aEuro` und
`haushaltsnaheDienstleistungen35aEuro` als Decimal-Felder.

### Erhaltungsrücklage / Abrechnungsspitze → nur HVAbrechnung
Beides Eigentümer-Informationen. Werden im Analyse-Screen
ausgewiesen, landen aber nicht in der Mieter-Abrechnung.

---

## 4. Wo in der App

### Scan-Einstieg (unverändert)
Aus `KontextDetailSheet` (Home → Objekt/Einheit-Card) oder
`NeuesObjektSheet` (beim Objekt-Anlegen) heraus. Der bestehende
„Neue Daten hinzufügen / ergänzen"-Button reicht — der Scan
wandert in die bestehende `DokumentAnalyseService.analysiere`-
Pipeline.

### Erkennung & Dispatch
`MietvertragsExtraktionService.extrahiere` liefert
`MietvertragsAnalyse` mit `erkannterTyp`. Wenn
`erkannterTyp == .hvAbrechnung`, wird im Analyse-Screen ein
anderer Block-Aufbau genutzt:
- **Block 1 — Stammdaten der HV-Abrechnung** (HV-Name, WEG,
  MEA, Zeitraum).
- **Block 2 — Umlagefähige Positionen** (Tabelle mit
  Bezeichnung · Anteil €, daneben Kostenart-Picker).
- **Block 3 — Nicht umlagefähige Positionen** (separate Tabelle,
  visuell ausgegraut / geringer Kontrast, klar als
  „Eigentümer-Kosten" markiert).
- **Block 4 — §35A, Erhaltungsrücklage, Abrechnungsspitze**
  (Eigentümer-Info).

### Übernehmen-Flow
Der „So übernehmen"-Button erzeugt:
1. Eine `HVAbrechnung`-Entity auf die Immobilie.
2. N `Rechnung`-Entities (eine pro umlagefähiger Position) mit
   Kostenart-Zuordnung, verknüpft über `hvAbrechnungID`.
3. M `HVEigentuemerKosten`-Entities (eine pro nicht umlagefähiger
   Position), verknüpft über `hvAbrechnung`.
4. §35A-Summen als Felder auf der HVAbrechnung.

Danach schließt das Sheet und navigiert den User optional in
die Rechnungen-Übersicht, wo er die neuen Rechnungen sieht.

---

## 5. Offene Fragen — Antworten für Stufe 2

### Q1: Reicht Rechnung/Kostenart, oder brauchen wir ein neues `@Model HVAbrechnung`?

**Antwort: Wir brauchen ein neues Model.**

Gründe:
- Metadaten (HV-Name, MEA-Anteil, Wirtschaftsplan-Vorauszahlung,
  Abrechnungsspitze, Erhaltungsrücklage) haben keinen Platz
  auf `Rechnung`.
- §35A-Aufteilung (Handwerker vs. haushaltsnah) braucht
  zwei Summenfelder, die über mehrere Rechnungen hinweg
  zusammengehören.
- Die Rückverfolgung „welche Rechnungen stammen aus welcher
  HV-Abrechnung" ist ohne Container-Entity nicht sauber
  lösbar (das PDF an `Rechnung.anhang` zu hängen ist
  redundant: ein PDF würde bei N Positions-Rechnungen N-fach
  gespeichert).

Struktur:

```swift
@Model
final class HVAbrechnung {
    var id: UUID = UUID()
    var erstelltAm: Date = Date()

    // Stammdaten
    var hvName: String = ""
    var hvAnschrift: String = ""
    var wegName: String = ""
    var meaAnteilZaehler: Int = 0
    var meaAnteilNenner: Int = 1

    var abrechnungVon: Date = Date()
    var abrechnungBis: Date = Date()

    // Summen
    var summeUmlagefaehigEuro: Decimal = 0
    var summeNichtUmlagefaehigEuro: Decimal = 0
    var abrechnungsspitzeEuro: Decimal = 0
    var vorauszahlungenLtWirtschaftsplanEuro: Decimal = 0
    var erhaltungsruecklageAnteilEuro: Decimal = 0

    // §35A
    var handwerkerleistungen35aEuro: Decimal = 0
    var haushaltsnaheDienstleistungen35aEuro: Decimal = 0

    // PDF-Anhang einmalig am Container
    @Attribute(.externalStorage) var anhang: Data?

    // Relationships
    var immobilie: Immobilie?

    @Relationship(deleteRule: .cascade, inverse: \HVEigentuemerKosten.hvAbrechnung)
    var nichtUmlagefaehigePositionen: [HVEigentuemerKosten]? = []

    // Rechnungen werden per Callback-Seite verknuepft (nicht
    // Cascade-Inverse, weil Rechnungen auch andere Quellen haben
    // koennen).

    init() {}
}

@Model
final class HVEigentuemerKosten {
    var id: UUID = UUID()
    var bezeichnung: String = ""
    var betragEuro: Decimal = 0
    var hvAbrechnung: HVAbrechnung?
    init() {}
}
```

`Rechnung` bekommt ein optionales Feld `hvAbrechnungID: UUID?`
(kein SwiftData-Relationship — das hält die HVAbrechnung ggf.
schlank bei Massen-Rechnungen und vermeidet einen
Cascade-Delete-Konflikt mit bestehender
`Immobilie.rechnungen`-Relation).

### Q2: Nicht-umlagefähige Kosten als Kostenart-Gruppe „Eigentümerkosten"?

**Antwort: Nein, nicht als Kostenart.**

Gründe:
- Die `Kostenart`-Entity ist semantisch „Umlagefähig nach BetrKV"
  (alle 17 BetrKV-Positionen). Dazu die Eigentümerkosten
  hinzuzufügen würde die Bedeutung verwaschen und Bugs in der
  Abrechnungsberechnung provozieren (was wenn jemand versehentlich
  eine Eigentümer-Kostenart in die Umlage zieht?).
- Eigentümerkosten haben keinen Mieter-Umlageschlüssel —
  sie sind per Definition _nicht_ umlagefähig.
- Die Darstellung ist grundverschieden: Eigentümer-Kosten
  tauchen nie in der Mieter-Abrechnung auf, sondern in einer
  separaten „Was kostet mich das Objekt?"-Übersicht.

Deshalb: eigene Entity `HVEigentuemerKosten` (oben skizziert)
als reiner Datencontainer, Anzeige in einem separaten UI-Bereich
(Vorschlag: neuer Tab oder Einstellungen-Section
„Eigentümer-Kosten" mit Jahres-Übersicht).

---

## 6. Hinweise zur Prompt-Architektur

Der bestehende Mietvertrags-Prompt in
`MietvertragsExtraktionService.userPrompt` ist bereits 50 Zeilen
mit Feldliste + Regeln. Eine vollständige HV-Extraktion würde
ihn mindestens verdoppeln (mehr Felder, verschachtelte Arrays
für Positionen).

**Zwei Varianten für Stufe 2:**

- **Variante A — Ein-Prompt-Mehrzweck:** Bestehenden Prompt erweitern.
  Claude entscheidet selbst anhand von `dokumentTyp`, welche Felder
  gefüllt werden. Einfach zu implementieren, günstiger (ein Call),
  aber Prompt wird groß (Token-Kosten pro Call steigen linear).
- **Variante B — Typ-spezifische Prompts:** Kurzer Klassifikator-Call
  entscheidet den Typ, dann zweiter Call mit typ-spezifischem
  Prompt. CLAUDE.md-Vorgabe ist
  „Stufe 1 on-device Foundation Models + Stufe 2 Claude" — passt
  hier. Sauber, aber zwei API-Calls pro Scan.

**Empfehlung:** Für die Stufe-2-Implementierung Variante A
(Prompt-Erweiterung), weil `AnthropicClient` aktuell keinen
Multi-Call-Flow hat. Variante B kann nachgeliefert werden,
sobald die Foundation-Models-Klassifikation steht.

---

## 7. Abgrenzung zu Stammdaten-vs-NK-Daten-Stufe-3

Die HV-Abrechnung sitzt klar in der **NK-laufenden-Daten-Welt**
(siehe `docs/stammdaten-vs-nk-daten.md`): sie kommt pro Periode,
wird einmal verarbeitet, betrifft keine Stammdaten des
Mietverhältnisses. Sie erzeugt allerdings laufende `Rechnung`-
Einträge, die anschließend im normalen BetrKV-Abrechnungsfluss
aufgehen. Dadurch bleibt der bestehende Abrechnungsservice
unverändert — er sieht nur Rechnungen, egal ob sie aus einem
Einzel-Scan oder aus einer HV-Abrechnung stammen.

---

## 8. Nächster Schritt

Stufe 2 (Code, nach User-OK):

1. **Model:** `HVAbrechnung` + `HVEigentuemerKosten` anlegen,
   `Rechnung.hvAbrechnungID` additiv ergänzen.
2. **Extraktion:** `MietvertragsExtraktion`-Prompt um HV-Felder
   erweitern, `ClaudeAntwort`-Decoder um Positions-Arrays.
3. **Analyse-Screen:** typ-spezifischer Block-Aufbau im
   `AnalyseBefundView` wenn `erkannterTyp == .hvAbrechnung`.
4. **Übernehmen-Flow:** neue `KontextDetailSheet.uebernehme…`-
   Variante, die N Rechnungen + M HVEigentuemerKosten +
   1 HVAbrechnung anlegt.
5. **Übersicht:** neue Einstellungen-Section oder Tab-Bereich
   „Eigentümer-Kosten" mit Jahresaggregat.

Reihenfolge: Model → Extraktion → UI-Analyse → Übernehmen →
Übersicht. Jeder Schritt einzeln testbar.
