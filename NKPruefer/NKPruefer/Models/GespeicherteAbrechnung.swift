import Foundation
import SwiftData

@Model
final class GespeicherteAbrechnung {
    var id: String
    var zeitraumVon: Date
    var zeitraumBis: Date
    var pruefDatum: Date

    /// "neu" | "geprueft" | "widerspruch_gesendet"
    var status: String

    var ersparnis: Decimal
    var pruefberichtJSON: Data?
    var originalBildData: Data?

    init(
        id: String,
        zeitraumVon: Date,
        zeitraumBis: Date,
        pruefDatum: Date = .now,
        status: String = "neu",
        ersparnis: Decimal = 0,
        pruefberichtJSON: Data? = nil,
        originalBildData: Data? = nil
    ) {
        self.id = id
        self.zeitraumVon = zeitraumVon
        self.zeitraumBis = zeitraumBis
        self.pruefDatum = pruefDatum
        self.status = status
        self.ersparnis = ersparnis
        self.pruefberichtJSON = pruefberichtJSON
        self.originalBildData = originalBildData
    }
}

// MARK: - Bericht Helpers

extension GespeicherteAbrechnung {
    /// Speichert einen Pruefbericht als JSON in `pruefberichtJSON`.
    func speichereBericht(_ bericht: Pruefbericht) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.pruefberichtJSON = try? encoder.encode(bericht)
        self.ersparnis = bericht.ersparnisGesamt
        self.pruefDatum = bericht.pruefDatum
        self.status = "geprueft"
    }

    /// Lädt den gespeicherten Pruefbericht zurück (nil bei Fehler oder leerem Slot).
    func ladeBericht() -> Pruefbericht? {
        guard let data = pruefberichtJSON else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Pruefbericht.self, from: data)
    }

    var pruefDatumFormatiert: String {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy"
        df.locale = Locale(identifier: "de_DE")
        return df.string(from: pruefDatum)
    }

    var fehlerAnzahl: Int {
        ladeBericht()?.findings.filter { $0.schwere == .fehler }.count ?? 0
    }

    var warnungAnzahl: Int {
        ladeBericht()?.findings.filter { $0.schwere == .warnung }.count ?? 0
    }
}
