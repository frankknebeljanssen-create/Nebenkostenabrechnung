//
//  UniversellerAnalyseScreen.swift
//  NebenkostenApp — UI/Scan
//
//  Post-Scan-Hub (Stage 1): drei klare Bloecke fuer den User.
//
//    Block 1  Typ-Badge + Metadaten (Dokument-Datum, Absender) +
//             Konfidenz-Warnung (< 85 %).
//    Block 2  Zuordnung zu Immobilie + Wohneinheit. Drei Faelle:
//               a) Auto-Zuordnung eindeutig  → gruene Bestaetigung.
//               b) Mehrere Kandidaten       → Inline-Picker.
//               c) Kein Treffer             → gelbe Warn-Card mit
//                  „Manuell zuordnen" / „Verwerfen".
//    Block 3  Was wird uebernommen (inline editierbar) vs
//             Was ist nur Kontext (read-only).
//
//  Die eigentliche Persistenz ist typ-abhaengig:
//    - `rechnung` / `bescheid` / Handwerker → oeffnet `RechnungEditView`
//      mit den erkannten Feldern (spaeter: vorbefuellt; heute: leer,
//      weil RechnungEditView noch keinen Init-mit-Feldern hat).
//    - `energieausweis` / `grundsteuerbescheid` → verknuepft Dokument
//      mit der gewaehlten Immobilie (produktiv).
//    - Alle anderen → Hinweis-Sheet „Bearbeitungs-UI folgt".
//

import SwiftUI
import SwiftData

struct UniversellerAnalyseScreen: View {
    let dokument: GespeichertesDokument
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ScopeManager.self) private var scope
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var ergebnis: ScanKlassifikationsErgebnis?
    @State private var laeuft = true
    @State private var klassifikationsFehler: String?

    /// User-Override der Auto-Zuordnung. Wenn nil: Auto-Match gilt.
    /// Wenn gesetzt: Picker-Auswahl gewinnt.
    @State private var manuelleAuswahl: ScanZuordnung.Kandidat?

    /// Pro Quell-Feld der vom User editierte Wert. Nur hier — die
    /// Original-Felder aus `ergebnis.felder` bleiben unveraendert,
    /// damit der User „zuruecksetzen" koennte (Follow-up).
    @State private var editierteFelder: [String: String] = [:]

    /// Bool-State: Welche Target-Felder uebernehmen wir? Default true.
    /// User kann pro Feld ab-/anhaken.
    @State private var feldAktiv: [String: Bool] = [:]

    @State private var zeigeTypPicker = false
    @State private var zeigeManuellerPicker = false
    @State private var zeigeVerwerfenAlert = false
    @State private var zeigeAbschlussAlert = false
    @State private var abschlussText = ""

    // Reaktive Flags fuer Banner + Diagnose.
    @AppStorage(ScanKlassifikator.debugFlagKey)
    private var devModusAktiv: Bool = false
    @AppStorage("anthropic.apiKey")
    private var apiKeyRoh: String = ""
    private var apiKeyDa: Bool {
        !apiKeyRoh.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Abgeleitet

    private var typ: Dokumenttyp { ergebnis?.typ ?? .unbekannt }
    private var felder: [String: String] { ergebnis?.felder ?? [:] }
    private var konfidenz: Double { ergebnis?.konfidenz ?? 0 }

    /// Auto-Zuordnungs-Ergebnis (wird bei laufendem Ergebnis neu
    /// berechnet). `nil` wenn kein `ergebnis` existiert.
    private var autoZuordnung: ScanZuordnung.Ergebnis {
        guard let erg = ergebnis else { return .nichtGefunden }
        return ScanZuordnung.finde(
            typ: erg.typ,
            felder: erg.felder,
            immobilien: immobilien
        )
    }

    /// Effektiver Kandidat fuer die Uebernahme (Manuell > Auto).
    private var effektiverKandidat: ScanZuordnung.Kandidat? {
        if let manuell = manuelleAuswahl { return manuell }
        if case .gefunden(let k) = autoZuordnung { return k }
        return nil
    }

    private var effektiveImmobilie: Immobilie? {
        guard let k = effektiverKandidat else { return nil }
        return immobilien.first(where: { $0.id == k.immobilieID })
    }

    private var effektiveEinheit: Wohneinheit? {
        guard let k = effektiverKandidat,
              let bez = k.einheitBezeichnung,
              let immo = effektiveImmobilie else { return nil }
        return (immo.wohneinheiten ?? [])
            .first(where: { $0.bezeichnung == bez })
    }

    private var zieleFuerTyp: [ScanZielFeld] {
        ScanFeldMapping.ziele(typ: typ)
    }

    /// Target-Felder, die auch im erkannten `felder`-Dict auftauchen —
    /// das sind die uebernehmbaren.
    private var uebernehmbareFelder: [ScanZielFeld] {
        zieleFuerTyp.filter { felder.keys.contains($0.quellKey) }
    }

    /// Nicht-Target-Felder aus der Erkennung — nur Kontext.
    private var kontextFelder: [(key: String, wert: String)] {
        let targetKeys = Set(zieleFuerTyp.map(\.quellKey))
        return felder
            .filter { !targetKeys.contains($0.key) }
            .sorted(by: { $0.key < $1.key })
            .map { (key: $0.key, wert: $0.value) }
    }

    private func effektiverWert(_ key: String) -> String {
        editierteFelder[key] ?? felder[key] ?? ""
    }

    /// Liefert den aktuellen Wert im System, der vom Neu-Wert
    /// ueberschrieben wuerde — oder nil, wenn das Feld im Datenmodell
    /// gar nicht existiert (dann ist es ein reiner Neu-Wert, kein
    /// Overwrite). Heute sauber bedient: NK-Vorauszahlung + Mieter-
    /// Stammdaten. Kaltmiete hat in `Mietverhaeltnis` kein Feld, also
    /// kein Alt-Wert — wird in Folge-Tasks ergaenzt, wenn ein
    /// `Mieterhoehung`/`Kaltmietenhistorie`-Entity kommt.
    private func aktuellerSystemWert(fuer key: String) -> String? {
        guard let einheit = effektiveEinheit,
              let mv = (einheit.mietverhaeltnisse ?? [])
                .first(where: { $0.auszugAm == nil }) else {
            return nil
        }
        switch (typ, key) {
        case (.erhoehungsschreiben, "nkVorauszahlungNeu"),
             (.mietvertrag, "nkVorauszahlungEuro"):
            guard mv.vorauszahlungErfasst else { return nil }
            return Formatting.euro(mv.vorauszahlungMonatEuro)
        case (.mietvertrag, "mieter"):
            let n = mv.mieterName.trimmingCharacters(in: .whitespaces)
            return n.isEmpty ? nil : n
        case (.mietvertrag, "einzugAm"):
            return Formatting.datum(mv.einzugAm)
        default:
            return nil
        }
    }

    /// True, wenn mindestens ein aktiv angehaktes uebernehmbares Feld
    /// einen bestehenden Systemwert ueberschreiben wuerde. Steuert den
    /// Bottom-Button-Text („Uebernehmen" vs „Uebernehmen und
    /// aktualisieren").
    private var ueberschreibtBestehend: Bool {
        uebernehmbareFelder.contains { zf in
            guard (feldAktiv[zf.quellKey] ?? true) else { return false }
            guard let alt = aktuellerSystemWert(fuer: zf.quellKey) else { return false }
            return alt != effektiverWert(zf.quellKey)
        }
    }

    /// „Übernehmen" ist nur klickbar, wenn …
    ///  - eine Zuordnung festgelegt ist UND
    ///  - mindestens ein uebernehmbares Feld aktiv ist.
    private var kannUebernehmen: Bool {
        guard effektiverKandidat != nil else { return false }
        let irgendeinAktiv = uebernehmbareFelder.contains { zf in
            (feldAktiv[zf.quellKey] ?? true)
        }
        return irgendeinAktiv || uebernehmbareFelder.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if devModusAktiv { devModusBanner }
                    if laeuft {
                        analyseLaeuftBlock
                    } else {
                        if let fehler = klassifikationsFehler {
                            fehlerBanner(fehler)
                        }
                        diagnoseCard
                        block1_Erkannt
                        block2_Zuordnung
                        if typ != .unbekannt && !zieleFuerTyp.isEmpty {
                            block3_Uebernahme
                        } else if typ == .unbekannt {
                            typPickerCta
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 100)  // Platz fuer Bottom-Bar
            }
            .background(DesignTokens.bgAppCompact)
            .safeAreaInset(edge: .bottom) {
                if !laeuft { bottomBar }
            }
            .sheetTitelHeader("Dokument einwerfen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen { dismiss() }
                }
            }
        }
        .onAppear {
            print("🟢 UniversellerAnalyseScreen erscheint dokumentID=\(dokument.id)")
            print("🔀 Toggle: \(devModusAktiv)  🔑 Key: \(apiKeyDa)")
        }
        .task { await klassifiziere() }
        .sheet(isPresented: $zeigeTypPicker) {
            UniversellerTypPicker { neuerTyp in
                zeigeTypPicker = false
                setzeTyp(neuerTyp)
            }
        }
        .sheet(isPresented: $zeigeManuellerPicker) {
            ManuellerZuordnungsPicker(
                immobilien: immobilien,
                objektWeit: ScanZuordnung.istObjektWeit(typ),
                onAuswahl: { kandidat in
                    manuelleAuswahl = kandidat
                    zeigeManuellerPicker = false
                }
            )
        }
        .alert(
            "Dokument verwerfen?",
            isPresented: $zeigeVerwerfenAlert,
            actions: {
                Button("Abbrechen", role: .cancel) {}
                Button("Verwerfen", role: .destructive) { verwerfen() }
            },
            message: {
                Text("Das Dokument wird gelöscht — die Rohdaten sind dann weg.")
            }
        )
        .alert(
            abschlussText,
            isPresented: $zeigeAbschlussAlert,
            actions: {
                Button("Fertig") { dismiss() }
            }
        )
    }

    // MARK: - Klassifikation

    private func klassifiziere() async {
        let erg = await ScanKlassifikator.klassifiziere(dokument: dokument)
        ergebnis = erg
        klassifikationsFehler = ScanKlassifikator.letzterFehler
        // Felder default ANgehakt.
        for z in ScanFeldMapping.ziele(typ: erg.typ) {
            if erg.felder.keys.contains(z.quellKey) {
                feldAktiv[z.quellKey] = true
            }
        }
        laeuft = false
    }

    private func setzeTyp(_ neu: Dokumenttyp) {
        if let alt = ergebnis {
            ergebnis = ScanKlassifikationsErgebnis(
                typ: neu,
                konfidenz: alt.konfidenz,
                felder: alt.felder
            )
        } else {
            ergebnis = ScanKlassifikationsErgebnis(
                typ: neu, konfidenz: 0, felder: [:]
            )
        }
        // Feld-Aktivierungen neu initialisieren.
        feldAktiv.removeAll()
        for z in ScanFeldMapping.ziele(typ: neu) {
            if felder.keys.contains(z.quellKey) {
                feldAktiv[z.quellKey] = true
            }
        }
        // Manuelle Zuordnung ggf. zuruecksetzen — bei Typ-Wechsel
        // koennten Kandidaten sich aendern (objekt-weit vs. WE).
        manuelleAuswahl = nil
    }

    // MARK: - Block 1 · Erkannt

    @ViewBuilder
    private var block1_Erkannt: some View {
        let istUnbekannt = typ == .unbekannt
        VStack(alignment: .leading, spacing: 12) {
            Text("ERKANNT")
                .appFont(AppFont.Basis.kicker())
                .foregroundStyle(DesignTokens.textSecondary)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: istUnbekannt ? "questionmark.circle.fill" : "doc.text.magnifyingglass")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(istUnbekannt ? DesignTokens.statusWarn : DesignTokens.accent)
                    Text(typ.anzeigeName.uppercased())
                        .appFont(AppFontStyle(
                            font: AppFont.plexSans(.semibold, 13),
                            tracking: 0.8,
                            uppercase: false
                        ))
                        .foregroundStyle(istUnbekannt ? DesignTokens.statusWarn : DesignTokens.accent)
                    Spacer(minLength: 0)
                }
                if let datum = felder["datum"] ?? felder["ausstellungsdatum"] ?? felder["rechnungsdatum"] {
                    metaZeile(label: "Datum", wert: datum)
                }
                if let absender = felder["absender"] ?? felder["verwalter"] ?? felder["amt"] {
                    metaZeile(label: "Absender", wert: absender)
                }
                if konfidenz > 0 && konfidenz < 0.85 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignTokens.statusWarn)
                        Text("Bitte prüfen · Konfidenz \(Int(konfidenz * 100)) %")
                            .appFont(AppFont.Basis.caption())
                            .foregroundStyle(DesignTokens.statusWarn)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.bgSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DesignTokens.separator, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func metaZeile(label: String, wert: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(DesignTokens.textSecondary)
            Spacer(minLength: 8)
            Text(wert)
                .appFont(AppFont.Basis.body())
                .foregroundStyle(DesignTokens.text)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    // MARK: - Block 2 · Zuordnung

    @ViewBuilder
    private var block2_Zuordnung: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ZUORDNUNG")
                .appFont(AppFont.Basis.kicker())
                .foregroundStyle(DesignTokens.textSecondary)
            zuordnungsKarte
        }
    }

    @ViewBuilder
    private var zuordnungsKarte: some View {
        if let kandidat = effektiverKandidat,
           let immo = immobilien.first(where: { $0.id == kandidat.immobilieID }) {
            zuordnungErfolgsCard(immo: immo, einheitBez: kandidat.einheitBezeichnung)
        } else if case .mehrdeutig(let kandidaten) = autoZuordnung {
            zuordnungMehrdeutigCard(kandidaten: kandidaten)
        } else {
            zuordnungLeerCard
        }
    }

    private func zuordnungErfolgsCard(immo: Immobilie, einheitBez: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignTokens.statusOk)
                Text("Zugeordnet")
                    .appFont(AppFont.Basis.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Spacer(minLength: 0)
                Button("Ändern") { zeigeManuellerPicker = true }
                    .appFont(AppFont.Basis.caption())
                    .foregroundStyle(DesignTokens.accent)
            }
            Text(immo.adresse.isEmpty ? "Ohne Adresse" : immo.adresse)
                .appFont(AppFont.Basis.body())
                .foregroundStyle(DesignTokens.text)
            if let bez = einheitBez {
                Text("\(bez) · \(mieterLabel(immo: immo, einheitBez: bez))")
                    .appFont(AppFont.Basis.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
            } else {
                Text("Gesamtes Objekt")
                    .appFont(AppFont.Basis.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.statusOkSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func zuordnungMehrdeutigCard(kandidaten: [ScanZuordnung.Kandidat]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignTokens.statusWarn)
                Text("\(kandidaten.count) mögliche Zuordnungen")
                    .appFont(AppFont.Basis.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Spacer(minLength: 0)
            }
            VStack(spacing: 0) {
                ForEach(kandidaten, id: \.self) { k in
                    Button { manuelleAuswahl = k } label: {
                        zuordnungKandidatenZeile(k)
                    }
                    .buttonStyle(.plain)
                    DividerLine()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.statusWarnSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func zuordnungKandidatenZeile(_ k: ScanZuordnung.Kandidat) -> some View {
        let immo = immobilien.first(where: { $0.id == k.immobilieID })
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(immo?.adresse ?? "Unbekannt")
                    .appFont(AppFont.Basis.body())
                    .foregroundStyle(DesignTokens.text)
                if let bez = k.einheitBezeichnung {
                    Text("\(bez) · \(mieterLabel(immo: immo, einheitBez: bez))")
                        .appFont(AppFont.Basis.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                } else {
                    Text("Gesamtes Objekt")
                        .appFont(AppFont.Basis.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var zuordnungLeerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignTokens.statusWarn)
                Text("Nicht zuordenbar")
                    .appFont(AppFont.Basis.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Spacer(minLength: 0)
            }
            Text("Kein passendes Objekt oder Mietverhältnis im Dokument erkannt.")
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(DesignTokens.textSecondary)
            HStack(spacing: 8) {
                Button { zeigeManuellerPicker = true } label: {
                    Text("Manuell zuordnen")
                        .appFont(AppFont.Basis.bodySemi())
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DesignTokens.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                Button { zeigeVerwerfenAlert = true } label: {
                    Text("Verwerfen")
                        .appFont(AppFont.Basis.bodySemi())
                        .foregroundStyle(DesignTokens.statusError)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(DesignTokens.statusError.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.statusWarnSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func mieterLabel(immo: Immobilie?, einheitBez: String) -> String {
        guard let einheit = (immo?.wohneinheiten ?? [])
            .first(where: { $0.bezeichnung == einheitBez }),
              let mv = (einheit.mietverhaeltnisse ?? [])
                .first(where: { $0.auszugAm == nil }) else {
            return "Leerstand"
        }
        return mv.mieterName.isEmpty ? "Mieter" : mv.mieterName
    }

    // MARK: - Block 3 · Uebernahme

    @ViewBuilder
    private var block3_Uebernahme: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !uebernehmbareFelder.isEmpty {
                Text("WIRD ÜBERNOMMEN")
                    .appFont(AppFont.Basis.kicker())
                    .foregroundStyle(DesignTokens.textSecondary)
                VStack(spacing: 0) {
                    ForEach(Array(uebernehmbareFelder.enumerated()), id: \.element.quellKey) { idx, zf in
                        uebernahmeZeile(zf)
                        if idx < uebernehmbareFelder.count - 1 {
                            DividerLine().padding(.leading, 14)
                        }
                    }
                }
                .background(DesignTokens.bgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(DesignTokens.separator, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            if !kontextFelder.isEmpty {
                Text("NUR KONTEXT")
                    .appFont(AppFont.Basis.kicker())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .padding(.top, 8)
                VStack(spacing: 0) {
                    ForEach(Array(kontextFelder.enumerated()), id: \.element.key) { idx, feld in
                        kontextZeile(key: feld.key, wert: feld.wert)
                        if idx < kontextFelder.count - 1 {
                            DividerLine().padding(.leading, 14)
                        }
                    }
                }
                .background(DesignTokens.bgSurface.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(DesignTokens.separator, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            if !ScanFeldMapping.hatProduktivenSavePath(typ) {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.textSecondary)
                    Text("Speicherung dieses Typs folgt in einem nächsten Task. Dokument wird archiviert.")
                        .appFont(AppFont.Basis.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                .padding(.top, 6)
            }
        }
    }

    @ViewBuilder
    private func uebernahmeZeile(_ zf: ScanZielFeld) -> some View {
        let aktiv = feldAktiv[zf.quellKey] ?? true
        let altWert = aktuellerSystemWert(fuer: zf.quellKey)
        let neuWert = effektiverWert(zf.quellKey)
        let ueberschreibt = altWert != nil && altWert != neuWert

        HStack(alignment: .top, spacing: 12) {
            Button {
                feldAktiv[zf.quellKey] = !aktiv
            } label: {
                Image(systemName: aktiv ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(aktiv ? DesignTokens.statusOk : DesignTokens.textTertiary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(zf.anzeige)
                    .appFont(AppFont.Basis.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
                if ueberschreibt, let alt = altWert {
                    // Alt-durchgestrichen → Neu-in-Accent. Daumen auf
                    // den „Neu"-Text tippen laesst den User den Wert
                    // nochmal editieren; der Alt-Wert bleibt statisch.
                    HStack(spacing: 8) {
                        Text(alt)
                            .appFont(AppFont.Basis.body())
                            .foregroundStyle(DesignTokens.textTertiary)
                            .strikethrough()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DesignTokens.textSecondary)
                        TextField(
                            "—",
                            text: Binding(
                                get: { effektiverWert(zf.quellKey) },
                                set: { editierteFelder[zf.quellKey] = $0 }
                            )
                        )
                        .appFont(AppFont.Basis.bodySemi())
                        .foregroundStyle(aktiv ? DesignTokens.accent : DesignTokens.textTertiary)
                        .disabled(!aktiv)
                    }
                } else {
                    HStack(spacing: 8) {
                        TextField(
                            "—",
                            text: Binding(
                                get: { effektiverWert(zf.quellKey) },
                                set: { editierteFelder[zf.quellKey] = $0 }
                            )
                        )
                        .appFont(AppFont.Basis.body())
                        .foregroundStyle(aktiv ? DesignTokens.text : DesignTokens.textTertiary)
                        .disabled(!aktiv)
                        // „(neu)"-Marker nur, wenn das Feld im System
                        // existiert, aber bisher leer war — macht dem
                        // User klar, dass nichts ueberschrieben wird.
                        if altWert == nil && istFeldImSystemVorhanden(key: zf.quellKey) {
                            Text("(neu)")
                                .appFont(AppFont.Basis.caption())
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// Helper fuer den „(neu)"-Marker — nur bei Feldern, die es im
    /// Datenmodell gibt (und deshalb beim naechsten Scan ein Alt-Wert
    /// zum Vergleich haetten). Reine Kosmetik, darf ruhig pauschal
    /// bleiben.
    private func istFeldImSystemVorhanden(key: String) -> Bool {
        switch (typ, key) {
        case (.erhoehungsschreiben, "nkVorauszahlungNeu"),
             (.mietvertrag, "nkVorauszahlungEuro"),
             (.mietvertrag, "mieter"),
             (.mietvertrag, "einzugAm"):
            return true
        default:
            return false
        }
    }

    private func kontextZeile(key: String, wert: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(DesignTokens.textTertiary)
            Spacer(minLength: 8)
            Text(wert)
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Typ-Picker-CTA (fuer .unbekannt)

    private var typPickerCta: some View {
        Button { zeigeTypPicker = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 15, weight: .semibold))
                Text("Dokumenttyp wählen")
                    .appFont(AppFont.Basis.bodySemi())
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(DesignTokens.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom-Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            DividerLine()
            HStack(spacing: 10) {
                Button { zeigeVerwerfenAlert = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Verwerfen")
                            .appFont(AppFont.Basis.bodySemi())
                    }
                    .foregroundStyle(DesignTokens.statusError)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DesignTokens.statusError.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button { uebernehmen() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: ueberschreibtBestehend ? "arrow.triangle.2.circlepath" : "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                        Text(ueberschreibtBestehend
                             ? "Übernehmen und aktualisieren"
                             : "Übernehmen")
                            .appFont(AppFont.Basis.bodySemi())
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(kannUebernehmen ? DesignTokens.accent : DesignTokens.textQuaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!kannUebernehmen)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .background(DesignTokens.bgHeaderFooter.ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Actions

    private func verwerfen() {
        DokumentAblageService.loesche(dokument, context: modelContext)
        try? modelContext.save()
        dismiss()
    }

    private func uebernehmen() {
        guard kannUebernehmen else { return }
        dokument.dokumenttyp = typ

        // Typ-spezifische Persistenz. Nur fuer produktive Pfade (siehe
        // ScanFeldMapping.hatProduktivenSavePath) wirklich speichern;
        // fuer die anderen bleibt das Dokument als Beleg archiviert
        // und der User sieht den „folgt"-Hinweis.
        switch typ {
        case .energieausweis, .grundsteuerbescheid:
            if let immo = effektiveImmobilie {
                dokument.immobilie = immo
            }
        default:
            break
        }
        try? modelContext.save()

        abschlussText = abschlussMeldung()
        zeigeAbschlussAlert = true
    }

    private func abschlussMeldung() -> String {
        let ziel: String
        if let einheit = effektiveEinheit {
            let mv = (einheit.mietverhaeltnisse ?? [])
                .first(where: { $0.auszugAm == nil })
            let mieter = (mv?.mieterName.isEmpty == false) ? mv!.mieterName : "Leerstand"
            ziel = "\(einheit.bezeichnung) · \(mieter)"
        } else if let immo = effektiveImmobilie {
            ziel = immo.adresse.isEmpty ? "Objekt" : immo.adresse
        } else {
            ziel = "Archiv"
        }
        if ScanFeldMapping.hatProduktivenSavePath(typ) {
            return "Übernommen für \(ziel)"
        }
        return "Archiviert · Bearbeitung folgt (\(typ.anzeigeName))"
    }

    // MARK: - Banner + Diagnose (unveraendert)

    private var devModusBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignTokens.statusError)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dev-Modus · ungeschwärzter Versand")
                    .appFont(AppFont.Basis.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Text("Das Dokument wird vollständig an Anthropic gesendet. Nicht für Produktiv-Daten.")
                    .appFont(AppFont.Basis.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.statusErrorSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func fehlerBanner(_ meldung: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignTokens.statusWarn)
            VStack(alignment: .leading, spacing: 2) {
                Text("Automatische Erkennung fehlgeschlagen")
                    .appFont(AppFont.Basis.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Text(meldung)
                    .appFont(AppFont.Basis.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.statusWarnSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var diagnoseCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            diagZeile(label: "Dev-Toggle", wert: devModusAktiv ? "AN" : "AUS", ok: devModusAktiv)
            diagZeile(label: "API-Key", wert: apiKeyDa ? "vorhanden" : "fehlt", ok: apiKeyDa)
            diagZeile(label: "Pfad", wert: pfadBeschreibung, ok: {
                if case .echt = ScanKlassifikator.letzterPfad { return true }
                return false
            }())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.bgSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DesignTokens.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func diagZeile(label: String, wert: String, ok: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ok ? DesignTokens.statusOk : DesignTokens.statusWarn)
                .frame(width: 6, height: 6)
            Text(label)
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(DesignTokens.textSecondary)
            Spacer(minLength: 8)
            Text(wert)
                .appFont(AppFont.Basis.monoCaption())
                .foregroundStyle(DesignTokens.text)
                .multilineTextAlignment(.trailing)
        }
    }

    private var pfadBeschreibung: String {
        switch ScanKlassifikator.letzterPfad {
        case .idle:                        return "läuft …"
        case .stub(let g):                 return "Stub · \(g)"
        case .echt(let t, let n):          return "Claude · \(t.rawValue) · \(n) Felder"
        case .echtFehler(let b):           return "Fehler: \(b.prefix(60))"
        }
    }

    private var analyseLaeuftBlock: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(DesignTokens.accent)
            Text("Dokument wird analysiert …")
                .appFont(AppFont.Basis.bodySemi())
                .foregroundStyle(DesignTokens.text)
            Text("Typ-Erkennung läuft.")
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
}

// MARK: - Manueller Zuordnungs-Picker

fileprivate struct ManuellerZuordnungsPicker: View {
    let immobilien: [Immobilie]
    let objektWeit: Bool
    let onAuswahl: (ScanZuordnung.Kandidat) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(immobilien) { immo in
                    Section(immo.adresse.isEmpty ? "Objekt" : immo.adresse) {
                        if objektWeit {
                            Button {
                                onAuswahl(ScanZuordnung.Kandidat(
                                    immobilieID: immo.id,
                                    einheitBezeichnung: nil,
                                    score: 99
                                ))
                            } label: {
                                zeile(text: "Gesamtes Objekt", mieter: nil)
                            }
                            .buttonStyle(.plain)
                        } else {
                            ForEach(immo.wohneinheiten ?? []) { einheit in
                                Button {
                                    onAuswahl(ScanZuordnung.Kandidat(
                                        immobilieID: immo.id,
                                        einheitBezeichnung: einheit.bezeichnung,
                                        score: 99
                                    ))
                                } label: {
                                    let mv = (einheit.mietverhaeltnisse ?? [])
                                        .first(where: { $0.auszugAm == nil })
                                    zeile(
                                        text: einheit.bezeichnung,
                                        mieter: mv?.mieterName
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Manuell zuordnen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen { dismiss() }
                }
            }
        }
    }

    private func zeile(text: String, mieter: String?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .appFont(AppFont.Basis.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                if let m = mieter, !m.isEmpty {
                    Text(m)
                        .appFont(AppFont.Basis.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Universeller Typ-Picker (fuer „Typ ändern")

fileprivate struct UniversellerTypPicker: View {
    let onAuswahl: (Dokumenttyp) -> Void
    @Environment(\.dismiss) private var dismiss

    private var optionen: [Dokumenttyp] {
        [.rechnung, .erhoehungsschreiben, .mietvertrag, .hvAbrechnung,
         .energieausweis, .grundsteuerbescheid, .zaehlerfoto,
         .handwerkerbeleg, .bescheid, .sonstiges]
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(optionen, id: \.self) { t in
                    Button { onAuswahl(t) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: symbol(fuer: t))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(DesignTokens.accent)
                                .frame(width: 32)
                            Text(t.anzeigeName)
                                .appFont(AppFont.Basis.bodySemi())
                                .foregroundStyle(DesignTokens.text)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Dokumenttyp wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func symbol(fuer t: Dokumenttyp) -> String {
        switch t {
        case .rechnung:            return "doc.text.fill"
        case .bescheid:            return "building.columns.fill"
        case .handwerkerbeleg:     return "wrench.and.screwdriver.fill"
        case .winterdienstbeleg:   return "snowflake"
        case .zaehlerfoto:         return "gauge.medium"
        case .mietvertrag:         return "person.text.rectangle.fill"
        case .energieausweis:      return "doc.badge.gearshape"
        case .grundsteuerbescheid: return "doc.text"
        case .hvAbrechnung:        return "building.2.fill"
        case .erhoehungsschreiben: return "arrow.up.right.circle.fill"
        case .unbekannt:           return "questionmark.circle"
        case .sonstiges:           return "doc"
        }
    }
}
