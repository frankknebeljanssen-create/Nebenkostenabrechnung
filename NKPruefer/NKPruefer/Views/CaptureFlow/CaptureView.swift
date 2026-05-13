import SwiftUI
import UIKit

/// v4-Capture-Screen: Foto aufnehmen oder aus Fotos wählen.
///
/// Layout-Regeln (v4-11):
///   • ScrollView + Bottom-Padding → garantiert, dass „Aus Fotos wählen"
///     komplett über der Tab Bar sichtbar bleibt
///   • Alle Größen aus AppSpacing / AppTheme
///   • Kein blauer Glow — System-default Hintergrund
struct CaptureView: View {
    let auftrag: PruefungsAuftrag

    @State private var aufgenommenesBild: UIImage? = nil
    @State private var ocrLaeuft = false
    @State private var fehler: String? = nil

    @State private var zeigeKamera = false
    @State private var zeigeFotoauswahl = false
    @State private var navigiereZuReview = false

    private var kameraVerfuegbar: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if let bild = aufgenommenesBild {
                    aufnahmeAnsicht(bild: bild)
                } else {
                    aufnahmeAuswahl
                }
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationTitle("Abrechnung fotografieren")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigiereZuReview) {
            OCRReviewView(auftrag: auftrag)
        }
        .fullScreenCover(isPresented: $zeigeKamera) {
            ImagePicker(sourceType: .camera, onImage: handleNewImage) {
                zeigeKamera = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $zeigeFotoauswahl) {
            ImagePicker(sourceType: .photoLibrary, onImage: handleNewImage) {
                zeigeFotoauswahl = false
            }
            .ignoresSafeArea()
        }
        .onAppear {
            if !ocrLaeuft && !navigiereZuReview {
                aufgenommenesBild = nil
                fehler = nil
            }
        }
    }

    // MARK: - Sub-Views

    private var aufnahmeAuswahl: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .fill(AppTheme.cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                            .stroke(AppTheme.border, lineWidth: 0.5)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.accent.opacity(0.7))
                    Text("Noch keine Aufnahme")
                        .font(AppTypography.hint)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            NKCard {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.top, 2)
                    Text("Fotografiere die Seiten mit Beträgen und Kostenaufstellung. Jede Seite einzeln, gerade und bei gutem Licht.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: AppSpacing.sm) {
                if kameraVerfuegbar {
                    NKPrimaryButton("Foto aufnehmen", icon: "camera.fill") {
                        zeigeKamera = true
                    }
                }
                NKSecondaryButton("Aus Fotos wählen", icon: "photo.on.rectangle") {
                    zeigeFotoauswahl = true
                }
            }
        }
    }

    private func aufnahmeAnsicht(bild: UIImage) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Image(uiImage: bild)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 320)
                .background(AppTheme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                        .stroke(AppTheme.border, lineWidth: 0.5)
                )
                .accessibilityLabel("Aufgenommenes Foto der Abrechnung")

            if ocrLaeuft {
                NKCard {
                    HStack(spacing: AppSpacing.sm) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Text wird erkannt …")
                            .font(AppTypography.body)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let fehler {
                fehlerAnsicht(fehler)
            }
        }
    }

    private func fehlerAnsicht(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            NKCard {
                Label(text, systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypography.body)
                    .foregroundStyle(AppTheme.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            NKPrimaryButton("Nochmal versuchen", icon: "arrow.clockwise") {
                if let bild = aufgenommenesBild {
                    starteOCR(bild: bild)
                }
            }

            NKSecondaryButton("Anderes Foto wählen", icon: "photo.on.rectangle") {
                aufgenommenesBild = nil
                fehler = nil
            }
        }
    }

    // MARK: - Actions

    private func handleNewImage(_ image: UIImage) {
        zeigeKamera = false
        zeigeFotoauswahl = false
        aufgenommenesBild = image
        fehler = nil
        starteOCR(bild: image)
    }

    private func starteOCR(bild: UIImage) {
        ocrLaeuft = true
        fehler = nil

        Task { @MainActor in
            do {
                let result = try await OCRService.recognizeText(from: bild)
                auftrag.ocrText = result.fullText
                auftrag.ocrConfidence = result.confidence
                auftrag.originalBild = bild
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

// MARK: - ImagePicker (UIKit-Bridge)

private struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        if sourceType == .camera {
            picker.cameraCaptureMode = .photo
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

#Preview {
    NavigationStack { CaptureView(auftrag: PruefungsAuftrag()) }
}
