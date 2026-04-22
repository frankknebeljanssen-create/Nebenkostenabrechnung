//
//  DokumenteRechnungenView.swift
//  NebenkostenApp — UI/Kacheln
//
//  Kachel-Screen der Dokumente-&-Rechnungen-Kategorie. Wird aus
//  `KachelansichtView` per `NavigationLink` geoeffnet.
//
//  Layout:
//    - Fortschrittsbalken oben: „X von 6 Pflichtkategorien
//      vollstaendig" (siehe `KachelKategorie.istPflicht`).
//    - Scan-CTA: grosser Button mit Doc-Viewfinder-Icon, oeffnet
//      `ScanEntryView` ohne Kostenart-Vorauswahl (App erkennt sie
//      beim Uebernehmen).
//    - 8 `CollapsibleSection`s — Zielbild-Kategorien in
//      BetrKV-Reihenfolge. Default: nur „Heizung & Warmwasser"
//      offen, Rest zu, persistiert per `@AppStorage`-aequivalent
//      durch `CollapsibleSection.persistKey`.
//    - Pro Kategorie: `RechnungRow` + `Divider`, Leerzustand mit
//      „+ Rechnung hinzufuegen"-Tap-Bereich → oeffnet Scan-Flow.
//
//  RechnungenView (Tab) bleibt unberuehrt. Die Kachel ist eine
//  eigene Perspektive — 8 breitere Gruppen, Thumbnails, Fokus auf
//  Completion der Pflicht-Kategorien.
//

import SwiftUI
import SwiftData

struct DokumenteRechnungenView: View {
    @Environment(ScopeManager.self) private var scope
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]
    @Query private var alleDokumente: [GespeichertesDokument]

    @State private var zeigeScanner = false
    @State private var auswahl: Rechnung?

    // MARK: - Abgeleitet

    private var aktiveImmobilie: Immobilie? {
        if let id = scope.aktuelleImmobilieID,
           let match = immobilien.first(where: { $0.id == id }) {
            return match
        }
        return immobilien.first
    }

    private var aktivePeriode: Abrechnungsperiode? {
        let perioden = (aktiveImmobilie?.perioden ?? [])
            .sorted(by: { $0.bis > $1.bis })
        let heute = Date()
        return perioden.first(where: { $0.bis < heute }) ?? perioden.first
    }

    /// Rechnungen der aktiven Periode, gruppiert nach Kachel-
    /// Kategorie.
    private var gruppiert: [KachelKategorie: [Rechnung]] {
        guard let immobilie = aktiveImmobilie,
              let p = aktivePeriode else { return [:] }
        let relevante = (immobilie.rechnungen ?? []).filter {
            $0.rechnungsdatum >= p.von && $0.rechnungsdatum <= p.bis
        }
        var dict: [KachelKategorie: [Rechnung]] = [:]
        for r in relevante {
            let rang = RechnungenView.betrKvRang(r.kostenart?.bezeichnung ?? "ohne")
            let kat = KachelKategorie.fuer(rang: rang)
            dict[kat, default: []].append(r)
        }
        // Pro Kategorie nach Rechnungsdatum absteigend.
        for key in dict.keys {
            dict[key]?.sort { $0.rechnungsdatum > $1.rechnungsdatum }
        }
        return dict
    }

    /// „X von 6 Pflichtkategorien vollstaendig" — eine
    /// Pflichtkategorie gilt als vollstaendig, sobald mindestens
    /// eine Rechnung in der Periode erfasst ist.
    private var pflichtkategorien: [KachelKategorie] {
        KachelKategorie.allCases.filter { $0.istPflicht }
    }

    private var pflichtErfuellt: Int {
        pflichtkategorien.filter { (gruppiert[$0] ?? []).isEmpty == false }.count
    }

    private var prozent: Int {
        let gesamt = pflichtkategorien.count
        guard gesamt > 0 else { return 0 }
        return Int(Double(pflichtErfuellt) / Double(gesamt) * 100)
    }

    private var gesamtSumme: Decimal {
        gruppiert.values.flatMap { $0 }.reduce(Decimal(0)) { $0 + $1.betragBruttoEuro }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                fortschrittHeader
                scanCTA
                kategorienListe
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(DesignTokens.bgAppCompact)
        .navigationTitle("Dokumente & Rechnungen")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $zeigeScanner) {
            ScanEntryView { _ in
                // Dokument ist persistiert, Rechnungs-Erzeugung
                // laeuft im `UebernahmeSheet` (AI-Flow). Die Kachel
                // aktualisiert sich ueber @Query automatisch,
                // sobald eine Rechnung committet wurde.
            }
        }
        .sheet(item: $auswahl) { r in
            RechnungEditView(modus: .bearbeiten(r))
        }
    }

    // MARK: - Fortschritts-Header

    private var fortschrittHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Vollständigkeit")
                    .appFont(AppFont.Basis.kicker())
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer()
                Text("\(prozent) %")
                    .appFont(AppFont.Basis.monoBodySemi())
                    .foregroundStyle(CompletionFarbe.fuer(prozent: prozent))
            }
            balken
            HStack {
                Text("\(pflichtErfuellt) von \(pflichtkategorien.count) Pflichtkategorien vollständig")
                    .appFont(AppFont.Basis.caption())
                    .foregroundStyle(DesignTokens.textTertiary)
                Spacer()
                if gesamtSumme > 0 {
                    Text(Formatting.euro(gesamtSumme))
                        .appFont(AppFont.Basis.monoCaption())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
        }
    }

    private var balken: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(CompletionFarbe.fuer(prozent: prozent).opacity(0.15))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(CompletionFarbe.fuer(prozent: prozent))
                    .frame(width: max(6, geo.size.width * CGFloat(prozent) / 100))
            }
        }
        .frame(height: 6)
    }

    // MARK: - Scan-CTA

    private var scanCTA: some View {
        Button {
            zeigeScanner = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dokument scannen oder importieren")
                        .appFont(AppFont.Basis.bodySemi())
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                    Text("Kamera · Mediathek · Datei")
                        .appFont(AppFont.Basis.caption())
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(DesignTokens.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Kategorien

    private var kategorienListe: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(KachelKategorie.allCases, id: \.self) { kat in
                kategorieSection(kat)
            }
        }
    }

    @ViewBuilder
    private func kategorieSection(_ kat: KachelKategorie) -> some View {
        let rechnungen = gruppiert[kat] ?? []
        let summe = rechnungen.reduce(Decimal(0)) { $0 + $1.betragBruttoEuro }
        CollapsibleSection(
            titel: kat.anzeigeName,
            summary: rechnungen.isEmpty ? nil : Formatting.euro(summe),
            persistKey: "dokrechnungen.\(kat.rawValue).offen",
            defaultOffen: kat == .heizungWarmwasser
        ) {
            if rechnungen.isEmpty {
                leerRow
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rechnungen.enumerated()), id: \.element.id) { idx, r in
                        Button {
                            auswahl = r
                        } label: {
                            RechnungRow(
                                rechnung: r,
                                dokument: dokumentFuer(rechnung: r)
                            )
                        }
                        .buttonStyle(.plain)
                        if idx < rechnungen.count - 1 {
                            DividerLine().padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }

    private var leerRow: some View {
        Button {
            zeigeScanner = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DesignTokens.textTertiary)
                Text("Rechnung hinzufügen")
                    .appFont(AppFont.Basis.bodyMedium())
                    .foregroundStyle(DesignTokens.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Lookup

    private func dokumentFuer(rechnung: Rechnung) -> GespeichertesDokument? {
        alleDokumente.first { $0.rechnungId == rechnung.id }
    }
}

// MARK: - KachelKategorie

/// Zielbild-Gruppierung fuer die Dokumente-&-Rechnungen-Kachel:
/// 8 breitere Kategorien (Spec Stufe 2 §2) statt der 10 feinen
/// BetrKV-Raenge aus dem Tab. Jede Kategorie mappt auf einen oder
/// mehrere `betrKvRang`-Werte aus `RechnungenView.betrKvRang`.
enum KachelKategorie: Int, CaseIterable, Hashable, Sendable {
    case heizungWarmwasser = 1
    case wasserAbwasser = 2
    case strom = 3
    case muellStrassen = 4
    case versicherungen = 5
    case hausmeisterGarten = 6
    case sonstigesUmlagefaehig = 7
    case nichtUmlagefaehig = 8

    var anzeigeName: String {
        switch self {
        case .heizungWarmwasser:     return "Heizung & Warmwasser"
        case .wasserAbwasser:        return "Wasser & Abwasser"
        case .strom:                 return "Strom"
        case .muellStrassen:         return "Müll & Straßenreinigung"
        case .versicherungen:        return "Versicherungen"
        case .hausmeisterGarten:     return "Hausmeister & Gartenpflege"
        case .sonstigesUmlagefaehig: return "Sonstiges umlagefähig"
        case .nichtUmlagefaehig:     return "Nicht umlagefähig"
        }
    }

    /// Gewertet im Fortschrittsbalken — die Kategorie muss fuer
    /// „100 %" mindestens eine Rechnung in der Periode enthalten.
    /// Sonstige + nicht-umlagefaehige Kosten fliegen aus der
    /// Nenner-Berechnung (nur fuer Archiv-Zwecke gelistet).
    var istPflicht: Bool {
        switch self {
        case .heizungWarmwasser,
             .wasserAbwasser,
             .strom,
             .muellStrassen,
             .versicherungen,
             .hausmeisterGarten: return true
        case .sonstigesUmlagefaehig,
             .nichtUmlagefaehig: return false
        }
    }

    /// Mapping aus dem bestehenden `RechnungenView.betrKvRang`. Der
    /// Tab-Mapper liefert 10 Ränge (+ 99 fuer „Ohne Kostenart"),
    /// die wir auf 8 verdichten.
    static func fuer(rang: Int) -> KachelKategorie {
        switch rang {
        case 1:     return .heizungWarmwasser       // Heizung & Warmwasser
        case 2:     return .wasserAbwasser           // Wasser & Entwaesserung
        case 3:     return .muellStrassen            // Muellabfuhr
        case 5:     return .versicherungen           // Gebaeudeversicherung
        case 7, 8:  return .hausmeisterGarten        // Reinigung/Garten + Hauswart
        case 9:     return .strom                    // Allgemeinstrom
        case 10:    return .nichtUmlagefaehig        // Reparatur
        default:    return .sonstigesUmlagefaehig    // 4=Grundsteuer, 6=Schornsteinfeger, 99=ohne
        }
    }
}
