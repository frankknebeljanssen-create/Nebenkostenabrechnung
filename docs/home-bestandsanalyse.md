# Home-Screen — Bestandsanalyse (Stand 2026-04-22, Commit d203b7c)

Grundlage für den Home-Screen-Rebuild (Stufe 2). Kein Code in diesem
Schritt — nur Inventar und Abgleich gegen das neue Ziel.

## Zielbild (zur Orientierung, noch nicht gebaut)

1. KontextHeader (unverändert, lebt im `AppShellChrome`)
2. Completion-Ring mit Prozent (groß, zentral, rot→orange→grün)
3. Nächste Schritte (max. 3–4 Items, jedes direkt tappbar →
   zuständiger Screen, ohne Umweg über die Kachelansicht)
4. CTA „Zur Kachelansicht" — immer sichtbar
5. CTA „Abrechnung erstellen" — nur bei 100 % Completion

Kein Scrollen nötig — alles auf einen Blick.

---

## 1. Bestehende Komponenten

Alle Home-Dateien liegen in `NebenkostenApp/UI/Home/`. Kein
Unterordner `Components/` — die Bausteine liegen flach daneben.

### Aktiv im Home-Render

| Datei | Rolle |
|---|---|
| `HomeView.swift` | Root-View des Übersicht-Tabs. Orchestriert die vier Cards unten, hält Sheets (ScopePicker, Einstellungen, Abrechnungsdaten, KontextDetail). |
| `WohneinheitCarousel.swift` | Horizontales `.page`-TabView: Seite 0 = „Gesamtes Objekt", 1…N = Einheiten nach Geschoss-Rang. Darunter `PaginationDots`. Swipe schreibt den Scope in `ScopeManager`, Tap öffnet `KontextDetailSheet`. **Enthält die einzige Adresse auf dem Home-Screen** (`zeigeAdresseOben: false` in AppShellChrome). |
| `AbrechnungsDatenSheet.swift` | Datei mit zwei Einheiten: (a) `AbrechnungsdatenCard` — Nav-Card mit Icon + „Belege · Zähler · Vorauszahlungen", (b) `AbrechnungsDatenSheet` — sheet mit drei Sprungzielen. |
| `HomeStatusCard.swift` | Kennzahlen-Card: „Zählerstände X/Y", „Rechnungen geprüft X/Y", „Dokumente N erfasst", plus `StatusPill` („Bereit" / „In Arbeit" / „Daten fehlen"). Nutzt `VollstaendigkeitsPruefung`. |
| `NaechsterSchrittCard.swift` | Unter der Status-Card. Zwei Zustände: unvollständige Liste aller nicht-erfüllten Anforderungen mit Sprungziel (Button-Rows, durch `DividerLine` getrennt), oder primärer CTA „Abrechnungsdokumente erstellen" bei 100 %. |
| `EmptyStateCard.swift` | Wenn `immobilien.isEmpty`. Zeigt CTA „Erstes Objekt anlegen" → öffnet EinstellungenSheet. |
| `KontextDetailSheet.swift` | Sheet, das auf Row-Tap der Carousel-Card öffnet. Stammdaten-Detail pro Scope + HV-Scan-Einstieg. **Kein Home-Rendering-Baustein** — nur Konsument der Home-Taps. |

### Dead Code im Home-Ordner

| Datei | Status |
|---|---|
| `HomeHeaderView.swift` | Ungenutzt (ehem. große Screen-Überschrift, entfiel beim Home-Refactor). |
| `CurrentPropertyCard.swift` | Ungenutzt (Phase-0-Card). |
| `CurrentUnitCard.swift` | Ungenutzt (Vorgänger der `WohneinheitCard` im Carousel). |
| `AnalyseBefundView.swift` | Wird vom Scan-Flow gerufen, nicht vom Home selbst. |
| `HVAnalyseBefundView.swift` | dito — HV-Scan-Detail. |

---

## 2. Bleibt / Ersetzen / Entfernen

### Bleibt

- `AppShellChrome` / `KontextHeader` — unberührt laut Zielbild #1.
- `EmptyStateCard` — Leerstaatsfall bleibt gleich, aber im neuen
  Layout möglicherweise inline statt als eigene Card (TBD Stufe 2).
- `VollstaendigkeitsPruefung` + `Sprungziel`-Infrastruktur —
  Datengrundlage bleibt identisch, die neue UI konsumiert sie nur
  anders (Ring + Top-3-Liste statt volle Liste + Kennzahlen).
- `KontextDetailSheet` / Sheets — erreichbar bleiben, nur der
  Öffnungsweg ändert sich (neue Kachel-Ansicht statt Carousel).

### Ersetzen

- `WohneinheitCarousel` → **entfällt auf Home** (die Kachel-Wahl
  wandert auf die separate „Kachelansicht", erreichbar über den
  neuen CTA #4). Der Scope-Wechsel bleibt nötig, passiert aber
  weiter via `ScopePickerSheet` (bereits über Chrome-Adress-Button
  erreichbar) oder künftig via die Kachelansicht.
- `HomeStatusCard` → **Kennzahlen-Block entfällt**. Das neue
  Zielbild verlangt nur einen zentralen **Completion-Ring mit
  Prozent** (#2). Die Detail-Zahlen „X/Y Zählerstände" etc. sind
  für den Einstieg too much und duplizieren, was die Nächste-
  Schritte-Liste sowieso zeigt.
- `NaechsterSchrittCard` → **gekürzt auf max. 3–4 Items ohne
  Hinweistexte** (#3). Aktuell: volle Liste aller nicht-erfüllten
  Anforderungen inkl. `anforderung.hinweis` in einer zweiten
  Textzeile. Zielbild: nur Titel, direkt tappbar. Der `chevron`
  rechts bleibt.
- Der 100%-CTA „Abrechnungsdokumente erstellen" wandert aus der
  NaechsterSchrittCard nach unten in den stabilen Button-Bereich
  (#5), ist nicht mehr nur sichtbar wenn man bis zur
  NaechsterSchritt-Card scrollt.

### Entfernen

- `AbrechnungsdatenCard` + `AbrechnungsDatenSheet` →
  **komplett weg**. Das Sheet bietet drei Sprungziele (Belege,
  Zähler, Vorauszahlungen) und ist damit eine schwächere
  Variante der geforderten „Nächste Schritte"-Direkt-Taps (#3).
  Jede relevante Aktion erreicht der User besser über die
  Anforderungs-Zeile oder den CTA „Zur Kachelansicht".
- `HomeHeaderView.swift`, `CurrentPropertyCard.swift`,
  `CurrentUnitCard.swift` → Dead Code, im selben Commit wie der
  Rebuild entfernen.

---

## 3. Completion — heute

**Kein zentraler CompletionService.** CLAUDE.md nennt einen
`Services/CompletionService.swift` (Abschnitt „Completion-Tracking"),
die Datei existiert so aber nicht. Die Doku ist veraltet — der
Anforderungs-Status-Flow hat sie abgelöst.

**Tatsächliche Quelle:**
`Services/VollstaendigkeitsPruefung.pruefe(immobilie:periode:)`
liefert `[AnforderungMitStatus]`. Jede Anforderung hat:

- `status: AnforderungsStatus` — `.erfuellt / .teilweise /
  .offen / .nichtErwartet`
- `schwere: Schwere` — `.blocker` (Default) / `.warnung`
- `sprungZiel: Sprungziel?`
- `hinweis: String?`

**Home nutzt das so (`HomeStatusCard` + `NaechsterSchrittCard`):**

- Kein Prozent-Wert wird heute berechnet oder angezeigt. Die
  StatusPill ist binär-ternär („Bereit" / „In Arbeit" / „Daten
  fehlen"), abgeleitet aus Counts der Offen/Teilweise-
  Anforderungen.
- Das Endgeld-CTA in `NaechsterSchrittCard` erscheint, wenn
  `unvollstaendig.isEmpty` — also keine Anforderung mit
  Sprungziel und Status != `.erfuellt` / `.nichtErwartet`. Das
  entspricht „100 %" im Sinne des Zielbilds #5.

**Für den Rebuild:**
Der Prozent-Wert muss neu abgeleitet werden. Naheliegend:

```
prozent = erfuellt / (erfuellt + teilweise + offen)
```

wobei `nichtErwartet` aus Zähler und Nenner rausfällt. `teilweise`
zählt als voll offen (konservative Lesart: „der Schritt ist nicht
abgeschlossen"). Die Berechnung gehört in einen kleinen, puren
Helper — nicht direkt in die View — damit die Ring-Animation
testbar ist.

---

## 4. „Nächste Schritte" — heute

**Vollständig dynamisch**, keine statischen Listen. Quelle:
`NaechsterSchrittCard.unvollstaendig` — gefiltert aus den
Anforderungen der aktiven Periode:

```swift
anforderungen.filter {
    $0.sprungZiel != nil
    && $0.status != .erfuellt
    && $0.status != .nichtErwartet
}
```

Jedes Item rendert als Button mit Titel, `hinweis`-Untertitel
und `chevron.right`. Tap ruft den Router:
`router.springe(zu: anf.sprungZiel!)`.

Reihenfolge = Reihenfolge aus `VollstaendigkeitsPruefung`:

1. Stammdaten (Gesamtfläche, Einheiten, Mieter, Vorauszahlung, Periode)
2. Zählerstände (pro Zähler)
3. Rechnungen (pro aktiver Kostenart)
4. WMZ-Plausi (nur Warnung, nicht blockend)

**Für den Rebuild (Zielbild #3):**

- Gleiche Datengrundlage bleibt — nur Präsentation ändert sich.
- Auf **max. 3–4 Items** begrenzen. Priorisierung offen: die
  natürliche Reihenfolge der Pruefung (Stammdaten zuerst, dann
  Zähler, dann Rechnungen) ist ein guter Default. Alternative:
  Blocker vor Warnungen, danach Zähler/Rechnungen nach Anzahl.
  Empfehlung: natürliche Reihenfolge behalten + Blocker-Priorität
  nur wenn `schwere: .blocker` vorliegt.
- **Hinweistexte entfallen** — nur `anforderung.titel`, kein
  zweites Text-Feld. Die bestehenden Titel sind bereits aktions-
  orientiert („Rechnung hinzufügen: Grundsteuer", „Zählerstand
  erfassen: Strom EG"), das funktioniert ohne Untertitel.

---

## 5. Passt der Screen heute ohne Scrollen?

**Nein.** Der Home ist aktuell in eine `ScrollView` verpackt
(`HomeView.swift:80`) und produziert mehr Inhalt, als auf einen
iPhone-Standard-Screen passt. Stapel heute:

1. KontextHeader (Chrome, ~88 pt)
2. WohneinheitCarousel inkl. `frame(height: 160)` + Dots + Card-
   Padding → ~180 pt
3. AbrechnungsdatenCard → ~72 pt
4. HomeStatusCard (drei Kennzahlen-Zeilen + StatusPill) → ~160 pt
5. NaechsterSchrittCard (Titel + 5-10 Anforderungs-Zeilen mit
   jeweils 2 Text-Zeilen und Divider) → **elastisch 200–500 pt+**
6. Vertikale Abstände 12 pt + Top-/Bottom-Padding (12 / 40)

Auf einem iPhone 15/17 mit ~850 pt Content-Height braucht
allein die NaechsterSchrittCard in voller Ausfüllung schon den
restlichen Platz. Bei einer Stammdaten-leeren Immobilie mit 10+
offenen Anforderungen entsteht ein 1 200–1 500 pt hoher Screen.

**Gründe im Detail:**

- NaechsterSchrittCard ist **unbegrenzt** — pro offener
  Anforderung mindestens eine Zeile mit 2 Text-Zeilen + Divider.
- HomeStatusCard hat drei feste Zeilen, selbst wenn die Daten
  leer sind — kein Collapse, kein „Sparen".
- AbrechnungsdatenCard nimmt Platz, den sie nicht braucht,
  weil die drei Sprungziele auch über die Tab-Bar erreichbar
  sind.

**Konsequenz für den Rebuild:**

Das Zielbild verlangt eine fixe, nicht-scrollende Höhe. Das
bedeutet:

- Ring + Prozent als zentraler Hero-Block (fester Footprint,
  z.B. 180–220 pt).
- Max. 3–4 Items in der „Nächste Schritte"-Liste (fester Footprint:
  ~3×50 pt = 150 pt).
- Zwei CTAs unten fix (je ~48 pt, insgesamt ~108 pt mit
  Abstand).
- Gesamt-Content ~480–520 pt — passt unter den Chrome-Header
  auf alle unterstützten iPhones (inkl. iPhone 13 mini
  600 pt Content-Height, knapp, aber ohne Scroll).

Die `ScrollView` wird also durch eine `VStack` mit `Spacer()`
ersetzt, und die Anforderungs-Liste bekommt ein hartes Cap.

---

## Offene Design-Fragen für Stufe 2

1. **Prozent-Formel:** `erfuellt / total` oder mit Teilweise-
   Gewichtung (z.B. `(erfuellt + 0.5×teilweise) / total`)?
2. **Farbschwellen** des Rings: rot < 50 %, orange < 90 %, grün
   ≥ 90 %? Oder strenger (grün erst bei 100 %, damit der CTA
   #5 synchron zum Farbwechsel erscheint)?
3. **Auswahl der Top 3-4:** natürliche Reihenfolge der Pruefung
   vs. Blocker-first. Empfehlung in #4 oben.
4. **Scope-Wechsel vom Home:** Heute via Swipe auf dem
   Carousel. Mit dem Entfall: Scope-Picker per Chrome-Adress-
   Button bleibt der einzige Weg vom Home aus. OK?
5. **CTA „Zur Kachelansicht":** existiert die Kachelansicht
   schon als separater Screen, oder ist das ein neuer Route-
   Zielpunkt, der erst in Stufe 2 implementiert wird?
