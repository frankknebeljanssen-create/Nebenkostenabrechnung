# Dokumente & Rechnungen-Kachel — Bestandsanalyse (Stand 2026-04-22, Commit 41d4221)

Grundlage für den Kachel-Rebuild (Stufe 2). Kein Code — nur
Inventar und Abgleich gegen das neue Ziel.

## Zielbild (zur Orientierung, noch nicht gebaut)

`DokumenteRechnungenView` — Kachel-Screen mit:

1. `[← Zurück] [Dokumente & Rechnungen]`
2. Fortschrittsbalken
3. Scan-Button prominent oben
4. Kategorien (User-Variante):
   - HEIZUNG & WARMWASSER
   - WASSER & ABWASSER
   - STROM
   - MÜLL & STRASSENREINIGUNG
   - VERSICHERUNGEN
   - HAUSMEISTER & GARTENPFLEGE
   - SONSTIGES UMLAGEFÄHIG
   - NICHT UMLAGEFÄHIG
5. Jede Kategorie aufklappbar, zeigt Rechnungen + Status-Pills
6. Tap auf Rechnung → Detail + Foto

---

## 1. Existierende Views

### Rechnungen (Tab)
- [`RechnungenView`](NebenkostenApp/NebenkostenApp/UI/Rechnung/RechnungenView.swift) — der Tab-Root. Sehr weit ausgebaut:
  - Kompakte Perioden-Card oben (Jahr + Zeitraum + N Rechnungen + Summe)
  - Suchfeld (eigener Style, `bgAppCompact`)
  - BetrKV-Gruppen als `CollapsibleSection` pro Kostenart-Rang
  - Rechnungs-Rows: Aussteller + Betrag + Datum/Periode + `StatusPill` („validiert" / „ungeprüft" / „§35a offen")
  - „+ Rechnung manuell hinzufügen" als dashed-Border-Button
  - Sprungziel-Reaktion `.rechnungKostenart(id)`: isoliertes Öffnen der Ziel-Kategorie + ScrollTo
- [`RechnungEditView`](NebenkostenApp/NebenkostenApp/UI/Rechnung/RechnungEditView.swift) — CRUD für Rechnungen, zwei Modi `.neu(immobilie)` + `.bearbeiten(Rechnung)`
- [`RechnungListeView`](NebenkostenApp/NebenkostenApp/UI/Rechnung/RechnungListeView.swift) — Phase-0-Liste, nicht im neuen Tab genutzt
- [`BelegVorschau`](NebenkostenApp/NebenkostenApp/UI/Rechnung/BelegVorschau.swift) — Thumbnail/Preview-Komponente
- `RechnungenListenZiel` — Helper-Enum für Phase-0-Routing

### Belege (Tab)
- [`BelegeView`](NebenkostenApp/NebenkostenApp/UI/Belege/BelegeView.swift) — der Tab-Root. Ebenfalls voll ausgebaut:
  - Kennzahlen-Card oben („Dokumente gesamt / mit OCR / validiert")
  - Monats-Cards (gruppiert nach Jahr-Monat, neueste zuerst)
  - Pro Dokument-Row: Thumbnail (Foto oder PDF-Preview), Dateiname, Typ · Datum · Seitenzahl, Pipeline-`StatusPill`
  - Scan-Entry-Sheet über `ScanEntryView`
  - Tap auf Dokument → entweder `ValidierungsView` (wenn Pipeline-Stage passt) oder PDF-Preview
  - Lösch-Alert mit zweistufiger Bestätigung

---

## 2. Rechnungen vs. Belege — getrennt oder zusammen?

**Heute: zwei getrennte Tabs** mit unterschiedlichen Entities.

| Rechnungen | Belege |
|---|---|
| Entity: `Rechnung` (Model) | Entity: `GespeichertesDokument` |
| Gruppiert nach BetrKV-Kostenart | Gruppiert nach Jahr-Monat |
| Fokus: Geld-Posten für die Abrechnung | Fokus: Scan-Archiv, alle PDFs |
| `Rechnung.kostenart` → Kostenart | `GespeichertesDokument.dokumenttyp` → Enum |
| Fließt direkt in die Abrechnung | Kann in Rechnung übernommen werden |

**Verbindung:** `GespeichertesDokument.rechnungId: UUID?` — wird gesetzt, wenn der User den Scan über `UebernahmeSheet` als Rechnung committet. Umgekehrt gibt es keinen direkten Verweis von `Rechnung` auf ein `GespeichertesDokument` — nur über den `rechnungId`-Lookup.

**Für die neue Kachel:**  Das Zielbild sagt „Dokumente & Rechnungen". Pragmatisch bedeutet das: **Rechnungs-zentrierte Sicht mit Foto-Anbindung**. Die Belege-Sicht (Monats-Archiv) ist eine andere Perspektive, die tabellenartig bleibt. Empfehlung: die Kachel zeigt primär `Rechnung`-Entities in BetrKV-Gruppen; das zugeordnete Dokument (Scan/Foto) erscheint als Thumbnail in der Row. Reine Archiv-Dokumente ohne Rechnungs-Verknüpfung bleiben im Belege-Tab sichtbar.

---

## 3. Rechnungs-Gruppierung heute

**Nach Kostenart, BetrKV-Rang** (`RechnungenView.betrKvDefinition`):

| Rang | Titel (Tab heute) | Mapping zum Zielbild |
|---|---|---|
| 1 | Heizung & Warmwasser | → HEIZUNG & WARMWASSER ✓ |
| 2 | Wasser & Entwässerung | → WASSER & ABWASSER ✓ |
| 3 | Müllabfuhr | → MÜLL & STRASSENREINIGUNG ✓ |
| 4 | Grundsteuer | → SONSTIGES UMLAGEFÄHIG |
| 5 | Gebäudeversicherung | → VERSICHERUNGEN ✓ |
| 6 | Schornsteinfeger | → SONSTIGES UMLAGEFÄHIG |
| 7 | Hausreinigung & Gartenpflege | → HAUSMEISTER & GARTENPFLEGE ✓ |
| 8 | Hauswart | → HAUSMEISTER & GARTENPFLEGE |
| 9 | Allgemeinstrom | → STROM ✓ |
| 10 | Reparatur | → NICHT UMLAGEFÄHIG ✓ |
| 99 | Ohne Kostenart | → SONSTIGES UMLAGEFÄHIG |

**Design-Frage:** Die Tab-View hat 10 feine Gruppen, das Zielbild hat 8 breitere. Das ist eine UX-Entscheidung — für die Kachel reichen die 8 (weniger Scrollen, klarere Kategorien), aber der bestehende `RechnungenView`-Tab mit 10 Gruppen bleibt erhalten. Mapping-Funktion in der Kachel-View.

**Sortierung innerhalb einer Gruppe:** Rechnungsdatum absteigend (neueste zuerst).

**Suche:** Volltext-Suche über Lieferant, Rechnungsnummer, Kostenart-Name, Betrag. Heute nur im Tab, nicht in der Kachel geplant (Kachel = schneller Überblick).

---

## 4. Completion heute — Rechnungs-Anteil

`VollstaendigkeitsPruefung.rechnungsAnforderungen` erzeugt pro aktive `Kostenart` eine Anforderung (ID `rechnung-<uuid>`, Kategorie `.rechnung`). Status-Logik:

| Bedingung | Status | Titel | Sprungziel |
|---|---|---|---|
| Keine Rechnung in Periode | `.offen` | „Rechnung hinzufügen: X" | `.scanMitKostenart(id)` |
| Mindestens eine Rechnung mit `validierungsStatus == .aiVorschlag` | `.offen` | „Rechnung validieren: X" | `.rechnungKostenart(id)` |
| §35a-Kostenart, mindestens eine Rechnung ohne `lohnanteilBruttoEuro` | `.teilweise` | „Lohnanteil ergänzen: X" | `.rechnungKostenart(id)` |
| Mindestens eine ungeprüfte Rechnung (`geprueft == false`) | `.teilweise` | „Rechnung prüfen: X" | `.rechnungKostenart(id)` |
| Alles valide + geprüft | `.erfuellt` | „Rechnung prüfen: X" | `.rechnungKostenart(id)` |

**Kachel-Prozent:** `KachelansichtView.rechnungenProzent` ruft `VollstaendigkeitsPruefung.completionProzent(_, kategorie: .rechnung)` auf. Basis: Anzahl Kostenart-Anforderungen, gewichtet nach Status.

Für den Kachel-Fortschrittsbalken ist das die richtige Zahl — spiegelt direkt, wie viele Kostenarten vollständig + geprüft sind.

---

## 5. Tap-Einstieg heute

`KachelansichtView.swift:112` — Platzhalter:

```swift
KachelCard(
    titel: "Dokumente & Rechnungen",
    icon: "doc.text.magnifyingglass",
    prozent: rechnungenProzent,
    onTap: { aktiveKachelNotiz = platzhalterText("Dokumente & Rechnungen") }
)
```

Wie bei den anderen Kacheln öffnet sich ein `KachelPlatzhalterSheet` mit „folgt im nächsten Task". Der Folgetask ersetzt das durch einen `NavigationLink` auf `DokumenteRechnungenView`.

---

## 6. Was fehlt komplett

### 6.1 Der Kachel-Screen selbst

Es gibt keine `DokumenteRechnungenView`. Muss neu gebaut werden.

**Architektur-Varianten:**

- **Variante A — Dünner Wrapper:** Der neue Screen ist ein `ScrollView` mit Fortschrittsbalken + Scan-Button + `RechnungenView`-ähnlichen Gruppen. Viel Copy-Paste zum bestehenden Tab. Vorteil: 100 % Kontrolle über Layout.
- **Variante B — ZielbildGruppierung neu, Rechnungs-Rows bleiben:** Eigene Kachel-View mit eigener Gruppen-Definition (8 statt 10), aber die Row-Komponente aus `RechnungenView` wird extrahiert und geteilt.
- **Variante C — Wiederverwendung per Parameter:** `RechnungenView` bekommt einen Modus (Tab vs. Kachel) und rendert entsprechend. Mehr Logik in einer View, schwerer wartbar.

Empfehlung: **Variante B.** Die Row-Komponente (`rechnungZeile`) + `pillDaten` werden in `UI/Rechnung/Components/RechnungRow.swift` hochgehoben; die Kachel-View baut ihre eigenen 8 Gruppen mit diesen Rows. Der Tab bleibt unberührt.

### 6.2 Scan-Button als CTA oben

Der `RechnungenView`-Tab hat nur einen dashed-Border-Button „+ Rechnung manuell hinzufügen" unten. Das Zielbild will oben einen prominenten Scan-Button. Quellen:
- `ScanEntryView` existiert und funktioniert (drei Optionen: Kamera / Mediathek / Datei).
- In der Kachel-View oben als primärer Accent-Button: `„Rechnung scannen"` → öffnet `ScanEntryView`.

Der bestehende Home-`scanMitKostenart`-Flow setzt beim Scan-OK eine neue `Rechnung` an. Wir könnten einen ähnlichen Mechanismus für die Kachel einsetzen — aber dort ohne Kostenart-Vorauswahl (User wählt sie in `UebernahmeSheet` selbst).

### 6.3 Foto-Thumbnail in Rechnungs-Rows

Die Bestands-`rechnungZeile` zeigt keine Thumbnails. Das Zielbild sagt „Tap auf Rechnung → Detail + Foto". Der Weg zum Foto:

`GespeichertesDokument` hat `thumbnailPfad: String` + `dateipfadRelativ: String`. Die Verknüpfung `rechnung.id → dokument.rechnungId` muss zur Laufzeit aufgelöst werden (kein direkter Model-Pointer auf der Rechnungs-Seite).

Empfehlung: Helper `static func dokumentFuer(rechnung: Rechnung, in: [GespeichertesDokument]) -> GespeichertesDokument?`. Die Kachel-View hat via `@Query` Zugriff auf alle Dokumente; sie kann pro Rechnung das passende Thumbnail laden. In der Row links ein 40×40-Thumbnail statt gar kein Bild.

### 6.4 Kategorien-Mapping (8 statt 10)

Der bestehende `betrKvRang`-Mapper liefert 10 Ränge. Für die Kachel brauchen wir einen zweiten Mapper `kachelKategorie(rang:) -> KachelKategorie`, der auf 8 Kategorien zusammenzieht. Tabelle in §3 oben.

### 6.5 „Nicht umlagefähig"-Flag

Das Zielbild hat eine eigene Kategorie „NICHT UMLAGEFÄHIG". Heute existiert dafür nur `Rang 10 = "Reparatur (nicht umlagefähig)"`. Aber auch Rechnungen in Rang 99 („Ohne Kostenart") oder Rechnungen, deren Kostenart `paragraph35a`-only-Lohnanteil ist, können für den Mieter nicht umlagefähig sein.

Klare Regel: eine Rechnung ist „umlagefähig", wenn ihre Kostenart gesetzt UND aktiv ist UND Rang ≠ 10. Alles andere fällt in „NICHT UMLAGEFÄHIG". — oder entsprechend der Mapping-Tabelle.

### 6.6 Foto-Viewer im Detail

Tap auf Rechnung → Detail: aktuell öffnet sich `RechnungEditView`. Das Zielbild sagt „Detail + Foto". Zwei Wege:

- **Erweitern:** `RechnungEditView` um eine Preview-Section, die das verknüpfte Dokument anzeigt (Thumbnail + „Anzeigen"-Button → PDFVorschau).
- **Separater Detail-Screen:** Neue `RechnungDetailView` mit Foto oben + Felder. Edit nur auf Swipe oder Tap.

Empfehlung: **Erweitern.** Weniger neuer Code, und der bestehende Edit-Flow funktioniert.

---

## 7. Offene Design-Fragen für Stufe 2

1. **Variante A / B / C** für die Kachel-View? Empfehlung: B (Row-Komponente aus `RechnungenView` extrahieren und teilen).
2. **Kategorien-Mapping** — 8 Gruppen wie im Zielbild, oder 10 wie im Tab? Empfehlung: 8, Mapping-Tabelle aus §3 oben.
3. **Scan-Button oben** — mit oder ohne Kostenart-Vorauswahl? Empfehlung: ohne (User sieht die Liste, wählt in `UebernahmeSheet`).
4. **Foto-Thumbnail in Rows** — immer, oder nur wenn Dokument verlinkt? Empfehlung: nur wenn verlinkt; sonst ein Platzhalter-Icon in Akzent-Farbe.
5. **Detail-View** — `RechnungEditView` um Foto-Section erweitern (empfohlen) oder separater `RechnungDetailView`?
6. **Belege-Tab parallel** — bleibt er bestehen? Empfehlung: ja, als Archiv-Ansicht. Die Kachel ist Rechnungs-zentriert, der Belege-Tab ist Scan-Archiv-zentriert.
