//
//  GenerateAppIcon.swift
//  tools
//
//  Standalone-Script, das die App-Icons fuer den Asset-Catalog
//  erzeugt. Ausgangspunkt ist der accent-blaue Hintergrund
//  (#3A5578) + ein weisses Haus mit gestricheltem Dach, kleinem
//  Schornstein auf der rechten Dachseite, gefuelltem Body und
//  einem Tuer-Cutout in Accent-Farbe.
//
//  Aufruf:
//      swift tools/GenerateAppIcon.swift \
//        NebenkostenApp/NebenkostenApp/Assets.xcassets/AppIcon.appiconset/AppIcon-Light.png \
//        NebenkostenApp/NebenkostenApp/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png \
//        NebenkostenApp/NebenkostenApp/Assets.xcassets/AppIcon.appiconset/AppIcon-Tinted.png
//
//  Die drei Pfade erhalten identische Bilder — iOS handhabt
//  Light/Dark/Tinted eigenstaendig. Wenn wir spaeter wirklich
//  unterschiedliche Varianten brauchen, hier verzweigen.
//

import AppKit
import Foundation

let size: CGFloat = 1024

// Farben: Accent aus DesignTokens.swift (#3A5578), "Papier"
// leicht gebrochen weiss (#F5EFE3) — derselbe Papier-Ton wie
// der Background-Token, damit das Haus nicht steril wirkt.
let accent = NSColor(
    red: 0x3A / 255.0,
    green: 0x55 / 255.0,
    blue: 0x78 / 255.0,
    alpha: 1
)
let paper = NSColor(
    red: 0xF5 / 255.0,
    green: 0xEF / 255.0,
    blue: 0xE3 / 255.0,
    alpha: 1
)

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

    // Canvas komplett mit Accent fuellen — iOS maskiert den
    // Radius beim Anzeigen selbst.
    accent.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()

    // Haus-Proportionen. AppKit-Koordinaten: 0 = unten.
    let cx: CGFloat = size / 2            // 512
    let cy: CGFloat = size * 0.48         // leicht unter Mitte

    // Body
    let bodyWidth: CGFloat = 460
    let bodyHeight: CGFloat = 330
    let bodyRect = NSRect(
        x: cx - bodyWidth / 2,
        y: cy - bodyHeight / 2 - 40,
        width: bodyWidth,
        height: bodyHeight
    )
    paper.setFill()
    NSBezierPath(roundedRect: bodyRect, xRadius: 28, yRadius: 28).fill()

    // Dach: Zwei Strokes ueber die Body-Top-Kante gesetzt, sodass
    // das Dach klar "auf" dem Body sitzt (nicht in ihn hinein).
    // LineCap/Join rund, damit die Ecken weich sind.
    let roofStroke: CGFloat = 44
    let roofLeftX: CGFloat = bodyRect.minX - 28
    let roofRightX: CGFloat = bodyRect.maxX + 28
    let roofBaseY: CGFloat = bodyRect.maxY
    let roofPeakY: CGFloat = cy + 258

    let roof = NSBezierPath()
    roof.move(to: NSPoint(x: roofLeftX, y: roofBaseY))
    roof.line(to: NSPoint(x: cx, y: roofPeakY))
    roof.line(to: NSPoint(x: roofRightX, y: roofBaseY))
    roof.lineCapStyle = .round
    roof.lineJoinStyle = .round
    roof.lineWidth = roofStroke
    paper.setStroke()
    roof.stroke()

    // Schornstein: schlanker Rechteck-Stab auf der rechten
    // Dachschraegen-Haelfte, naeher Richtung Firstspitze. Der
    // Fuss tangiert die Dachlinie, der Kopf steht sichtbar drueber.
    let chimneyWidth: CGFloat = 40
    let chimneyX = cx + 130
    let chimneyBaseY: CGFloat = cy + 165
    let chimneyTopY: CGFloat = cy + 260
    let chimneyRect = NSRect(
        x: chimneyX,
        y: chimneyBaseY,
        width: chimneyWidth,
        height: chimneyTopY - chimneyBaseY
    )
    paper.setFill()
    NSBezierPath(roundedRect: chimneyRect, xRadius: 6, yRadius: 6).fill()

    // Tuer: Accent-Farbe, flush mit Body-Boden, mittig.
    let doorWidth: CGFloat = 100
    let doorHeight: CGFloat = 175
    let doorRect = NSRect(
        x: cx - doorWidth / 2,
        y: bodyRect.minY + 4,
        width: doorWidth,
        height: doorHeight
    )
    accent.setFill()
    NSBezierPath(roundedRect: doorRect, xRadius: 12, yRadius: 12).fill()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG-Encoding fehlgeschlagen")
    }
    return data
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
