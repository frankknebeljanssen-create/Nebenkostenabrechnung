import SwiftUI

/// Wiederverwendbares In-App-Logo der App.
///
/// Visuelles Pendant zum App-Icon: blaues `house.fill` mit grünem
/// Checkmark-Badge unten rechts. Default-Größe 60pt.
///
/// Verwendung:
/// ```swift
/// NKAppLogo()                 // 60pt
/// NKAppLogo(size: 80)         // größer
/// ```
struct NKAppLogo: View {
    var size: CGFloat = 60

    // Hex-Farben aus Design-Tokens, direkt als rgb hier verewigt:
    //   Accent  #185FA5  →  rgb(0.094, 0.373, 0.647)
    //   Erfolg  #0F6E56  →  rgb(0.059, 0.431, 0.337)
    private let accentBlau = Color(red: 0.094, green: 0.373, blue: 0.647)
    private let erfolgGruen = Color(red: 0.059, green: 0.431, blue: 0.337)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Haus-Symbol mittig im Frame
            Image(systemName: "house.fill")
                .font(.system(size: size * 0.55, weight: .medium))
                .foregroundStyle(accentBlau)
                .frame(width: size, height: size)
                .accessibilityHidden(true)

            // Checkmark-Badge unten rechts, mit weißem Ring
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.38, height: size * 0.38)
                Circle()
                    .fill(erfolgGruen)
                    .frame(width: size * 0.32, height: size * 0.32)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .offset(x: size * 0.05, y: size * 0.05)
            .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("NK-Prüfer Logo")
    }
}

#Preview {
    VStack(spacing: 24) {
        NKAppLogo()
        NKAppLogo(size: 80)
        NKAppLogo(size: 40)
    }
    .padding()
}
