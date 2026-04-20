//
//  PDFVorschauView.swift
//  NebenkostenApp — UI/Dokumente
//
//  SwiftUI-Wrapper um PDFKit's PDFView. Ersetzt den QuickLook-Viewer
//  für die Vorschau gespeicherter Dokumente — passt, weil alle
//  Dokumente in Task 1.1 konsequent als PDF persistiert werden.
//

import SwiftUI
import PDFKit

struct PDFVorschauView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(url: url)
        view.usePageViewController(false)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}
