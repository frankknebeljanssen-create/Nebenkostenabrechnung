//
//  ScopeBanner.swift
//  NebenkostenApp — UI/Components
//
//  Kleiner Banner, den Kachel-Screens unter ihrem Fortschritts-
//  Header einblenden, wenn der aktive Scope NICHT `.objekt` ist.
//  Macht fuer den User transparent, dass die Liste/Zahlen nur
//  einen Ausschnitt zeigen.
//
//  Format:
//    [🏠-Icon in ScopeFarbe]  Ansicht: <Bezeichnung> · <Mieter-Abk>
//
//  Bei Objekt-Scope rendert der Banner einen `EmptyView` — Aufrufer
//  koennen ihn also bedenkenlos in ihren VStack einhaengen, ohne
//  selbst auf den Scope-Case zu schalten.
//

import SwiftUI
import SwiftData

struct ScopeBanner: View {
    let immobilie: Immobilie
    @Environment(ScopeManager.self) private var scope

    var body: some View {
        switch scope.scope {
        case .objekt:
            EmptyView()
        case .einheit(let id):
            if let einheit = (immobilie.wohneinheiten ?? [])
                .first(where: { $0.bezeichnung.caseInsensitiveCompare(id) == .orderedSame }) {
                bannerInhalt(fuer: einheit)
            }
        }
    }

    private func bannerInhalt(fuer e: Wohneinheit) -> some View {
        let farbe = ScopeFarbe.farbe(fuer: e)
        return HStack(spacing: 8) {
            Image(systemName: ScopeFarbe.icon(fuer: e))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(farbe)
            Text("Ansicht: \(labelFuer(e))")
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(farbe)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(farbe.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(farbe.opacity(0.35), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func labelFuer(_ e: Wohneinheit) -> String {
        let bez = e.bezeichnung.trimmingCharacters(in: .whitespaces)
        let aktiv = (e.mietverhaeltnisse ?? [])
            .first(where: { $0.auszugAm == nil })
        guard let mv = aktiv else { return bez.isEmpty ? "Einheit" : bez }
        let kurz = ScopeTexte.abkuerzungName(mv.mieterName)
        if kurz.isEmpty { return bez }
        return "\(bez) · \(kurz)"
    }
}
