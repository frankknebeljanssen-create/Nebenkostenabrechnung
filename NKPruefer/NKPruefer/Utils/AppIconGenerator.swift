import SwiftUI
import UIKit

struct AppIconGenerator {

    /// Generiert das App-Icon programmatisch.
    /// Design: Weißer Hintergrund mit blauem Haus-Symbol und grünem Checkmark-Badge.
    /// Einfach und für ältere Nutzer sofort als „Wohnungs-/Prüf-App" erkennbar.
    static func generate(size: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { _ in
            // Hintergrund: Weiß mit leichtem Blaustich
            let bg = UIColor(red: 0.95, green: 0.97, blue: 1.00, alpha: 1.0)
            bg.setFill()
            UIBezierPath(
                roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
                cornerRadius: size * 0.22
            ).fill()

            // Haus-Symbol — zentriert, ca. 55 % der Icon-Größe
            let symbolPoint = size * 0.55
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: symbolPoint, weight: .medium)
            if let house = UIImage(systemName: "house.fill", withConfiguration: symbolConfig) {
                let tint = UIColor(red: 0.0, green: 0.47, blue: 0.85, alpha: 1.0) // ≈ NKDesign.accentColor
                let tinted = house.withTintColor(tint, renderingMode: .alwaysOriginal)
                let houseRect = CGRect(
                    x: (size - tinted.size.width) / 2,
                    y: (size - tinted.size.height) / 2 - size * 0.02,
                    width: tinted.size.width,
                    height: tinted.size.height
                )
                tinted.draw(in: houseRect)
            }

            // Checkmark-Badge — unten rechts
            let badgeSize = size * 0.30
            let badgeX = size * 0.62
            let badgeY = size * 0.58
            let badgeRect = CGRect(x: badgeX, y: badgeY, width: badgeSize, height: badgeSize)

            // Weißer Outer-Ring
            UIColor.white.setFill()
            UIBezierPath(ovalIn: badgeRect.insetBy(dx: -2, dy: -2)).fill()

            // Grüner Kreis
            let green = UIColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1.0)
            green.setFill()
            UIBezierPath(ovalIn: badgeRect).fill()

            // Weißer Checkmark im Badge
            let checkConfig = UIImage.SymbolConfiguration(pointSize: badgeSize * 0.50, weight: .bold)
            if let check = UIImage(systemName: "checkmark", withConfiguration: checkConfig) {
                let white = check.withTintColor(.white, renderingMode: .alwaysOriginal)
                let checkRect = CGRect(
                    x: badgeX + (badgeSize - white.size.width) / 2,
                    y: badgeY + (badgeSize - white.size.height) / 2,
                    width: white.size.width,
                    height: white.size.height
                )
                white.draw(in: checkRect)
            }
        }
    }

    /// Schreibt alle benötigten Icon-Größen in den temporären Ordner.
    /// Aufruf z. B. aus einem Debug-Button oder einem XCTest.
    /// Anschließend die PNGs in Xcode → Assets.xcassets → AppIcon einsetzen.
    @discardableResult
    static func exportAll() -> [URL] {
        let sizes: [(String, CGFloat)] = [
            ("icon_60x2", 120),    // iPhone @2x
            ("icon_60x3", 180),    // iPhone @3x
            ("icon_76x2", 152),    // iPad @2x
            ("icon_83.5x2", 167),  // iPad Pro @2x
            ("icon_1024", 1024)    // App Store
        ]
        var urls: [URL] = []
        for (name, size) in sizes {
            let image = generate(size: size)
            guard let data = image.pngData() else { continue }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(name).png")
            do {
                try data.write(to: url, options: .atomic)
                urls.append(url)
                print("AppIconGenerator: \(url.path)")
            } catch {
                print("AppIconGenerator: konnte \(name) nicht schreiben — \(error.localizedDescription)")
            }
        }
        return urls
    }
}
