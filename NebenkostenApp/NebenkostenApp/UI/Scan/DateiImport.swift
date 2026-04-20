//
//  DateiImport.swift
//  NebenkostenApp — UI/Scan
//
//  Wrapper um SwiftUI's `.fileImporter` für PDFs und Bilder. Liefert
//  den Dateiinhalt als `Data` + Endung zurück; die Service-Schicht
//  entscheidet dann, ob gespeichert oder konvertiert wird.
//

import SwiftUI
import UniformTypeIdentifiers

struct DateiImportErgebnis {
    let data: Data
    let endung: String   // "pdf", "jpg", "png", "heic", ...
    let urspruenglicherName: String
}

private struct DateiImportModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onFertig: (DateiImportErgebnis) -> Void
    let onFehler: (Error) -> Void

    func body(content: Content) -> some View {
        content.fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { ergebnis in
            verarbeite(ergebnis)
        }
    }

    private func verarbeite(_ ergebnis: Result<[URL], Error>) {
        switch ergebnis {
        case .success(let urls):
            guard let url = urls.first else { return }
            let gotAccess = url.startAccessingSecurityScopedResource()
            defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let endung = url.pathExtension.lowercased()
                let name = url.lastPathComponent
                onFertig(DateiImportErgebnis(
                    data: data, endung: endung, urspruenglicherName: name
                ))
            } catch {
                onFehler(error)
            }
        case .failure(let fehler):
            onFehler(fehler)
        }
    }
}

extension View {
    /// SwiftUI-nativer File-Importer für PDFs und Bilder. Der
    /// Handler bekommt den Inhalt als `Data` plus die Endung. Multi-
    /// Select ist bewusst aus — ein Dokument pro Aufruf.
    func dateiImport(
        isPresented: Binding<Bool>,
        onFertig: @escaping (DateiImportErgebnis) -> Void,
        onFehler: @escaping (Error) -> Void = { _ in }
    ) -> some View {
        modifier(DateiImportModifier(
            isPresented: isPresented,
            onFertig: onFertig,
            onFehler: onFehler
        ))
    }
}
