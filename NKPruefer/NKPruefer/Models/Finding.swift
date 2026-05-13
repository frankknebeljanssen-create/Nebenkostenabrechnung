import Foundation

// MARK: - Finding

struct Finding: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let typ: FindingTyp
    let schwere: Schwere
    let konfidenz: Konfidenz
    let quelle: Quelle
    let positionId: Int
    let bezeichnung: String
    let beschreibung: String
    let betragAbrechnung: Decimal
    let betragKorrekt: Decimal?
    let differenz: Decimal
    let rechtsgrundlage: String?
    let rechtsgrundlageVerifiziert: Bool

    // MARK: - Neue Felder für v4-Ergebnis-Ansicht (alle optional)
    //
    // Diese Felder werden vom Berichterstatter-Agenten gefüllt und in der
    // aufklappbaren Ergebnis-Karte angezeigt. Sie sind optional, damit alte
    // Pruefberichte (die im SwiftData-Store als JSON liegen) weiter geladen
    // werden können — siehe `init(from:)` unten.

    /// Verständliche Erklärung in einfacher Sprache (1–2 Sätze).
    let erklaerung: String?

    /// Konkrete Handlungsempfehlung für den Mieter (1 Satz).
    let handlungsempfehlung: String?

    enum CodingKeys: String, CodingKey {
        case id
        case typ
        case schwere
        case konfidenz
        case quelle
        case positionId = "position_id"
        case bezeichnung
        case beschreibung
        case betragAbrechnung = "betrag_abrechnung"
        case betragKorrekt = "betrag_korrekt"
        case differenz
        case rechtsgrundlage
        case rechtsgrundlageVerifiziert = "rechtsgrundlage_verifiziert"
        case erklaerung
        case handlungsempfehlung
    }

    // MARK: - Memberwise Init mit Defaults
    //
    // Defaults für die neuen Felder, damit alle bestehenden Aufrufe in
    // Calculator.swift, LegalDBService.swift, OrchestrationService.swift
    // unverändert weiter kompilieren.
    init(
        id: String,
        typ: FindingTyp,
        schwere: Schwere,
        konfidenz: Konfidenz,
        quelle: Quelle,
        positionId: Int,
        bezeichnung: String,
        beschreibung: String,
        betragAbrechnung: Decimal,
        betragKorrekt: Decimal?,
        differenz: Decimal,
        rechtsgrundlage: String?,
        rechtsgrundlageVerifiziert: Bool,
        erklaerung: String? = nil,
        handlungsempfehlung: String? = nil
    ) {
        self.id = id
        self.typ = typ
        self.schwere = schwere
        self.konfidenz = konfidenz
        self.quelle = quelle
        self.positionId = positionId
        self.bezeichnung = bezeichnung
        self.beschreibung = beschreibung
        self.betragAbrechnung = betragAbrechnung
        self.betragKorrekt = betragKorrekt
        self.differenz = differenz
        self.rechtsgrundlage = rechtsgrundlage
        self.rechtsgrundlageVerifiziert = rechtsgrundlageVerifiziert
        self.erklaerung = erklaerung
        self.handlungsempfehlung = handlungsempfehlung
    }

    // MARK: - Backward-kompatibles Decoding
    //
    // Alte Pruefberichte (vor v4) kennen die Felder `erklaerung` und
    // `handlungsempfehlung` nicht. Mit `try?` decoden wir sie tolerant,
    // sodass alte Daten ohne Crash geladen werden.

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.typ = try c.decode(FindingTyp.self, forKey: .typ)
        self.schwere = try c.decode(Schwere.self, forKey: .schwere)
        self.konfidenz = try c.decode(Konfidenz.self, forKey: .konfidenz)
        self.quelle = try c.decode(Quelle.self, forKey: .quelle)
        self.positionId = try c.decode(Int.self, forKey: .positionId)
        self.bezeichnung = try c.decode(String.self, forKey: .bezeichnung)
        self.beschreibung = try c.decode(String.self, forKey: .beschreibung)
        self.betragAbrechnung = try c.decode(Decimal.self, forKey: .betragAbrechnung)
        self.betragKorrekt = try? c.decode(Decimal.self, forKey: .betragKorrekt)
        self.differenz = try c.decode(Decimal.self, forKey: .differenz)
        self.rechtsgrundlage = try? c.decode(String.self, forKey: .rechtsgrundlage)
        self.rechtsgrundlageVerifiziert = (try? c.decode(Bool.self, forKey: .rechtsgrundlageVerifiziert)) ?? false
        // Neue v4-Felder — alte JSONs haben sie nicht:
        self.erklaerung = try? c.decode(String.self, forKey: .erklaerung)
        self.handlungsempfehlung = try? c.decode(String.self, forKey: .handlungsempfehlung)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(typ, forKey: .typ)
        try c.encode(schwere, forKey: .schwere)
        try c.encode(konfidenz, forKey: .konfidenz)
        try c.encode(quelle, forKey: .quelle)
        try c.encode(positionId, forKey: .positionId)
        try c.encode(bezeichnung, forKey: .bezeichnung)
        try c.encode(beschreibung, forKey: .beschreibung)
        try c.encode(betragAbrechnung, forKey: .betragAbrechnung)
        try c.encodeIfPresent(betragKorrekt, forKey: .betragKorrekt)
        try c.encode(differenz, forKey: .differenz)
        try c.encodeIfPresent(rechtsgrundlage, forKey: .rechtsgrundlage)
        try c.encode(rechtsgrundlageVerifiziert, forKey: .rechtsgrundlageVerifiziert)
        try c.encodeIfPresent(erklaerung, forKey: .erklaerung)
        try c.encodeIfPresent(handlungsempfehlung, forKey: .handlungsempfehlung)
    }
}

extension Finding {
    func withId(_ newId: String) -> Finding {
        Finding(
            id: newId,
            typ: typ,
            schwere: schwere,
            konfidenz: konfidenz,
            quelle: quelle,
            positionId: positionId,
            bezeichnung: bezeichnung,
            beschreibung: beschreibung,
            betragAbrechnung: betragAbrechnung,
            betragKorrekt: betragKorrekt,
            differenz: differenz,
            rechtsgrundlage: rechtsgrundlage,
            rechtsgrundlageVerifiziert: rechtsgrundlageVerifiziert,
            erklaerung: erklaerung,
            handlungsempfehlung: handlungsempfehlung
        )
    }

    /// Korrektur 2: Schwere ändern (z. B. Challenger empfiehlt Herabstufung).
    func withSchwere(_ neueSchwere: Schwere) -> Finding {
        Finding(
            id: id,
            typ: typ,
            schwere: neueSchwere,
            konfidenz: konfidenz,
            quelle: quelle,
            positionId: positionId,
            bezeichnung: bezeichnung,
            beschreibung: beschreibung,
            betragAbrechnung: betragAbrechnung,
            betragKorrekt: betragKorrekt,
            differenz: differenz,
            rechtsgrundlage: rechtsgrundlage,
            rechtsgrundlageVerifiziert: rechtsgrundlageVerifiziert,
            erklaerung: erklaerung,
            handlungsempfehlung: handlungsempfehlung
        )
    }

    /// Nachträgliches Anreichern durch den Berichterstatter.
    func withErklaerungen(
        erklaerung: String?,
        rechtsgrundlage: String?,
        handlungsempfehlung: String?
    ) -> Finding {
        Finding(
            id: id,
            typ: typ,
            schwere: schwere,
            konfidenz: konfidenz,
            quelle: quelle,
            positionId: positionId,
            bezeichnung: bezeichnung,
            beschreibung: beschreibung,
            betragAbrechnung: betragAbrechnung,
            betragKorrekt: betragKorrekt,
            differenz: differenz,
            // Berichterstatter darf eine fehlende Rechtsgrundlage ergänzen,
            // aber eine vorhandene NICHT überschreiben.
            rechtsgrundlage: self.rechtsgrundlage ?? rechtsgrundlage,
            rechtsgrundlageVerifiziert: rechtsgrundlageVerifiziert,
            erklaerung: erklaerung,
            handlungsempfehlung: handlungsempfehlung
        )
    }
}

// MARK: - Enums

enum FindingTyp: String, Codable, Sendable {
    case rechenfehler
    case nichtUmlagefaehig = "nicht_umlagefaehig"
    case verteilerschluessel
    case plausibilitaet
    case grenzfall
}

enum Schwere: String, Codable, Sendable {
    case fehler
    case warnung
    case info
}

enum Konfidenz: String, Codable, Sendable {
    case sicher
    case wahrscheinlich
    case unsicher
}

enum Quelle: String, Codable, Sendable {
    case code
    case juristAgent = "jurist_agent"
}
