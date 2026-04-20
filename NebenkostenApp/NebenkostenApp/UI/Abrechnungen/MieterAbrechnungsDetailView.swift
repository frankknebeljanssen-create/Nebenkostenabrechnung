//
//  MieterAbrechnungsDetailView.swift
//  NebenkostenApp — UI/Abrechnungen
//
//  Positionsliste + PDF-Export. Erzeugt aus der Mieterabrechnung einen
//  Mustache-Kontext, rendert das abrechnung.html-Template via
//  PDFGenerator zu einer PDF-Datei im tmp-Verzeichnis und bietet sie
//  per ShareLink an.
//

import SwiftUI
import SwiftData

struct MieterAbrechnungsDetailView: View {
    let abrechnung: Mieterabrechnung
    let periode: Abrechnungsperiode
    let immobilie: Immobilie

    @Query private var users: [AppUser]
    @Query(sort: \Abrechnungsperiode.bis) private var allePerioden: [Abrechnungsperiode]
    @Environment(\.modelContext) private var modelContext

    @State private var pdfURL: URL?
    @State private var laeuftPDF: Bool = false
    @State private var fehlermeldung: String?

    @State private var ausstehendeWarnungen: [Warnung] = []
    @State private var zeigeWarnungsSheet: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                kopf
                positionen
                saldoBlock
                pdfBlock
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(abrechnung.mieterName.isEmpty ? "Mieter" : abrechnung.mieterName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("PDF-Fehler",
               isPresented: .init(get: { fehlermeldung != nil }, set: { if !$0 { fehlermeldung = nil } }),
               actions: { Button("OK", role: .cancel) {} },
               message: { Text(fehlermeldung ?? "") })
        .sheet(isPresented: $zeigeWarnungsSheet) {
            WarnungsSheet(
                warnungen: ausstehendeWarnungen,
                onFortfahren: {
                    speichereAuditLog(warnungen: ausstehendeWarnungen)
                    erzeugePDFWirklich()
                },
                onAbbrechen: {
                    ausstehendeWarnungen = []
                }
            )
        }
    }

    // MARK: - Sektionen

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(abrechnung.mieterName)
                .font(.title3.bold())
            Text("Einheit \(abrechnung.einheitBezeichnung)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(periodenText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var positionen: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Positionen")
                .font(.headline)

            if abrechnung.positionen.isEmpty {
                Text("Keine umlagefähigen Rechnungen in dieser Periode.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(abrechnung.positionen) { pos in
                        positionZeile(pos)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func positionZeile(_ p: Mieterposition) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(p.kostenart)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(formatiereEuro(p.mieteranteilEuro))
                    .font(.subheadline.monospacedDigit())
            }
            HStack {
                Text(p.verteilerschluesselText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Gesamt \(formatiereEuro(p.gesamtkostenEuro))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var saldoBlock: some View {
        VStack(spacing: 8) {
            zeileSaldo("Gesamtkosten",   wert: abrechnung.gesamtkostenEuro,    negativ: false)
            zeileSaldo("Vorauszahlungen", wert: abrechnung.vorauszahlungenEuro, negativ: true)
            Divider()
            HStack {
                Text(abrechnung.saldoEuro >= 0 ? "Nachzahlung" : "Erstattung")
                    .font(.title3.bold())
                Spacer()
                Text(formatiereEuro(abrechnung.saldoEuro.magnitude))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(abrechnung.saldoEuro >= 0 ? .orange : .green)
            }
            if abrechnung.steuer35aBetragEuro > 0 {
                HStack {
                    Label("§ 35a EStG-Anteil", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.tint)
                        .font(.caption)
                    Spacer()
                    Text(formatiereEuro(abrechnung.steuer35aBetragEuro))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var pdfBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PDF erstellen und teilen")
                .font(.headline)

            if let url = pdfURL {
                HStack {
                    Label("PDF bereit", systemImage: "doc.text.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    ShareLink(item: url) {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if laeuftPDF {
                HStack {
                    ProgressView()
                    Text("PDF wird erzeugt …")
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    erzeugePDF()
                } label: {
                    Label("PDF erstellen", systemImage: "doc.badge.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - PDF-Erzeugung mit vorgelagerter Validierung

    private func erzeugePDF() {
        let umlageSumme = abrechnung.positionen
            .reduce(Decimal(0)) { $0 + $1.gesamtkostenEuro }
        let input = ValidierungsAdapter.baueInput(
            fuerPeriode: periode,
            immobilie: immobilie,
            allePerioden: allePerioden,
            umlageSummeEuro: umlageSumme > 0 ? umlageSumme : nil,
            rechnungGesamtEuro: umlageSumme > 0 ? umlageSumme : nil
        )
        let warnungen = Validierung.pruefe(input)

        if warnungen.isEmpty {
            erzeugePDFWirklich()
        } else {
            ausstehendeWarnungen = warnungen
            zeigeWarnungsSheet = true
        }
    }

    private func erzeugePDFWirklich() {
        laeuftPDF = true
        let context = buildMustacheContext()
        let dateiname = "Abrechnung_\(sanitisiert(abrechnung.mieterName))_\(periodeKurz()).pdf"

        Task { @MainActor in
            defer { laeuftPDF = false }
            do {
                let data = try await PDFGenerator.generiereAbrechnungsPDF(context: context)
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(dateiname)
                try data.write(to: url, options: .atomic)
                pdfURL = url
            } catch {
                fehlermeldung = error.localizedDescription
            }
        }
    }

    // MARK: - Audit-Log

    private func speichereAuditLog(warnungen: [Warnung]) {
        let audit = WarnungsAudit()
        audit.userName = users.first?.name ?? ""
        audit.periodeID = periode.id
        audit.mieterID = abrechnung.mieterID
        audit.mieterName = abrechnung.mieterName

        let zahlen = warnungen.reduce(into: (fehler: 0, warnung: 0, hinweis: 0)) { res, w in
            switch w.stufe {
            case .fehler:  res.fehler += 1
            case .warnung: res.warnung += 1
            case .hinweis: res.hinweis += 1
            }
        }
        audit.zusammenfassung = "\(warnungen.count) Warnung\(warnungen.count == 1 ? "" : "en") akzeptiert "
            + "(\(zahlen.fehler) Fehler, \(zahlen.warnung) Warnungen, \(zahlen.hinweis) Hinweise)"

        let serialisiert: [[String: String]] = warnungen.map {
            ["stufe": $0.stufe.rawValue,
             "kategorie": $0.kategorie,
             "nachricht": $0.nachricht]
        }
        if let data = try? JSONSerialization.data(
            withJSONObject: serialisiert,
            options: [.sortedKeys]
        ) {
            audit.warnungenJSON = String(data: data, encoding: .utf8) ?? ""
        }

        modelContext.insert(audit)
        try? modelContext.save()
    }

    // MARK: - Mustache-Kontext

    private func buildMustacheContext() -> [String: Any] {
        let user = users.first

        let positionenDicts: [[String: Any]] = abrechnung.positionen.map { p in
            [
                "bezeichnung":          p.kostenart,
                "gesamtkostenEuro":     formatiereZahl(p.gesamtkostenEuro),
                "verteilerschluessel":  p.verteilerschluesselText,
                "mieteranteilEuro":     formatiereZahl(p.mieteranteilEuro)
            ]
        }

        let saldoLabel = abrechnung.saldoEuro >= 0 ? "Ihre Nachzahlung" : "Ihre Erstattung"
        let saldoFmt = formatiereZahl(abrechnung.saldoEuro.magnitude)
        let saldoText = abrechnung.saldoEuro >= 0 ? saldoFmt : "− \(saldoFmt)"

        var ctx: [String: Any] = [
            "vermieter": [
                "name":     user?.name ?? "",
                "adresse":  user?.anschrift ?? "",
                "ort":      user?.ort ?? ""
            ],
            "mieter": [
                "anrede":        "Sehr geehrte Mieterin, sehr geehrter Mieter,",
                "anredeFormell": "Sehr geehrte Damen und Herren",
                "name":          abrechnung.mieterName,
                "adresse":       abrechnung.mieterAnschrift,
                "ort":           ""
            ],
            "datum":       datumHeute(),
            "periode": [
                "bezeichnung": periodenText,
                "von":         formatiereDatum(periode.von),
                "bis":         formatiereDatum(periode.bis)
            ],
            "einheit": [
                "bezeichnung":  abrechnung.einheitBezeichnung,
                "flaecheM2":    formatiereZahl(abrechnung.einheitFlaecheM2)
            ],
            "immobilie": [
                "adresse":         immobilie.adresse,
                "ort":             immobilie.ort,
                "gesamtflaecheM2": formatiereZahl(immobilie.gesamtflaecheM2)
            ],
            "abrechnung": [
                "gesamtkostenEuro":      formatiereZahl(abrechnung.gesamtkostenEuro),
                "vorauszahlungenEuro":   formatiereZahl(abrechnung.vorauszahlungenEuro),
                "saldoLabel":            saldoLabel,
                "saldoBetragFormatiert": saldoText,
                "steuer35aBetragEuro":   formatiereZahl(abrechnung.steuer35aBetragEuro)
            ],
            "positionen":          positionenDicts,
            "steuer35aRelevant":   abrechnung.steuer35aBetragEuro > 0,
            "hatHeizungsAnlage":   abrechnung.heizungsAnlage != nil,
            "hatCo2Anlage":        false
        ]

        if let h = abrechnung.heizungsAnlage {
            let heizTopf  = h.heizkostenTopfEuro
            let wwTopf    = h.warmwasserkostenTopfEuro
            let anteilHeiz = abrechnung.positionen
                .first(where: { $0.kostenart == "Heizung" })?.mieteranteilEuro ?? 0
            let anteilWw = abrechnung.positionen
                .first(where: { $0.kostenart == "Warmwasser" })?.mieteranteilEuro ?? 0
            ctx["heizung"] = [
                "gesamtkostenEuro":     formatiereZahl(heizTopf + wwTopf),
                "heizkostenTopfEuro":   formatiereZahl(heizTopf),
                "warmwasserTopfEuro":   formatiereZahl(wwTopf),
                "qHeizungKwh":          formatiereGanz(h.qHeizungKwh),
                "qWarmwasserKwh":       formatiereGanz(h.qWarmwasserKwh),
                "wmzGesamt":            formatiereGanz(h.qHeizungKwh),
                "wmzAnteil":            formatiereGanz(h.wmzAnteilKwh),
                "wwVerbrauchM3":        formatiereZahl(Decimal(h.wwVerbrauchM3)),
                "flaechenanteilEuro":   formatiereZahl(h.flaechenanteilHeizungEuro
                                                       + h.flaechenanteilWarmwasserEuro),
                "verbrauchsanteilEuro": formatiereZahl(h.verbrauchsanteilHeizungEuro
                                                       + h.verbrauchsanteilWarmwasserEuro),
                "verbrauchAnteilProzent": "70",
                "gesamtAnteilEuro":     formatiereZahl(anteilHeiz + anteilWw)
            ]
        }
        return ctx
    }

    private func formatiereGanz(_ wert: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.locale = Locale(identifier: "de_DE")
        nf.maximumFractionDigits = 0
        return nf.string(from: NSNumber(value: wert)) ?? "\(Int(wert.rounded()))"
    }

    // MARK: - Formatter-Helfer

    private var periodenText: String {
        "\(formatiereDatum(periode.von)) – \(formatiereDatum(periode.bis))"
    }

    private func zeileSaldo(_ label: String, wert: Decimal, negativ: Bool) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text((negativ ? "− " : "") + formatiereEuro(wert))
                .font(.callout.monospacedDigit())
        }
    }

    private func formatiereEuro(_ betrag: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "EUR"
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: NSDecimalNumber(decimal: betrag)) ?? "\(betrag) €"
    }

    private func formatiereZahl(_ betrag: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.locale = Locale(identifier: "de_DE")
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        return nf.string(from: NSDecimalNumber(decimal: betrag)) ?? "\(betrag)"
    }

    private func formatiereDatum(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: d)
    }

    private func datumHeute() -> String {
        formatiereDatum(Date())
    }

    private func periodeKurz() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.timeZone = TimeZone(identifier: "UTC")
        return "\(f.string(from: periode.von))_\(f.string(from: periode.bis))"
    }

    private func sanitisiert(_ name: String) -> String {
        name.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "ß", with: "ss")
    }
}
