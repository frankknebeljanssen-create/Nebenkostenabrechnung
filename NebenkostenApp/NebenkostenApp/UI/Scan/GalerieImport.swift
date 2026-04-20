//
//  GalerieImport.swift
//  NebenkostenApp — UI/Scan
//
//  PhotosPicker-Wrapper, der bis zu N Bilder aus der Foto-Mediathek
//  einliest und als UIImage-Array über einen Callback zurückgibt.
//

import SwiftUI
import PhotosUI
import UIKit

struct GalerieImportButton<Label: View>: View {
    let maxAuswahl: Int
    let onFertig: ([UIImage]) -> Void
    let onFehler: (Error) -> Void
    @ViewBuilder let label: () -> Label

    @State private var auswahl: [PhotosPickerItem] = []
    @State private var laeuftImport = false

    init(
        maxAuswahl: Int = 10,
        onFertig: @escaping ([UIImage]) -> Void,
        onFehler: @escaping (Error) -> Void = { _ in },
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.maxAuswahl = maxAuswahl
        self.onFertig = onFertig
        self.onFehler = onFehler
        self.label = label
    }

    var body: some View {
        PhotosPicker(
            selection: $auswahl,
            maxSelectionCount: maxAuswahl,
            matching: .images
        ) {
            label()
        }
        .disabled(laeuftImport)
        .onChange(of: auswahl) { _, neu in
            guard !neu.isEmpty else { return }
            Task { await verarbeite(neu) }
        }
    }

    private func verarbeite(_ items: [PhotosPickerItem]) async {
        laeuftImport = true
        defer { laeuftImport = false }

        var bilder: [UIImage] = []
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let bild = UIImage(data: data) {
                    bilder.append(bild)
                }
            } catch {
                onFehler(error)
            }
        }

        // Zurücksetzen, damit ein erneutes Öffnen des Pickers den
        // gleichen Auswahl-Zustand frisch beginnt.
        auswahl = []

        if !bilder.isEmpty {
            onFertig(bilder)
        }
    }
}
