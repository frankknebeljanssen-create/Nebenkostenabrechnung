import Foundation
import Combine

class PrivacyConsent: ObservableObject {
    @Published var hatZugestimmt: Bool {
        didSet { UserDefaults.standard.set(hatZugestimmt, forKey: "privacy_consent_given") }
    }
    @Published var consentDatum: Date? {
        didSet {
            if let d = consentDatum {
                UserDefaults.standard.set(d.timeIntervalSince1970, forKey: "privacy_consent_date")
            } else {
                UserDefaults.standard.removeObject(forKey: "privacy_consent_date")
            }
        }
    }

    init() {
        self.hatZugestimmt = UserDefaults.standard.bool(forKey: "privacy_consent_given")
        let ts = UserDefaults.standard.double(forKey: "privacy_consent_date")
        self.consentDatum = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    func erteileZustimmung() {
        consentDatum = Date()
        hatZugestimmt = true
    }

    func widerrufeZustimmung() {
        hatZugestimmt = false
        consentDatum = nil
    }
}
