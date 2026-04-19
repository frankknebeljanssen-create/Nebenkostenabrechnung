//
//  WohneinheitDetailView.swift
//  NebenkostenApp — UI/Wohneinheit
//

import SwiftUI

struct WohneinheitDetailView: View {
    let wohneinheit: Wohneinheit

    private var viewModel: WohneinheitDetailViewModel {
        WohneinheitDetailViewModel(wohneinheit: wohneinheit)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                EinheitHeader(
                    wohneinheit: wohneinheit,
                    gesamtflaeche: viewModel.gesamtflaecheImmobilie
                )
                MieterBlock(wohneinheit: wohneinheit, mietverhaeltnis: viewModel.aktiverMieter)
                ZaehlerBlock(zaehler: viewModel.zaehler)
                VorauszahlungBlock()
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(wohneinheit.bezeichnung.isEmpty ? "Einheit" : wohneinheit.bezeichnung)
        .navigationBarTitleDisplayMode(.inline)
    }
}
