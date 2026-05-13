import Foundation

struct Pruefbericht: Codable, Identifiable, Hashable, Sendable {
    let abrechnungId: String
    let pruefDatum: Date
    let abrechnung: Abrechnung
    let findings: [Finding]
    let berichtText: String
    let ersparnisGesamt: Decimal
    /// findingId → TrustScore. Korrektur 1: Trust lebt im Pruefbericht, nicht im Finding.
    var trustScores: [String: TrustScore]

    var id: String { abrechnungId }

    init(
        abrechnungId: String,
        pruefDatum: Date,
        abrechnung: Abrechnung,
        findings: [Finding],
        berichtText: String,
        ersparnisGesamt: Decimal,
        trustScores: [String: TrustScore] = [:]
    ) {
        self.abrechnungId = abrechnungId
        self.pruefDatum = pruefDatum
        self.abrechnung = abrechnung
        self.findings = findings
        self.berichtText = berichtText
        self.ersparnisGesamt = ersparnisGesamt
        self.trustScores = trustScores
    }

    // MARK: - Codable (backward-compat für alte JSONs ohne trustScores)

    enum CodingKeys: String, CodingKey {
        case abrechnungId, pruefDatum, abrechnung, findings,
             berichtText, ersparnisGesamt, trustScores
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.abrechnungId = try container.decode(String.self, forKey: .abrechnungId)
        self.pruefDatum = try container.decode(Date.self, forKey: .pruefDatum)
        self.abrechnung = try container.decode(Abrechnung.self, forKey: .abrechnung)
        self.findings = try container.decode([Finding].self, forKey: .findings)
        self.berichtText = try container.decode(String.self, forKey: .berichtText)
        self.ersparnisGesamt = try container.decode(Decimal.self, forKey: .ersparnisGesamt)
        self.trustScores = (try? container.decode([String: TrustScore].self, forKey: .trustScores)) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(abrechnungId, forKey: .abrechnungId)
        try container.encode(pruefDatum, forKey: .pruefDatum)
        try container.encode(abrechnung, forKey: .abrechnung)
        try container.encode(findings, forKey: .findings)
        try container.encode(berichtText, forKey: .berichtText)
        try container.encode(ersparnisGesamt, forKey: .ersparnisGesamt)
        try container.encode(trustScores, forKey: .trustScores)
    }

    // MARK: - Hashable / Equatable über abrechnungId

    static func == (lhs: Pruefbericht, rhs: Pruefbericht) -> Bool {
        lhs.abrechnungId == rhs.abrechnungId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(abrechnungId)
    }
}
