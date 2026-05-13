import SwiftUI
import SwiftData

/// v4-18: Detaillierter Prüfbericht.
///
/// Aufbau (top-down):
///   1. Ergebnis-Header (alles-korrekt vs. X Auffälligkeiten gefunden)
///   2. Eckdaten-Card (Zeitraum, Objekt, Wohnung, Fläche, Vorauszahlung, Ergebnis)
///   3. Geprüfte Positionen — IMMER alle, aufklappbar (Details + Finding)
///   4. Handlungsempfehlungen — nur wenn Findings > 0
///   5. Disclaimer (NKDisclaimerStrip)
///   6. Aktionen (Widerspruch wenn Findings, Neue Prüfung, Schließen)
///
/// Glossar-Tap-Targets in Eckdaten + Positionen öffnen ein Bottom-Sheet
/// mit dem zugehörigen NKGlossary-Eintrag.
struct BerichtView: View {
    let bericht: Pruefbericht
    let mietobjekt: Mietobjekt

    /// v4-21: Demo-Modus aktiviert die Beispiel-Daten-Banner und
    /// deaktiviert PDF-Export sowie Persistence-Side-Effects in
    /// nachgelagerten Aktionen (z. B. WiderspruchView).
    var isDemo: Bool = false

    @Environment(\.dismiss) private var dismiss

    /// Gewählter Glossar-Key (gesetzt durch tappbare Begriffe in der View).
    /// Wird vom `.glossarSheet(key:)`-Modifier aufgelöst.
    @State private var glossarKey: String? = nil

    /// Programmatischer Push zum Widerspruchs-Flow.
    @State private var navigiereZuWiderspruch: Bool = false

    /// Programmatischer Push zur neuen Prüfung.
    @State private var navigiereZuNeuePruefung: Bool = false

    /// v4-19 Fix 5: Share-Sheet für den exportierten Bericht-PDF.
    @State private var pdfExportURL: URL? = nil

    /// Wrapper für `URL` als `Identifiable` — `sheet(item:)` braucht
    /// einen Identifiable-Wert. Wir nutzen `absoluteString` als ID,
    /// damit Re-Exports mit unterschiedlichen Pfaden erkannt werden.
    private struct PDFShareItem: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    private var pdfExportURLBinding: Binding<PDFShareItem?> {
        Binding(
            get: { pdfExportURL.map(PDFShareItem.init(url:)) },
            set: { neu in pdfExportURL = neu?.url }
        )
    }

    // MARK: - Abgeleitete Werte

    private var findings: [Finding] {
        bericht.findings.sorted { sortValue($0.schwere) < sortValue($1.schwere) }
    }

    private var positionen: [Kostenposition] {
        bericht.abrechnung.kostenpositionen
    }

    private var anzahlPositionen: Int { positionen.count }

    private var vertrauenswertProzent: Int? {
        let scores = bericht.trustScores.values
        guard !scores.isEmpty else { return nil }
        let summe = scores.reduce(0) { $0 + $1.prozent }
        return Int((Double(summe) / Double(scores.count)).rounded())
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xxl) {
                if isDemo { demoBanner }
                ergebnisHeader
                eckdatenCard
                positionenListe
                if !findings.isEmpty {
                    handlungsempfehlungen
                }
                NKDisclaimerStrip()
                aktionen
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationTitle("Prüfbericht")
        .navigationBarTitleDisplayMode(.inline)
        // X-Button: Endpunkt → reset zur HomeView.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    NotificationCenter.default.post(name: .nkResetToHome, object: nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Schließen")
            }
            // v4-19 Fix 5: PDF-Export oben rechts.
            // v4-21: im Demo-Modus deaktiviert (kein Echt-Export
            // beispielhafter Daten).
            if !isDemo {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        pdfExportURL = PDFService.writeBerichtPDF(
                            bericht: bericht,
                            mietobjekt: mietobjekt
                        )
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Prüfbericht als PDF teilen")
                }
            }
        }
        .sheet(item: pdfExportURLBinding) { wrapper in
            ShareSheet(activityItems: [wrapper.url])
                .ignoresSafeArea()
        }
        .navigationDestination(isPresented: $navigiereZuWiderspruch) {
            WiderspruchView(bericht: bericht, mietobjekt: mietobjekt, isDemo: isDemo)
        }
        .navigationDestination(isPresented: $navigiereZuNeuePruefung) {
            PreCaptureView()
        }
        .glossarSheet(key: $glossarKey)
    }

    // MARK: - Demo-Banner (v4-21)

    private var demoBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.accent)
            Text("Demo-Modus — Beispieldaten")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.accent)
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
    }

    // MARK: - Block 1: Ergebnis-Header

    @ViewBuilder
    private var ergebnisHeader: some View {
        if findings.isEmpty {
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.success)
                    .accessibilityHidden(true)

                Text("Alles korrekt")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.success)
                    .multilineTextAlignment(.center)

                Text("Wir haben \(anzahlPositionen) \(anzahlPositionen == 1 ? "Kostenposition" : "Kostenpositionen"), die Verteilung und die Gesamtsumme deiner Abrechnung geprüft — alles in Ordnung.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
        } else {
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.warning)
                    .accessibilityHidden(true)

                Text("\(findings.count) \(findings.count == 1 ? "Auffälligkeit" : "Auffälligkeiten") gefunden")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.warning)
                    .multilineTextAlignment(.center)

                Text("Wir haben \(anzahlPositionen) \(anzahlPositionen == 1 ? "Kostenposition" : "Kostenpositionen") geprüft und dabei \(findings.count) \(findings.count == 1 ? "Auffälligkeit" : "Auffälligkeiten") festgestellt.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let p = vertrauenswertProzent {
                    vertrauenswertBalken(prozent: p)
                        .padding(.top, AppSpacing.xs)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
        }
    }

    private func vertrauenswertBalken(prozent: Int) -> some View {
        let farbe: Color = prozent >= 80 ? AppTheme.success
                         : prozent >= 60 ? AppTheme.warning
                         : AppTheme.error

        return VStack(spacing: AppSpacing.xs) {
            HStack {
                Text("Vertrauenswert")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("\(prozent) %")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(farbe)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.border)
                    Capsule()
                        .fill(farbe)
                        .frame(width: geo.size.width * CGFloat(prozent) / 100)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: 280)
    }

    // MARK: - Block 2: Eckdaten-Card

    private var eckdatenCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Eckdaten deiner Abrechnung")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(spacing: 0) {
                if let zeitraumStr = formatZeitraum() {
                    eckdatenRow(label: "Zeitraum", value: zeitraumStr,
                                glossarKey: "abrechnungszeitraum")
                }
                if let adresse = bericht.abrechnung.meta.objekt.adresse?.nilIfEmpty {
                    teiler
                    eckdatenRow(label: "Objekt", value: adresse)
                }
                if let bez = bericht.abrechnung.meta.mieterEinheit.bezeichnung?.nilIfEmpty {
                    teiler
                    eckdatenRow(label: "Wohnung", value: bez)
                }
                if let flaeche = bericht.abrechnung.meta.mieterEinheit.flaecheQm {
                    teiler
                    eckdatenRow(label: "Wohnfläche", value: formatFlaeche(flaeche))
                }
                if let vz = bericht.abrechnung.meta.vorauszahlungenGesamt {
                    teiler
                    eckdatenRow(label: "Vorauszahlung", value: formatGeldKurz(vz),
                                glossarKey: "vorauszahlung")
                }
                if let ergebnis = bericht.abrechnung.meta.nachzahlungOderGuthaben {
                    teiler
                    eckdatenRow(
                        label: "Ergebnis",
                        value: formatErgebnis(betrag: ergebnis, typ: bericht.abrechnung.meta.typ),
                        glossarKey: bericht.abrechnung.meta.typ == .guthaben ? "guthaben" : "nachzahlung",
                        valueColor: bericht.abrechnung.meta.typ == .guthaben ? AppTheme.success : AppTheme.error
                    )
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .stroke(AppTheme.border, lineWidth: 0.5)
            )
        }
    }

    private var teiler: some View {
        Divider().padding(.vertical, AppSpacing.xs)
    }

    @ViewBuilder
    private func eckdatenRow(label: String, value: String,
                             glossarKey: String? = nil,
                             valueColor: Color = AppTheme.textPrimary) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 110, alignment: .leading)

            Spacer(minLength: 0)

            if let key = glossarKey {
                Button {
                    glossarKey == nil ? () : ()
                    self.glossarKey = key
                } label: {
                    HStack(spacing: 4) {
                        Text(value)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(valueColor)
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
                .accessibilityLabel("\(label): \(value). Tippe für Erklärung.")
            } else {
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Block 3: Geprüfte Positionen (immer alle)

    @ViewBuilder
    private var positionenListe: some View {
        if !positionen.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Geprüfte Positionen")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)

                VStack(spacing: 0) {
                    ForEach(Array(positionen.enumerated()), id: \.offset) { idx, pos in
                        PositionRow(
                            position: pos,
                            finding: findings.first(where: { $0.positionId == pos.id }),
                            glossarKey: $glossarKey
                        )
                        if idx < positionen.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                        .stroke(AppTheme.border, lineWidth: 0.5)
                )
            }
        }
    }

    // MARK: - Block 4: Handlungsempfehlungen (nur bei Findings)

    private var handlungsempfehlungen: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Handlungsempfehlungen")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(findings.enumerated()), id: \.offset) { idx, f in
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Image(systemName: schwereIcon(f.schwere))
                            .font(.system(size: 14))
                            .foregroundStyle(schwereFarbe(f.schwere))
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.bezeichnung)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            if let tip = f.handlungsempfehlung?.nilIfEmpty {
                                Text("→ \(tip)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, AppSpacing.sm)

                    if idx < findings.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .stroke(AppTheme.border, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Block 6: Aktionen

    private var aktionen: some View {
        VStack(spacing: AppSpacing.md) {
            if !findings.isEmpty {
                Button {
                    navigiereZuWiderspruch = true
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "envelope.fill")
                        Text("Widerspruch erstellen")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 0.85, green: 0.65, blue: 0.0))
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                }
                .accessibilityLabel("Widerspruch erstellen")
            }

            Button {
                navigiereZuNeuePruefung = true
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "doc.viewfinder")
                    Text("Neue Prüfung")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
            }
            .accessibilityLabel("Neue Prüfung starten")

            Button {
                NotificationCenter.default.post(name: .nkResetToHome, object: nil)
            } label: {
                Text("Schließen")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .accessibilityLabel("Bericht schließen")
            .padding(.top, AppSpacing.xs)
        }
    }

    // MARK: - Formatter-Helfer

    private func formatZeitraum() -> String? {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy"
        df.locale = Locale(identifier: "de_DE")
        let von = df.string(from: bericht.abrechnung.meta.zeitraum.von)
        let bis = df.string(from: bericht.abrechnung.meta.zeitraum.bis)
        return "\(von) – \(bis)"
    }

    private func formatFlaeche(_ wert: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 1
        nf.locale = Locale(identifier: "de_DE")
        let s = nf.string(from: wert as NSDecimalNumber) ?? "—"
        return "\(s) m²"
    }

    private func formatGeldKurz(_ wert: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "EUR"
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: wert as NSDecimalNumber) ?? "—"
    }

    private func formatErgebnis(betrag: Decimal, typ: AbrechnungsTyp?) -> String {
        let absStr = formatGeldKurz(abs(betrag))
        switch typ {
        case .guthaben:   return "\(absStr) Guthaben"
        case .nachzahlung: return "\(absStr) Nachzahlung"
        case .none:       return absStr
        }
    }

    private func sortValue(_ s: Schwere) -> Int {
        switch s {
        case .fehler:  return 0
        case .warnung: return 1
        case .info:    return 2
        }
    }

    private func schwereIcon(_ s: Schwere) -> String {
        switch s {
        case .fehler:  return "exclamationmark.octagon.fill"
        case .warnung: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    private func schwereFarbe(_ s: Schwere) -> Color {
        switch s {
        case .fehler:  return AppTheme.error
        case .warnung: return AppTheme.warning
        case .info:    return AppTheme.textSecondary
        }
    }
}

// MARK: - Position-Row (aufklappbar)

private struct PositionRow: View {
    let position: Kostenposition
    let finding: Finding?
    @Binding var glossarKey: String?

    @State private var expanded: Bool = false

    private var hasFinding: Bool { finding != nil }

    private var statusIcon: String {
        guard let f = finding else { return "checkmark.circle.fill" }
        switch f.schwere {
        case .fehler:  return "exclamationmark.octagon.fill"
        case .warnung: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    private var statusFarbe: Color {
        guard let f = finding else { return AppTheme.success }
        switch f.schwere {
        case .fehler:  return AppTheme.error
        case .warnung: return AppTheme.warning
        case .info:    return AppTheme.textSecondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Text(position.bezeichnungOriginal)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: AppSpacing.sm)
                    Text(formatGeld(position.mieterAnteil))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                    Image(systemName: statusIcon)
                        .font(.system(size: 16))
                        .foregroundStyle(statusFarbe)
                }
                .padding(.vertical, AppSpacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    detailRow(label: "Verteilerschlüssel",
                              value: position.verteilerschluessel.rawValue.capitalized,
                              glossarKey: "verteilerschluessel")

                    if let gk = position.gesamtkosten {
                        detailRow(label: "Gesamtkosten", value: formatGeld(gk))
                    }

                    if let kn = position.kostenartNormalisiert?.nilIfEmpty {
                        detailRow(label: "Kategorie", value: kn.capitalized)
                    }

                    if let f = finding {
                        Divider().padding(.vertical, 4)
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            Image(systemName: statusIcon)
                                .font(.system(size: 14))
                                .foregroundStyle(statusFarbe)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(f.beschreibung)
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)

                                if let erkl = f.erklaerung?.nilIfEmpty {
                                    Text(erkl)
                                        .font(.system(size: 13))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                if let rg = f.rechtsgrundlage?.nilIfEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "books.vertical")
                                            .font(.system(size: 11))
                                        Text(rg)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundStyle(AppTheme.accent)
                                }

                                if let tip = f.handlungsempfehlung?.nilIfEmpty {
                                    Text("→ \(tip)")
                                        .font(.system(size: 13))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.top, 2)
                                }
                            }
                        }
                    } else {
                        Text("Keine Auffälligkeiten festgestellt.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.bottom, AppSpacing.md)
                .padding(.leading, AppSpacing.xs)
                .transition(.opacity)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func detailRow(label: String, value: String, glossarKey: String? = nil) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text("\(label):")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
            if let key = glossarKey {
                Button {
                    self.glossarKey = key
                } label: {
                    HStack(spacing: 3) {
                        Text(value)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                            .underline()
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.accent.opacity(0.7))
                    }
                }
                .accessibilityLabel("\(label): \(value). Tippe für Erklärung.")
            } else {
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Lokaler String-Helper

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

// MARK: - Preview

#Preview {
    let bericht = Pruefbericht(
        abrechnungId: "NK-2026-PREV",
        pruefDatum: Date(),
        abrechnung: Abrechnung(
            meta: AbrechnungMeta(
                vermieter: ParsedVermieter(name: "Demo", adresse: "Demo-Adresse"),
                objekt: ParsedObjekt(adresse: "Bahnhofstr. 37, 12207 Berlin",
                                     gesamtflaecheQm: 1000, anzahlEinheiten: 18, baujahr: nil),
                zeitraum: Zeitraum(von: .now, bis: .now),
                mieterEinheit: MieterEinheit(bezeichnung: "OG - Wohnung",
                                             flaecheQm: 187, personen: 2),
                vorauszahlungenGesamt: 5640,
                nachzahlungOderGuthaben: 674.90,
                typ: .guthaben
            ),
            kostenpositionen: [],
            summeAnteile: 0,
            confidenceGesamt: .high,
            warnungen: []
        ),
        findings: [],
        berichtText: "",
        ersparnisGesamt: 0
    )
    let demoMietobjekt = Mietobjekt(adresse: "Bahnhofstr. 37, 12207 Berlin",
                                    flaecheQm: 187, personenzahl: 2)
    return NavigationStack { BerichtView(bericht: bericht, mietobjekt: demoMietobjekt) }
        .modelContainer(for: [Mietobjekt.self, GespeicherteAbrechnung.self, APIAuditEntry.self], inMemory: true)
}
