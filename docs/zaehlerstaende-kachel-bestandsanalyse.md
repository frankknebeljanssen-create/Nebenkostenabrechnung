# Zählerstände-Kachel — Bestandsanalyse (Stand 2026-04-22, Commit 3a31195)

Grundlage für den Zählerstände-Kachel-Rebuild (Stufe 2). Kein Code —
nur Inventar und Abgleich gegen das neue Ziel.

## Zielbild (zur Orientierung, noch nicht gebaut)

`ZaehlerstaendeView` — Kachel-Screen mit:

1. `[← Zurück] [Zählerstände]`
2. Fortschrittsbalken
3. Gruppiert nach Medium: WÄRME / WARMWASSER / KALTWASSER / STROM / GAS
4. Pro Zähler: Anfangs- + Endstand, Status-Dot (grün/gelb/rot)
5. Tap auf Zähler → Erfassung
6. Button „Zählerstand erfassen"

---

## 1. Zähler-Typen (Medium-Enum)

`Models/DataModel.swift:281-288` — sechs Cases:

| Medium | Typische Einheit | UI-Gruppe (MediumMeta) | SF Symbol | Farbe |
|---|---|---|---|---|
| `.waermeenergie` | kWh | „Wärme" (Rang 0) | `flame` | #C2610F |
| `.warmwasser` | m³ | „Warmwasser" (Rang 1) | `drop.fill` | #8C5A3C |
| `.kaltwasser` | m³ | „Kaltwasser" (Rang 2) | `drop` | #3A6B8C |
| `.strom` | kWh | „Allgemeinstrom" (Rang 3) | `bolt` | #B8841F |
| `.gas` | m³ | „Gas" (Rang 4) | `flame` | #B8841F |
| `.oel` | Liter | „Öl" (Rang 5) | `drop.triangle.fill` | #C2610F |

Plus **Zählertyp** (`Zaehlertyp`-Enum, 3 Cases):
- `.haupt` — Hausanschluss, hängt an `Immobilie.hauptzaehler`
- `.wohnung` — pro Einheit, hängt an `Wohneinheit.zaehler`
- `.zwischen` — z. B. Gartenwasser, subtrahiert vom Hauptzähler

Invariante (Comment in Code): Entweder `immobilie` ODER `wohneinheit`
ist gesetzt, nie beides.

## 2. Zaehler / Zaehlerstand — Datenmodell

### `Zaehler` (`DataModel.swift:290-324`)

| Feld | Typ | Zweck |
|---|---|---|
| `seriennummer` | String | Geräte-Seriennummer |
| `bezeichnung` | String | Lesbarer Name, z. B. „WMZ OG Bad" |
| `typ` / `medium` | Enum | siehe oben |
| `einheit` | String | „m³", „kWh", … (Display) |
| `umrechnungsfaktor` | Decimal | Gaszähler: z-Zahl (Default 1) |
| `brennwertKwhProM3` | Decimal? | Gaszähler: Brennwert aus Versorger-Rechnung |
| `immobilie` / `wohneinheit` | Relation | exklusiv, siehe oben |
| `staende` | `[Zaehlerstand]?` | cascade-delete |

### `Zaehlerstand` (`DataModel.swift:346-372`)

| Feld | Typ | Zweck |
|---|---|---|
| `ablesedatum` | Date | Datum der Ablesung |
| `stand` | Decimal | Zählerwert |
| `erfasstAm` | Date? | **Strikte-Daten-Marker** — nur wenn != nil, gilt der Stand als erfasst |
| `quelle` | `Ablesequelle` | manuell / kiExtrahiert / importiert / versorgerRechnung / geschaetzt |
| `foto` | Data? | `@Attribute(.externalStorage)` — Beweisfoto |
| `notizen` | String | Freitext |

`Ablesequelle` kennt fünf Cases; `.kiExtrahiert` (Anzeige „Foto") deutet
auf eine geplante Kamera-Pipeline, wird aktuell aber **nicht aus der
UI gesetzt** — siehe unten.

## 3. Existierende Views

### Tab-Root
- [`ZaehlerView`](NebenkostenApp/NebenkostenApp/UI/Zaehler/ZaehlerView.swift)
  — der Haupt-Tab. Layout nach UI-Fix-3:
  - `WarnCardEndstaende` oben: „N Endstände fehlen" + Tap → erster
    offener Zähler
  - `MediumSection` pro Medium (nur nicht-leere werden gezeigt)
  - `.sheet(item: $detailZaehler)` → `ZaehlerDetailView`
  - `.sheet(item: $erfassenZaehler)` → `ZaehlerstandErfassenView`
  - Sprungziel-Reaktion: `.zaehlerstandErfassen(id:)` → direkt
    Erfassen, `.wmzPlausi` → Quittieren (kein Expand-Handling)

### Detail
- [`ZaehlerDetailView`](NebenkostenApp/NebenkostenApp/UI/Zaehler/ZaehlerDetailView.swift)
  — seit UI-Fix auf DesignTokens + AppFont.Zaehler umgestylt.
  Header-Card mit Icon, Meta-Liste (Standort, Kennzeichen,
  Seriennummer, Einheit), Stände-Historie, Primär-Button
  „Neuer Stand" → `ZaehlerstandErfassenView` als zweites Sheet.

### Erfassung (nur manuell)
- [`ZaehlerstandErfassenView`](NebenkostenApp/NebenkostenApp/UI/Zaehler/ZaehlerstandErfassenView.swift)
  — Form mit vier Sections:
  - Datum (DatePicker, `de_DE`)
  - Quelle (Picker über `verfuegbareQuellen` aus dem ViewModel —
    `.kiExtrahiert` ist aktuell ausgeschlossen)
  - Zählerstand (TextField, `decimalPad`, monospaced)
  - Notiz (TextField, multiline bis 3 Zeilen)
  - Optionale Plausi-Warnung (Rücklauf-Erkennung)
  - Save-Button „primär" via `SheetToolbar.primaer`; ViewModel
    validiert (`istGueltig`) und fragt bei Rücklauf nach
    Bestätigung („Rücklauf erkannt"-Alert)

**Keine Kamera.** Auch kein VisionKit-Flow. Die Ablesequelle
`.kiExtrahiert` (Anzeige „Foto") ist im Enum vorgemerkt, aber kein
UI-Pfad setzt sie heute. CLAUDE.md nennt einen Custom-AVFoundation-
Kamera-Flow für Phase 1 — der ist nicht gebaut.

### Phase-0-Übersicht
- [`ZaehlerUebersichtView`](NebenkostenApp/NebenkostenApp/UI/Zaehler/ZaehlerUebersichtView.swift)
  — alte Phase-0-Liste, wird aus `ObjektTabRoot` gerendert, nicht aus
  dem neuen Zähler-Tab. Kann als Referenz dienen, aber nicht Basis
  für den Kachel-Screen.

### Reusable-Komponenten (`UI/Zaehler/Components/`)
- `MediumMeta` — Gruppen-Reihenfolge, SF-Symbols, Farben
- `MediumSection` — eine Gruppe (Header + Row-Liste)
- `MeterRow` — eine Zähler-Zeile (ScopePill + Name + Typ + drei
  Messzellen)
- `MeterReading` — einzelne Messzelle (StatusDot + Datum + Wert)
- `VerbrauchAnzeige` — „Verbrauch"-Zelle rechts
- `WarnCardEndstaende` — Warn-Card oben auf ZaehlerView
- `ZaehlerSammelZeile` — Tabellen-Zeile für Mehrfach-Summen

Alle diese Komponenten sind für den neuen Kachel-Screen
**wiederverwendbar** — die Gruppierung nach Medium mit Anfangs/Ende/
Verbrauch-Zellen passt 1:1 zum Zielbild.

## 4. Zählerstand-Erfassung — wie heute

**Nur manuell.** Der User tippt den Wert über die Tastatur ein.
Flow:

1. `ZaehlerView` → Tap auf `MeterRow` → `ZaehlerView.detailZaehler = z`
2. → `ZaehlerDetailView` → Tap „Neuer Stand" → eigenes Sheet
3. `ZaehlerstandErfassenView` → Form ausfüllen → Save
4. ViewModel erstellt `Zaehlerstand(erfasstAm: Date())` und hängt
   ihn an `zaehler.staende`

Alternative Einstiegspunkte:
- Warn-Card auf `ZaehlerView` → direkt in Schritt 3 (umgeht Detail)
- Sprungziel `.zaehlerstandErfassen(zaehlerId:)` aus Home → direkt
  in Schritt 3
- `ZaehlerDetailView`-Leerzustand → Primär-Button „Ersten Stand
  erfassen" → Schritt 3

Kein Mehrwert-Flow mit Kamera + VisionKit. Kein Foto-Upload pro
Stand (`Zaehlerstand.foto: Data?` existiert, wird aber vom UI
nicht befüllt).

## 5. Completion heute — Zähler-Anteil

`VollstaendigkeitsPruefung.zaehlerAnforderungen` (Aufruf in
`pruefe(immobilie:periode:)`) erzeugt pro Zähler eine Anforderung
(ID `zaehler-<uuid>`), Kategorie `.zaehlerstand`. Plus einen
Sonderfall `plausi-wmz` (WMZ-Summen-Plausi).

`zaehlerStatus(_, periode:)` berechnet Status:

| Bedingung | Status | Hinweis |
|---|---|---|
| Keine Stände in Periode | `.offen` | „Anfangs- und Endstand fehlen" |
| `erfasstAm == nil` für alle | `.offen` | „Stände in Periode vorhanden, aber nicht aktiv erfasst" |
| Nur ein Stand erfasst | `.teilweise` | „Nur ein Stand erfasst, Endstand fehlt" |
| Mindestens ein Stand ohne `erfasstAm` | `.teilweise` | „N Stand ohne Bestätigung" |
| Endstand < Anfangsstand | `.teilweise` | „Rücklauf: …" |
| 2+ Stände, alle erfasst, kein Rücklauf | `.erfuellt` | — |

Sprungziel: `.zaehlerstandErfassen(zaehlerId: z.id)`.

**WMZ-Plausi** (`plausi-wmz`): Sonderfall. Heuristik §9 HeizkostenV —
WMZ-Summe soll 85–115 % des Gas-Heizanteils sein. Schwere
`.warnung`, blockiert nie. Wird in der Kachel-Listen-Sektion
bewusst **ausgeblendet** (analog Home-„Nächste Schritte").

`KachelansichtView.zaehlerProzent` ruft
`VollstaendigkeitsPruefung.completionProzent(_, kategorie: .zaehlerstand)`
auf, nach dem Filtern von `plausi-wmz`.

## 6. Tap-Einstieg heute

`KachelansichtView.swift` — für die Zählerstände-Kachel derselbe
Platzhalter wie bei den anderen (außer Stammdaten, die neu
gelinkt sind):

```swift
KachelCard(
    titel: "Zählerstände",
    icon: "gauge.medium",
    prozent: zaehlerProzent,
    onTap: { aktiveKachelNotiz = platzhalterText("Zählerstände") }
)
```

Öffnet `KachelPlatzhalterSheet` mit „folgt im nächsten Task"-Text.

Dasselbe Muster wie Stammdaten-Kachel vor dem Rebuild: Der
Folgetask ersetzt den `onTap`-Handler durch einen
`NavigationLink { ZaehlerstaendeView() }`.

## 7. Was fehlt komplett

### 7.1 Eigener Kachel-Screen „ZaehlerstaendeView"

Der neue Screen existiert nicht. Optionen für die Implementierung:

- **Variante A — Kopie der ZaehlerView:** Die bestehende `ZaehlerView`
  (Tab-Content) hat exakt das Layout, das das Zielbild beschreibt —
  Warn-Card oben, Medium-Sections, Tap → Erfassung. Der Kachel-
  Screen könnte sie als Unter-View aufrufen (mit angepasster
  Navigation — aus dem Kachel-Kontext braucht es keine TabBar-
  Rückkehr).
- **Variante B — Eigener Rebuild:** Schlanker, nur auf die aktive
  Periode fokussiert (ZaehlerView zeigt Stände zu beliebigen
  Zeiten, der Kachel-Screen könnte nur „Anfang + Ende der aktuellen
  Periode" zeigen).

Empfehlung: Variante A mit minimalem Wrapper, damit die Components
nicht zweimal gepflegt werden.

### 7.2 Fortschrittsbalken oben

Der Kachel-Screen braucht einen Fortschrittsbalken (analog
`StammdatenView`). `ZaehlerView` hat aktuell nur die Warn-Card,
aber keinen Prozent-Balken. Muss neu gebaut werden.

### 7.3 Kamera-Flow für Zählerstand

Aktuell: nur manuelle Eingabe. Das Zielbild enthält keine
explizite Foto-Anforderung, aber die Spec in CLAUDE.md benennt
ihn als Phase-1-Feature („Custom AVFoundation-Kamera-View mit
Tap-to-Focus, Long-Press-to-Lock, Pinch-Zoom, Blitz-Toggle,
Guide-Rahmen"). Stufe-2 könnte den Foto-Upload im
`ZaehlerstandErfassenView` nachziehen (einfacher PhotoPicker
oder VisionKit-Camera-Flow), aber das ist Scope-Creep gegenüber
dem Kachel-Task. Empfehlung: **nicht in Stufe 2**, separater
Task.

### 7.4 Status-Dot pro Zähler

Das Zielbild (Punkt 4) nennt einen Status-Dot grün/gelb/rot
pro Zähler. `MeterReading` rendert bereits einen `StatusDot`
pro Messzelle (Anfang / Ende). Für eine Zähler-weite Ampel
(nur EIN Dot pro Row) muss die Status-Logik aggregiert werden:
`.erfuellt` → grün, `.teilweise` → gelb, `.offen` → rot. Das
kommt direkt aus `zaehlerStatus(_:periode:)`.

### 7.5 Bottom-CTA „Zählerstand erfassen"

Das Zielbild verlangt einen Button unten. Bei welchem Zähler
soll er starten? Zwei mögliche UX-Pfade:

- **Pfad A:** Öffnet einen Zähler-Picker (Sheet mit allen offenen
  Zählern) → Auswahl → Erfassung
- **Pfad B:** Öffnet direkt die Erfassung für den nächsten
  offenen Zähler (wie die Warn-Card heute macht) — und wenn
  alle erfasst sind, wird der Button zu „Alles erfasst ✓" oder
  versteckt

Empfehlung: Pfad B, konsistent mit dem bestehenden Warn-Card-
Verhalten.

---

## 8. Offene Design-Fragen für Stufe 2

1. **Variante A vs. B** für den Screen-Aufbau? Empfehlung: A
   (bestehende ZaehlerView wiederverwenden, nur Chrome-Wrapper
   tauschen und Fortschrittsbalken davor setzen).
2. **Fortschritts-Balken-Formel:** Identisch zur Stammdaten-
   Kachel (`completionProzent` der Kategorie) — `plausi-wmz`
   rausfiltern? Ja, wie im Home-Ring.
3. **Zähler-weiter Status-Dot:** Eine Ampel pro Row
   (Zielbild) ODER zwei StatusDots pro Zelle (heutiges
   `MeterReading`)? Zielbild sagt eins, Layout sagt zwei —
   beides gleichzeitig wäre Rauschen. Empfehlung: Zelle-Dots
   behalten (MeterReading-Komponente), zusätzlich einen
   Row-Leading-Dot an der ScopePill verzichten.
4. **Bottom-CTA — Pfad A oder B?** Empfehlung: B (direktes
   Erfassen des nächsten offenen Zählers). Falls alle erfasst
   sind: Button wird zu „Alle Stände aktuell", nicht entfernt.
5. **Kamera-Integration in Stufe 2 einbauen?** Empfehlung:
   **nein** — getrennter Task. Der Kachel-Screen selbst braucht
   sie nicht, um „auf einen Blick"-Tauglichkeit zu erreichen.
