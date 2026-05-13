import SwiftUI

/// v4-Darstellung-Ansicht.
///
/// Migriert die „Darstellung"-Sektion aus der alten SettingsView:
///  • Erscheinungsbild (System / Hell / Dunkel)
///  • App-Lock-Toggle (Face ID / Touch ID), nur wenn Biometrie verfügbar
struct DarstellungView: View {
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            NKHeader(title: "Darstellung", showBack: true)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    erscheinungsbildSection
                    if BiometricService.isAvailable {
                        appLockSection
                    }
                }
                .padding(AppSpacing.contentPadding)
            }
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Erscheinungsbild

    private var erscheinungsbildSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            NKSectionLabel(text: "Erscheinungsbild")

            NKCard {
                Picker("Erscheinungsbild", selection: $appSettings.appearanceMode) {
                    Text("System").tag(0)
                    Text("Hell").tag(1)
                    Text("Dunkel").tag(2)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - App-Lock

    private var appLockSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            NKSectionLabel(text: "App-Schutz")

            NKCard {
                Toggle(isOn: $appSettings.appLockEnabled) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: biometrieIcon)
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("App mit \(BiometricService.biometricType) sperren")
                                .font(.system(size: 15))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Beim Öffnen entsperren mit \(BiometricService.biometricType).")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .tint(AppTheme.accent)
            }
        }
    }

    private var biometrieIcon: String {
        switch BiometricService.biometricType {
        case "Face ID":  return "faceid"
        case "Touch ID": return "touchid"
        case "Optic ID": return "opticid"
        default:         return "lock.shield"
        }
    }
}

#Preview {
    NavigationStack { DarstellungView() }
        .environmentObject(AppSettings())
}
