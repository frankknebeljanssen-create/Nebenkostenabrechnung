//
//  BelegVorschau.swift
//  NebenkostenApp — UI/Rechnung
//
//  Zeigt den gespeicherten Originalbeleg einer Rechnung:
//    - BelegVorschauCard: 220 pt hohe Thumbnail-Card oben im
//      RechnungEditView, tappbar fuer Vollbild.
//    - BelegVorschauSheet: QuickLook-ersatzweise Vollbild mit
//      PDFKit fuer PDFs, Image-Zoom fuer Fotos.
//
//  Quelle ist `Rechnung.anhang: Data?` + `Rechnung.anhangTyp`
//  ("pdf", "jpg", "heic"). Wenn `anhang` nil ist, rendert die
//  Card einen Platzhalter „Kein Originalbeleg gespeichert".
//

import SwiftUI
import PDFKit
import UIKit

// MARK: - Card

struct BelegVorschauCard: View {
    let anhang: Data?
    let anhangTyp: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DesignTokens.bgSurface)
                inhalt
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DesignTokens.separatorStrong, lineWidth: 0.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
        }
        .buttonStyle(.plain)
        .disabled(anhang == nil)
        .accessibilityLabel(anhang == nil ? "Kein Originalbeleg" : "Originalbeleg anzeigen")
    }

    @ViewBuilder
    private var inhalt: some View {
        if let data = anhang, let image = BelegRenderer.thumbnail(
            aus: data, typ: anhangTyp, maxBreite: 1200
        ) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DesignTokens.text)
                        .padding(6)
                        .background(DesignTokens.bgSurface.opacity(0.92))
                        .clipShape(Circle())
                        .padding(10)
                }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(DesignTokens.textTertiary)
                Text("Kein Originalbeleg gespeichert")
                    .appFont(AppFont.bodyMedium())
                    .foregroundStyle(DesignTokens.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Vollbild-Sheet

struct BelegVorschauSheet: View {
    let anhang: Data
    let anhangTyp: String
    let titel: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if anhangTyp.lowercased() == "pdf" {
                    PDFDatenVorschauView(data: anhang)
                } else {
                    BildZoomView(data: anhang)
                }
            }
            .background(DesignTokens.bgApp)
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Fertig")
                            .appFont(AppFont.bodySemi())
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - PDFKit-Wrapper mit Data-Input

private struct PDFDatenVorschauView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(data: data)
        view.usePageViewController(false)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document == nil {
            view.document = PDFDocument(data: data)
        }
    }
}

// MARK: - Zoom-Image-Wrapper

private struct BildZoomView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.minimumZoomScale = 1.0
        scroll.maximumZoomScale = 5.0
        scroll.bouncesZoom = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.delegate = context.coordinator
        scroll.backgroundColor = UIColor(DesignTokens.bgApp)

        let imageView = UIImageView(image: UIImage(data: data))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(imageView)
        context.coordinator.imageView = imageView

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])

        return scroll
    }

    func updateUIView(_ view: UIScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    }
}

// MARK: - Thumbnail-Renderer

enum BelegRenderer {

    /// Erzeugt ein UIImage aus dem Anhang-Data. PDF → erste Seite
    /// gerendert, Bilder → direkt dekodiert. Liefert nil, wenn die
    /// Daten nicht lesbar sind.
    static func thumbnail(aus data: Data, typ: String, maxBreite: CGFloat) -> UIImage? {
        switch typ.lowercased() {
        case "pdf":
            return pdfErsteSeite(aus: data, maxBreite: maxBreite)
        default:
            return UIImage(data: data)
        }
    }

    private static func pdfErsteSeite(aus data: Data, maxBreite: CGFloat) -> UIImage? {
        guard let pdf = PDFDocument(data: data),
              let seite = pdf.page(at: 0) else {
            return nil
        }
        let seitenGroesse = seite.bounds(for: .mediaBox).size
        guard seitenGroesse.width > 0 else { return nil }
        let skalierung = maxBreite / seitenGroesse.width
        let zielGroesse = CGSize(
            width: seitenGroesse.width * skalierung,
            height: seitenGroesse.height * skalierung
        )
        let renderer = UIGraphicsImageRenderer(size: zielGroesse)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: zielGroesse))
            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: 0, y: zielGroesse.height)
            ctx.cgContext.scaleBy(x: skalierung, y: -skalierung)
            seite.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }
    }
}
