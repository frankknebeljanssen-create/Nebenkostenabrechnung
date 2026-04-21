//
//  VollstaendigkeitsInspektorSheet.swift
//  NebenkostenApp — UI/Vollstaendigkeit
//
//  "Was fehlt mir noch?" — Read-only-Inspektor-Sheet, das die
//  AnforderungMitStatus-Liste gruppiert nach offen / in Arbeit /
//  erledigt darstellt. Bietet Sprungziele (Rechnung neu anlegen,
//  Zählerstand erfassen) über Callbacks; die Parent-View kümmert
//  sich um die Sheet-Abfolge.
//

import SwiftUI
import SwiftData
import UIKit

struct VollstaendigkeitsInspektorSheet: View {
    let immobilie: Immobilie
    let periode: Abrechnungsperiode

    /// Callback: User möchte eine neue Rechnung manuell anlegen.
    var onRechnungAnlegen: () -> Void = {}
    /// Callback: User möchte Zählerstände für diesen Zähler erfassen.
    var onZaehlerOeffnen: (Zaehler) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var erledigteAufgeklappt = false
    @State private var kopiertHinweis = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusHeader

                    // STAMMDATEN-GRUPPE
                    if !fehlendeStammdaten.isEmpty {
                        gruppenHeader(
                            titel: "Stammdaten",
                            untertitel: "Objekt · Mieter · Vermieter",
                            symbol: "person.text.rectangle"
                        )
                        sektion(
                            titel: "Stammdaten, die fehlen",
                            farbe: .gray,
                            eintraege: fehlendeStammdaten
                        ) { eintrag in
                            zeileInfoOnly(eintrag)
                        }
                    }

                    // ABRECHNUNGSDATEN-GRUPPE
                    if !fehlendeZaehler.isEmpty || !fehlendeRechnungen.isEmpty {
                        gruppenHeader(
                            titel: "Abrechnungsdaten diese Periode",
                            untertitel: "Belege · Zählerstände · Vorauszahlungen",
                            symbol: "doc.text.magnifyingglass"
                        )
                        if !fehlendeRechnungen.isEmpty {
                            sektion(
                                titel: "Rechnungen, die noch fehlen",
                                farbe: .gray,
                                eintraege: fehlendeRechnungen
                            ) { eintrag in
                                zeileFehlendeRechnung(eintrag)
                            }
                        }
                        if !fehlendeZaehler.isEmpty {
                            sektion(
                                titel: "Zählerstände, die fehlen",
                                farbe: .gray,
                                eintraege: fehlendeZaehler
                            ) { eintrag in
                                zeileFehlenderZaehler(eintrag)
                            }
                        }
                    }

                    // UEBERGREIFEND (keine saubere Einordnung — evtl.
                    // WMZ-Plausi-Warnungen, die sowohl Stamm als auch
                    // Laufend beruehren). Wir halten den Block separat.
                    if !inArbeit.isEmpty {
                        sektion(
                            titel: "In Arbeit / Unklar",
                            farbe: .orange,
                            eintraege: inArbeit
                        ) { eintrag in
                            zeileInArbeit(eintrag)
                        }
                    }
                    if !erledigte.isEmpty {
                        erledigteSektion
                    }
                    exportButton
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Was fehlt mir noch?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    /// Uppercase-Kategorie-Header zwischen den Sektionen. Visuell
    /// deutlich abgesetzt von den Sektions-Titeln („Stammdaten,
    /// die fehlen" usw.), damit der User die beiden Daten-Welten
    /// klar trennen kann.
    private func gruppenHeader(
        titel: String,
        untertitel: String,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(titel.uppercased())
                    .font(.footnote.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            Text(untertitel)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    // MARK: - Daten

    private var anforderungen: [AnforderungMitStatus] {
        VollstaendigkeitsPruefung.pruefe(immobilie: immobilie, periode: periode)
    }

    private var zusammenfassung: VollstaendigkeitsPruefung.Zusammenfassung {
        VollstaendigkeitsPruefung.zusammenfassung(fuer: anforderungen)
    }

    private var fehlendeRechnungen: [AnforderungMitStatus] {
        anforderungen.filter {
            $0.status == .offen && $0.anforderung.kategorie == .rechnung
        }
    }

    private var fehlendeZaehler: [AnforderungMitStatus] {
        anforderungen.filter {
            $0.status == .offen && $0.anforderung.kategorie == .zaehlerstand
        }
    }

    private var fehlendeStammdaten: [AnforderungMitStatus] {
        anforderungen.filter {
            $0.status == .offen && $0.anforderung.kategorie == .stammdaten
        }
    }

    private var inArbeit: [AnforderungMitStatus] {
        anforderungen.filter { $0.status == .teilweise }
    }

    private var erledigte: [AnforderungMitStatus] {
        anforderungen.filter { $0.status == .erfuellt }
    }

    // MARK: - Status-Header

    private var statusHeader: some View {
        let z = zusammenfassung
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(immobilie.adresse) · Abrechnungszeitraum")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(ObjektDashboardViewModel.formatiere(periode))
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: z.bereit
                      ? "checkmark.seal.fill"
                      : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(z.bereit ? .green : .orange)
                Text(z.bereit ? "Bereit zur Abrechnung" : "Nicht bereit zur Abrechnung")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(z.bereit ? .green : .orange)
            }
            .padding(.top, 4)

            Text("\(z.erfuellt) erledigt · \(z.teilweise) in Arbeit · \(z.offen) offen")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Sektion-Helper

    private func sektion<Row: View>(
        titel: String,
        farbe: Color,
        eintraege: [AnforderungMitStatus],
        @ViewBuilder row: @escaping (AnforderungMitStatus) -> Row
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(farbe).frame(width: 8, height: 8)
                Text("\(titel) (\(eintraege.count))")
                    .font(.callout.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Divider().padding(.leading, 14)

            VStack(spacing: 0) {
                ForEach(Array(eintraege.enumerated()), id: \.element.id) { idx, item in
                    row(item)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    if idx < eintraege.count - 1 {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Zeilen

    private func zeileFehlendeRechnung(_ eintrag: AnforderungMitStatus) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(eintrag.anforderung.titel)
                    .font(.callout.weight(.medium))
                Text(eintrag.anforderung.details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            Button {
                onRechnungAnlegen()
                dismiss()
            } label: {
                Label("Eingeben", systemImage: "square.and.pencil")
                    .font(.caption.weight(.medium))
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func zeileFehlenderZaehler(_ eintrag: AnforderungMitStatus) -> some View {
        let zaehler = zaehlerAusID(eintrag.anforderung.id)
        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(eintrag.anforderung.titel)
                    .font(.callout.weight(.medium))
                Text(eintrag.anforderung.details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let hinweis = eintrag.hinweis {
                    Text(hinweis)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 6)
            if let z = zaehler {
                Button {
                    onZaehlerOeffnen(z)
                    dismiss()
                } label: {
                    Label("Erfassen", systemImage: "plus.circle")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func zeileInArbeit(_ eintrag: AnforderungMitStatus) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(eintrag.anforderung.titel)
                    .font(.callout.weight(.medium))
                Text(eintrag.anforderung.details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let hinweis = eintrag.hinweis {
                    Text(hinweis)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func zeileInfoOnly(_ eintrag: AnforderungMitStatus) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(eintrag.anforderung.titel)
                .font(.callout.weight(.medium))
            Text(eintrag.anforderung.details)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Erledigte

    private var erledigteSektion: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation { erledigteAufgeklappt.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text("Alles erledigt (\(erledigte.count))")
                        .font(.callout.weight(.semibold))
                    Spacer()
                    Image(systemName: erledigteAufgeklappt ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if erledigteAufgeklappt {
                Divider().padding(.leading, 14)
                VStack(spacing: 0) {
                    ForEach(Array(erledigte.enumerated()), id: \.element.id) { idx, e in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.anforderung.titel)
                                    .font(.callout)
                                Text(e.anforderung.details)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        if idx < erledigte.count - 1 {
                            Divider().padding(.leading, 40)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Export

    private var exportButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                UIPasteboard.general.string = textExport
                kopiertHinweis = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    kopiertHinweis = false
                }
            } label: {
                Label(kopiertHinweis ? "In Zwischenablage kopiert" : "Liste als Text kopieren",
                      systemImage: kopiertHinweis ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            Text("Praktisch für Einkaufslisten oder eigene Notizen.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var textExport: String {
        var zeilen: [String] = []
        let ref = "\(immobilie.adresse) · \(ObjektDashboardViewModel.formatiere(periode))"
        zeilen.append("Vollständigkeit \(ref)")
        zeilen.append("")
        let z = zusammenfassung
        zeilen.append("Status: \(z.bereit ? "BEREIT" : "NICHT BEREIT") — \(z.erfuellt) erledigt, \(z.teilweise) in Arbeit, \(z.offen) offen")
        zeilen.append("")
        zeilen.append(contentsOf: blockText("RECHNUNGEN FEHLEN", fehlendeRechnungen))
        zeilen.append(contentsOf: blockText("ZÄHLERSTÄNDE FEHLEN", fehlendeZaehler))
        zeilen.append(contentsOf: blockText("STAMMDATEN FEHLEN", fehlendeStammdaten))
        zeilen.append(contentsOf: blockText("IN ARBEIT", inArbeit))
        return zeilen.joined(separator: "\n")
    }

    private func blockText(_ titel: String, _ liste: [AnforderungMitStatus]) -> [String] {
        guard !liste.isEmpty else { return [] }
        var result = ["[\(titel)]"]
        for e in liste {
            var line = "• \(e.anforderung.titel) — \(e.anforderung.details)"
            if let h = e.hinweis { line += " (\(h))" }
            result.append(line)
        }
        result.append("")
        return result
    }

    // MARK: - Zähler-Lookup

    private var alleZaehler: [Zaehler] {
        let haupt = immobilie.hauptzaehler ?? []
        let wohnung = (immobilie.wohneinheiten ?? []).flatMap { $0.zaehler ?? [] }
        return haupt + wohnung
    }

    private func zaehlerAusID(_ id: String) -> Zaehler? {
        let prefix = "zaehler-"
        guard id.hasPrefix(prefix) else { return nil }
        let rest = String(id.dropFirst(prefix.count))
        guard let uuid = UUID(uuidString: rest) else { return nil }
        return alleZaehler.first(where: { $0.id == uuid })
    }
}
