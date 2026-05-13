import SwiftUI

/// Kompakter Bottom-Sheet für einen einzelnen Glossar-Eintrag.
///
/// Verwendung:
/// ```swift
/// @State private var glossarKey: String? = nil
/// // …
/// .glossarSheet(key: $glossarKey)
/// ```
///
/// Der View-Modifier `.glossarSheet(key:)` (unten definiert) übernimmt
/// das Auflösen des Keys in einen `GlossarEintrag` und zeigt das Sheet
/// nur, wenn der Key bekannt ist. Damit muss jede Aufruferstelle nur
/// einen String setzen.
struct NKGlossarSheet: View {
    let eintrag: GlossarEintrag

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(alignment: .top) {
                Text(eintrag.begriff)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AppSpacing.md)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .accessibilityLabel("Schließen")
            }

            ScrollView {
                Text(eintrag.erklaerung)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - View-Modifier für bequeme Aufrufe

extension View {
    /// Bindet einen optionalen Glossar-Key an einen Sheet-Trigger.
    /// Wenn der Key in `NKGlossary.eintraege` existiert, wird das Sheet
    /// gezeigt — sonst wird der Key stillschweigend zurückgesetzt.
    func glossarSheet(key: Binding<String?>) -> some View {
        let eintragBinding = Binding<GlossarEintrag?>(
            get: {
                guard let k = key.wrappedValue else { return nil }
                return NKGlossary.eintraege[k]
            },
            set: { neuerWert in
                key.wrappedValue = neuerWert?.id
            }
        )
        return self.sheet(item: eintragBinding) { eintrag in
            NKGlossarSheet(eintrag: eintrag)
        }
    }
}

#Preview {
    Color.gray.opacity(0.1)
        .sheet(isPresented: .constant(true)) {
            NKGlossarSheet(eintrag: NKGlossary.eintraege["verteilerschluessel"]!)
        }
}
