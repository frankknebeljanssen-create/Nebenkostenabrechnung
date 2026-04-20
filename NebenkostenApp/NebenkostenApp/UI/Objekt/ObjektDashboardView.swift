//
//  ObjektDashboardView.swift
//  NebenkostenApp — UI/Objekt
//

import SwiftUI
import SwiftData

struct ObjektDashboardView: View {
    @Bindable var immobilie: Immobilie

    @State private var gewaehltePeriodeID: UUID?

    private let spalten = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                kopf
                periodePicker
                ring
                kachelGrid
                wohneinheitenSektion
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Objekt")
        .onAppear(perform: waehleDefaultPeriode)
    }

    // MARK: - Abgeleitete Werte

    private var perioden: [Abrechnungsperiode] {
        (immobilie.perioden ?? []).sorted(by: { $0.bis > $1.bis })
    }

    private var aktivePeriode: Abrechnungsperiode? {
        if let id = gewaehltePeriodeID, let treffer = perioden.first(where: { $0.id == id }) {
            return treffer
        }
        return defaultPeriode
    }

    /// Jüngste bereits abgeschlossene Periode (bis < heute). Ist meist die
    /// Periode, für die der User gerade abrechnen will — deren Daten liegen
    /// vollständig vor. Fallback: jüngste Periode überhaupt.
    private var defaultPeriode: Abrechnungsperiode? {
        let heute = Date()
        if let abgeschlossen = perioden.first(where: { $0.bis < heute }) {
            return abgeschlossen
        }
        return perioden.first
    }

    private var viewModel: ObjektDashboardViewModel {
        ObjektDashboardViewModel(immobilie: immobilie, aktivePeriode: aktivePeriode)
    }

    private func waehleDefaultPeriode() {
        if gewaehltePeriodeID == nil {
            gewaehltePeriodeID = defaultPeriode?.id
        }
    }

    // MARK: - Sektionen

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(immobilie.adresse.isEmpty ? "Unbenanntes Objekt" : immobilie.adresse)
                .font(.title2.bold())
            if !immobilie.ort.isEmpty {
                Text(immobilie.ort)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var periodePicker: some View {
        HStack {
            Text("Abrechnungsperiode")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            if perioden.isEmpty {
                Text("keine Periode")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                Menu {
                    ForEach(perioden) { periode in
                        Button {
                            gewaehltePeriodeID = periode.id
                        } label: {
                            HStack {
                                Text(ObjektDashboardViewModel.formatiere(periode))
                                if periode.id == aktivePeriode?.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.periodeBezeichnung)
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var ring: some View {
        CompletionBalken(prozent: viewModel.completionProzent)
            .padding(.vertical, 4)
    }

    private var kachelGrid: some View {
        LazyVGrid(columns: spalten, spacing: 12) {
            let m = viewModel.mieter
            NavigationLink(value: MieterListenZiel(immobilie: immobilie)) {
                StatusKachel(titel: "Mieter", symbol: "person.2", status: m.status, ist: m.ist, soll: m.soll)
            }
            .buttonStyle(.plain)

            let z = viewModel.zaehler
            StatusKachel(titel: "Zähler",      symbol: "gauge",                 status: z.status,  ist: z.ist,  soll: z.soll)

            let r = viewModel.rechnungen
            NavigationLink(value: RechnungenListenZiel(immobilie: immobilie)) {
                StatusKachel(titel: "Rechnungen", symbol: "doc.text", status: r.status, ist: r.ist, soll: r.soll)
            }
            .buttonStyle(.plain)

            let k = viewModel.kostenarten
            NavigationLink(value: KostenartenListenZiel(immobilie: immobilie)) {
                StatusKachel(titel: "Kostenarten", symbol: "list.bullet.rectangle", status: k.status, ist: k.ist, soll: k.soll)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Wohneinheiten-Sektion

    private var wohneinheitenSektion: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wohneinheiten")
                .font(.title2.bold())
                .padding(.top, 8)

            ForEach(sortierteWohneinheiten) { einheit in
                NavigationLink(value: einheit) {
                    WohneinheitZeile(wohneinheit: einheit)
                }
                .buttonStyle(.plain)
            }

            if sortierteWohneinheiten.isEmpty {
                Text("Noch keine Wohneinheiten angelegt.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            }
        }
    }

    private var sortierteWohneinheiten: [Wohneinheit] {
        (immobilie.wohneinheiten ?? []).sorted { lhs, rhs in
            let rL = Self.sortierrang(lhs.bezeichnung)
            let rR = Self.sortierrang(rhs.bezeichnung)
            if rL != rR { return rL < rR }
            return lhs.bezeichnung.localizedStandardCompare(rhs.bezeichnung) == .orderedAscending
        }
    }

    /// Geschoss-Ordnung KG → EG → OG → DG (klein genug für MVP).
    private static func sortierrang(_ bezeichnung: String) -> Int {
        let key = bezeichnung
            .uppercased()
            .trimmingCharacters(in: .whitespaces)
        switch key {
        case "KG", "UG", "KELLER", "KELLERGESCHOSS", "UNTERGESCHOSS":
            return 0
        case "EG", "ERDGESCHOSS":
            return 1
        case "OG", "1. OG", "1.OG", "OBERGESCHOSS", "1. OBERGESCHOSS":
            return 2
        case "2. OG", "2.OG", "2. OBERGESCHOSS":
            return 3
        case "DG", "DACHGESCHOSS":
            return 4
        default:
            return 99
        }
    }
}
