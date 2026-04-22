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

    /// Alle offenen/teilweise erfuellten Anforderungen mit Sprungziel
    /// (ohne WMZ-Plausi — die ist eine Warnung, kein Schritt). Basis
    /// fuer `topSchritte` und die "N offen"-Anzeige im Card-Header.
    private var offeneAnforderungen: [AnforderungMitStatus] {
        anforderungen.filter {
            $0.sprungZiel != nil
                && $0.status != .erfuellt
                && $0.status != .nichtErwartet
                && $0.anforderung.id != "plausi-wmz"
        }
    }

    /// Die naechsten Anforderungen, Blocker-first nach Kategorie
    /// (stammdaten → zaehlerstand → rechnung). Wir zeigen mindestens
    /// vier — Platz auf dem Home-Screen ist da, und der User sieht
    /// damit unten schon drei Schritte voraus, nicht nur einen.
    private var topSchritte: [AnforderungMitStatus] {
        let sortiert = offeneAnforderungen.sorted { lhs, rhs in
            kategorieRang(lhs.anforderung.kategorie)
                < kategorieRang(rhs.anforderung.kategorie)
        }
        return Array(sortiert.prefix(4))
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
            // Unsichtbarer navigationTitle — AppShellChrome blendet
            // die NavBar eh aus. iOS nutzt ihn aber fuer den
            // automatischen Back-Button-Text beim Push
            // (Kachelansicht → zurueck zu „Home").
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
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
                gesamtOffen: offeneAnforderungen.count,
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

    /// CTA-Block. Regel:
    ///   - prozent < 100  → "Home" ist primaer (Accent).
    ///     "Abrechnung erstellen" ist nicht sichtbar, solange nicht
    ///     alle Anforderungen erfuellt sind.
    ///   - prozent == 100 → "Abrechnung erstellen" ist primaer,
    ///     "Home" rutscht auf secondary (Outline).
    private var ctaBlock: some View {
        VStack(spacing: 10) {
            if prozent == 100 {
                Button {
                    router.aktiverTab = .abrechnungen
                } label: {
                    HomeCTALabel(
                        titel: "Abrechnung erstellen",
                        symbol: "doc.text.fill",
                        istPrimaer: true
                    )
                }
                .buttonStyle(.plain)
                NavigationLink(value: HomeDestination.kachelansicht) {
                    HomeCTALabel(
                        titel: "Zur Übersicht",
                        symbol: "square.grid.2x2",
                        istPrimaer: false
                    )
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(value: HomeDestination.kachelansicht) {
                    HomeCTALabel(
                        titel: "Zur Übersicht",
                        symbol: "square.grid.2x2",
                        istPrimaer: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
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
    /// Gesamt-Anzahl der offenen Anforderungen (nicht nur die drei
    /// sichtbaren) — wird im Card-Header als "N offen" angezeigt,
    /// damit der User weiss, dass es moeglicherweise mehr gibt als
    /// die Top 3.
    let gesamtOffen: Int
    let onTap: (Sprungziel) -> Void

    var body: some View {
        if items.isEmpty {
            alleBereitZeile
        } else {
            karteMitItems
        }
    }

    /// Ein gemeinsamer Card-Container: Header (Titel + "N offen")
    /// oben, danach eine Liste der Top-3-Items durch `Divider`
    /// getrennt. Keine Schatten — `bgSurface` auf `bgAppCompact`
    /// setzt die Card genug ab.
    private var karteMitItems: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ForEach(Array(items.enumerated()), id: \.element.anforderung.id) { idx, anf in
                row(anf)
                if idx < items.count - 1 {
                    Divider().padding(.leading, 40)
                }
            }
        }
        .background(DesignTokens.bgSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DesignTokens.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Noch zu erledigen")
                .appFont(AppFont.Basis.kicker())
                .foregroundStyle(DesignTokens.textSecondary)
            Spacer()
            // +2pt ggue. `monoSmall()` (11 → 13) plus Medium-Weight —
            // der Counter rechts oben war bisher zu leise.
            Text("\(gesamtOffen) offen")
                .appFont(AppFontStyle(
                    font: AppFont.plexMono(.medium, 13),
                    tracking: 0,
                    uppercase: false
                ))
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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

    private func row(_ anf: AnforderungMitStatus) -> some View {
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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

// MARK: - CTA

/// Einheitlicher Label-Baustein fuer die Home-CTAs. Unter
/// `NavigationLink` fuer den Kachelansicht-Push, unter `Button`
/// fuer "Abrechnung erstellen". `istPrimaer` steuert Accent-Fill
/// + weisse Schrift (primaer) vs. Outline + text-Farbe (secondary).
/// 62-pt-Mindesthoehe — nach Geraete-Feedback vergroessert, damit
/// der Hero-CTA sich klar absetzt und der Daumen zuverlaessig
/// trifft (Zielgruppe 50+).
fileprivate struct HomeCTALabel: View {
    let titel: String
    let symbol: String
    let istPrimaer: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
            Text(titel)
                .appFont(AppFont.Basis.bodySemi())
            Spacer(minLength: 4)
            Image(systemName: istPrimaer ? "arrow.right" : "chevron.right")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(istPrimaer ? Color.white : DesignTokens.text)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(istPrimaer ? DesignTokens.accent : DesignTokens.bgSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    istPrimaer ? Color.clear : DesignTokens.separator,
                    lineWidth: 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
