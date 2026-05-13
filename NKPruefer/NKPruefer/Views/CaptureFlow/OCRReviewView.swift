import SwiftUI

struct OCRReviewView: View {
    let auftrag: PruefungsAuftrag

    @Environment(\.dismiss) private var dismiss

    private var konfidenzProzent: Int {
        Int((auftrag.ocrConfidence * 100).rounded())
    }

    private var konfidenzStufe: KonfidenzStufe {
        switch auftrag.ocrConfidence {
        case 0.85...:    return .gut
        case 0.70..<0.85: return .mittel
        case 0.50..<0.70: return .schlecht
        default:         return .zuSchlecht
        }
    }

    private var weiterAktiv: Bool {
        konfidenzStufe != .zuSchlecht
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Das haben wir gelesen")
                .font(.system(size: 15, weight: .semibold))

            erkannterTextBox

            konfidenzAnzeige

            Spacer(minLength: 12)

            VStack(spacing: 12) {
                NavigationLink {
                    EckdatenQuickView(pruefungsAuftrag: auftrag)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Weiter zur Prüfung")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: NKDesign.bigButtonHeight)
                    .background(weiterAktiv ? NKDesign.successColor : Color.gray.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
                }
                .disabled(!weiterAktiv)
                .opacity(weiterAktiv ? 1.0 : 0.6)
                .accessibilityLabel("Weiter zur Prüfung")

                NKBigButton(
                    title: "Nochmal fotografieren",
                    icon: "camera",
                    style: .secondary
                ) {
                    dismiss()
                }
            }
        }
        .padding(.horizontal, 16)
        .navigationTitle("Erkannter Text")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sub-Views

    private var erkannterTextBox: some View {
        ScrollView {
            Text(auftrag.ocrText.isEmpty ? "(Kein Text erkannt)" : auftrag.ocrText)
                .font(.system(size: 15, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .textSelection(.enabled)
        }
        .frame(maxHeight: 300)
        .background(Color.gray.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
    }

    private var konfidenzAnzeige: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: konfidenzStufe.icon)
                .font(.system(size: 22))
                .foregroundStyle(konfidenzStufe.farbe)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(konfidenzStufe.titel(prozent: konfidenzProzent))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                if let hinweis = konfidenzStufe.hinweis {
                    Text(hinweis)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(konfidenzStufe.farbe.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Konfidenz-Stufen

private enum KonfidenzStufe {
    case gut         // >= 85 %
    case mittel      // 70 – 84 %
    case schlecht    // 50 – 69 %
    case zuSchlecht  // < 50 %

    var farbe: Color {
        switch self {
        case .gut:        return NKDesign.successColor
        case .mittel:     return NKDesign.warningColor
        case .schlecht,
             .zuSchlecht: return NKDesign.errorColor
        }
    }

    var icon: String {
        switch self {
        case .gut:        return "checkmark.circle.fill"
        case .mittel:     return "exclamationmark.circle.fill"
        case .schlecht,
             .zuSchlecht: return "xmark.octagon.fill"
        }
    }

    func titel(prozent: Int) -> String {
        switch self {
        case .gut:        return "Gute Qualität (\(prozent) %)"
        case .mittel:     return "Mittlere Qualität (\(prozent) %)"
        case .schlecht:   return "Schlechte Qualität (\(prozent) %)"
        case .zuSchlecht: return "Sehr schlechte Qualität (\(prozent) %)"
        }
    }

    var hinweis: String? {
        switch self {
        case .gut:
            return nil
        case .mittel:
            return "Einige Stellen könnten ungenau sein. Wenn etwas wichtig aussieht, lieber nochmal fotografieren."
        case .schlecht:
            return "Bitte nochmal fotografieren — möglichst ohne Schatten und mit guter Beleuchtung."
        case .zuSchlecht:
            return "Bitte nochmal fotografieren. Wir können den Text so nicht zuverlässig prüfen."
        }
    }
}

#Preview {
    let auftrag = PruefungsAuftrag()
    auftrag.ocrText = "Nebenkostenabrechnung für das Kalenderjahr 2025\nMieter: Max Mustermann\nWohnfläche: 68,00 m²"
    auftrag.ocrConfidence = 0.92
    return NavigationStack { OCRReviewView(auftrag: auftrag) }
}
