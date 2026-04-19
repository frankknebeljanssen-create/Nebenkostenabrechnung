//
//  ObjektDashboardView.swift
//  NebenkostenApp — UI/Objekt
//

import SwiftUI
import SwiftData

struct ObjektDashboardView: View {
    @Bindable var immobilie: Immobilie

    private var viewModel: ObjektDashboardViewModel {
        ObjektDashboardViewModel(immobilie: immobilie)
    }

    private let spalten = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                kopf
                periodePicker
                ring
                kachelGrid
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Objekt")
    }

    // MARK: - Sektionen

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(immobilie.adresse.isEmpty ? "Unbenanntes Objekt" : immobilie.adresse)
                .font(.title2.bold())
            if !immobilie.ort.isEmpty {
                Text(immobilie.ort)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
            Menu {
                Button(viewModel.periodeBezeichnung) { /* MVP: nur Anzeige */ }
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

    private var ring: some View {
        HStack {
            Spacer()
            CompletionRing(prozent: viewModel.completionProzent)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var kachelGrid: some View {
        LazyVGrid(columns: spalten, spacing: 12) {
            let m = viewModel.mieter
            StatusKachel(titel: "Mieter",      symbol: "person.2",              status: m.status,  ist: m.ist,  soll: m.soll)

            let z = viewModel.zaehler
            StatusKachel(titel: "Zähler",      symbol: "gauge",                 status: z.status,  ist: z.ist,  soll: z.soll)

            let r = viewModel.rechnungen
            StatusKachel(titel: "Rechnungen",  symbol: "doc.text",              status: r.status,  ist: r.ist,  soll: r.soll)

            let k = viewModel.kostenarten
            StatusKachel(titel: "Kostenarten", symbol: "list.bullet.rectangle", status: k.status,  ist: k.ist,  soll: k.soll)
        }
    }
}
