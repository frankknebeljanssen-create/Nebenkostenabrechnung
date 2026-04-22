//
//  HomeView.swift
//  NebenkostenApp — UI/Home
//
//  Home-Screen-Rebuild (Stufe 2 nach docs/home-bestandsanalyse.md):
//  Ein Ring, eine Top-Schritte-Liste, zwei feste CTAs am unteren
//  Rand. Kein Scroll — der gesamte Content sitzt in einer VStack
//  unter dem `KontextHeader` und nutzt `Spacer` fuer die vertikale
//  Verteilung.
//
//  Komponenten in dieser Datei (private fileprivate structs):
//    - `CompletionRingView`        — animierter Kreis-Ring
//    - `NaechsteSchritteListe`     — max. 3 tappbare Zeilen
//    - `HomeCTAButtonPrimary`      — Accent, nur bei 100 % sichtbar
//    - `HomeCTAButtonSecondary`    — immer sichtbar, fuehrt zur
//                                    KachelansichtView via
//                                    `NavigationLink`
//    - `HomeLeerzustand`           — Keine Immobilie/Periode
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(ScopeManager.self) private var scope
    @Environment(AppShellRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var zeigeScopePicker = false
    @State private var zeigeEinstellungen = false
    /// Aktive Scan-Anforderung aus einem Naechste-Schritte-Tap.
    /// Wenn gesetzt, oeffnet sich `ScanEntryView` — nach Fertig
    /// erzeugt `erzeugeRechnungNachScan` eine neue Rechnung mit
    /// exakt dieser Kostenart.
    @State private var scanKostenartID: UUID?

    /// Aktuell angezeigte Immobilie — Fallback auf die erste.
    private var aktiveImmobilie: Immobilie? {
        if let id = scope.aktuelleImmobilieID,
           let treffer = immobilien.first(where: { $0.id == id }) {
            return treffer
        }
        return immobilien.first
    }

    /// Die aktivste Periode: entweder die zuletzt abgeschlossene
    /// (bis < heute), sonst die erste sortiert nach bis-Datum.
    private var aktivePeriode: Abrechnungsperiode? {
        let perioden = (aktiveImmobilie?.perioden ?? [])
            .sorted(by: { $0.bis > $1.bis })
        let heute = Date()
        return perioden.first(where: { $0.bis < heute }) ?? perioden.first
    }

    /// Alle Anforderungen der aktiven Periode.
    private var anforderungen: [AnforderungMitStatus] {
        guard let immobilie = aktiveImmobilie,
              let p = aktivePeriode else { return [] }
        return VollstaendigkeitsPruefung.pruefe(immobilie: immobilie, periode: p)
    }

    private var zusammenfassung: VollstaendigkeitsPruefung.Zusammenfassung {
        VollstaendigkeitsPruefung.zusammenfassung(fuer: anforderungen)
    }

    private var prozent: Int { zusammenfassung.completionProzent }

    /// Die drei nachsten Anforderungen — gefiltert (nur mit
    /// Sprungziel, keine erfuellten, keine nichtErwartet) und sortiert
    /// nach Kategorie-Rang (stammdaten → zaehlerstand → rechnung).
    /// WMZ-Plausi (Warnung, kein Blocker) fliegt raus — die gehoert
    /// nicht in "Naechste Schritte".
    private var topSchritte: [AnforderungMitStatus] {
        let offen = anforderungen.filter {
            $0.sprungZiel != nil
                && $0.status != .erfuellt
                && $0.status != .nichtErwartet
                && $0.anforderung.id != "plausi-wmz"
        }
        let sortiert = offen.sorted { lhs, rhs in
            kategorieRang(lhs.anforderung.kategorie)
                < kategorieRang(rhs.anforderung.kategorie)
        }
        return Array(sortiert.prefix(3))
    }

    private func kategorieRang(_ k: AnforderungsKategorie) -> Int {
        switch k {
        case .stammdaten:   return 0
        case .zaehlerstand: return 1
        case .rechnung:     return 2
        }
    }

    var body: some View {
        inhalt
            .appShellChrome(
                titel: nil,
                subtitel: nil,
                onAdresse: { zeigeScopePicker = true },
                onEinstellungen: { zeigeEinstellungen = true },
                zeigeAdresseOben: false,
                zeigeScopeStrip: false
            )
            .sheet(isPresented: $zeigeScopePicker) { ScopePickerSheet() }
            .sheet(isPresented: $zeigeEinstellungen) { EinstellungenSheet() }
            .sheet(isPresented: Binding(
                get: { scanKostenartID != nil },
                set: { if !$0 { scanKostenartID = nil } }
            )) {
                ScanEntryView(
                    vorausgewaehlteKostenartName: gewaehlteScanKostenart?.bezeichnung,
                    onFertig: { dokument in
                        erzeugeRechnungNachScan(dokument: dokument)
                    }
                )
            }
            .onChange(of: router.aktuellesSprungziel) { _, neu in
                reagiereAufSprungziel(neu)
            }
    }

    /// Nachschlag der Ziel-Kostenart aus der aktiven Immobilie.
    /// Wird fuer die Anzeige im Scan-Sheet und fuer die Rechnungs-
    /// Erzeugung genutzt. Nil, wenn die ID zwischenzeitlich
    /// geloescht wurde — der Scan laeuft dann ohne Kontext-Hinweis.
    private var gewaehlteScanKostenart: Kostenart? {
        guard let id = scanKostenartID,
              let immobilie = aktiveImmobilie else { return nil }
        return (immobilie.kostenarten ?? []).first { $0.id == id }
    }

    /// Erzeugt nach Abschluss von `DokumentErfassungView` eine neue
    /// `Rechnung`-Entity mit der vorausgewaehlten Kostenart, Betrag
    /// und Versorger aus dem Dokument. `validierungsStatus = .manuell`
    /// + `geprueft = true` — der User hat den Scan aktiv erfasst,
    /// die Rechnung gilt als durchgereicht. Die Anforderung
    /// "Rechnung hinzufuegen" verschwindet damit aus der Home-Liste.
    private func erzeugeRechnungNachScan(dokument: GespeichertesDokument) {
        guard let kostenart = gewaehlteScanKostenart,
              let immobilie = aktiveImmobilie else { return }
        let rechnung = Rechnung()
        rechnung.lieferant = dokument.versorger ?? kostenart.bezeichnung
        rechnung.rechnungsdatum = dokument.erstelltAm
        rechnung.leistungVon = dokument.erstelltAm
        rechnung.leistungBis = dokument.erstelltAm
        rechnung.betragBruttoEuro = dokument.betragBrutto ?? 0
        rechnung.immobilie = immobilie
        rechnung.kostenart = kostenart
        rechnung.validierungsStatus = .manuell
        rechnung.geprueft = true
        rechnung.extraktionsNotizen = "Direkt aus Home-Scan ("
            + kostenart.bezeichnung + ")"
        modelContext.insert(rechnung)
        try? modelContext.save()
    }

    @ViewBuilder
    private var inhalt: some View {
        if immobilien.isEmpty || aktivePeriode == nil {
            HomeLeerzustand(ctaAktion: { zeigeEinstellungen = true })
        } else {
            hauptStapel
        }
    }

    /// Der eigentliche Home-Content — Ring + Schritte + CTAs.
    /// Wir verteilen Ring-Block (oben) und CTA-Block (unten) ueber
    /// einen `Spacer()` zwischen Schritten und Buttons, damit der
    /// Screen auf kleinen iPhones ohne Scroll funktioniert.
    private var hauptStapel: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)
            CompletionRingView(prozent: prozent)
            Spacer(minLength: 16)
            NaechsteSchritteListe(
                items: topSchritte,
                onTap: { ziel in
                    router.springe(zu: ziel)
                }
            )
            .padding(.horizontal, 16)
            Spacer()
            ctaBlock
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignTokens.bgAppCompact)
    }

    private var ctaBlock: some View {
        VStack(spacing: 10) {
            if prozent == 100 {
                HomeCTAButtonPrimary(
                    titel: "Abrechnung erstellen",
                    symbol: "doc.text.fill"
                ) {
                    router.aktiverTab = .abrechnungen
                }
            }
            NavigationLink {
                KachelansichtView()
            } label: {
                HomeCTAButtonSecondaryLabel(
                    titel: "Zur Kachelansicht",
                    symbol: "square.grid.2x2"
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Router-Reaktion

    private func reagiereAufSprungziel(_ ziel: Sprungziel?) {
        switch ziel {
        case .mieterVorauszahlung(let einheitId):
            router.oeffneVorauszahlungSheet(einheitID: einheitId)
            router.quittiere()
        case .einstellungenObjekt,
             .einstellungenPeriode:
            zeigeEinstellungen = true
            router.quittiere()
        case .scanMitKostenart(let kostenartId):
            scanKostenartID = kostenartId
            router.quittiere()
        default:
            break
        }
    }
}

// MARK: - Ring

fileprivate struct CompletionRingView: View {
    let prozent: Int

    /// `.onAppear` sorgt fuer den Ease-In, `.onChange` fuer Updates
    /// nach dem Pruefen (z.B. wenn der User aus einem Sheet zurueck-
    /// kehrt und Stammdaten geaendert hat).
    @State private var animatedProzent: CGFloat = 0

    private var farbe: Color { CompletionFarbe.fuer(prozent: prozent) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(farbe.opacity(0.15), style: strokeStyle)
                .frame(width: 140, height: 140)
            Circle()
                .trim(from: 0, to: animatedProzent / 100)
                .stroke(farbe, style: strokeStyle)
                .rotationEffect(.degrees(-90))
                .frame(width: 140, height: 140)
            VStack(spacing: 2) {
                Text("\(prozent)%")
                    .appFont(AppFontStyle(
                        font: AppFont.plexMono(.semibold, 36),
                        tracking: -0.5,
                        uppercase: false
                    ))
                    .foregroundStyle(DesignTokens.text)
                Text("vollständig")
                    .appFont(AppFont.Basis.subtitle())
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedProzent = CGFloat(prozent)
            }
        }
        .onChange(of: prozent) { _, neu in
            withAnimation(.easeInOut(duration: 0.4)) {
                animatedProzent = CGFloat(neu)
            }
        }
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 12, lineCap: .round)
    }
}

// MARK: - Naechste Schritte

fileprivate struct NaechsteSchritteListe: View {
    let items: [AnforderungMitStatus]
    let onTap: (Sprungziel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nächste Schritte")
                .appFont(AppFont.Basis.kicker())
                .foregroundStyle(DesignTokens.textSecondary)

            if items.isEmpty {
                alleBereitZeile
            } else {
                VStack(spacing: 8) {
                    ForEach(items, id: \.anforderung.id) { anf in
                        schrittRow(anf)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var alleBereitZeile: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DesignTokens.statusOk)
            Text("Alles vollständig")
                .appFont(AppFont.Basis.bodySemi())
                .foregroundStyle(DesignTokens.statusOk)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(DesignTokens.statusOkSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func schrittRow(_ anf: AnforderungMitStatus) -> some View {
        Button {
            if let ziel = anf.sprungZiel { onTap(ziel) }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(statusFarbe(anf.status))
                    .frame(width: 8, height: 8)
                Text(anf.anforderung.titel)
                    .appFont(AppFont.Basis.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.bgSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(DesignTokens.separator, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statusFarbe(_ status: AnforderungsStatus) -> Color {
        switch status {
        case .offen:     return DesignTokens.statusError
        case .teilweise: return DesignTokens.statusWarn
        default:         return DesignTokens.textSecondary
        }
    }
}

// MARK: - CTAs

fileprivate struct HomeCTAButtonPrimary: View {
    let titel: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(titel)
                    .appFont(AppFont.Basis.bodySemi())
                Spacer(minLength: 4)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(DesignTokens.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(titel)
    }
}

fileprivate struct HomeCTAButtonSecondaryLabel: View {
    let titel: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
            Text(titel)
                .appFont(AppFont.Basis.bodySemi())
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(DesignTokens.text)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(DesignTokens.bgSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DesignTokens.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Leerzustand

fileprivate struct HomeLeerzustand: View {
    let ctaAktion: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "house")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(DesignTokens.textSecondary)
            Text("Willkommen")
                .appFont(AppFont.Basis.periodenHeader())
                .foregroundStyle(DesignTokens.text)
            Text("Legen Sie Ihr erstes Objekt mit Abrechnungsperiode an, dann erscheint hier der Completion-Ring.")
                .appFont(AppFont.Basis.body())
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            Button(action: ctaAktion) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Erstes Objekt anlegen")
                        .appFont(AppFont.Basis.bodySemi())
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(DesignTokens.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.bgAppCompact)
    }
}
