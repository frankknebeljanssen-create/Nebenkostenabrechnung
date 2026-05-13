import SwiftUI

// MARK: - FindingCard
//
// Klassische, voll-aufgeklappte Ergebnis-Karte für die History-Detailansicht
// (PruefberichtDetailView). Die neue, aufklappbare v4-Karte für BerichtView
// liegt direkt in BerichtView.swift (ErgebnisCard).

struct FindingCard: View {
    let finding: Finding
    var trustScore: TrustScore? = nil

    @State private var zeigeTrustDetail = false

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(akzentFarbe)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: schwereIcon)
                        .foregroundStyle(akzentFarbe)
                    Text(finding.bezeichnung)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    KonfidenzBadge(konfidenz: finding.konfidenz)
                    if let score = trustScore {
                        Button {
                            zeigeTrustDetail = true
                        } label: {
                            TrustBadge(score: score)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(finding.beschreibung)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if finding.differenz != 0 {
                    Text(formatGeld(abs(finding.differenz)))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(akzentFarbe)
                }

                if let rg = finding.rechtsgrundlage, !rg.isEmpty {
                    Label(rg, systemImage: "books.vertical")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
        .accessibilityElement(children: .combine)
        .sheet(isPresented: $zeigeTrustDetail) {
            if let score = trustScore {
                TrustScoreDetailSheet(score: score)
                    .presentationDetents([.medium])
            }
        }
    }

    private var akzentFarbe: Color {
        switch finding.schwere {
        case .fehler:  return NKDesign.errorColor
        case .warnung: return NKDesign.warningColor
        case .info:    return .gray
        }
    }

    private var schwereIcon: String {
        switch finding.schwere {
        case .fehler:  return "exclamationmark.octagon.fill"
        case .warnung: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }
}

// MARK: - Konfidenz-Badge

struct KonfidenzBadge: View {
    let konfidenz: Konfidenz

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(farbe)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(farbe.opacity(0.15))
            .clipShape(Capsule())
            .accessibilityLabel("Konfidenz: \(text)")
    }

    private var text: String {
        switch konfidenz {
        case .sicher:         return "sicher"
        case .wahrscheinlich: return "wahrscheinlich"
        case .unsicher:       return "unsicher"
        }
    }

    private var farbe: Color {
        switch konfidenz {
        case .sicher:         return NKDesign.successColor
        case .wahrscheinlich: return NKDesign.warningColor
        case .unsicher:       return .gray
        }
    }
}

// MARK: - TrustBadge + Detail-Sheet
//
// UI-Sprache: „Vertrauenswert" statt „Trust-Score".
// Variablen- und Modellnamen bleiben aus Konsistenz-Gründen englisch.

struct TrustBadge: View {
    let score: TrustScore

    var body: some View {
        Text("Vertrauenswert \(score.prozent) %")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(farbe)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(farbe.opacity(0.15))
            .clipShape(Capsule())
            .accessibilityLabel("Vertrauenswert: \(score.prozent) Prozent — \(score.label)")
    }

    private var farbe: Color {
        switch score.prozent {
        case 80...100: return NKDesign.successColor
        case 60..<80:  return NKDesign.accentColor
        case 40..<60:  return NKDesign.warningColor
        default:       return NKDesign.errorColor
        }
    }
}

struct TrustScoreDetailSheet: View {
    let score: TrustScore

    private struct Layer: Identifiable {
        let id = UUID()
        let label: String
        let beschreibung: String
        let bestanden: Bool
    }

    private var layers: [Layer] {
        [
            Layer(label: "V1 — Struktur",
                  beschreibung: "JSON-Schema vollständig und plausibel.",
                  bestanden: score.strukturValid),
            Layer(label: "V2 — Cross-Check",
                  beschreibung: "Summe der Einzelposten stimmt mit Gesamtsumme.",
                  bestanden: score.crossCheckValid),
            Layer(label: "V3 — Quelltreue",
                  beschreibung: "Validator-Agent bestätigt: Daten stehen so im OCR-Text.",
                  bestanden: score.quelltreuValid),
            Layer(label: "V4 — Debatte",
                  beschreibung: "Challenger-Agent hat nicht widersprochen.",
                  bestanden: score.debatteBestaetigt),
            Layer(label: "V5 — Audit",
                  beschreibung: "Audit-Agent hat das Ergebnis freigegeben.",
                  bestanden: score.auditBestaetigt)
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(score.label)
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Text("\(score.prozent) %")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(NKDesign.accentColor)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    ForEach(layers) { layer in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: layer.bestanden ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(layer.bestanden ? NKDesign.successColor : .secondary)
                                .imageScale(.large)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(layer.label)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(layer.beschreibung)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Validierungs-Schichten")
                } footer: {
                    Text("Jede Schicht zählt 20 % des Vertrauenswerts.")
                }
            }
            .navigationTitle("Vertrauenswert")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Geld-Formatierung (global)

func formatGeld(_ wert: Decimal) -> String {
    let nf = NumberFormatter()
    nf.numberStyle = .currency
    nf.currencyCode = "EUR"
    nf.locale = Locale(identifier: "de_DE")
    return nf.string(from: wert as NSDecimalNumber) ?? "—"
}
