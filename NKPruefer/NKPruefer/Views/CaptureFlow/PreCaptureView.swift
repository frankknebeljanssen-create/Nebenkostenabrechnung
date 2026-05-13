import SwiftUI
import PhotosUI
import UIKit

/// v4-PreCapture-Screen — die Erklärseite vor dem Kamera-Start.
///
/// v4-16: Bietet jetzt BEIDE Wege schon hier an — „Kamera öffnen" und
/// „Aus Fotos wählen". Wer schon fertige Fotos auf dem iPhone hat, soll
/// nicht erst durch den Kamera-Screen klicken müssen, nur um dort die
/// Galerie zu öffnen.
struct PreCaptureView: View {
    @State private var auftrag = PruefungsAuftrag()

    /// Vom PhotosPicker auf diesem Screen ausgewählte Items.
    @State private var selectedPhotos: [PhotosPickerItem] = []

    /// Bilder, die nach dem Laden an `CaptureView` durchgereicht werden.
    @State private var vorausgewaehlteBilder: [UIImage] = []

    /// Programmatischer Navigation-Trigger: wird nach erfolgreichem Laden
    /// der Fotos gesetzt, damit der Push mit gefüllten Bildern passiert.
    @State private var navigiereMitBildern: Bool = false

    /// Lädt-State während der PhotosPicker-Items in UIImages umgewandelt werden.
    @State private var ladeFotos: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("So funktioniert's")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppSpacing.sm)

                VStack(spacing: AppSpacing.sm) {
                    NummerKarte(
                        nummer: 1,
                        icon: "camera",
                        text: "Fotografiere mindestens die Zusammenfassung und alle Seiten mit Kostenaufstellungen — meistens 2–4 Seiten"
                    )
                    NummerKarte(
                        nummer: 2,
                        icon: "doc.text.magnifyingglass",
                        text: "Wir prüfen automatisch"
                    )
                    NummerKarte(
                        nummer: 3,
                        icon: "checkmark.shield",
                        text: "Du bekommst das Ergebnis sofort"
                    )
                }

                NKCard {
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.top, 2)
                        Text("Falls dein Handy fragt, ob die App die Kamera benutzen darf — tippe auf „Erlauben“.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                aktionsButtons
                    .padding(.top, AppSpacing.xs)
            }
            .padding(.horizontal, AppSpacing.contentPadding)
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationTitle("Abrechnung prüfen")
        .navigationBarTitleDisplayMode(.inline)
        // Standard-Push zum Kamera-Screen (frische auftrag, keine Bilder).
        // Wird vom „Kamera öffnen"-NavigationLink genutzt.
        // Programmatischer Push für den „Aus Fotos wählen"-Pfad, der mit
        // bereits geladenen Bildern in CaptureView springt.
        .navigationDestination(isPresented: $navigiereMitBildern) {
            CaptureView(auftrag: auftrag, vorausgewaehlteBilder: vorausgewaehlteBilder)
        }
        .onChange(of: selectedPhotos) { _, neue in
            Task { await ladeFotosUndNavigiere(neue) }
        }
    }

    // MARK: - Aktions-Buttons (beide gleich-prominent gefüllt)

    private var aktionsButtons: some View {
        VStack(spacing: AppSpacing.md) {
            // 1. Kamera öffnen (primär)
            NavigationLink {
                CaptureView(auftrag: auftrag)
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "camera.fill")
                    Text("Kamera öffnen")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
            }
            .accessibilityLabel("Kamera öffnen, um die Abrechnung zu fotografieren")

            // 2. Aus Fotos wählen — EXAKT gleiche Geometrie und Schrift-
            // Stärke wie der „Kamera öffnen"-Button. Unterscheidet sich
            // NUR in der Hintergrundfarbe (success-grün statt accent-blau),
            // damit beide klar als gleichwertige CTAs lesbar sind.
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 10,
                matching: .images
            ) {
                HStack(spacing: AppSpacing.sm) {
                    if ladeFotos {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "photo.on.rectangle")
                    }
                    Text(ladeFotos ? "Fotos werden geladen …" : "Aus Fotos wählen")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.success)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
            }
            .disabled(ladeFotos)
            .accessibilityLabel("Aus Fotos wählen, statt zu fotografieren")
        }
    }

    // MARK: - Photo-Picker-Loading
    //
    // Wandelt die ausgewählten Picker-Items asynchron in UIImages um und
    // triggert dann den Push zur CaptureView mit gefüllten Bildern.

    private func ladeFotosUndNavigiere(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        await MainActor.run { ladeFotos = true }

        var geladen: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                geladen.append(image)
            }
        }

        await MainActor.run {
            ladeFotos = false
            selectedPhotos = []
            guard !geladen.isEmpty else { return }
            vorausgewaehlteBilder = geladen
            navigiereMitBildern = true
        }
    }
}

// MARK: - Nummerierte Karte
//
// Eine Zeile pro Schritt: links Nummer in Kreis, mittig Icon, rechts Text.
// Alles in einer HStack — kein ZStack/Overlay, damit nichts überlappt.

private struct NummerKarte: View {
    let nummer: Int
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text("\(nummer)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(text)
                .font(AppTypography.body)
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.md)
        .background(AppTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Schritt \(nummer): \(text)")
    }
}

#Preview {
    NavigationStack { PreCaptureView() }
}
