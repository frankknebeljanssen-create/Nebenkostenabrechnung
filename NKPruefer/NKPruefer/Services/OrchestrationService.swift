import Foundation

@MainActor
@Observable
final class OrchestrationService {

    // MARK: - Phasen & Status

    enum Phase: String, CaseIterable {
        case parser       = "Dokument wird gelesen"
        case validierung  = "Extraktion wird geprüft"
        case rechner      = "Berechnungen werden geprüft"
        case recht        = "Rechtliche Prüfung"
        case jurist       = "Grenzfälle werden bewertet"
        case debatte      = "Agenten debattieren"
        case bericht      = "Prüfbericht wird erstellt"
        case review       = "Bericht wird geprüft"
        case audit        = "Finale Prüfung"
        case fertig       = "Fertig"
    }

    enum Status: Equatable {
        case idle, running, finished, failed
    }

    // MARK: - Nested Result Types (Korrektur 6)

    struct ValidierungsErgebnis {
        let istKorrekt: Bool
        let fehlerDetails: String
        let bewertung: String
    }

    struct ChallengeResult {
        let findingId: String
        let bestaetige: Bool
        let empfehlung: String   // "behalten" | "herabstufen" | "entfernen"
        let begruendung: String
    }

    struct QualityResult {
        let istKorrekt: Bool
        let korrekturanweisungen: String
    }

    struct AuditResult {
        let freigabe: Bool
        let gesamtBewertung: String
        let findingsZuEntfernen: [String]
    }

    // MARK: - Agenten-Kommunikation (Live-Log für UI)

    struct AgentenNachricht: Identifiable {
        let id = UUID()
        let zeitpunkt: Date = Date()
        let von: String
        let an: String
        let nachricht: String
        let typ: NachrichtTyp

        enum NachrichtTyp {
            case delegation   // grau
            case antwort      // blau
            case challenge    // rot
            case korrektur    // amber
            case freigabe     // grün
        }
    }

    // MARK: - Observable State

    var status: Status = .idle
    var aktuellePhase: Phase? = nil
    var bericht: Pruefbericht? = nil
    var fehlerMeldung: String? = nil
    var abgeschlosseneSchritte: Int = 0
    let gesamtSchritte: Int = 9

    /// Live-Log der Agenten-Kommunikation (für AnalyseView).
    var agentenLog: [AgentenNachricht] = []

    /// Persistierungs-Log (wird in AnalyseView in SwiftData geschrieben).
    var auditEntries: [APIAuditEntry] = []

    // MARK: - Public Entry Point

    func starte(
        ocrText: String,
        mietobjekt: Mietobjekt,
        mieterName: String = "",
        mieterAdresse: String = ""
    ) async {
        guard status == .idle else { return }
        status = .running
        aktuellePhase = .parser
        abgeschlosseneSchritte = 0
        fehlerMeldung = nil
        bericht = nil
        agentenLog = []
        auditEntries = []

        guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fehlerMeldung = "Es liegt kein OCR-Text vor."
            status = .failed
            return
        }

        do {
            // ── PHASE 1: Parser (mit Original-ocrText) ──
            logge("Orchestrator", an: "Parser", "Extrahiere die Abrechnung aus dem OCR-Text.", typ: .delegation)
            var abrechnung = try await parseAbrechnung(ocrText: ocrText)
            logge("Parser", an: "Orchestrator", "Extraktion abgeschlossen. \(abrechnung.kostenpositionen.count) Posten gefunden.", typ: .antwort)
            auditEntries.append(APIAuditEntry(
                agent: "Parser",
                zweck: "OCR-Extraktion",
                datenGesendet: "OCR-Text, \(ocrText.count) Zeichen",
                anonymisiert: false
            ))
            abgeschlosseneSchritte = 1

            // Anonymisierung NACH Parser, VOR allen weiteren Agent-Calls
            let anon = AnonymizationService.anonymize(
                ocrText: ocrText,
                mieterName: mieterName,
                mieterAdresse: mieterAdresse,
                vermieterName: mietobjekt.vermieterName,
                vermieterAdresse: mietobjekt.vermieterAdresse
            )
            let anonymizedOCR = anon.anonymizedText

            // ── PHASE 2: Validator (V3 — Quelltreue) ──
            aktuellePhase = .validierung
            logge("Orchestrator", an: "Validator", "Prüfe die Extraktion gegen den Originaltext.", typ: .delegation)

            // Korrektur 10: Validator failt graceful
            let validierung: ValidierungsErgebnis
            do {
                validierung = try await validiereExtraktion(abrechnung: abrechnung, anonOcrText: anonymizedOCR)
                auditEntries.append(APIAuditEntry(
                    agent: "Validator", zweck: "Quelltreue-Check",
                    datenGesendet: "Anonymisierter OCR + JSON, \(anonymizedOCR.count) Zeichen",
                    anonymisiert: true,
                    statsNamen: anon.stats.namesReplaced,
                    statsIBANs: anon.stats.ibansReplaced,
                    statsEmails: anon.stats.emailsReplaced,
                    statsTelefon: anon.stats.phonesReplaced
                ))
            } catch {
                logge("Orchestrator", an: "Alle", "Validator nicht erreichbar — fahre ohne Validierung fort.", typ: .korrektur)
                validierung = ValidierungsErgebnis(istKorrekt: true, fehlerDetails: "", bewertung: "Übersprungen")
            }

            if !validierung.istKorrekt {
                logge("Validator", an: "Parser", "Fehler gefunden: \(validierung.bewertung). Korrigiere.", typ: .challenge)
                // FEEDBACK-LOOP — max. 1 Retry
                if let korrigiert = try? await parseAbrechnungMitKorrektur(
                    ocrText: ocrText,
                    korrekturhinweise: validierung.fehlerDetails
                ) {
                    abrechnung = korrigiert
                    logge("Parser", an: "Orchestrator", "Korrigierte Extraktion mit \(abrechnung.kostenpositionen.count) Posten.", typ: .korrektur)
                }
            } else {
                logge("Validator", an: "Orchestrator", "Extraktion korrekt. Keine Fehler gefunden.", typ: .freigabe)
            }
            abgeschlosseneSchritte = 2

            // ── PHASE 3: V1 + V2 (Code) + Calculator ──
            aktuellePhase = .rechner

            // V1: Struktur — Korrektur 9: hartes Abort bei Fehler
            let (v1valid, v1fehler) = ValidationService.validateStruktur(abrechnung: abrechnung)
            if !v1valid {
                fehlerMeldung = "Die Abrechnung konnte nicht korrekt gelesen werden: \(v1fehler.joined(separator: ". ")). Bitte fotografiere die Abrechnung erneut."
                status = .failed
                return
            }

            // V2: Cross-Check — soft, fließt in TrustScore
            let (v2valid, v2fehler) = ValidationService.validateCrossCheck(abrechnung: abrechnung)
            logge(
                "Prüfer", an: "Orchestrator",
                "Struktur: OK. Cross-Check: \(v2valid ? "OK" : v2fehler.joined(separator: "; "))",
                typ: v2valid ? .freigabe : .challenge
            )

            let mathFindings = Calculator.checkAlle(
                abrechnung: abrechnung,
                userFlaecheQm: mietobjekt.flaecheQm,
                userPersonenzahl: mietobjekt.personenzahl
            )
            abgeschlosseneSchritte = 3

            // ── PHASE 4: Legal-DB (Code) ──
            aktuellePhase = .recht
            let db = LegalDBService.loadDB()
            let (legalFindings, grenzfaelle) = LegalDBService.checkAll(
                positionen: abrechnung.kostenpositionen,
                db: db
            )
            abgeschlosseneSchritte = 4

            // ── PHASE 5: Jurist (Grenzfälle) ──
            aktuellePhase = .jurist
            var juristFindings: [Finding] = []
            for grenzfall in grenzfaelle {
                logge("Orchestrator", an: "Jurist", "Bewerte: '\(grenzfall.bezeichnungOriginal)'", typ: .delegation)
                if let f = try? await pruefeGrenzfall(position: grenzfall, db: db) {
                    logge("Jurist", an: "Orchestrator", "Nicht umlagefähig: \(f.bezeichnung)", typ: .antwort)
                    juristFindings.append(f)
                } else {
                    logge("Jurist", an: "Orchestrator", "Umlagefähig oder unklar — kein Finding.", typ: .antwort)
                }
            }
            if !grenzfaelle.isEmpty {
                auditEntries.append(APIAuditEntry(
                    agent: "Jurist", zweck: "Grenzfall-Bewertung",
                    datenGesendet: "\(grenzfaelle.count) Kostenposition(en) klassifiziert",
                    anonymisiert: true
                ))
            }
            abgeschlosseneSchritte = 5

            // ── PHASE 6: Challenger (Debatte) ──
            aktuellePhase = .debatte
            var alleFindings = mathFindings + legalFindings + juristFindings

            logge("Orchestrator", an: "Challenger", "Prüfe \(alleFindings.count) Findings kritisch.", typ: .delegation)

            // Korrektur 10: Challenger failt graceful
            let challengeResults: [ChallengeResult]
            do {
                challengeResults = try await challengeFindings(findings: alleFindings, anonOcrText: anonymizedOCR)
                auditEntries.append(APIAuditEntry(
                    agent: "Challenger", zweck: "Kritische Findings-Prüfung",
                    datenGesendet: "\(alleFindings.count) Findings + OCR",
                    anonymisiert: true
                ))
            } catch {
                logge("Orchestrator", an: "Alle", "Challenger nicht erreichbar — alle Findings behalten.", typ: .korrektur)
                challengeResults = []
            }

            // Korrektur 3: Guardrail — Code-Findings nicht entfernen
            for result in challengeResults {
                guard let idx = alleFindings.firstIndex(where: { $0.id == result.findingId }) else { continue }
                let finding = alleFindings[idx]

                if result.empfehlung == "entfernen" {
                    if finding.quelle == .code {
                        logge("Orchestrator", an: "Challenger",
                              "Abgelehnt: Code-basierte Findings können nicht entfernt werden. Herabstufung möglich.",
                              typ: .challenge)
                        alleFindings[idx] = finding.withSchwere(.warnung)
                    } else {
                        logge("Challenger", an: "Orchestrator",
                              "Finding \(result.findingId): ENTFERNT — \(result.begruendung)",
                              typ: .challenge)
                        alleFindings.remove(at: idx)
                    }
                } else if result.empfehlung == "herabstufen" {
                    logge("Challenger", an: "Orchestrator",
                          "Finding \(result.findingId): Herabgestuft — \(result.begruendung)",
                          typ: .challenge)
                    alleFindings[idx] = finding.withSchwere(.warnung)
                } else {
                    logge("Challenger", an: "Orchestrator",
                          "Finding \(result.findingId): Bestätigt.",
                          typ: .freigabe)
                }
            }
            abgeschlosseneSchritte = 6
            // Korrektur 8: KEINE Renummerierung hier — IDs bleiben stabil.

            // ── PHASE 7: Berichterstatter ──
            aktuellePhase = .bericht
            logge("Orchestrator", an: "Berichterstatter", "Formuliere den Prüfbericht. \(alleFindings.count) Findings.", typ: .delegation)
            let berichtErgebnis = try await erstelleBericht(
                abrechnung: abrechnung,
                findings: alleFindings,
                mietobjekt: mietobjekt
            )
            var berichtTextAnon = berichtErgebnis.berichtText

            // v4: Pro-Finding-Details (erklaerung / rechtsgrundlage /
            // handlungsempfehlung) in die Findings mergen. Wenn der LLM
            // keine Details geliefert hat, bleibt das Finding unverändert.
            alleFindings = alleFindings.map { f in
                guard let d = berichtErgebnis.details[f.id] else { return f }
                return f.withErklaerungen(
                    erklaerung: d.erklaerung,
                    rechtsgrundlage: d.rechtsgrundlage,
                    handlungsempfehlung: d.handlungsempfehlung
                )
            }

            logge("Berichterstatter", an: "Orchestrator", "Bericht formuliert.", typ: .antwort)
            auditEntries.append(APIAuditEntry(
                agent: "Berichterstatter", zweck: "Prüfbericht-Formulierung",
                datenGesendet: "\(alleFindings.count) Findings + Eckdaten",
                anonymisiert: true
            ))
            abgeschlosseneSchritte = 7

            // ── PHASE 8: Quality Review ──
            aktuellePhase = .review
            logge("Orchestrator", an: "Quality-Reviewer", "Prüfe den Bericht auf Fakten-Treue.", typ: .delegation)

            // Korrektur 10: Quality failt graceful
            let qualityResult: QualityResult
            do {
                qualityResult = try await reviewBericht(berichtText: berichtTextAnon, findings: alleFindings)
                auditEntries.append(APIAuditEntry(
                    agent: "Quality-Reviewer", zweck: "Bericht-Faktentreue",
                    datenGesendet: "Bericht (\(berichtTextAnon.count) Zeichen) + Findings",
                    anonymisiert: true
                ))
            } catch {
                logge("Orchestrator", an: "Alle", "Quality-Review nicht erreichbar — Bericht wird übernommen.", typ: .korrektur)
                qualityResult = QualityResult(istKorrekt: true, korrekturanweisungen: "")
            }

            if !qualityResult.istKorrekt {
                logge("Quality-Reviewer", an: "Berichterstatter",
                      "Korrekturen nötig: \(qualityResult.korrekturanweisungen)", typ: .challenge)
                if let ueberarbeitet = try? await ueberarbeiteBericht(
                    originalBericht: berichtTextAnon,
                    korrekturanweisungen: qualityResult.korrekturanweisungen,
                    findings: alleFindings
                ) {
                    berichtTextAnon = ueberarbeitet
                    logge("Berichterstatter", an: "Orchestrator", "Bericht überarbeitet.", typ: .korrektur)
                }
            } else {
                logge("Quality-Reviewer", an: "Orchestrator", "Bericht ist faktengetreu und sachlich.", typ: .freigabe)
            }
            abgeschlosseneSchritte = 8

            // De-anonymisieren des finalen Bericht-Texts
            let berichtText = AnonymizationService.deanonymize(berichtTextAnon, mapping: anon.mapping)

            // ── PHASE 9: Audit ──
            aktuellePhase = .audit
            logge("Orchestrator", an: "Audit", "Finale Prüfung aller Findings und des Berichts.", typ: .delegation)

            // Korrektur 10: Audit failt graceful
            let auditResult: AuditResult
            do {
                auditResult = try await auditAlles(
                    anonOcrText: anonymizedOCR,
                    findings: alleFindings,
                    berichtText: berichtTextAnon
                )
                auditEntries.append(APIAuditEntry(
                    agent: "Audit", zweck: "Finale Freigabe",
                    datenGesendet: "Bericht + Findings + OCR",
                    anonymisiert: true
                ))
            } catch {
                logge("Orchestrator", an: "Alle", "Audit nicht erreichbar — Freigabe ohne Audit.", typ: .korrektur)
                auditResult = AuditResult(freigabe: true, gesamtBewertung: "Audit übersprungen", findingsZuEntfernen: [])
            }

            // Audit-Ergebnis anwenden — Findings zu entfernen
            for zuEntfernen in auditResult.findingsZuEntfernen {
                if let idx = alleFindings.firstIndex(where: { $0.id == zuEntfernen }) {
                    if alleFindings[idx].quelle == .code {
                        logge("Orchestrator", an: "Audit",
                              "Abgelehnt: Code-Finding \(zuEntfernen) kann nicht entfernt werden.",
                              typ: .challenge)
                    } else {
                        logge("Audit", an: "Orchestrator", "Entferne: \(zuEntfernen)", typ: .challenge)
                        alleFindings.remove(at: idx)
                    }
                }
            }
            logge("Audit", an: "Orchestrator", auditResult.gesamtBewertung,
                  typ: auditResult.freigabe ? .freigabe : .challenge)
            abgeschlosseneSchritte = 9

            // ── Trust-Scores berechnen (Korrektur 7) ──
            var trustScores: [String: TrustScore] = [:]
            for finding in alleFindings {
                var score = TrustScore()
                score.strukturValid = v1valid
                score.crossCheckValid = v2valid
                score.quelltreuValid = validierung.istKorrekt
                let challenge = challengeResults.first(where: { $0.findingId == finding.id })
                score.debatteBestaetigt = challenge.map { $0.empfehlung == "behalten" || $0.bestaetige } ?? true
                score.auditBestaetigt = auditResult.freigabe && !auditResult.findingsZuEntfernen.contains(finding.id)
                trustScores[finding.id] = score
            }

            // ── Korrektur 8: EINE Renumerierung am Ende + TrustScore-Remapping ──
            let originalIds = alleFindings.map { $0.id }
            let finalFindings = alleFindings.enumerated().map { i, f in
                f.withId("F\(String(format: "%03d", i + 1))")
            }
            var mappedScores: [String: TrustScore] = [:]
            for (i, neueId) in finalFindings.map(\.id).enumerated() {
                if let score = trustScores[originalIds[i]] {
                    mappedScores[neueId] = score
                }
            }

            // ── Pruefbericht zusammenbauen ──
            let ersparnis = finalFindings
                .filter { $0.differenz > 0 }
                .reduce(Decimal(0)) { $0 + $1.differenz }

            let result = Pruefbericht(
                abrechnungId: "NK-\(Calendar.current.component(.year, from: Date()))-\(UUID().uuidString.prefix(4))",
                pruefDatum: Date(),
                abrechnung: abrechnung,
                findings: finalFindings,
                berichtText: berichtText,
                ersparnisGesamt: ersparnis,
                trustScores: mappedScores
            )

            self.bericht = result
            aktuellePhase = .fertig
            status = .finished

        } catch {
            fehlerMeldung = error.localizedDescription
            status = .failed
        }
    }

    func zurueckSetzen() {
        status = .idle
        aktuellePhase = nil
        abgeschlosseneSchritte = 0
        bericht = nil
        fehlerMeldung = nil
        agentenLog = []
        auditEntries = []
    }

    // MARK: - Logging Helper

    private func logge(_ von: String, an: String, _ nachricht: String, typ: AgentenNachricht.NachrichtTyp) {
        agentenLog.append(AgentenNachricht(von: von, an: an, nachricht: nachricht, typ: typ))
    }

    // MARK: - Agent Calls

    private func parseAbrechnung(ocrText: String) async throws -> Abrechnung {
        let userMessage = """
        Extrahiere die Daten aus folgender Nebenkostenabrechnung.

        OCR-TEXT:
        \(ocrText)

        Antworte NUR mit einem JSON-Objekt mit folgenden Feldern:
        {
          "meta": {
            "vermieter": { "name": "...", "adresse": "..." },
            "objekt": { "adresse": "...", "gesamtflaeche_qm": 0.0, "anzahl_einheiten": 0, "baujahr": null },
            "zeitraum": { "von": "YYYY-MM-DD", "bis": "YYYY-MM-DD" },
            "mieter_einheit": { "bezeichnung": "...", "flaeche_qm": 0.0, "personen": null },
            "vorauszahlungen_gesamt": 0.0,
            "nachzahlung_oder_guthaben": 0.0,
            "typ": "nachzahlung"
          },
          "kostenpositionen": [
            {
              "id": 1,
              "bezeichnung_original": "exakter Text aus Dokument",
              "kostenart_normalisiert": "grundsteuer",
              "gesamtkosten": 0.0,
              "verteilerschluessel": "wohnflaeche",
              "mieter_anteil": 0.0,
              "confidence": "high",
              "notiz": null
            }
          ],
          "summe_mieter_anteile": 0.0,
          "confidence_gesamt": "high",
          "warnungen": []
        }

        Erlaubte Werte:
        - typ: "nachzahlung" oder "guthaben"
        - verteilerschluessel: "wohnflaeche" | "personenzahl" | "einheiten" | "verbrauch" | "miteigentumsanteil" | "unbekannt"
        - confidence / confidence_gesamt: "high" | "medium" | "low"
        - kostenart_normalisiert: grundsteuer, wasserversorgung, entwaesserung, heizung, warmwasser, aufzug, strassenreinigung, muellabfuhr, gebaeudereinigung, gartenpflege, beleuchtung, schornsteinfeger, versicherung, hauswart, antenne, waeschepflege, sonstige, verwaltung, reparatur — oder null

        Antworte NUR mit dem JSON.
        """
        return try await AgentService.callJSON(
            systemPrompt: AgentPrompts.parserSystem,
            userMessage: userMessage,
            maxTokens: 4096,
            type: Abrechnung.self
        )
    }

    private func parseAbrechnungMitKorrektur(
        ocrText: String,
        korrekturhinweise: String
    ) async throws -> Abrechnung {
        let userMessage = """
        Extrahiere die Daten aus folgender Nebenkostenabrechnung erneut.

        OCR-TEXT:
        \(ocrText)

        KORREKTUREN AUS VALIDIERUNG (bitte beheben):
        \(korrekturhinweise)

        Verwende dasselbe JSON-Schema wie bisher. Antworte NUR mit dem JSON.
        """
        return try await AgentService.callJSON(
            systemPrompt: AgentPrompts.parserSystem,
            userMessage: userMessage,
            maxTokens: 4096,
            type: Abrechnung.self
        )
    }

    private func validiereExtraktion(
        abrechnung: Abrechnung,
        anonOcrText: String
    ) async throws -> ValidierungsErgebnis {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let jsonData = (try? encoder.encode(abrechnung)) ?? Data()
        let jsonStr = String(data: jsonData, encoding: .utf8) ?? "{}"

        let userMessage = """
        OCR-TEXT:
        \(anonOcrText)

        EXTRAHIERTES JSON:
        \(jsonStr)

        Prüfe die Extraktion. Antworte NUR mit dem JSON.
        """

        let antwort = try await AgentService.call(
            systemPrompt: AgentPrompts.validatorSystem,
            userMessage: userMessage,
            maxTokens: 2048
        )

        let cleaned = antwort
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ValidierungsErgebnis(istKorrekt: true, fehlerDetails: "", bewertung: "Nicht parsbar")
        }

        let istKorrekt = (json["ist_korrekt"] as? Bool) ?? true
        let bewertung = (json["bewertung"] as? String) ?? ""
        var fehlerDetails = ""
        if let fehler = json["fehler"] as? [[String: Any]] {
            let beschreibungen = fehler.compactMap { $0["korrektur"] as? String }
            fehlerDetails = beschreibungen.joined(separator: ". ")
        }
        if let fehlend = json["fehlende_posten"] as? [String], !fehlend.isEmpty {
            fehlerDetails += fehlerDetails.isEmpty ? "" : " "
            fehlerDetails += "Fehlende Posten: " + fehlend.joined(separator: ", ")
        }

        return ValidierungsErgebnis(
            istKorrekt: istKorrekt,
            fehlerDetails: fehlerDetails,
            bewertung: bewertung
        )
    }

    private func pruefeGrenzfall(
        position: Kostenposition,
        db: [LegalDBService.LegalEntry]
    ) async throws -> Finding? {
        let dbExcerpt = db.prefix(8).map { entry in
            "- \(entry.kostenart): \(entry.umlagefaehig ? "umlagefähig" : "NICHT umlagefähig") (\(entry.rechtsgrundlage))"
        }.joined(separator: "\n")

        let userMessage = """
        Bewerte folgende Kostenposition:

        Bezeichnung: \(position.bezeichnungOriginal)
        Gesamtkosten: \(position.gesamtkosten)
        Mieteranteil: \(position.mieterAnteil)
        Verteilerschlüssel: \(position.verteilerschluessel.rawValue)

        RECHTSDATENBANK (Auszug):
        \(dbExcerpt)

        Antworte NUR mit dem JSON.
        """

        let antwort = try await AgentService.call(
            systemPrompt: AgentPrompts.juristSystem,
            userMessage: userMessage,
            maxTokens: 1024
        )

        guard let data = antwort
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        guard let umlagefaehig = json["umlagefaehig"] as? Bool, umlagefaehig == false else {
            return nil
        }

        let konfidenzStr = (json["konfidenz"] as? String) ?? "unsicher"
        let konfidenz: Konfidenz = {
            switch konfidenzStr {
            case "sicher":         return .sicher
            case "wahrscheinlich": return .wahrscheinlich
            default:               return .unsicher
            }
        }()

        return Finding(
            id: "J\(String(format: "%03d", position.id))",
            typ: .grenzfall,
            schwere: .warnung,
            konfidenz: konfidenz,
            quelle: .juristAgent,
            positionId: position.id,
            bezeichnung: position.bezeichnungOriginal,
            beschreibung: (json["begruendung"] as? String) ?? "Grenzfall durch KI-Jurist bewertet.",
            betragAbrechnung: position.mieterAnteil,
            betragKorrekt: 0,
            differenz: position.mieterAnteil,
            rechtsgrundlage: json["rechtsgrundlage"] as? String,
            rechtsgrundlageVerifiziert: (json["rechtsgrundlage_verifiziert"] as? Bool) ?? false
        )
    }

    private func challengeFindings(
        findings: [Finding],
        anonOcrText: String
    ) async throws -> [ChallengeResult] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let findingsData = (try? encoder.encode(findings)) ?? Data()
        let findingsStr = String(data: findingsData, encoding: .utf8) ?? "[]"

        let userMessage = """
        OCR-TEXT (zur Kontext-Prüfung):
        \(anonOcrText.prefix(2000))

        FINDINGS:
        \(findingsStr)

        Prüfe jedes Finding kritisch. Antworte NUR mit JSON-Array.
        """

        let antwort = try await AgentService.call(
            systemPrompt: AgentPrompts.challengerSystem,
            userMessage: userMessage,
            maxTokens: 3000
        )

        let cleaned = antwort
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }

        return array.compactMap { item in
            guard let id = item["finding_id"] as? String else { return nil }
            return ChallengeResult(
                findingId: id,
                bestaetige: (item["bestaetige"] as? Bool) ?? true,
                empfehlung: (item["empfehlung"] as? String) ?? "behalten",
                begruendung: (item["begruendung"] as? String) ?? ""
            )
        }
    }

    /// Ergebnis des Berichterstatters: Fließtext + pro-Finding-Details (v4).
    private struct BerichtResult {
        let berichtText: String
        /// findingId → (erklaerung, rechtsgrundlage, handlungsempfehlung).
        /// Fehlende Einträge sind nicht-fatal — die UI fällt dann auf
        /// generische Fallbacks zurück.
        let details: [String: (erklaerung: String?, rechtsgrundlage: String?, handlungsempfehlung: String?)]
    }

    private func erstelleBericht(
        abrechnung: Abrechnung,
        findings: [Finding],
        mietobjekt: Mietobjekt
    ) async throws -> BerichtResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let findingsData = (try? encoder.encode(findings)) ?? Data()
        let findingsStr = String(data: findingsData, encoding: .utf8) ?? "[]"

        let zeitraumDF = DateFormatter()
        zeitraumDF.dateFormat = "dd.MM.yyyy"
        zeitraumDF.locale = Locale(identifier: "de_DE")
        let zeitraumStr = "\(zeitraumDF.string(from: abrechnung.meta.zeitraum.von)) – \(zeitraumDF.string(from: abrechnung.meta.zeitraum.bis))"

        let flaecheNF = NumberFormatter()
        flaecheNF.numberStyle = .decimal
        flaecheNF.maximumFractionDigits = 2
        flaecheNF.locale = Locale(identifier: "de_DE")
        let flaecheStr = flaecheNF.string(from: mietobjekt.flaecheQm as NSDecimalNumber) ?? "—"

        let userMessage = """
        Erstelle einen Prüfbericht.

        Wohnung: \(mietobjekt.adresse), \(flaecheStr) m²
        Zeitraum: \(zeitraumStr)

        FINDINGS:
        \(findingsStr)

        Erstelle einen verständlichen Prüfbericht. Kurz und klar.
        Am Ende: Zusammenfassung mit Gesamtersparnis und empfohlenen nächsten Schritten.

        Antworte AUSSCHLIESSLICH als JSON mit den Feldern `bericht_text` und
        `finding_details` — wie im System-Prompt beschrieben.
        """

        let antwort = try await AgentService.call(
            systemPrompt: AgentPrompts.berichterstatterSystem,
            userMessage: userMessage,
            maxTokens: 3072
        )

        // Tolerantes JSON-Parsing: Code-Fences abstreifen, dann decodieren.
        let cleaned = antwort
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            // Fallback: ältere LLM-Antwort ohne JSON-Wrapping — Text 1:1 übernehmen.
            return BerichtResult(berichtText: antwort, details: [:])
        }

        func cleanString(_ raw: Any?) -> String? {
            guard let s = raw as? String else { return nil }
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        let berichtText = (json["bericht_text"] as? String) ?? antwort
        var details: [String: (String?, String?, String?)] = [:]
        if let liste = json["finding_details"] as? [[String: Any]] {
            for item in liste {
                guard let fid = item["finding_id"] as? String else { continue }
                details[fid] = (
                    cleanString(item["erklaerung"]),
                    cleanString(item["rechtsgrundlage"]),
                    cleanString(item["handlungsempfehlung"])
                )
            }
        }
        return BerichtResult(berichtText: berichtText, details: details)
    }

    private func reviewBericht(
        berichtText: String,
        findings: [Finding]
    ) async throws -> QualityResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let findingsStr = String(data: (try? encoder.encode(findings)) ?? Data(), encoding: .utf8) ?? "[]"

        let userMessage = """
        BERICHT:
        \(berichtText)

        FINDINGS:
        \(findingsStr)

        Prüfe den Bericht. Antworte NUR mit JSON.
        """

        let antwort = try await AgentService.call(
            systemPrompt: AgentPrompts.qualityReviewSystem,
            userMessage: userMessage,
            maxTokens: 1024
        )

        let cleaned = antwort
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return QualityResult(istKorrekt: true, korrekturanweisungen: "")
        }

        return QualityResult(
            istKorrekt: (json["ist_korrekt"] as? Bool) ?? true,
            korrekturanweisungen: (json["korrekturanweisungen"] as? String) ?? ""
        )
    }

    private func ueberarbeiteBericht(
        originalBericht: String,
        korrekturanweisungen: String,
        findings: [Finding]
    ) async throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let findingsStr = String(data: (try? encoder.encode(findings)) ?? Data(), encoding: .utf8) ?? "[]"

        let userMessage = """
        ORIGINAL-BERICHT:
        \(originalBericht)

        KORREKTUR-ANWEISUNGEN:
        \(korrekturanweisungen)

        FAKTEN (Findings):
        \(findingsStr)

        Schreibe den Bericht überarbeitet neu. Nur den Text, keine Erklärung.
        """

        return try await AgentService.call(
            systemPrompt: AgentPrompts.berichterstatterUeberarbeitenSystem,
            userMessage: userMessage,
            maxTokens: 2048
        )
    }

    private func auditAlles(
        anonOcrText: String,
        findings: [Finding],
        berichtText: String
    ) async throws -> AuditResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let findingsStr = String(data: (try? encoder.encode(findings)) ?? Data(), encoding: .utf8) ?? "[]"

        let userMessage = """
        OCR-TEXT (Auszug):
        \(anonOcrText.prefix(2000))

        FINDINGS:
        \(findingsStr)

        BERICHT:
        \(berichtText)

        Finale Audit-Prüfung. Antworte NUR mit JSON.
        """

        let antwort = try await AgentService.call(
            systemPrompt: AgentPrompts.auditSystem,
            userMessage: userMessage,
            maxTokens: 2048
        )

        let cleaned = antwort
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return AuditResult(freigabe: true, gesamtBewertung: "Audit nicht parsbar — Freigabe.", findingsZuEntfernen: [])
        }

        return AuditResult(
            freigabe: (json["freigabe"] as? Bool) ?? true,
            gesamtBewertung: (json["gesamt_bewertung"] as? String) ?? "",
            findingsZuEntfernen: (json["findings_zu_entfernen"] as? [String]) ?? []
        )
    }
}
