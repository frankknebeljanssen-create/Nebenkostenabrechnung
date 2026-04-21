//
//  KontextDetailSheet.swift
//  NebenkostenApp — UI/Home
//
//  Detail-Sheet, das beim Tap auf eine Home-Card (Objekt bzw.
//  Wohneinheit) erscheint. Zeigt scope-abhaengig entweder die
//  Objekt-Uebersicht (Adresse + alle Einheiten mit Mieter + VZ)
//  oder das Detail einer einzelnen Wohneinheit (Mieter-Name,
//  Anschrift, Vorauszahlung) — genau der Einheit, die der User
//  antippt, ohne Daten der anderen Mieter.
//
//  Architektur-Regel (systemweit): Einstellungen erreicht man
//  AUSSCHLIESSLICH ueber das Zahnrad in `AppShellChrome`. Taps
//  auf Cards oeffnen stets Detail-Views ueber dem aktuellen
//  Kontext, NICHT das Einstellungen-Sheet.
//

import SwiftUI

struct KontextDetailSheet: View {
    let immobilie: Immobilie
    let scope: AppScope

    @Environment(\.dismiss) private var dismiss
    @Environment(AppShellRouter.self) private var router

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch scope {
                    case .objekt:
                        ObjektDetailInhalt(
                            immobilie: immobilie,
                            onVzFuer: { id in
                                router.oeffneVorauszahlungSheet(einheitID: id)
                            }
                        )
                    case .einheit(let id):
                        if let we = (immobilie.wohneinheiten ?? []).first(where: { $0.bezeichnung == id }) {
                            EinheitDetailInhalt(
                                immobilie: immobilie,
                                einheit: we,
                                onVzBearbeiten: {
                                    router.oeffneVorauszahlungSheet(einheitID: id)
                                }
                            )
                        } else {
                            Text("Wohneinheit \(id) nicht gefunden.")
                                .appFont(AppFont.bodyMedium())
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(DesignTokens.bgApp)
            .navigationTitle(navTitel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen(titel: "Fertig") { dismiss() }
                }
            }
        }
        .tint(DesignTokens.accent)
    }

    private var navTitel: String {
        switch scope {
        case .objekt:
            return "Objekt"
        case .einheit(let id):
            return "\(id)"
        }
    }
}

// MARK: - Objekt-Detail

private struct ObjektDetailInhalt: View {
    let immobilie: Immobilie
    let onVzFuer: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Card(tiefe: .erhoben, balkenFarbe: DesignTokens.unitObjekt) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("OBJEKT")
                        .appFont(AppFont.Dashboard.kartenKicker())
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text(immobilie.adresse.isEmpty ? "Ohne Adresse" : immobilie.adresse)
                        .appFont(AppFont.bodySemi())
                        .foregroundStyle(DesignTokens.text)
                    if !immobilie.ort.isEmpty {
                        Text(immobilie.ort)
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                    if immobilie.gesamtflaecheM2 > 0 {
                        Text(Formatting.m2(immobilie.gesamtflaecheM2))
                            .appFont(AppFont.monoCaption())
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }
            }

            let sortiert = (immobilie.wohneinheiten ?? []).sorted {
                ScopeFilter.einheitRang($0.bezeichnung) < ScopeFilter.einheitRang($1.bezeichnung)
            }

            if sortiert.isEmpty {
                Card {
                    Text("Noch keine Einheiten erfasst.")
                        .appFont(AppFont.bodyMedium())
                        .foregroundStyle(DesignTokens.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(sortiert) { einheit in
                    MieterCard(
                        einheit: einheit,
                        onVzBearbeiten: { onVzFuer(einheit.bezeichnung) }
                    )
                }
            }
        }
    }
}

// MARK: - Einheit-Detail

private struct EinheitDetailInhalt: View {
    let immobilie: Immobilie
    let einheit: Wohneinheit
    let onVzBearbeiten: () -> Void

    private var aktivesMv: Mietverhaeltnis? {
        (einheit.mietverhaeltnisse ?? []).first { $0.auszugAm == nil }
    }

    private var scopeFarbe: Color { ScopeFarbe.farbe(fuer: einheit) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Einheit-Kopfzeile
            Card(tiefe: .erhoben, balkenFarbe: scopeFarbe) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WOHNEINHEIT")
                        .appFont(AppFont.Dashboard.kartenKicker())
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text(einheit.bezeichnung)
                        .appFont(AppFont.bodySemi())
                        .foregroundStyle(DesignTokens.text)
                    HStack(spacing: 10) {
                        if einheit.flaecheM2 > 0 {
                            Text(Formatting.m2(einheit.flaecheM2))
                                .appFont(AppFont.monoCaption())
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                        Text(einheit.nutzungsart.rawValue.capitalized)
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                    if !immobilie.adresse.isEmpty {
                        Text(immobilie.adresse + (immobilie.ort.isEmpty ? "" : ", \(immobilie.ort)"))
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.textTertiary)
                            .lineLimit(2)
                    }
                }
            }

            MieterCard(einheit: einheit, onVzBearbeiten: onVzBearbeiten)
        }
    }
}

// MARK: - Mieter-Card (wiederverwendet in Objekt- und Einheit-Detail)

private struct MieterCard: View {
    let einheit: Wohneinheit
    let onVzBearbeiten: () -> Void

    private var aktivesMv: Mietverhaeltnis? {
        (einheit.mietverhaeltnisse ?? []).first { $0.auszugAm == nil }
    }

    private var scopeFarbe: Color { ScopeFarbe.farbe(fuer: einheit) }

    var body: some View {
        Card(tiefe: .flach, balkenFarbe: scopeFarbe) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(einheit.bezeichnung)
                        .appFont(AppFont.bodySemi())
                        .foregroundStyle(DesignTokens.text)
                    Spacer()
                    if einheit.flaecheM2 > 0 {
                        Text(Formatting.m2(einheit.flaecheM2))
                            .appFont(AppFont.monoCaption())
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }

                if let mv = aktivesMv {
                    feldZeile(label: "Mieter", wert: mv.mieterName.isEmpty ? "—" : mv.mieterName)
                    if !mv.mieterAnschrift.isEmpty {
                        feldZeile(label: "Anschrift", wert: mv.mieterAnschrift, mehrzeilig: true)
                    }
                    if !mv.mieterEmail.isEmpty {
                        feldZeile(label: "E-Mail", wert: mv.mieterEmail)
                    }
                    DividerLine()
                    Button(action: onVzBearbeiten) {
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Vorauszahlung / Monat")
                                    .appFont(AppFont.caption())
                                    .foregroundStyle(DesignTokens.textSecondary)
                                if mv.vorauszahlungErfasst {
                                    Text(Formatting.euro(mv.vorauszahlungMonatEuro))
                                        .appFont(AppFont.monoBetrag17())
                                        .foregroundStyle(DesignTokens.text)
                                } else {
                                    Text("Noch nicht erfasst")
                                        .appFont(AppFont.bodyMedium())
                                        .foregroundStyle(DesignTokens.textTertiary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Leerstand · kein aktives Mietverhältnis")
                        .appFont(AppFont.bodyMedium())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
        }
    }

    @ViewBuilder
    private func feldZeile(label: String, wert: String, mehrzeilig: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .appFont(AppFont.caption())
                .foregroundStyle(DesignTokens.textSecondary)
                .frame(width: 92, alignment: .leading)
            Text(wert)
                .appFont(AppFont.bodyMedium())
                .foregroundStyle(DesignTokens.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineLimit(mehrzeilig ? nil : 1)
        }
    }
}
