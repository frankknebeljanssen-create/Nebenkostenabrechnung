import SwiftUI

/// v4-17: OCR-Review als Tab-pro-Seite.
///
/// Statt einer Textwand über 7 Seiten zeigen wir einen horizontalen
/// Seiten-Picker. Der User klickt sich durch die Seiten und kann
/// jede einzeln korrigieren. Beim „Fertig und weiter" werden die
/// editierten Seiten wieder mit `--- Seite N ---`-Markern
/// zusammengefügt, damit die Pipeline die Seitenstruktur weiter sieht.
struct OCRReviewView: View {
    let auftrag: PruefungsAuftrag

    @Environment(\.dismiss) private var dismiss

    @State private var aktiveSeite: Int = 0
    @State private var seitenInhalte: [String] = []

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                vertrauensSignal
                infoCard
                seitenPicker
                textEditor
                fertigButton
                nochmalFotografierenButton
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationTitle("Text prüfen")
        .navigationBarTitleDisplayMode(.inline)
        // Custom Chevron statt System-„Back"-Beschriftung.
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
        .onAppear {
            // Beim ersten Erscheinen den OCR-Text in Seiten splitten.
            // Bei wiederholtem onAppear (z. B. Rück-Navigation) behalten
            // wir die bereits editierten Inhalte.
            if seitenInhalte.isEmpty {
                seitenInhalte = Self.splitInSeiten(auftrag.ocrText)
                if seitenInhalte.isEmpty {
                    // Falls splitInSeiten leer liefert, eine leere Seite anlegen,
                    // damit der TextEditor ein gültiges Binding bekommt.
                    seitenInhalte = [""]
                }
            }
        }
    }

    // MARK: - 1. Vertrauens-Signal

    private var vertrauensSignal: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.success)
            Text("\(seitenInhalte.count) \(seitenInhalte.count == 1 ? "Seite" : "Seiten") erkannt")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, AppSpacing.md)
        .padding(.horizontal, AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
    }

    // MARK: - 2. Info-Card

    private var infoCard: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "info.circle")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.accent)
                .padding(.top, 2)
            Text("Prüfe, ob der Text korrekt erkannt wurde. Du kannst Fehler direkt korrigieren.")
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

    // MARK: - 3. Seiten-Picker (horizontal scrollbar)

    @ViewBuilder
    private var seitenPicker: some View {
        if seitenInhalte.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(0..<seitenInhalte.count, id: \.self) { index in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                aktiveSeite = index
                            }
                        } label: {
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(aktiveSeite == index ? .white : AppTheme.textSecondary)
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(aktiveSeite == index
                                              ? AppTheme.accent
                                              : Color(.tertiarySystemFill))
                                )
                        }
                        .accessibilityLabel("Seite \(index + 1)")
                        .accessibilityAddTraits(aktiveSeite == index ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 4. Text-Editor (aktive Seite)

    private var textEditor: some View {
        TextEditor(text: aktuellerTextBinding)
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.textPrimary)
            .scrollContentBackground(.hidden)
            .padding(AppSpacing.md)
            .frame(minHeight: 320)
            .background(AppTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .stroke(AppTheme.border, lineWidth: 0.5)
            )
            .accessibilityLabel("Erkannter Text der Seite \(aktiveSeite + 1)")
    }

    /// Binding zum aktiven Seiten-Index. Out-of-bounds defensiv: Default-
    /// Wert + no-op-Setter, damit kein Crash entsteht falls `seitenInhalte`
    /// in einem Lifecycle-Race kurz leer ist.
    private var aktuellerTextBinding: Binding<String> {
        Binding(
            get: {
                guard aktiveSeite < seitenInhalte.count else { return "" }
                return seitenInhalte[aktiveSeite]
            },
            set: { neuerText in
                guard aktiveSeite < seitenInhalte.count else { return }
                seitenInhalte[aktiveSeite] = neuerText
            }
        )
    }

    // MARK: - 5. CTAs

    private var fertigButton: some View {
        Button {
            speichereUndWeiter()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "checkmark")
                Text("Fertig")
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(red: 0.85, green: 0.65, blue: 0.0))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
        }
        .accessibilityLabel("Korrekturen speichern und Sheet schließen")
    }

    private var nochmalFotografierenButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "camera")
                Text("Nochmal fotografieren")
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(AppTheme.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                    .stroke(AppTheme.border, lineWidth: 0.5)
            )
        }
        .accessibilityLabel("Zurück zur Foto-Aufnahme")
    }

    // MARK: - Actions

    /// v4-19 Fix 2: OCRReviewView ist jetzt ein optionaler Editor —
    /// wird als Sheet von EckdatenQuickView aufgerufen. Beim „Fertig"
    /// schreiben wir die editierten Seiten zurück in `auftrag.ocrText`
    /// und dismissen das Sheet. `auftrag` ist eine Klasse, die Edits
    /// sind also für den Aufrufer sofort sichtbar.
    private func speichereUndWeiter() {
        if seitenInhalte.count == 1 {
            // Single-Page: ohne Marker speichern.
            auftrag.ocrText = seitenInhalte[0].trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let zusammengefuegt = seitenInhalte.enumerated().map { (idx, text) in
                "--- Seite \(idx + 1) ---\n\(text.trimmingCharacters(in: .whitespacesAndNewlines))"
            }.joined(separator: "\n\n")
            auftrag.ocrText = zusammengefuegt
        }
        dismiss()
    }

    // MARK: - Splitting-Logik

    /// Splittet einen OCR-Text mit `--- Seite N ---`-Markern in ein
    /// Array pro-Seiten-Inhalt. Kein Marker → ein einzelnes Element
    /// mit dem ganzen Text.
    static func splitInSeiten(_ text: String) -> [String] {
        let marker = "--- Seite "
        guard text.contains(marker) else {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        }

        var seiten: [String] = []
        let blocks = text.components(separatedBy: "--- Seite ")

        for (i, raw) in blocks.enumerated() {
            var block = raw
            if i == 0 {
                // Pre-Block vor dem ersten Marker — meist leer, manchmal Prolog.
            } else {
                // Marker hatte die Form „N ---\n…" — Nummer + „ ---\n" entfernen.
                if let r = block.range(of: "---\n") {
                    block = String(block[r.upperBound...])
                } else if let r = block.range(of: "---") {
                    block = String(block[r.upperBound...])
                }
            }
            // „(kein Text erkannt)"-Marker des OCRService passieren hier
            // unverändert — der User sieht den Hinweis im Editor.
            let cleaned = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                seiten.append(cleaned)
            }
        }
        return seiten
    }
}

#Preview {
    let auftrag = PruefungsAuftrag()
    auftrag.ocrText = """
    --- Seite 1 ---
    Nebenkostenabrechnung 2024
    Mieter: Max Mustermann
    --- Seite 2 ---
    Heizkosten: 320,50 €
    Wasser:     112,80 €
    --- Seite 3 ---
    Hausmeister: 84,00 €
    """
    auftrag.ocrConfidence = 0.92
    return NavigationStack { OCRReviewView(auftrag: auftrag) }
}
