//
//  DesignTokensTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Spot-Checks auf die Hex-Parsing-Logik und fünf repräsentative
//  Farb-Werte. Die Tokens kommen aus dem Design-Handoff; dieser Test
//  verifiziert, dass die Swift-Seite exakt dieselben RGB-Tripel
//  produziert.
//

import Foundation
import SwiftUI
import Testing
@testable import NebenkostenApp

@MainActor
struct DesignTokensTests {

    @Test("Hex-Parser: '#F5F1E8' ergibt 245/241/232")
    func hex_bgApp() async throws {
        let rgb = rgbKomponenten(Color(hex: "#F5F1E8"))
        #expect(rgb.r == 245)
        #expect(rgb.g == 241)
        #expect(rgb.b == 232)
    }

    @Test("Hex-Parser: '#3A5578' (Accent Blue) ergibt 58/85/120")
    func hex_accent() async throws {
        let rgb = rgbKomponenten(Color(hex: "#3A5578"))
        #expect(rgb.r == 58)
        #expect(rgb.g == 85)
        #expect(rgb.b == 120)
    }

    @Test("Hex-Parser: '#B08968' (unitKG) ergibt 176/137/104")
    func hex_unitKG() async throws {
        let rgb = rgbKomponenten(Color(hex: "#B08968"))
        #expect(rgb.r == 176)
        #expect(rgb.g == 137)
        #expect(rgb.b == 104)
    }

    @Test("Hex-Parser: Alpha wird angewendet")
    func hex_mit_alpha() async throws {
        let (_, _, _, alpha) = rgbaKomponenten(Color(hex: "#000000", alpha: 0.25))
        #expect(abs(alpha - 0.25) < 0.001)
    }

    @Test("Ungültiger Hex → Schwarz mit gewünschtem Alpha (silent fallback)")
    func hex_ungueltig() async throws {
        let (r, g, b, a) = rgbaKomponenten(Color(hex: "nonsense", alpha: 0.5))
        #expect(r == 0 && g == 0 && b == 0)
        #expect(abs(a - 0.5) < 0.001)
    }

    // MARK: - Helper

    /// Extrahiert RGB-Komponenten (0…255) aus einem SwiftUI-Color.
    private func rgbKomponenten(_ color: Color) -> (r: Int, g: Int, b: Int) {
        let rgba = rgbaKomponenten(color)
        return (Int(round(rgba.r * 255)),
                Int(round(rgba.g * 255)),
                Int(round(rgba.b * 255)))
    }

    private func rgbaKomponenten(_ color: Color) -> (r: Double, g: Double, b: Double, a: Double) {
        #if canImport(UIKit)
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
        #else
        return (0, 0, 0, 1)
        #endif
    }
}
