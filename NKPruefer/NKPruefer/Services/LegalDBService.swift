import Foundation

struct LegalDBService {

    // MARK: - DB-Modelle

    struct LegalEntry: Codable {
        let kostenart: String
        let bezeichnungen: [String]
        let umlagefaehig: Bool
        let rechtsgrundlage: String
        let bedingungen: String?
        let hinweise: String
        let bghUrteile: [BGHUrteil]

        enum CodingKeys: String, CodingKey {
            case kostenart, bezeichnungen, umlagefaehig, rechtsgrundlage
            case bedingungen, hinweise
            case bghUrteile = "bgh_urteile"
        }
    }

    struct BGHUrteil: Codable {
        let aktenzeichen: String
        let zusammenfassung: String
    }

    struct LegalCheckResult {
        let position: Kostenposition
        let entry: LegalEntry?
        let istUmlagefaehig: Bool?
        let rechtsgrundlage: String?
    }

    // MARK: - DB Loader

    static func loadDB() -> [LegalEntry] {
        guard let url = Bundle.main.url(forResource: "LEGAL_DB", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        do {
            let root = try JSONDecoder().decode(DBRoot.self, from: data)
            return root.kostenarten
        } catch {
            return []
        }
    }

    private struct DBRoot: Decodable {
        let kostenarten: [LegalEntry]
    }

    // MARK: - Single Position Check

    static func check(
        position: Kostenposition,
        db: [LegalEntry]
    ) -> LegalCheckResult {
        // 1. Exakter Match über kostenartNormalisiert
        if let normalisiert = position.kostenartNormalisiert,
           let entry = db.first(where: { $0.kostenart == normalisiert }) {
            return LegalCheckResult(
                position: position,
                entry: entry,
                istUmlagefaehig: entry.umlagefaehig,
                rechtsgrundlage: entry.rechtsgrundlage
            )
        }

        // 2. Fuzzy-Match: Original-Bezeichnung gegen entry.bezeichnungen
        let originalLower = position.bezeichnungOriginal.lowercased()
        for entry in db {
            for bezeichnung in entry.bezeichnungen {
                let bezLower = bezeichnung.lowercased()
                if originalLower.contains(bezLower) || bezLower.contains(originalLower) {
                    return LegalCheckResult(
                        position: position,
                        entry: entry,
                        istUmlagefaehig: entry.umlagefaehig,
                        rechtsgrundlage: entry.rechtsgrundlage
                    )
                }
            }
        }

        // 3. Kein Match → Grenzfall
        return LegalCheckResult(
            position: position,
            entry: nil,
            istUmlagefaehig: nil,
            rechtsgrundlage: nil
        )
    }

    // MARK: - Bulk Check

    static func checkAll(
        positionen: [Kostenposition],
        db: [LegalEntry]
    ) -> (findings: [Finding], grenzfaelle: [Kostenposition]) {
        var findings: [Finding] = []
        var grenzfaelle: [Kostenposition] = []
        var counter = 1

        for position in positionen {
            let result = check(position: position, db: db)
            switch result.istUmlagefaehig {
            case .some(true):
                continue

            case .some(false):
                let beschreibung: String = {
                    if let entry = result.entry {
                        return "„\(position.bezeichnungOriginal)“ ist nach \(entry.rechtsgrundlage) nicht umlagefähig. \(entry.hinweise)"
                    }
                    return "„\(position.bezeichnungOriginal)“ ist nach BetrKV nicht umlagefähig."
                }()

                let finding = Finding(
                    id: "L\(String(format: "%03d", counter))",
                    typ: .nichtUmlagefaehig,
                    schwere: .fehler,
                    konfidenz: .sicher,
                    quelle: .code,
                    positionId: position.id,
                    bezeichnung: position.bezeichnungOriginal,
                    beschreibung: beschreibung,
                    betragAbrechnung: position.mieterAnteil,
                    betragKorrekt: 0,
                    differenz: position.mieterAnteil,
                    rechtsgrundlage: result.rechtsgrundlage,
                    rechtsgrundlageVerifiziert: true
                )
                findings.append(finding)
                counter += 1

            case .none:
                grenzfaelle.append(position)
            }
        }
        return (findings, grenzfaelle)
    }
}
