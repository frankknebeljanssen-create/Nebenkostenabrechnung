import SwiftUI

struct LockScreenView: View {
    @Binding var isUnlocked: Bool
    @State private var authFailed = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("NK-Prüfer ist gesperrt")
                .font(.system(size: 17, weight: .semibold))

            Text("Entsperre mit \(BiometricService.biometricType)")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            if authFailed {
                Text("Authentifizierung fehlgeschlagen")
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
            }

            Spacer()

            Button {
                authenticate()
            } label: {
                HStack {
                    Image(systemName: biometricIcon)
                    Text("Entsperren")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .task { authenticate() }
    }

    private var biometricIcon: String {
        BiometricService.biometricType == "Face ID" ? "faceid" : "touchid"
    }

    private func authenticate() {
        Task {
            let result = await BiometricService.authenticate()
            await MainActor.run {
                switch result {
                case .success:
                    withAnimation { isUnlocked = true }
                case .failed:
                    authFailed = true
                case .notAvailable, .notConfigured:
                    // Keine Biometrie → kein Lock möglich, durchlassen
                    isUnlocked = true
                }
            }
        }
    }
}
