import SwiftUI
import UIKit
import PhotosUI

/// v4-Capture-Screen — Multi-Page-Scanning (v4-16).
///
/// Statt einer Custom-Kamera nutzen wir Apples `VNDocumentCameraViewController`
/// (via `DocumentScannerView`) — der bietet Rand-Erkennung, Perspektiv-
/// Korrektur, Auto-Auslöser und Multi-Page bereits eingebaut.
///
/// Aufbau:
///   • Header (Custom-Chevron-Zurück + „Abrechnung fotografieren")
///   • Thumbnail-Grid der bereits gescannten Seiten (leerer State mit Hinweis)
///   • Info-Box („Seiten mit Beträgen … meistens 2–4 Seiten")
///   • Zwei gleich-prominente CTAs: „Seiten scannen" + „Aus Fotos wählen"
///   • „Weiter →"-Button, nur sichtbar wenn min. 1 Seite vorhanden
///
/// Bestehende Scans bleiben beim erneuten Scannen erhalten — neue Seiten
/// werden hinten ANGEHÄNGT (nicht ersetzt). Einzelne Seiten lassen sich
/// per X-Button am Thumbnail wieder entfernen.
struct CaptureView: View {
    let auftrag: PruefungsAuftrag

    @Environment(\.dismiss) private var dismiss

    @State private var scannedImages: [UIImage]
    @State private var ocrLaeuft = false
    @State private var fehler: String? = nil

    @State private var zeigeScanner = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var navigiereZuReview = false

    /// v4-19 Fix 6a: Vollbild-Index für Tap-to-Fullscreen am Thumbnail.
    @State private var vollbildIndex: FullscreenIndex? = nil

    /// v4-16: Optional vorab vom PreCapture-Screen ausgewählte Bilder
    /// (z. B. aus dem PhotosPicker dort). Wenn nicht-leer, sieht der User
    /// die Thumbnails direkt beim Eintritt und kann sofort auf „Weiter".
    init(auftrag: PruefungsAuftrag, vorausgewaehlteBilder: [UIImage] = []) {
        self.auftrag = auftrag
        self._scannedImages = State(initialValue: vorausgewaehlteBilder)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                seitenBlock

                // Zustand A (keine Fotos):  Info + großer Foto-Button
                // Zustand B (Fotos da):     keine Info, drei Folge-Buttons
                if scannedImages.isEmpty {
                    infoHinweis
                    fotografierenButton
                } else {
                    weitereButtonsBlock
                }

                if ocrLaeuft {
                    ladeIndikator
                }
                if let fehler {
                    fehlerHinweis(text: fehler)
                }
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationTitle("Abrechnung fotografieren")
        .navigationBarTitleDisplayMode(.inline)
        // Custom Chevron-Back ohne „Back"/„Zurück"-Beschriftung,
        // damit Device-Sprache keinen englischen Fallback erzeugt.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Zurück")
            }
        }
        .fullScreenCover(isPresented: $zeigeScanner) {
            DocumentScannerView { newImages in
                // Append, nicht replace — mehrere Scan-Sessions sind erlaubt.
                scannedImages.append(contentsOf: newImages)
            }
            .ignoresSafeArea()
        }
        // v4-19 Fix 2: OCR-Review entfällt aus dem Pflicht-Flow.
        // Statt automatisch dorthin zu navigieren, springen wir direkt
        // zur EckdatenQuickView. Der User kann den erkannten Text dort
        // optional per Sheet einsehen und korrigieren.
        .navigationDestination(isPresented: $navigiereZuReview) {
            EckdatenQuickView(pruefungsAuftrag: auftrag)
        }
        .onChange(of: selectedPhotos) { _, neue in
            Task { await ladePhotoPickerAuswahl(neue) }
        }
        // v4-19 Fix 6a: Tap-to-Fullscreen für Thumbnails
        .fullScreenCover(item: $vollbildIndex) { wrapper in
            vollbildAnsicht(index: wrapper.id)
        }
    }

    // MARK: - Vollbild-Ansicht (v4-19 Fix 6a)

    private func vollbildAnsicht(index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if index < scannedImages.count {
                Image(uiImage: scannedImages[index])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Button {
                vollbildIndex = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white, .black.opacity(0.55))
                    .padding(AppSpacing.lg)
            }
            .accessibilityLabel("Vollbild schließen")
        }
    }

    // MARK: - Seiten-Block (Thumbnail-Grid oder leerer State)

    @ViewBuilder
    private var seitenBlock: some View {
        if scannedImages.isEmpty {
            NKCard {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("Noch keine Seiten gescannt")
                        .font(AppTypography.body)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
            }
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("\(scannedImages.count) \(scannedImages.count == 1 ? "Seite" : "Seiten") gescannt")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 90), spacing: AppSpacing.sm)],
                    spacing: AppSpacing.sm
                ) {
                    ForEach(Array(scannedImages.enumerated()), id: \.offset) { idx, bild in
                        thumbnail(image: bild, index: idx)
                    }
                }
            }
        }
    }

    private func thumbnail(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topLeading) {
            // v4-19 Fix 6a: Tap auf das Bild öffnet die Vollbild-Anzeige.
            Button {
                vollbildIndex = FullscreenIndex(id: index)
            } label: {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.sm)
                            .stroke(AppTheme.border, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Seite \(index + 1) im Vollbild anzeigen")

            // Seiten-Nummer (oben links)
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(AppTheme.accent))
                .padding(4)

            // Löschen-Button (oben rechts)
            Button {
                if index < scannedImages.count {
                    scannedImages.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white, .black.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .topTrailing)
            .padding(4)
            .accessibilityLabel("Seite \(index + 1) entfernen")
        }
    }

    // MARK: - Info-Hinweis
    //
    // Bewusst inline statt NKCard, weil NKCard ein festes 16pt-Padding
    // hat — hier wollen wir 20pt für mehr Luft. Außerdem explizites
    // `frame(maxWidth: .infinity, alignment: .leading)`, damit die Card
    // GENAU so breit ist wie die anderen Elemente im VStack (sonst
    // schrumpft sie auf Content-Breite).

    private var infoHinweis: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "info.circle")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.accent)
                .padding(.top, 2)
            Text("Fotografiere die Seiten mit Beträgen und Kostenaufstellung.\n\nMeistens sind das 2–4 Seiten.")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
    }

    // MARK: - Zustand A: Großer Foto-Button
    //
    // Wenn noch keine Seite da ist, zeigen wir EINEN sehr prominenten
    // 100pt-Button — die einzige sinnvolle Action auf diesem Screen.

    private var fotografierenButton: some View {
        Button {
            zeigeScanner = true
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "doc.viewfinder")
                Text("Fotografieren")
            }
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
        }
        .accessibilityLabel("Fotografieren")
    }

    // MARK: - Zustand B: Drei Folge-Buttons
    //
    // Wenn schon mindestens eine Seite da ist:
    //   1. „Weitere Seiten fotografieren" (accent blau)
    //   2. „Weitere Fotos hinzufügen"     (success grün)
    //   Spacer 24pt — visuell abgesetzt
    //   3. „Fertig und weiter →"          (accent blau, volle Breite)
    //
    // Beide oberen Buttons öffnen unterschiedliche Wege, hängen neue
    // Bilder aber an die bestehende `scannedImages`-Liste an (Append,
    // nicht Replace).

    private var weitereButtonsBlock: some View {
        VStack(spacing: AppSpacing.md) {
            // 1. Weitere Seiten fotografieren (Scanner)
            Button {
                zeigeScanner = true
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "doc.viewfinder")
                    Text("Weitere Seiten fotografieren")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
            }
            .accessibilityLabel("Weitere Seiten fotografieren")

            // 2. Weitere Fotos hinzufügen (PhotosPicker)
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 10,
                matching: .images
            ) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "photo.on.rectangle")
                    Text("Weitere Fotos hinzufügen")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.success)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
            }
            .accessibilityLabel("Weitere Fotos aus der Galerie hinzufügen")

            // 3. Fertig und weiter — visuell abgesetzt (sattes Gold,
            // damit der CTA in der dritten Reihe trotz gleicher Größe
            // wie die beiden oberen Buttons klar als „Endpunkt" wirkt).
            Button {
                starteOCR()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Text("Fertig und weiter")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(red: 0.85, green: 0.65, blue: 0.0))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
            }
            .padding(.top, AppSpacing.md)
            .accessibilityLabel("Fertig und mit der Prüfung fortfahren")
            .disabled(ocrLaeuft)
        }
    }

    // MARK: - Lade/Fehler

    private var ladeIndikator: some View {
        NKCard {
            HStack(spacing: AppSpacing.sm) {
                ProgressView().controlSize(.small)
                Text("Text wird erkannt …")
                    .font(AppTypography.body)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fehlerHinweis(text: String) -> some View {
        NKCard {
            Label(text, systemImage: "exclamationmark.triangle.fill")
                .font(AppTypography.body)
                .foregroundStyle(AppTheme.error)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    /// Lädt Fotos aus dem PhotosPicker („Weitere Fotos hinzufügen") und
    /// hängt sie hinten an die bestehende `scannedImages`-Liste an.
    /// Auswahl wird danach zurückgesetzt, damit derselbe Picker-State
    /// beim nächsten Aufruf nicht erneut triggert.
    private func ladePhotoPickerAuswahl(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                scannedImages.append(image)
            }
        }
        await MainActor.run { selectedPhotos = [] }
    }

    private func starteOCR() {
        guard !scannedImages.isEmpty else { return }
        ocrLaeuft = true
        fehler = nil

        Task { @MainActor in
            do {
                let result = try await OCRService.recognizeText(from: scannedImages)
                auftrag.ocrText = result.fullText
                auftrag.ocrConfidence = result.confidence
                auftrag.originalBild = scannedImages.first
                ocrLaeuft = false
                navigiereZuReview = true
            } catch let ocrError as OCRError {
                ocrLaeuft = false
                fehler = ocrError.localizedDescription
                NKHaptic.error()
            } catch {
                ocrLaeuft = false
                fehler = "Texterkennung fehlgeschlagen: \(error.localizedDescription)"
                NKHaptic.error()
            }
        }
    }
}

// MARK: - Wrapper für Int als Identifiable
//
// `fullScreenCover(item:)` braucht Identifiable. Wir wollen den Index
// von 0 starten, ohne `String` oder andere globale Identity-Pollution.

private struct FullscreenIndex: Identifiable {
    let id: Int
}

#Preview {
    NavigationStack { CaptureView(auftrag: PruefungsAuftrag()) }
}
