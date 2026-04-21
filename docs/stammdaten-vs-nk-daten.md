# Stammdaten vs. NK-laufende Daten — Architektur-Analyse

Stand: 2026-04-21 · Status: Stufe 1 (Bestandsaufnahme, keine Code-Änderungen)

## TL;DR

Die App trennt Stammdaten und NK-laufende Daten **implizit im Datenmodell**
(unterschiedliche Entities) und **explizit im Vollständigkeits-Inspektor**
(`AnforderungsKategorie` mit drei Werten: `stammdaten`, `zaehlerstand`,
`rechnung`). In der UI gibt es keine eigenständige Benennung oder
Zweiteilung der Scan-/Erfass-Flows. Drei Grenzfälle sind heute als
Stammdatum modelliert, gehören aber teilweise zur laufenden Ebene —
allen voran die NK-Vorauszahlung. Die Empfehlung für Stufe 2 fasst
die offenen Entscheidungen unten zusammen.

---

## Analysebasis

Gelesen wurden:

- `NebenkostenApp/Models/DataModel.swift` (alle 14 `@Model`-Entities)
- `NebenkostenApp/Calc/DatenAnforderung.swift` (Kategorie-Enum)
- `NebenkostenApp/Services/VollstaendigkeitsPruefung.swift` (Zuordnung
  der Anforderungen zu den drei Kategorien)
- `NebenkostenApp/Services/MietvertragsExtraktion.swift` (User-Prompt
  für den Scan-Flow — zeigt, welche Felder die App bei Stammdaten-
  Scans anfragt)
- `NebenkostenApp/UI/Home/HomeView.swift`,
  `NebenkostenApp/UI/Shell/EinstellungenSheet.swift`,
  `NebenkostenApp/UI/Shell/InspektorSheet.swift`,
  `NebenkostenApp/UI/Vollstaendigkeit/VollstaendigkeitsInspektorSheet.swift`
  (wie die Unterscheidung heute an den User getragen wird)

---

## STAMMDATEN (ändern sich selten, einmalig pro Entity gesetzt)

### AppUser (Vermieter) — `DataModel.swift:25`
`name`, `anschrift`, `ort`, `email`, `telefon`, `steuerID`, `rolle`,
`iban`, `datenschutzZustimmungAm`, `avvZustimmungAm`

Alles Vermieter-Stammdaten, geändert nur bei Umzug / Rollenwechsel.

### Immobilie (Objekt) — `DataModel.swift:78`
`adresse`, `ort`, `gesamtflaecheM2`, `abrechnungsstartMonat`,
`abrechnungsstartTag`, `heizungsart`, `warmwasserbereitung`

Alles bauliche bzw. vertraglich-vereinbarte Rahmenwerte.
`abrechnungsstart*` definiert den Zyklus, verändert sich praktisch nie.

### Wohneinheit — `DataModel.swift:145`
`bezeichnung`, `flaecheM2`, `nutzungsart`, `selbstnutzung`,
`farbkennungHex`

### Mietverhältnis — `DataModel.swift:188`
Als Stammdaten klassifiziert: `mieterName`, `mieterAnschrift`,
`mieterEmail`, `mieterTyp`, `einzugAm`, `auszugAm`, `anzahlPersonen`

**Grenzfälle in dieser Entity (siehe Abschnitt unten):**
`vorauszahlungMonatEuro`, `vorauszahlungErfasst`,
`vorauszahlungGueltigAb`

### Kostenart / Umlageschlüssel — `DataModel.swift:388`
`bezeichnung`, `betrKvKategorie`, `umlageschluessel`, `paragraph35a`,
`paragraph35aNurLohnanteil`, `aktiv`, `sortierung`

Der Katalog (BetrKV-Kostenarten + Umlageschlüssel) ist Stammdaten
des Objekts.

### Zähler (Gerät) — `DataModel.swift:267`
`seriennummer`, `bezeichnung`, `typ`, `medium`, `einheit`,
`umrechnungsfaktor`, `brennwertKwhProM3`

Das Gerät selbst ist Stammdatum. Seine Ablesungen (`Zaehlerstand`)
sind laufende Daten — saubere Trennung bereits im Modell.

---

## NK-LAUFENDE DATEN (pro Periode, regelmäßig erfasst)

### Zählerstand — `DataModel.swift:323`
`ablesedatum`, `stand`, `erfasstAm`, `quelle`, `foto`, `notizen`

### Rechnung — `DataModel.swift:427`
`lieferant`, `rechnungsnummer`, `rechnungsdatum`, `leistungVon`,
`leistungBis`, `betragBruttoEuro`, `lohnanteilBruttoEuro`,
`verbrauchMenge`, `internerArbeitspreisEuroProKwh`, `anhang`,
`anhangTyp`, `geprueft`, `validierungsStatus`

### Abrechnungsperiode — `DataModel.swift:533`
`von`, `bis`, `abgeschlossen`, `versandtAm`

### Abrechnung (pro Mietverhältnis) — `DataModel.swift:558`
`erstelltAm`, `gesamtkostenEuro`, `vorauszahlungenEuro`, `saldoEuro`,
`steuer35aBetragEuro`, `pdfDatei`

### Abrechnungsposition — `DataModel.swift:762`
`gesamtkostenEuro`, `mieteranteilEuro`, `verteilerschluesselText`,
`sortierung`

### GespeichertesDokument — `DataModel.swift:628`
Belegmetadaten inkl. 3-Ebenen-Pipeline (OCR-Rohdaten → AIVorschlag →
validierte Rechnung). Entity selbst ist laufend, aber die Dokumenten-
Art (Mietvertrag vs. Rechnung) kann auf beiden Ebenen liegen.

---

## GRENZFÄLLE — Empfehlung & Begründung

### 1. NK-Vorauszahlung (`Mietverhaeltnis.vorauszahlungMonatEuro` +
       `vorauszahlungGueltigAb`)

**Heute:** Einzelfeld auf Mietverhaeltnis. Bei Erhöhung wird
überschrieben; `vorauszahlungGueltigAb` speichert ab wann der neue
Wert gilt. Keine Historie.

**Empfehlung: Zwitter — Stamm-Charakter, aber mit laufender Historie.**

- Stamm-Charakter: Die VZ ist eine vertragliche Vereinbarung (Basis-
  Betrag pro Monat, wenige Änderungen im Vertragsleben) und bestimmt
  zusammen mit `einzugAm` die Basis-Vertragsbedingungen.
- Laufender Charakter: In der Abrechnung einer Periode mit VZ-Wechsel
  muss die App den Zeitraum pro-rata rechnen (z.B. 9 × 180 € + 3 ×
  260 €). Das geht nur mit Historie.

**Konsequenz (Stufe 2):** Eigenes `@Model VorauszahlungsStand` mit
`gueltigAb: Date`, `betragEuro: Decimal`, optional `quellDokument: UUID`
(Verweis auf GespeichertesDokument). Mietverhaeltnis bekommt Relation
`[VorauszahlungsStand]`. Die bestehenden Felder auf Mietverhaeltnis
bleiben als „aktueller Stand"-Cache (= letzter Eintrag), damit Views,
die keine Historie brauchen, nicht aufwendiger werden. Additive
Migration, kein Schema-Bruch.

### 2. Mieterhöhung (Kaltmiete und/oder NK-VZ)

**Heute:** Kein dediziertes Feld / Entity. Der Scan-Flow (`MietvertragsExtraktion`)
akzeptiert `vorauszahlungNKVorher` und `kaltmieteVorher` als Extraktions-
Felder, aber beim Übernehmen wird nur `vorauszahlungMonatEuro`
überschrieben. Der alte Wert ist dann weg, das Erhöhungsschreiben hat
keine persistente Spur außer dem gescannten PDF im Dokumenten-Archiv.

**Empfehlung: laufendes Ereignis.**

Eine Mieterhöhung ist zeitlich gebunden (Datum des Schreibens, gesetzliche
Ankündigungsfrist, Gültig-ab-Datum) und hat Beleg-Referenz. Klassisches
laufendes Ereignis.

**Konsequenz (Stufe 2):** `@Model Mieterhoehung` mit `schreibenDatum`,
`gueltigAb`, `betragAlt`, `betragNeu`, `art: .kaltmiete / .nkVorauszahlung`,
`mietverhaeltnis`, `dokument: UUID?`. Koppelt sich mit der VZ-Historie
aus Grenzfall 1: eine Mieterhöhung erzeugt beim Übernehmen automatisch
einen neuen `VorauszahlungsStand`-Eintrag.

### 3. Kaution

**Heute:** Fehlt im SwiftData-Model. Wird von Claude extrahiert
(`MietvertragsExtraktion.kaution`), aber nicht persistiert — der
Wert landet im Analyse-Screen und wird verworfen.

**Empfehlung: Stammdatum pro Mietverhältnis.** Einmalig bei Einzug,
ändert sich nur bei expliziter Anpassung. Feld `kautionEuro: Decimal`
auf Mietverhaeltnis.

### 4. Mieter-Bankverbindung (für Erstattungen)

**Heute:** Fehlt komplett im Model. Ein „SEPA-Mandat / Bankverbindung
fehlt"-Eintrag steht als _empfohlenes_ fehlendes Dokument in
`DokumentAnalyseService.berechneFehlendeDaten`, aber es gibt weder
`mieterIBAN` noch `mieterBank` auf Mietverhaeltnis.

**Empfehlung: Stammdatum.** Felder `mieterIBAN: String`, `mieterBIC:
String`, `bankName: String` auf Mietverhaeltnis.

### 5. Heizungsart / Warmwasserbereitung

**Heute:** Stammdatum auf Immobilie.

**Empfehlung: passt.** Ändert sich nur bei Heizungswechsel (seltenes
Bau-Ereignis).

### 6. Abrechnungsperiode

**Heute:** Eigene Entity (laufend). Der Jahres-Rhythmus selbst ist
Stammdatum (`Immobilie.abrechnungsstartMonat/Tag`).

**Empfehlung: passt.** Periode = laufende Instanz, Rhythmus = Stamm.

---

## Wie unterscheidet die App heute?

### Implizit (sauber)
- **Entity-Grenzen in DataModel.swift**: Stammdaten-Entities
  (Immobilie, Wohneinheit, Mietverhaeltnis, AppUser, Kostenart,
  Zaehler) vs. laufende Entities (Zaehlerstand, Rechnung,
  Abrechnungsperiode, Abrechnung, Abrechnungsposition,
  GespeichertesDokument).

### Explizit im Calc-Layer
- `AnforderungsKategorie` (`DatenAnforderung.swift:16-28`) hat
  drei Werte: `stammdaten`, `zaehlerstand`, `rechnung`.
- `VollstaendigkeitsPruefung` erzeugt für jede Periode die
  Anforderungs-Liste und weist jeder Anforderung ihre Kategorie zu.
- `InspektorSheet` und `VollstaendigkeitsInspektorSheet` rendern
  diese Kategorien als getrennte Blöcke (z.B. „Stammdaten, die
  fehlen" vs. „Zählerstände").

### Explizit in der UI
- **EinstellungenSheet**: Sections „Objekt", „Mieter &
  Vorauszahlungen", „Umlageschlüssel", „Vermieter" — alles
  Stammdaten-orientiert. Darunter „Daten", „Rechtliches",
  „Über die App".
- **Tab-Bar**: „Zähler" und „Rechnungen" sind dedizierte Tabs für
  laufende Daten.
- **Home-Cards**: zeigen Objekt + Mieter (Stammdaten) und
  Periodenstatus (laufend) in derselben Übersicht — getrennte
  Cards, aber keine beschriftete Aufteilung.

### Wo es FEHLT / unsauber ist

1. **VZ auf Mietverhaeltnis ist ein Kompromiss.** Formal
   Stammdatum-Feld, fachlich mit Historie (s. Grenzfall 1). Heute
   wird der Kompromiss durch `vorauszahlungGueltigAb` + Komplett-
   Überschreibung gemacht — Historie geht verloren.
2. **Kaution + Mieter-Bankverbindung + Mieterhöhungs-Historie**
   fehlen ganz im Model (s. Grenzfälle 2–4), obwohl Claude die
   Werte teilweise extrahiert.
3. **Scan-Flow trennt die beiden Ebenen nicht am Einstieg.** Der
   Button „Neue Daten hinzufügen / ergänzen" im
   `KontextDetailSheet` führt auf ein und denselben
   `AnthropicClient`-Call, egal ob der User einen Mietvertrag
   (Stammdatum) oder eine Rechnung (laufendes Datum) scannt. Der
   `DokumentTyp` wird erst POST-Extraktion sichtbar und in
   `DokumentAnalyseService.baueFelder` / `berechneFehlendeDaten`
   ausgewertet.
4. **Der „Was fehlt"-Block** im Analyse-Screen und im
   Vollständigkeits-Inspektor beruft sich zwar auf die Kategorie-
   Enum, aber die „Was wurde erkannt"-Liste und die „Was fehlt"-
   Liste laufen auf unterschiedlichen Wegen — der Konsistenz-Fix
   (`fix(analyse): Erkannte Felder nicht mehr als fehlend markiert`,
   `commit bd363ec`) kompensiert das erst nachträglich.

---

## Empfehlungs-Priorisierung für Stufe 2

1. **Scharfes UX-Problem zuerst.**
   Mieterhöhungs-Schreiben: beim Übernehmen explizit als „Mieterhöhung"
   kennzeichnen, Historie speichern (auch wenn zunächst als JSON-Feld
   auf Mietverhaeltnis als Low-Risk-Brücke), Alt-Wert sichtbar halten.

2. **Model-Ergänzungen.**
   Kaution und Mieter-IBAN auf Mietverhaeltnis. Beide sind Stammdaten,
   additiv, kein Schema-Bruch.

3. **Architektur-Hygiene (VZ-Historie).**
   Eigenes `VorauszahlungsStand`-Model + Migration bestehender Werte
   als einzelner History-Eintrag mit `gueltigAb = einzugAm`. Setzt
   Empfehlung 1 auf saubere Basis und ermöglicht pro-rata-Rechnung
   für Perioden mit VZ-Wechsel.

4. **UI-Trennung am Scan-Einstieg (optional).**
   Die Card „Neue Daten hinzufügen / ergänzen" in zwei Aktionen
   aufteilen: „Stammdaten aktualisieren (Mietvertrag, Nachtrag,
   Erhöhung)" vs. „Laufende Daten erfassen (Rechnung, Zählerstand,
   Handwerker)". Der Claude-Prompt kann dann typ-spezifisch
   schärfer formuliert werden.

---

Nächster Schritt: User-Entscheidung zu Prioritäten. Erst dann Stufe 2
(Code-Umsetzung).
