import SwiftUI
import UIKit

struct PruefberichtDetailView: View {
    let abrechnung: GespeicherteAbrechnung
    let mietobjekt: Mietobjekt

    private let disclaimerText = """
    Diese Prüfung ersetzt keine Rechtsberatung. Bei Unstimmigkeiten empfehlen wir die Beratung durch einen Mieterverein oder Rechtsanwalt.
    """

    private var bericht: Pruefbericht? {
        abrechnung.ladeBericht()
    }

    var body: some View {
        Group {
            if let bericht {
                inhalt(bericht: bericht)
            } else {
                fehlerAnsicht
            }
        }
        .navigationTitle("Prüfung vom \(abrechnung.pruefDatumFormatiert)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Inhalt

    private func inhalt(bericht: Pruefbericht) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                kopfBox(bericht: bericht)

                if let bild = originalBild {
                    sectionTitle("Originalfoto")
                    Image(uiImage: bild)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 240)
                        .background(Color.gray.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
                        .accessibilityLabel("Originalfoto der Abrechnung")
                }

                if !bericht.findings.isEmpty {
                    sectionTitle("Ergebnisse")
                    VStack(spacing: 12) {
                        ForEach(sortiereFindings(bericht.findings)) { finding in
                            FindingCard(finding: finding)
                        }
                    }
                }

                if !bericht.berichtText.isEmpty {
                    sectionTitle("Bericht")
                    Text(bericht.berichtText)
                        .font(.system(size: 17))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                aktionsButtons(bericht: bericht)

                Text(disclaimerText)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Kopf-Box

    private func kopfBox(bericht: Pruefbericht) -> some View {
        let positiv = bericht.ersparnisGesamt > 0
        let fehler = bericht.findings.filter { $0.schwere == .fehler }.count
        let warnungen = bericht.findings.filter { $0.schwere == .warnung }.count

        return VStack(alignment: .leading, spacing: 8) {
            Text(positiv ? "Mögliche Ersparnis" : "Keine Auffälligkeiten")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(positiv ? NKDesign.successColor : .secondary)

            Text(formatGeld(bericht.ersparnisGesamt))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(positiv ? NKDesign.successColor : .primary)

            HStack(spacing: 16) {
                Label("\(fehler) Fehler", systemImage: "exclamationmark.octagon.fill")
                    .foregroundStyle(NKDesign.errorColor)
                Label("\(warnungen) \(warnungen == 1 ? "Warnung" : "Warnungen")", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(NKDesign.warningColor)
            }
            .font(.system(size: 15, weight: .medium))

            Text(mietobjekt.adresse)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .background((positiv ? NKDesign.successColor : Color.gray).opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
    }

    // MARK: - Aktionen

    private func aktionsButtons(bericht: Pruefbericht) -> some View {
        let widerspruchMoeglich = bericht.findings.contains { $0.differenz > 0 }
        return VStack(spacing: 12) {
            if widerspruchMoeglich {
                NavigationLink {
                    WiderspruchView(bericht: bericht, mietobjekt: mietobjekt)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Widerspruch senden")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: NKDesign.bigButtonHeight)
                    .background(NKDesign.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
                }
                .accessibilityLabel("Widerspruch senden")
            }

            NavigationLink {
                PreCaptureView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Erneut prüfen")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: NKDesign.bigButtonHeight)
                .background(Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
            }
        }
    }

    // MARK: - Fehler-Ansicht

    private var fehlerAnsicht: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(NKDesign.warningColor)
            Text("Der Bericht konnte nicht geladen werden.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding()
    }

    // MARK: - Helpers

    private var originalBild: UIImage? {
        guard let data = abrechnung.originalBildData else { return nil }
        return UIImage(data: data)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sortiereFindings(_ findings: [Finding]) -> [Finding] {
        findings.sorted { sortKey($0.schwere) < sortKey($1.schwere) }
    }

    private func sortKey(_ schwere: Schwere) -> Int {
        switch schwere {
        case .fehler:  return 0
        case .warnung: return 1
        case .info:    return 2
        }
    }
}
