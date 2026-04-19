//
//  PDFGenerator.swift
//  NebenkostenApp — Services
//
//  HTML-Template + Mustache-Context → PDF (A4). Rendert via WKWebView
//  mit Navigation-Delegate-Continuation, erzeugt PDF-Data über
//  `webView.pdf(configuration:)`.
//

import Foundation
import UIKit
import WebKit

enum PDFGeneratorFehler: Error, LocalizedError {
    case templateNichtGefunden(ressource: String)
    case rendererFehler(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .templateNichtGefunden(let r):
            return "Template \(r).html nicht im App-Bundle gefunden."
        case .rendererFehler(let u):
            return "PDF-Renderer-Fehler: \(u.localizedDescription)"
        }
    }
}

@MainActor
enum PDFGenerator {

    /// Lädt `abrechnung.html` aus dem Bundle, rendert mit Mustache und
    /// den übergebenen Kontext-Werten, erzeugt daraus ein A4-PDF.
    static func generiereAbrechnungsPDF(context: [String: Any]) async throws -> Data {
        try await generierePDF(templateRessource: "abrechnung", context: context)
    }

    /// Allgemeine Variante: beliebiges HTML-Template aus dem Bundle.
    static func generierePDF(
        templateRessource name: String,
        context: [String: Any]
    ) async throws -> Data {
        guard let url = Bundle.main.url(forResource: name, withExtension: "html") else {
            throw PDFGeneratorFehler.templateNichtGefunden(ressource: name)
        }
        let template = try String(contentsOf: url, encoding: .utf8)
        let html = Mustache.render(template, with: context)
        return try await rendereAlsPDF(html: html)
    }

    /// Rendert einen HTML-String als A4-PDF. WKWebView muss fertig geladen
    /// sein, bevor der PDF-Export läuft — wir warten via Navigation-Delegate-
    /// Continuation.
    private static func rendereAlsPDF(html: String) async throws -> Data {
        let a4Punkte = CGRect(x: 0, y: 0, width: 595, height: 842)
        let konfig = WKWebViewConfiguration()
        let webView = WKWebView(frame: a4Punkte, configuration: konfig)
        let delegierter = LadeDelegierter()
        webView.navigationDelegate = delegierter

        webView.loadHTMLString(html, baseURL: nil)
        do {
            try await delegierter.warten()
        } catch {
            throw PDFGeneratorFehler.rendererFehler(underlying: error)
        }

        // Kurze Pause für CSS-Render-Pipeline (WKWebView feuert didFinish
        // bevor Layout abgeschlossen ist).
        try? await Task.sleep(for: .milliseconds(150))

        return try await webView.pdf(configuration: WKPDFConfiguration())
    }
}

// MARK: - Ladedelegierter

@MainActor
private final class LadeDelegierter: NSObject, WKNavigationDelegate {
    private var fortsetzung: CheckedContinuation<Void, Error>?

    func warten() async throws {
        try await withCheckedThrowingContinuation { cont in
            self.fortsetzung = cont
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.fortsetzung?.resume()
            self.fortsetzung = nil
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        Task { @MainActor in
            self.fortsetzung?.resume(throwing: error)
            self.fortsetzung = nil
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        Task { @MainActor in
            self.fortsetzung?.resume(throwing: error)
            self.fortsetzung = nil
        }
    }
}
