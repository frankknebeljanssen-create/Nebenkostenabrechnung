# Stammdaten-Kachel — Bestandsanalyse (Stand 2026-04-22, Commit 56d781f)

Grundlage für den Stammdaten-Kachel-Rebuild (Stufe 2). Kein Code in
diesem Schritt — nur Inventar und Abgleich gegen das neue Ziel.

## Zielbild (zur Orientierung, noch nicht gebaut)

Tap auf die Stammdaten-Kachel in der `KachelansichtView` öffnet
einen neuen Screen `StammdatenView` mit:

1. `[← Zurück] [Stammdaten]` (NavigationBar)
2. Fortschrittsbalken rot → grün mit Prozent (analog
   `CompletionFarbe`)
3. Drei aufklappbare Sektionen:
   - **A) Objekt** — Adresse, Fläche, Heizungsart, Periode
   - **B) Mieter pro WE** — Name, Einzug, Vorauszahlung, Mietvertrag
   - **C) Dokumente** — Energieausweis, Grundsteuer-Bescheid
4. Pro Sektion: Completion-Indikator, tappbare Rows, Edit-Button
5. Bottom-Button „Dokument scannen" — Scan-Flow für
   Stammdaten-Dokumente

---

## 1. Stammdaten-Felder im Datenmodell

### Immobilie (`Models/DataModel.swift:77-140`)

| Feld | Typ | Default | Pflicht für Abrechnung? | Quelle |
|---|---|---|---|---|
| `adresse` | String | `""` | **ja (faktisch)** — für Mieter-PDF nötig | `NeuesObjektSheet` |
| `ort` | String | `""` | **ja (faktisch)** — für Mieter-PDF | `NeuesObjektSheet` |
| `gesamtflaecheM2` | Decimal | `0` | **ja** — Pruefung-Blocker (siehe §4) | `NeuesObjektSheet` |
| `abrechnungsstartMonat` | Int | `1` | implizit — Periode leitet sich daraus ab | `NeuesObjektSheet` |
| `abrechnungsstartTag` | Int | `1` | implizit | `NeuesObjektSheet` |
| `heizungsart` | Enum (7 Cases) | `.gasZentral` | **ja** — wählt Kostenart-Setup + Heizkosten-Logik | `NeuesObjektSheet` |
| `warmwasserbereitung` | Enum (4 Cases) | `.zentralMitHeizung` | **ja** — steuert §9-HeizkostenV-Split | `NeuesObjektSheet` |

Alle nach CloudKit-Konvention mit Default-Wert → Pflicht-Status ist
semantisch, nicht Compiler-erzwungen. Kein Ort in der laufenden App,
wo diese Felder nach dem Anlegen noch geändert werden können — die
`ObjektSection` im `EinstellungenSheet` ist **readonly**.

### Wohneinheit (`DataModel.swift:151-184`)

| Feld | Typ | Default | Pflicht? |
|---|---|---|---|
| `bezeichnung` | String | `""` | **ja** — dient als Scope-ID (KG/EG/OG) |
| `flaecheM2` | Decimal | `0` | **ja** — Umlage-Basis |
| `nutzungsart` | Enum | `.wohnung` | implizit, Leerstand = Sonderfall |
| `selbstnutzung` | Bool | `false` | optional — §35a-relevant |
| `farbkennungHex` | String | `""` | optional (UI-Farbe) |

Edit-Path: initial via `NeuesObjektSheet`. Danach: **kein
dedizierter Wohneinheit-Edit-View.** Änderungen nur durch Löschen
des Objekts und Neuanlegen, oder manuell im Scan-Flow.

### Mietverhältnis (`DataModel.swift:195-251`)

| Feld | Typ | Pflicht? |
|---|---|---|
| `mieterName` | String | **ja** |
| `mieterAnschrift` | String | für PDF-Versand |
| `mieterEmail` | String | für Mail-Versand |
| `mieterTyp` | Enum | ja (Wohnungsmieter / Gewerbe / Selbstnutzer) |
| `einzugAm` | Date | ja |
| `auszugAm` | Date? | optional |
| `vorauszahlungMonatEuro` | Decimal | **ja + Flag** |
| `vorauszahlungErfasst` | Bool | **ja** (Strikte-Daten-Marker) |
| `vorauszahlungGueltigAb` | Date? | optional |
| `anzahlPersonen` | Int | ja (personenbezogene Umlage) |

**Edit vorhanden:** [MieterEditView](NebenkostenApp/NebenkostenApp/UI/Mieter/MieterEditView.swift) — voller CRUD mit zwei Modi (`.neu` + `.bearbeiten`).
Separat: [VorauszahlungEingabeSheet](NebenkostenApp/NebenkostenApp/UI/Mieter/VorauszahlungEingabeSheet.swift) für gezielte VZ-Updates.

### Abrechnungsperiode (`DataModel.swift:548-569`)

| Feld | Typ | Pflicht? |
|---|---|---|
| `von` / `bis` | Date | ja (`von < bis`) |
| `abgeschlossen` | Bool | false (nach Final-Abrechnung true) |
| `versandtAm` | Date? | optional |

Edit-Path: **nur initial** im `NeuesObjektSheet` (erste Periode).
Danach existiert kein UI, um eine weitere Periode anzulegen oder
die bestehende zu ändern.

---

## 2. Existierende Edit-Views

| View | Zweck | Kann wiederverwendet werden? |
|---|---|---|
| `NeuesObjektSheet` | Geführter Erstanlage-Flow: Immobilie + Wohneinheiten + Kostenarten + erste Periode, inkl. Mietvertrag-Scan-Stub | Nicht als Row-Edit — ist ein One-Shot-Wizard. Bleibt für den Leerstaats-CTA „Erstes Objekt anlegen". |
| `MieterEditView` | Vollständiger CRUD für Mietverhältnisse, Modus `.neu / .bearbeiten` | **Ja**, 1:1 für die Mieter-Sektion. Row-Tap öffnet `.bearbeiten`, Plus-Button `.neu` mit Einheit-Vorauswahl. |
| `VorauszahlungEingabeSheet` | Nur VZ-Betrag + „Gültig ab" | Kann als Schnellzugriff in der Mieter-Row bleiben — ist das, wohin der „Vorauszahlung"-Sprungziel heute führt. |
| `EinstellungenSheet.ObjektSection` (private) | Readonly-Liste der Immobilien-Felder | **Nicht direkt**, nur als Daten-Vorlage. Die neuen Rows brauchen ein Tap → Edit, nicht nur Anzeigen. |
| `EinstellungenSheet.MieterSection` (private) | Tappbare Zeilen pro Einheit → Vorauszahlung-Sheet | Konzeptvorlage für das Layout der Mieter-Rows in der Stammdaten-Kachel. |
| `EinstellungenSheet.UmlageSection` | Kostenart-Katalog mit Umlage-Schlüssel | Liegt außerhalb der Kachel-Struktur (Umlage ist eher Abrechnungs-Vorbereitung als Stammdaten). Nicht aufgeführt im Zielbild — bleibt im Einstellungen-Sheet. |

---

## 3. Was fehlt komplett

### 3.1 Objekt-Bearbeiten-View

Kein View ändert Adresse, Ort, Gesamtfläche, Heizungsart oder
Warmwasserbereitung nach der Erstanlage. **Neu bauen:**
`ObjektEditView` mit denselben Feldern wie in `NeuesObjektSheet`
(ohne den Einheit-/Periode-Block), eigener Modus `.bearbeiten`.

### 3.2 Wohneinheit-Bearbeiten-View

Einheit-Flächen, Nutzungsart, Bezeichnung sind nach Anlage nicht
änderbar. **Neu bauen:** `WohneinheitEditView` (Bezeichnung,
Flächen-m², Nutzungsart, Selbstnutzung-Flag, Farbe).

### 3.3 Periode-Bearbeiten-/Anlage-View

Nur die erste Periode wird im `NeuesObjektSheet` angelegt. Für
eine zweite Periode existiert kein UI. **Neu bauen:**
`PeriodeEditView` (`von` / `bis`, `abgeschlossen`-Toggle nur
lesend) — plus Liste aller Perioden als Rows in der Objekt-
Sektion.

### 3.4 Stammdaten-Dokumente

Das Zielbild verlangt eine **Dokumenten-Sektion** mit
Energieausweis, Grundsteuer-Bescheid etc.
Aktueller Stand: `GespeichertesDokument` + `Rechnung` existieren,
aber **keine Typisierung „Stammdaten-Dokument"**. Der
`Dokumenttyp`-Enum enthält Typen wie `.rechnung`, `.mahnung`,
`.bescheid` — aber keine explizite Stammdaten-Kategorie.

**Offene Design-Entscheidung (siehe unten):**
- Eigener Typ `Dokumenttyp.stammdatenEnergieausweis` /
  `.stammdatenGrundsteuer`?
- Oder Free-Form-Feld `kontext` wie heute, das als Label dient?
- Oder eigenes `StammdatenDokument`-Model ohne
  Abrechnungs-Zuordnung?

### 3.5 Mietvertrag als Dokument am Mietverhältnis

Der Mietvertrag-Scan-Flow (`NeuesObjektSheet` M1-Stub) erkennt
Mieterdaten, aber das gescannte Dokument wird **nicht** am
`Mietverhaeltnis` verlinkt. Für Punkt 3B des Zielbilds
(„Mietvertrag" pro Mieter-Row) bräuchte es eine neue Relation
`Mietverhaeltnis.mietvertragDokument: GespeichertesDokument?`
oder einen Reverse-Lookup via `dokument.mietverhaeltnis`.

---

## 4. Completion heute — Stammdaten-Anteil

Alle Regeln leben in `Services/VollstaendigkeitsPruefung.swift`,
Kategorie `.stammdaten`. Fünf Regeln werden pro Periode geprüft:

| ID | Beschreibung | Status-Logik | Sprungziel |
|---|---|---|---|
| `stammdaten-gesamtflaeche` | `immobilie.gesamtflaecheM2 > 0` | `.erfuellt` / `.offen` | `.einstellungenObjekt` |
| `stammdaten-wohneinheiten` | Einheiten mit `flaecheM2 > 0` | `.erfuellt` / `.teilweise` / `.offen` | `.einstellungenObjekt` |
| `stammdaten-mieter` | Aktives MV pro nicht-leerer Einheit | `.erfuellt` / `.teilweise` / `.offen` | `.mieterVorauszahlung(einheitId:)` bzw. `.einstellungenObjekt` |
| `stammdaten-vorauszahlung` | `vorauszahlungErfasst == true` pro aktivem MV | `.erfuellt` / `.offen` (Blocker) | `.mieterVorauszahlung(einheitId:)` |
| `stammdaten-periode` | `von < bis` für alle Perioden | `.erfuellt` / `.offen` | `.einstellungenPeriode` |

`KachelansichtView.stammdatenProzent` ruft
`VollstaendigkeitsPruefung.completionProzent(_, kategorie: .stammdaten)`
auf. Der Nenner lässt `nichtErwartet`-Regeln weg (z. B. VZ-Anforderung
ohne Mieter). Formel = `erfuellt / (total - nichtErwartet)`.

**Wichtig für den Rebuild:** Das Zielbild listet Sektion C
„Dokumente" (Energieausweis, Grundsteuer-Bescheid) — für diese
Unter-Sektion existiert **keine Anforderung in `VollstaendigkeitsPruefung`**.
Die Completion dort muss entweder neu definiert werden
(z. B. „Dokument vorhanden" + „Gültigkeit in Ordnung") oder die
Sektion C trägt keinen Completion-Einfluss in das Gesamt-Prozent.

---

## 5. Tap-Einstiegspunkt heute

`KachelansichtView.swift:86-90` — Tap auf die Stammdaten-Kachel:

```swift
KachelCard(
    titel: "Stammdaten",
    icon: "person.text.rectangle",
    prozent: stammdatenProzent,
    onTap: { aktiveKachelNotiz = platzhalterText("Stammdaten") }
)
```

Das öffnet `KachelPlatzhalterSheet` mit Text:
> „Das Dashboard für „Stammdaten" folgt im nächsten Task. Bis dahin
> erreichen Sie die Inhalte über die TabBar."

Alle vier Kacheln haben heute diesen Platzhalter-Handler. Die
`StammdatenView` ersetzt den `onTap`-Body durch einen
`NavigationLink` (die Kachel sitzt bereits in einem
`NavigationStack`, der aus `AppShell → NavigationStack →
UebersichtView → HomeView → NavigationLink → KachelansichtView`
durchläuft). Von da aus wird ein weiterer Push auf
`StammdatenView` natürlich möglich.

---

## 6. Offene Design-Fragen für Stufe 2

1. **Wohneinheit + Periode editierbar nach Anlage?**
   Im MVP heißt „Stammdaten ändern" praktisch immer Objekt
   neu anlegen. Soll Stufe 2 volle CRUD-Views bringen, oder nur
   Mieter-Edit (bereits vorhanden)? → Empfehlung: voll,
   sonst bleiben Sektionen A/B-WE readonly wie heute.

2. **Stammdaten-Dokumente — wie modellieren?**
   Eigener `Dokumenttyp`-Case `.stammdaten(subtyp:)` ist die
   geringste Schema-Änderung. Alternative: eigenes `Stammdaten
   Dokument`-@Model mit direkter Relation zu Immobilie. Der
   Energieausweis + Grundsteuer-Bescheid haben unterschiedliche
   Gültigkeits-Semantik (Ausweis 10 Jahre vs. Bescheid jährlich),
   die der Enum-Case nicht abbildet.

3. **Mietvertrag am Mietverhältnis?**
   `Mietverhaeltnis.mietvertragDokument: GespeichertesDokument?`
   als additives Feld — CloudKit-safe, optional. Für Stufe 2
   nötig, damit die „Mietvertrag"-Row tappbar ist.

4. **Completion-Einfluss der Dokumente-Sektion?**
   Zählen die beiden Stammdaten-Dokumente (Energieausweis,
   Grundsteuer) für den Home-Ring? Heute nicht — wenn Stufe 2
   sie mitrechnet, muss `VollstaendigkeitsPruefung` um zwei
   neue Regeln erweitert werden. Sonst bleibt die Sektion nur
   UX-Zugang, ohne Prozent-Gewicht.

5. **„Dokument scannen"-CTA unten: welcher Typ-Picker?**
   Der Button öffnet den Scan-Flow, aber mit welcher Vorbelegung?
   Vorschlag: Typ-Picker im Sheet auswählen
   (Energieausweis / Grundsteuer / Mietvertrag / Sonstiges),
   danach regulärer `ScanEntryView`-Flow. Konsequenz: minimaler
   Eingriff in `ScanEntryView` (neuer optionaler
   `vorbelegterTyp: Dokumenttyp?`).
