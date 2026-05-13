import Foundation
import SwiftData

@Model
final class Mietobjekt {
    var id: UUID
    var erstelltAm: Date

    // Wohnung
    var adresse: String
    var bezeichnung: String?
    var flaecheQm: Decimal
    var personenzahl: Int
    var mietbeginn: Date?
    var kaltmiete: Decimal?
    var nkVorauszahlungMonatlich: Decimal?

    // Vermieter (optional — wird beim Widerspruch nachgefragt)
    var vermieterName: String?
    var vermieterAnsprechpartner: String?
    var vermieterAdresse: String?
    var vermieterEmail: String?
    var vermieterTelefon: String?
    var vermieterWhatsApp: String?

    // Mietvertrag
    var mietvertragPdfData: Data?

    @Relationship(deleteRule: .cascade)
    var abrechnungen: [GespeicherteAbrechnung]

    init(
        id: UUID = UUID(),
        erstelltAm: Date = .now,
        adresse: String = "",
        bezeichnung: String? = nil,
        flaecheQm: Decimal = 0,
        personenzahl: Int = 1,
        mietbeginn: Date? = nil,
        kaltmiete: Decimal? = nil,
        nkVorauszahlungMonatlich: Decimal? = nil,
        vermieterName: String? = nil,
        vermieterAnsprechpartner: String? = nil,
        vermieterAdresse: String? = nil,
        vermieterEmail: String? = nil,
        vermieterTelefon: String? = nil,
        vermieterWhatsApp: String? = nil,
        mietvertragPdfData: Data? = nil,
        abrechnungen: [GespeicherteAbrechnung] = []
    ) {
        self.id = id
        self.erstelltAm = erstelltAm
        self.adresse = adresse
        self.bezeichnung = bezeichnung
        self.flaecheQm = flaecheQm
        self.personenzahl = personenzahl
        self.mietbeginn = mietbeginn
        self.kaltmiete = kaltmiete
        self.nkVorauszahlungMonatlich = nkVorauszahlungMonatlich
        self.vermieterName = vermieterName
        self.vermieterAnsprechpartner = vermieterAnsprechpartner
        self.vermieterAdresse = vermieterAdresse
        self.vermieterEmail = vermieterEmail
        self.vermieterTelefon = vermieterTelefon
        self.vermieterWhatsApp = vermieterWhatsApp
        self.mietvertragPdfData = mietvertragPdfData
        self.abrechnungen = abrechnungen
    }

    /// Mieter-Daten kommen aus UserProfile (extern geprüft).
    var kannWiderspruchErstellen: Bool {
        guard let vName = vermieterName, !vName.trimmed.isEmpty,
              let vAdr = vermieterAdresse, !vAdr.trimmed.isEmpty,
              !adresse.trimmed.isEmpty else {
            return false
        }
        return true
    }

    var letzteAbrechnung: GespeicherteAbrechnung? {
        abrechnungen.max(by: { $0.pruefDatum < $1.pruefDatum })
    }

    var letzteErsparnis: Decimal? {
        letzteAbrechnung?.ersparnis
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
