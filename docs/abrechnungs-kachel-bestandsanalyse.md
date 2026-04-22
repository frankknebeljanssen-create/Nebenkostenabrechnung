# Abrechnungs-Kachel — Bestandsanalyse (Stand 2026-04-22, Commit 28aa4af)

Grundlage für den Kachel-Rebuild (Stufe 2). Kein Code — nur
Inventar und Abgleich gegen das neue Ziel.

## Zielbild (zur Orientierung, noch nicht gebaut)

`AbrechnungsKachelView` — Kachel-Screen mit:

1. `[← Zurück] [Abrechnung]`
2. Großer Status-Block:
   - GRÜN „Bereit" wenn 100 % Completion
   - ORANGE „X Punkte fehlen noch" mit Liste, was fehlt
3. Pro Wohneinheit eine Card:
   - Mieter-Name, Saldo-Vorschau (Nachzahlung / Guthaben)
4. Button „Abrechnung erstellen" — nur aktiv bei 100 %
5. Bereits erstellte Abrechnungen darunter als Archiv

---

## 1. Existierende Views

### Tab-Root
- [`AbrechnungenView`](NebenkostenApp/NebenkostenApp/UI/Abrechnungen/AbrechnungenView.swift) — der Tab-Root. Sehr weit ausgebaut:
  - **Kennzahlen-Card** oben: `PeriodStatsBlock` mit „Berechenbar"-Count + „Offen"-Count über alle Perioden. Tap auf „Vollständigkeit prüfen" → `InspektorPlatzhalter`.
  - **Perioden-Liste**: Pro Periode eine Card mit drei Zuständen — `berechenbar` (Einheit-Rows mit Saldo, StatusPill grün), `blockiert` (oben Warn-Zeile + bis zu 4 Anforderungs-Rows mit Sprungziel + Link zum Inspektor), `leer` (kein aktives Mietverhältnis).
  - **Row-Tap öffnet** `AbrechnungDetailView` mit berechneter `Mieterabrechnung` + echter Periode + Immobilie + User für PDF/Mail/Drucken.

### Detail + PDF / Mail / Drucken
- [`AbrechnungDetailView`](NebenkostenApp/NebenkostenApp/UI/Abrechnungen/AbrechnungDetailView.swift) — Spec-konformes Hero-Card mit Saldo, Positionen, §35a, ActionBar (PDF-Vorschau, Mail, Drucken). Alles funktioniert — wir haben's vor wenigen Commits verdrahtet.
- [`PDFVorschauSheet`](NebenkostenApp/NebenkostenApp/UI/Abrechnungen/PDFVorschauSheet.swift) — async PDF-Generierung + PDFKit-Vorschau + ShareLink.
- [`AbrechnungsMailSheet`](NebenkostenApp/NebenkostenApp/UI/Abrechnungen/AbrechnungsMailSheet.swift) — MFMailCompose mit PDF-Attachment.
- [`PeriodeEditView`](NebenkostenApp/NebenkostenApp/UI/Abrechnungen/PeriodeEditView.swift) — Edit / Neu für `Abrechnungsperiode` (von/bis).

### Phase-0 / Legacy
- [`AbrechnungVorschauView`](NebenkostenApp/NebenkostenApp/UI/Abrechnungen/AbrechnungVorschauView.swift) — ältere Vorschau pro Periode mit Status-Switch (bereit/blockiert/leer), Navigation zu MieterAbrechnungsDetailView. Wird aktuell nur aus dem Objekt-Tab (Phase 0) gerufen — nicht im neuen Tab-Root.
- [`MieterAbrechnungsDetailView`](NebenkostenApp/NebenkostenApp/UI/Abrechnungen/MieterAbrechnungsDetailView.swift) — Phase-0-Form mit PDF-Erstellen-Button + ShareLink. Delegiert jetzt an `PDFAbrechnungsKontext` (DRY mit dem neuen Pfad).
- [`AbrechnungenTabRoot`](NebenkostenApp/NebenkostenApp/UI/Abrechnungen/AbrechnungenTabRoot.swift) — Phase-0-Wrapper, heute nicht mehr aktiv.
- [`WarnungsSheet`](NebenkostenApp/NebenkostenApp/UI/Abrechnungen/WarnungsSheet.swift) — Warnungs-Liste mit „Fortfahren / Abbrechen"-Actions, ruft bei Ausfall `speichereAuditLog` + `erzeugePDFWirklich`.

### Relevante Services / Helper
- `AbrechnungsService.aggregiere(periode:immobilie:) throws` — zentraler Berechnungs-Call. Wirft `AbrechnungsBlocker.fehlendeDaten(...)` sobald ein Blocker aus `VollstaendigkeitsPruefung` offen ist. Liefert sonst `[Mieterabrechnung]`.
- `PDFAbrechnungsKontext.baue(...)` + `PDFGenerator.generiereAbrechnungsPDF(context:)` — Mustache-Template-Renderer → `Data` → temp-File → PDFKit.
- `VollstaendigkeitsPruefung.pruefe(immobilie:periode:)` — liefert alle Anforderungen (Stammdaten + Zähler + Rechnung + WMZ-Plausi-Warnung).

---

## 2. Abrechnungs-Flow heute

### Happy Path (alles erfüllt)

1. User landet im `AbrechnungenView`-Tab.
2. `AbrechnungsService.aggregiere` läuft pro Periode. Kein Throw → `.berechenbar(Mieterabrechnungen)`.
3. Pro Mieter-Row im Card zeigt Saldo + StatusPill (grün „Bereit").
4. Tap auf Row → `AbrechnungDetailView`.
5. Im Detail: Hero-Card mit Saldo, Positionen, §35a-Card, ActionBar (PDF-Vorschau, Mail, Drucken).
6. PDF-Erzeugung läuft über `PDFGenerator.generiereAbrechnungsPDF` (Mustache + WKWebView → A4-PDF).
7. Mail-Versand über MFMailCompose mit PDF-Attachment + Mieter-Email als Empfänger.

### Blockiert

1. `AbrechnungsService.aggregiere` wirft `AbrechnungsBlocker.fehlendeDaten(offeneAnforderungen: [AnforderungMitStatus])`.
2. Im Tab-Root: Periode-Card zeigt StatusPill „Daten fehlen" (rot) + Top-4 Anforderungen als sprungfähige Rows.
3. Tap auf Anforderung → Router → passendes Sprungziel (Einstellungen, Zähler, Rechnungs-Kostenart, Vorauszahlung).
4. User korrigiert, zurück in den Tab, Prüfung läuft neu.

### Vollständigkeits-Prüfung

Aus CLAUDE.md: drei Abrechnungs-Modi sind konzipiert (Final / Vorschau / Prognose), **aber aktuell nur Final-PDF**. „Vorschau"-Button ist eigentlich auch der PDF-Vorschau — identisches Ergebnis, kein Watermark-Flag.

---

## 3. Was blockiert die Abrechnung?

`VollstaendigkeitsPruefung.pruefe()` erzeugt Anforderungen mit
`schwere: .blocker | .warnung`. `AbrechnungsService.aggregiere`
filtert nur auf `blockiertBerechnung` (blocker + status == .offen):

| Kategorie | Regel | Schwere |
|---|---|---|
| Stammdaten | Gesamtfläche > 0 | Blocker |
| Stammdaten | Einheit-Flächen > 0 | Blocker |
| Stammdaten | Aktives MV pro nicht-leerer Einheit | Blocker |
| Stammdaten | `vorauszahlungErfasst == true` (auch bei 0 €) | Blocker |
| Stammdaten | Periode `von < bis` | Blocker |
| Stammdaten | Energieausweis vorhanden | Warnung (nicht blockend) |
| Stammdaten | Grundsteuer-Bescheid vorhanden | Warnung (nicht blockend) |
| Zähler | Anfang + Ende in Periode erfasst | Blocker |
| Zähler | WMZ-Plausi in Toleranz 85-115 % | Warnung |
| Rechnung | Mindestens eine Rechnung je aktiver Kostenart | Blocker |
| Rechnung | Keine `.aiVorschlag`-Rechnungen unvalidiert | Blocker |
| Rechnung | §35a-Kostenart hat Lohnanteil (bei Bedarf) | Warnung |

Warnung-Level-Anforderungen (Energieausweis, Grundsteuer, WMZ) blockieren die Abrechnung NICHT — werden nur in der Warn-Card des `AbrechnungDetailView` gelistet.

---

## 4. PDF-Generierung

```
[User tippt "PDF-Vorschau"]
        ↓
PDFAbrechnungsKontext.baue(abrechnung, immobilie, user, periode)
    → [String: Any] Mustache-Dict
        ↓
PDFGenerator.generiereAbrechnungsPDF(context:)
    1. Template `abrechnung.html` aus Bundle laden
    2. Mustache.render(template, with: context) → HTML-String
    3. WKWebView.loadHTMLString → Navigation-Delegate-Wait
    4. webView.pdf(configuration:) → Data
        ↓
Temp-File unter `tmp/<vorschlagDateiname>.pdf`
        ↓
PDFVorschauView(url: tempURL) im Sheet + ShareLink
```

Mail-Versand nimmt denselben Data-Block und hängt ihn via `MailAnlage(data:, mimeType: "application/pdf", dateiname:)` an `MailInhalt` → `MailComposer`.

Drucken nimmt `data` als `printingItem` für `UIPrintInteractionController.shared.present(...)`.

Archiv-Persistenz: `Abrechnung.pdfDatei: Data?` existiert im Model (CloudKit external storage), wird aber **heute nicht befüllt**. Jede PDF-Erstellung landet im temp-Verzeichnis und ist nach App-Restart weg. Der Kachel-Rebuild sollte das fixen.

---

## 5. Tap-Einstieg heute

`KachelansichtView.swift:118` — Platzhalter:

```swift
KachelCard(
    titel: "Abrechnung",
    icon: "doc.badge.checkmark",
    prozent: abrechnungProzent,
    onTap: { aktiveKachelNotiz = platzhalterText("Abrechnung") }
)
```

`abrechnungProzent` ist die Gesamt-`completionProzent` aus `VollstaendigkeitsPruefung.zusammenfassung(fuer: anforderungen).completionProzent` — über ALLE Anforderungen der Periode (nicht nur Abrechnungs-spezifisch). 100 % bedeutet: alle Blocker und Warnungen sind resolved.

---

## 6. Was fehlt komplett

### 6.1 Kachel-Screen selbst

Keine `AbrechnungsKachelView`. Muss neu gebaut werden. Kann den bestehenden Tab-Code in wesentlichen Teilen **wiederverwenden**:

- **Status-Hero-Block (Zielbild §2):** neu. Nutzt `VollstaendigkeitsPruefung.zusammenfassung` — bei `bereit` einen großen grünen Card mit „Bereit zum Abrechnen", bei blockiert einen orange Card mit Top-3-Anforderungen.
- **Mieter-Cards (§3):** Liste der `Mieterabrechnung`-Objekte aus `AbrechnungsService.aggregiere`. Pro Einheit Saldo + Vorzeichen + Mieter-Name. Nutzt die bestehende `Row`-Komponente mit `UnitBalken` — Parallelen zum Tab. Tap → `AbrechnungDetailView` (unverändert).
- **„Abrechnung erstellen"-Button (§4):** nur aktiv bei 100 %. Was passiert beim Tap?
  - **Option A:** Springt in den Tab und öffnet die erste Periode. Wenig zusätzliche Arbeit.
  - **Option B:** Erzeugt pro Mieter direkt das PDF und persistiert `Abrechnung.pdfDatei`. Das ist der eigentliche "Final"-Modus.
  - Empfehlung: **Option B** — „Abrechnung erstellen" schafft die `Abrechnung`-Entities im Store. Detail-Tap öffnet dann `AbrechnungDetailView`, die schon die PDF-Sheet-Flows anbietet. Archiv zeigt alle erstellten `Abrechnung`-Records.

### 6.2 Archiv-Persistenz

`Abrechnung.pdfDatei: Data?` wird aktuell nicht gesetzt. Beim Kachel-„Abrechnung erstellen":
1. Für jede Mieterabrechnung ein PDF generieren (wiederverwendete PDFVorschau-Logik).
2. PDF-Data in neue `Abrechnung`-Entity schreiben: `pdfDatei = data`, `erstelltAm`, `periode`, `mietverhaeltnis`, `saldoEuro` etc.
3. Store-Save.
4. Ab dann zeigt das Archiv die Records, Tap öffnet PDF.

### 6.3 Archiv-Sektion

„Bereits erstellte Abrechnungen darunter als Archiv" (Zielbild §5). Query über `Abrechnung`-Entities sortiert nach `erstelltAm` absteigend. Pro Record eine Row mit Periode, Mieter, Saldo, PDF-Indicator, Tap → PDFVorschauView.

### 6.4 „Abrechnung erstellen" als Batch

Wenn der User den Button tippt, sollen alle Mieter-Abrechnungen der aktiven Periode erzeugt werden. Loop über `AbrechnungsService.aggregiere(...)`-Ergebnis + PDF-Generierung pro Mieter. Dauer: ~1-2 s pro PDF. Die App zeigt Progress-Indikator, async.

### 6.5 Abschluss-Zustand

Nach Batch-Erstellung: `periode.abgeschlossen = true`. Weitere Änderungen an der Periode blockiert (PeriodeEditView kennt das schon). Kachel-Screen zeigt dann „Abgeschlossen am X", kein Button mehr.

---

## 7. Offene Design-Fragen für Stufe 2

1. **Tap auf „Abrechnung erstellen" — Option A (Tab-Sprung) oder B (direkter Batch + Archiv)?** Empfehlung: **B**. Tab-Sprung wäre ein Umweg; der User ist schon in der Kachel-Perspektive, die „finale Abrechnung" soll dort entstehen.
2. **PDF pro Mieter oder eine Gesamt-PDF?** Empfehlung: **pro Mieter**. Das Template ist auf einen Mieter pro PDF ausgelegt; Versand geht dann pro Empfänger.
3. **Archiv-Gruppierung:** nach Periode oder nach Mieter? Empfehlung: **nach Periode**, darunter Mieter. Das entspricht dem Jahres-Rhythmus der Abrechnung.
4. **Status-Hero: Warn-Liste — Top-3 oder -4 Anforderungen?** Empfehlung: **Top-3** (konsistent mit Home-Ring, der auch auf 3 cappt).
5. **Periode wechseln im Kachel-Screen?** Heute wird nur die aktive Periode gezeigt. Wenn mehrere Perioden existieren, soll der User zwischen ihnen wechseln können? Empfehlung: **ja, via Chip-Reihe oben** (aktive Periode hervorgehoben). Falls nur eine Periode: kein Chip.
6. **Inspektor oder Direkt-Links zur Fehler-Behebung?** Heute hat der Tab ein „Vollständigkeit prüfen"-Card, das auf `InspektorPlatzhalter` verweist. Empfehlung: **Direkt-Links** zur Sprungziel-Adresse (wie auf Home), um den User schneller zum Erfassungsort zu bringen.
