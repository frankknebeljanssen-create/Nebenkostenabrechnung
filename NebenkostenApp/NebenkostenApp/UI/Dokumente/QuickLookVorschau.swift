//
//  QuickLookVorschau.swift
//  NebenkostenApp — UI/Dokumente
//
//  SwiftUI-Wrapper um QLPreviewController. Zeigt PDFs oder Bilder
//  im nativen Vollbild-Viewer mit Zoom, Share, Markup.
//

import SwiftUI
import QuickLook

struct QuickLookVorschau: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let vc = QLPreviewController()
        vc.dataSource = context.coordinator
        return vc
    }

    func updateUIViewController(
        _ uiViewController: QLPreviewController,
        context: Context
    ) {
        context.coordinator.url = url
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Koordinator {
        Koordinator(url: url)
    }

    @MainActor
    final class Koordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(url: URL) { self.url = url }

        nonisolated func numberOfPreviewItems(
            in controller: QLPreviewController
        ) -> Int {
            1
        }

        nonisolated func previewController(
            _ controller: QLPreviewController,
            previewItemAt index: Int
        ) -> QLPreviewItem {
            // URL ist nicht Sendable; MainActor.assumeIsolated ist OK,
            // weil QLPreviewController-Callbacks auf dem Main-Thread
            // laufen.
            MainActor.assumeIsolated {
                url as NSURL
            }
        }
    }
}
