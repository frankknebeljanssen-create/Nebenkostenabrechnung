//
//  RechnungRow.swift
//  NebenkostenApp — UI/Components
//
//  Wiederverwendbare Rechnungs-Zeile fuer RechnungenView-Tab UND
//  die DokumenteRechnungenView-Kachel. Extraktion aus dem frueher
//  privaten `RechnungenView.rechnungZeile` — Spec-Variante B aus
//  docs/dokumente-rechnungen-kachel-bestandsanalyse.md.
//
//  Layout (Spec):
//
//    HStack {
//      [Thumbnail 44x44]      // nur wenn Dokument-Foto vorhanden
//      VStack(leading) {
//        Aussteller   (bodySemi)
//        Datum        (caption textSecondary)
//        Leistungszeitraum (caption textSecondary)
//      }
//      Spacer()
//      VStack(trailing) {
//        Betrag       (mono)
//        StatusPill   (ValidierungsStatus)
//      }
//    }
//
//  Thumbnail kommt aus dem verknuepften `GespeichertesDokument`
//  (Lookup ueber `dokument.rechnungId == rechnung.id`, wird vom
//  Call-Site durchgereicht). Ohne Dokument/Thumbnail rendert die
//  Row ohne Bild — kein leerer Platzhalter (Design-Entscheidung).
//

import SwiftUI
import UIKit

struct RechnungRow: View {
    let rechnung: Rechnung
    /// Optional verknuepftes Dokument — wenn vorhanden, wird dessen
    /// Thumbnail links gerendert. Call-Site macht den Lookup
    /// (`dokumente.first(where: { $0.rechnungId == rechnung.id })`)
    /// damit die Row keine `@Query`-Abhaengigkeit braucht.
    let dokument: GespeichertesDokument?

    var body: some View {
        HStack(spacing: 12) {
            if let bild = thumbnailBild {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(DesignTokens.separator, lineWidth: 0.5)
                    )
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(aussteller)
                    .appFont(AppFont.Rechnungen.issuer())
                    .foregroundStyle(DesignTokens.text)
                    .lineLimit(1)
                Text(Formatting.datum(rechnung.rechnungsdatum))
                    .appFont(AppFont.Rechnungen.datumPeriode())
                    .foregroundStyle(DesignTokens.textSecondary)
                if let zeitraum = leistungszeitraumText {
                    Text(zeitraum)
                        .appFont(AppFont.Rechnungen.datumPeriode())
                        .foregroundStyle(DesignTokens.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatting.euro(rechnung.betragBruttoEuro))
                    .appFont(AppFont.Rechnungen.betrag())
                    .foregroundStyle(DesignTokens.text)
                pill
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Anzeige-Werte

    private var aussteller: String {
        let trimmed = rechnung.lieferant.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Ohne Lieferant" : trimmed
    }

    /// Leistungszeitraum-Zeile: nur wenn `leistungVon` und
    /// `leistungBis` sinnvoll (verschieden + in realistischer
    /// Reichweite). Defaults aus dem Model (beide = `Date()`) fliegen
    /// raus — sonst steht auf jeder Rechnung ein nichtssagender
    /// „heute – heute"-Block.
    private var leistungszeitraumText: String? {
        let von = rechnung.leistungVon
        let bis = rechnung.leistungBis
        let kal = Calendar(identifier: .gregorian)
        // Gleich auf Datum-Genauigkeit? Dann nichts anzeigen —
        // ist der Model-Default, kein echter Zeitraum.
        if kal.isDate(von, inSameDayAs: bis) {
            return nil
        }
        return Formatting.periode(von, bis)
    }

    // MARK: - Pill

    @ViewBuilder
    private var pill: some View {
        let (text, style) = pillDaten
        StatusPill(text: text, style: style)
    }

    /// Mapping `ValidierungsStatus` → Pill.
    /// Spec-Variante aus dem Stufe-2-Brief:
    ///   - .validiert / .importiert → „Validiert" (ok, gruen)
    ///   - .manuell                  → „Manuell" (accent, blau)
    ///   - .aiVorschlag              → „KI-Vorschlag" (warn, gelb)
    ///
    /// `.importiert` faellt semantisch mit `.validiert` zusammen
    /// (beides berechnungstauglich, Seed-Daten).
    private var pillDaten: (String, StatusPill.Style) {
        switch rechnung.validierungsStatus {
        case .validiert, .importiert:
            return ("Validiert", .ok)
        case .manuell:
            return ("Manuell", .accent)
        case .aiVorschlag:
            return ("KI-Vorschlag", .warn)
        }
    }

    // MARK: - Thumbnail

    private var thumbnailBild: UIImage? {
        guard let dokument,
              !dokument.thumbnailPfad.isEmpty,
              let url = try? DokumentAblageService.absoluterPfad(
                fuer: dokument.thumbnailPfad
              ),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }
}
