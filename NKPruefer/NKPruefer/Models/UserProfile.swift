import SwiftUI
import Combine

class UserProfile: ObservableObject {
    @Published var vorname: String {
        didSet { UserDefaults.standard.set(vorname, forKey: "up_vorname") }
    }
    @Published var nachname: String {
        didSet { UserDefaults.standard.set(nachname, forKey: "up_nachname") }
    }
    @Published var strasse: String {
        didSet { UserDefaults.standard.set(strasse, forKey: "up_strasse") }
    }
    @Published var plz: String {
        didSet { UserDefaults.standard.set(plz, forKey: "up_plz") }
    }
    @Published var ort: String {
        didSet { UserDefaults.standard.set(ort, forKey: "up_ort") }
    }
    @Published var email: String {
        didSet { UserDefaults.standard.set(email, forKey: "up_email") }
    }

    var vollerName: String {
        let v = vorname.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = nachname.trimmingCharacters(in: .whitespacesAndNewlines)
        return [v, n].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var volleAdresse: String {
        let s = strasse.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = plz.trimmingCharacters(in: .whitespacesAndNewlines)
        let o = ort.trimmingCharacters(in: .whitespacesAndNewlines)
        let zeile2 = [p, o].filter { !$0.isEmpty }.joined(separator: " ")
        return [s, zeile2].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    var hatName: Bool {
        !vollerName.isEmpty
    }

    var displayVorname: String? {
        let v = vorname.trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : v
    }

    init() {
        self.vorname = UserDefaults.standard.string(forKey: "up_vorname") ?? ""
        self.nachname = UserDefaults.standard.string(forKey: "up_nachname") ?? ""
        self.strasse = UserDefaults.standard.string(forKey: "up_strasse") ?? ""
        self.plz = UserDefaults.standard.string(forKey: "up_plz") ?? ""
        self.ort = UserDefaults.standard.string(forKey: "up_ort") ?? ""
        self.email = UserDefaults.standard.string(forKey: "up_email") ?? ""
    }
}
