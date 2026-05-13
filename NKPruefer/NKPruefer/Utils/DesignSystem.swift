import SwiftUI
import UIKit

// DESIGN-REGELN:
// - Body: 15pt, Headlines: 17pt semibold, Captions: 12pt
// - Buttons: 15pt semibold
// - App ist fullscreen, Tab-Bar native iOS
// - Äußere Container: kein .background/.clipShape/.padding
// - Content-padding: 16pt horizontal

// MARK: - Design Tokens

enum NKDesign {
    static let bodyFont: Font = .system(size: 15)
    static let headlineFont: Font = .system(size: 17, weight: .semibold)
    static let captionFont: Font = .system(size: 12)

    static let minTapTarget: CGFloat = 44
    static let bigButtonHeight: CGFloat = 44
    static let cornerRadius: CGFloat = 10

    static let accentColor = Color.blue
    static let successColor = Color.green
    static let warningColor = Color.orange
    static let errorColor = Color.red

    static let infoBoxBackground = Color.blue.opacity(0.08)
    static let fieldBackground = Color(.systemBackground)
    static let fieldBorder = Color.gray.opacity(0.3)
}

// MARK: - NKTextField

struct NKTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var helperText: String? = nil
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var autocorrection: Bool = true
    var isRequired: Bool = false
    var hasError: Bool = false
    var errorText: String? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                if isRequired {
                    Text("*")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NKDesign.errorColor)
                }
            }

            TextField(placeholder, text: $text)
                .font(NKDesign.bodyFont)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(!autocorrection)
                .focused($isFocused)
                .frame(minHeight: NKDesign.minTapTarget)
                .padding(.horizontal, 14)
                .background(NKDesign.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: NKDesign.cornerRadius)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .accessibilityLabel(label)

            if hasError, let errorText {
                Label(errorText, systemImage: "exclamationmark.circle.fill")
                    .font(NKDesign.captionFont)
                    .foregroundStyle(NKDesign.errorColor)
            } else if let helperText, !helperText.isEmpty {
                Text(helperText)
                    .font(NKDesign.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var borderColor: Color {
        if hasError { return NKDesign.errorColor }
        if isFocused { return NKDesign.accentColor }
        return NKDesign.fieldBorder
    }

    private var borderWidth: CGFloat {
        (hasError || isFocused) ? 2 : 1
    }
}

// MARK: - NKDecimalField

struct NKDecimalField: View {
    let label: String
    let unit: String
    let placeholder: String
    @Binding var value: Decimal?

    var helperText: String? = nil
    var isRequired: Bool = false
    var hasError: Bool = false
    var errorText: String? = nil

    @FocusState private var isFocused: Bool

    private static let germanFormat: Decimal.FormatStyle = .number
        .locale(Locale(identifier: "de_DE"))
        .precision(.fractionLength(0...2))

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                if isRequired {
                    Text("*")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NKDesign.errorColor)
                }
            }

            HStack(spacing: 8) {
                TextField(
                    placeholder,
                    value: $value,
                    format: Self.germanFormat
                )
                .font(NKDesign.bodyFont)
                .keyboardType(.decimalPad)
                .focused($isFocused)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(unit)
                    .font(NKDesign.bodyFont.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: NKDesign.minTapTarget)
            .background(NKDesign.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: NKDesign.cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(label) in \(unit)")

            if hasError, let errorText {
                Label(errorText, systemImage: "exclamationmark.circle.fill")
                    .font(NKDesign.captionFont)
                    .foregroundStyle(NKDesign.errorColor)
            } else if let helperText, !helperText.isEmpty {
                Text(helperText)
                    .font(NKDesign.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var borderColor: Color {
        if hasError { return NKDesign.errorColor }
        if isFocused { return NKDesign.accentColor }
        return NKDesign.fieldBorder
    }

    private var borderWidth: CGFloat {
        (hasError || isFocused) ? 2 : 1
    }
}

// MARK: - NKInfoBox

struct NKInfoBox: View {
    let text: String
    var icon: String = "info.circle.fill"

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .imageScale(.large)
                .foregroundStyle(NKDesign.accentColor)
                .accessibilityHidden(true)

            Text(text)
                .font(NKDesign.bodyFont)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(NKDesign.infoBoxBackground)
        .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
    }
}

// MARK: - NKBigButton

struct NKBigButton: View {
    enum Style { case primary, success, secondary }

    let title: String
    var icon: String? = nil
    var style: Style = .primary
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(minHeight: NKDesign.bigButtonHeight)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
        .accessibilityLabel(title)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return NKDesign.accentColor
        case .success: return NKDesign.successColor
        case .secondary: return Color.gray.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .success: return .white
        case .secondary: return .primary
        }
    }
}

// MARK: - NKTextButton (sekundär, nur Text)

struct NKTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NKDesign.bodyFont)
                .foregroundStyle(NKDesign.accentColor)
                .frame(maxWidth: .infinity)
                .frame(minHeight: NKDesign.minTapTarget)
        }
        .accessibilityLabel(title)
    }
}

// MARK: - NKStepIndicator

struct NKStepIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(spacing: 8) {
            Text("Schritt \(current) von \(total)")
                .font(NKDesign.captionFont.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Schritt \(current) von \(total)")

            HStack(spacing: 10) {
                ForEach(1...total, id: \.self) { step in
                    Circle()
                        .fill(step <= current ? NKDesign.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - NKPersonenStepper (große +/- Buttons)

struct NKPersonenStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...10

    var body: some View {
        HStack(spacing: 16) {
            stepperButton(symbol: "minus", enabled: value > range.lowerBound, label: "Eine Person weniger") {
                if value > range.lowerBound {
                    value -= 1
                    NKHaptic.selection()
                }
            }

            Text("\(value)")
                .font(.system(size: 32, weight: .semibold))
                .monospacedDigit()
                .frame(minWidth: 80, minHeight: 56)
                .background(Color.gray.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
                .accessibilityLabel("\(value) Personen")

            stepperButton(symbol: "plus", enabled: value < range.upperBound, label: "Eine Person mehr") {
                if value < range.upperBound {
                    value += 1
                    NKHaptic.selection()
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func stepperButton(symbol: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(enabled ? NKDesign.accentColor : Color.gray.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

// MARK: - NKSuccessOverlay

struct NKSuccessOverlay: View {
    let message: String
    var onComplete: () -> Void = {}

    @State private var iconScale: CGFloat = 0.4
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(NKDesign.successColor)
                    .scaleEffect(iconScale)

                Text(message)
                    .font(NKDesign.headlineFont)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .padding(36)
            .background(.thickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .opacity(contentOpacity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .onAppear {
            NKHaptic.success()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                iconScale = 1.0
                contentOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.25)) {
                    contentOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onComplete()
                }
            }
        }
    }
}
