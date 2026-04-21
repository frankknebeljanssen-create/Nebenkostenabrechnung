//
//  GenerateAppIcon.swift
//  tools
//
//  Standalone-Script, das die App-Icons fuer den Asset-Catalog
//  erzeugt. Entwurf angelehnt an die User-Vorlage vom 21.04.2026:
//  heller Blau-Gradient, grosses weisses Haus mit spitzem Dach,
//  zentriertem Schornstein, zwei hellblauen Sprossenfenstern und
//  einer dunkelblauen Tuer mit weissem Euro-Symbol.
//
//  Aufruf:
//      swift tools/GenerateAppIcon.swift \
//        NebenkostenApp/NebenkostenApp/Assets.xcassets/AppIcon.appiconset/AppIcon-Light.png \
//        NebenkostenApp/NebenkostenApp/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png \
//        NebenkostenApp/NebenkostenApp/Assets.xcassets/AppIcon.appiconset/AppIcon-Tinted.png
//

import AppKit
import Foundation

let size: CGFloat = 1024

// Farben (aus der Vorlage ausgemessen).
let bgTop = NSColor(red: 0x52 / 255.0, green: 0x91 / 255.0, blue: 0xF5 / 255.0, alpha: 1) // #5291F5
let bgBottom = NSColor(red: 0x2A / 255.0, green: 0x64 / 255.0, blue: 0xD8 / 255.0, alpha: 1) // #2A64D8
let weiss = NSColor.white
let fensterFuellung = NSColor(red: 0xBF / 255.0, green: 0xD5 / 255.0, blue: 0xF0 / 255.0, alpha: 1) // #BFD5F0
let tuerFarbe = NSColor(red: 0x2A / 255.0, green: 0x55 / 255.0, blue: 0xB0 / 255.0, alpha: 1) // #2A55B0
let griffDot = NSColor(red: 0x5B / 255.0, green: 0x9A / 255.0, blue: 0xF5 / 255.0, alpha: 1)

func makeIconData() -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("konnte NSBitmapImageRep nicht erzeugen")
    }

    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("konnte GraphicsContext nicht aus Rep erzeugen")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    // Canvas: 0,0 = unten links (AppKit-Standard).

    // 1. Hintergrund-Gradient (Top-Links heller, Bottom-Rechts dunkler)
    let gradient = NSGradient(starting: bgTop, ending: bgBottom)!
    gradient.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        angle: -45   // von links oben nach rechts unten
    )

    // 2. Haus-Body (Rechteck)
    //    Breite ~ 780, Hoehe ~ 450, zentriert X, unterer Rand ca. 60
    let bodyX: CGFloat = 122
    let bodyY: CGFloat = 60
    let bodyWidth: CGFloat = 780
    let bodyHeight: CGFloat = 450
    weiss.setFill()
    NSBezierPath(rect: NSRect(x: bodyX, y: bodyY, width: bodyWidth, height: bodyHeight)).fill()

    // 3. Dach (gefuelltes Dreieck, steile Giebel-Form)
    let roofLeftX: CGFloat = bodyX - 40
    let roofRightX: CGFloat = bodyX + bodyWidth + 40
    let roofBaseY: CGFloat = bodyY + bodyHeight      // sitzt auf dem Body auf
    let roofPeakY: CGFloat = bodyY + bodyHeight + 380
    let roof = NSBezierPath()
    roof.move(to: NSPoint(x: roofLeftX, y: roofBaseY))
    roof.line(to: NSPoint(x: size / 2, y: roofPeakY))
    roof.line(to: NSPoint(x: roofRightX, y: roofBaseY))
    roof.close()
    weiss.setFill()
    roof.fill()

    // 4. Schornstein (weisser Block mit kleiner oberer Krempe)
    //    Steht auf der linken Haelfte des Daches, ragt sichtbar
    //    ueber die Spitze hinaus.
    let schornsteinX: CGFloat = 438
    let schornsteinWidth: CGFloat = 56
    let schornsteinStand: CGFloat = roofBaseY + 180
    let schornsteinTop: CGFloat = roofPeakY + 70
    let schornstein = NSBezierPath(rect: NSRect(
        x: schornsteinX,
        y: schornsteinStand,
        width: schornsteinWidth,
        height: schornsteinTop - schornsteinStand
    ))
    weiss.setFill()
    schornstein.fill()
    // Krempe oben (leicht breiter als der Stab)
    let krempe = NSBezierPath(rect: NSRect(
        x: schornsteinX - 6,
        y: schornsteinTop - 24,
        width: schornsteinWidth + 12,
        height: 24
    ))
    krempe.fill()

    // 5. Fenster (zwei hellblaue Sprossenfenster mit weissem Kreuz)
    zeichneFenster(mittelpunkt: NSPoint(x: 290, y: 340), groesse: 170)
    zeichneFenster(mittelpunkt: NSPoint(x: 734, y: 340), groesse: 170)

    // 6. Tuer — dunkelblaues Rechteck mit runden OBEREN Ecken.
    //    Breite ~ 240, Hoehe ~ 330, zentriert, unten buendig mit Body.
    let tuerWidth: CGFloat = 240
    let tuerHeight: CGFloat = 340
    let tuerX: CGFloat = (size - tuerWidth) / 2
    let tuerY: CGFloat = bodyY            // buendig mit Body-Unterkante
    let tuerRadius: CGFloat = 34
    let tuerPfad = pfadMitRundenOberkanten(
        x: tuerX, y: tuerY,
        width: tuerWidth, height: tuerHeight,
        radius: tuerRadius
    )
    tuerFarbe.setFill()
    tuerPfad.fill()

    // 7. Euro-Symbol weiss in der Mitte der Tuer
    let euro = "€" as NSString
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 176, weight: .bold),
        .foregroundColor: weiss
    ]
    let euroSize = euro.size(withAttributes: attrs)
    let euroX = tuerX + (tuerWidth - euroSize.width) / 2
    let euroY = tuerY + (tuerHeight - euroSize.height) / 2 + 18
    euro.draw(at: NSPoint(x: euroX, y: euroY), withAttributes: attrs)

    // 8. Tuergriff-Dot (kleines helles Blau, rechts oben auf der Tuer)
    let dotRadius: CGFloat = 14
    let dotCenter = NSPoint(
        x: tuerX + tuerWidth - 32,
        y: tuerY + tuerHeight - 100
    )
    griffDot.setFill()
    NSBezierPath(ovalIn: NSRect(
        x: dotCenter.x - dotRadius,
        y: dotCenter.y - dotRadius,
        width: dotRadius * 2,
        height: dotRadius * 2
    )).fill()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG-Encoding fehlgeschlagen")
    }
    return data
}

/// Sprossen-Fenster: hellblaue Fuellung + weisses Kreuz mit
/// Kreuzungs-Lichteffekt.
func zeichneFenster(mittelpunkt m: NSPoint, groesse g: CGFloat) {
    let rect = NSRect(x: m.x - g / 2, y: m.y - g / 2, width: g, height: g)
    let pfad = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
    fensterFuellung.setFill()
    pfad.fill()

    // Weisses Kreuz (ca. 14 pt breit fuer 170er Fenster — etwa 8 %)
    let balken: CGFloat = 14
    weiss.setFill()
    // horizontal
    NSBezierPath(rect: NSRect(
        x: rect.minX, y: m.y - balken / 2,
        width: rect.width, height: balken
    )).fill()
    // vertikal
    NSBezierPath(rect: NSRect(
        x: m.x - balken / 2, y: rect.minY,
        width: balken, height: rect.height
    )).fill()
}

/// Pfad fuer Rechteck mit runden OBEREN Ecken (unten spitz).
/// AppKit-Koordinaten: y waechst nach oben.
func pfadMitRundenOberkanten(
    x: CGFloat, y: CGFloat,
    width w: CGFloat, height h: CGFloat,
    radius r: CGFloat
) -> NSBezierPath {
    let p = NSBezierPath()
    // Start unten-links, gegen den Uhrzeigersinn
    p.move(to: NSPoint(x: x, y: y))
    p.line(to: NSPoint(x: x + w, y: y))                     // Unterkante
    p.line(to: NSPoint(x: x + w, y: y + h - r))             // rechts hoch bis Rundung
    // obere rechte Ecke (90°-Bogen)
    p.appendArc(
        withCenter: NSPoint(x: x + w - r, y: y + h - r),
        radius: r,
        startAngle: 0,
        endAngle: 90,
        clockwise: false
    )
    p.line(to: NSPoint(x: x + r, y: y + h))                 // Oberkante
    // obere linke Ecke
    p.appendArc(
        withCenter: NSPoint(x: x + r, y: y + h - r),
        radius: r,
        startAngle: 90,
        endAngle: 180,
        clockwise: false
    )
    p.line(to: NSPoint(x: x, y: y))                         // links runter
    p.close()
    return p
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("Usage: \(args[0]) <out1.png> [out2.png ...]\n".utf8))
    exit(1)
}

let pngData = makeIconData()
for path in args.dropFirst() {
    let url = URL(fileURLWithPath: path)
    do {
        try pngData.write(to: url)
        print("Wrote \(url.path) (\(pngData.count) bytes)")
    } catch {
        FileHandle.standardError.write(Data("Failed \(path): \(error)\n".utf8))
        exit(2)
    }
}
