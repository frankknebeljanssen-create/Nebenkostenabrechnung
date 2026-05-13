import LocalAuthentication

enum BiometricService {

    enum BiometricResult {
        case success
        case failed
        case notAvailable
        case notConfigured
    }

    static func authenticate() async -> BiometricResult {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let err = error, err.code == LAError.biometryNotEnrolled.rawValue {
                return .notConfigured
            }
            return .notAvailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Entsperre NK-Prüfer um deine Abrechnungen zu sehen"
            )
            return success ? .success : .failed
        } catch {
            return .failed
        }
    }

    static var biometricType: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default:       return "Biometrie"
        }
    }

    static var isAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
}
