//
//  ValidierungsView.swift
//  NebenkostenApp — UI/Validierung
//
//  Zeigt die drei Ebenen eines Dokuments strikt getrennt:
//    1. Rohdaten — OCR-Volltext (read-only, monospaced).
//    2. AI-Vorschlag — editierbares Formular, immer UNVALIDIERT.
//    3. Uebernehmen — Buttons zum Anlegen einer Rechnung oder zum
//       reinen Speichern des Dokuments.
//
//  Die Rechnungs-Übernahme-Logik (Button "Als Rechnung übernehmen")
//  wird in Task 1.2-C7 vervollständigt; hier in C6 steht zunächst
//  das Layout + OCR- und AI-Trigger.
//

import SwiftUI
import SwiftData

struct ValidierungsView: View {
    @Bindable var dokument: GespeichertesDokument

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ObjektWahl.self) private var objektWahl
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var rohdatenAufgeklappt = true
    @State private var aiAufgeklappt = true
    @State private var laeuftOCR = false
    @State private var laeuftAI = false
    @State private var fehler: String?
    @State private var zeigeUebernahme = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusHeader
                    rohdatenCard
                    aiCard
                    uebernahmeCard
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dokument validieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .alert(
                "Fehler",
                isPresented: .init(
                    get: { fehler != nil },
                    set: { if !$0 { fehler = nil } }
                ),
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(fehler ?? "") }
            )
            .sheet(isPresented: $zeigeUebernahme) {
                UebernahmeSheet(
                    dokument: dokument,
                    immobilie: aktiveImmobilie,
                    onFertig: { dismiss() }
                )
            }
        }
    }

    private var aktiveImmobilie: Immobilie? {
        if let id = objektWahl.aktiveID,
           let match = immobilien.first(where: { $0.id == id }) {
            return match
        }
        return immobilien.first
    }

    // MARK: - Status-Header

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dokument.dateiname)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            HStack(spacing: 10) {
                badge("1 Rohdaten", farbe: dokument.ocrVolltext != nil ? .green : .gray)
                badge("2 AI-Vorschlag", farbe: dokument.aiVorschlag != nil ? .orange : .gray)
                badge("3 Validiert", farbe: dokument.rechnungId != nil ? .green : .gray)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func badge(_ text: String, farbe: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(farbe).frame(width: 8, height: 8)
            Text(text).font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(farbe.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Ebene 1 Rohdaten

    private var rohdatenCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ebenenHeader(
                titel: "1 Rohdaten",
                untertitel: rohdatenUntertitel,
                aufgeklappt: $rohdatenAufgeklappt
            )

            if rohdatenAufgeklappt {
                Divider()
                if let text = dokument.ocrVolltext, !text.isEmpty {
                    if let conf = dokument.ocrConfidence {
                        konfidenzBadgeZeile(conf)
                    }
                    ScrollView(.horizontal) {
                        Text(text)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                    }
                    .frame(maxHeight: 200)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text("Noch kein OCR-Lauf durchgeführt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await starteOCR() }
                    } label: {
                        if laeuftOCR {
                            HStack {
                                ProgressView()
                                Text("OCR läuft …")
                            }
                        } else {
                            Label("OCR starten", systemImage: "doc.text.magnifyingglass")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(laeuftOCR)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var rohdatenUntertitel: String {
        if dokument.ocrVolltext == nil { return "Noch kein OCR" }
        let zeichen = dokument.ocrVolltext?.count ?? 0
        return "\(zeichen) Zeichen, Confidence "
            + String(format: "%.0f %%", (dokument.ocrConfidence ?? 0) * 100)
    }

    private func konfidenzBadgeZeile(_ conf: Double) -> some View {
        HStack {
            Image(systemName: iconFuerKonfidenz(conf))
                .foregroundStyle(farbeFuerKonfidenz(conf))
            Text(String(format: "OCR-Confidence %.0f %%", conf * 100))
                .font(.caption.weight(.medium))
            Spacer()
        }
    }

    // MARK: - Ebene 2 AI-Vorschlag

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ebenenHeader(
                titel: "2 AI-Vorschlag",
                untertitel: aiUntertitel,
                aufgeklappt: $aiAufgeklappt
            )

            if aiAufgeklappt {
                Divider()
                if let vorschlag = dokument.aiVorschlag {
                    vorschlagFormular(vorschlag)
                } else {
                    Text("Noch kein AI-Vorschlag erzeugt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if dokument.ocrVolltext == nil {
                        Text("OCR muss zuerst laufen.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Button {
                        Task { await starteAI() }
                    } label: {
                        if laeuftAI {
                            HStack { ProgressView(); Text("Extraktion läuft …") }
                        } else {
                            Label("AI-Extraktion starten", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(laeuftAI || dokument.ocrVolltext == nil)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var aiUntertitel: String {
        if dokument.aiVorschlag == nil { return "Unvalidiert, noch offen" }
        return "Unvalidiert — bitte prüfen und bestätigen"
    }

    private func vorschlagFormular(_ v: AIVorschlag) -> some View {
        let konfidenzen = AIExtraktionService.konfidenzen(aus: v)
        return VStack(alignment: .leading, spacing: 8) {
            feldZeile("Versorger",   wert: v.versorger ?? "—",
                      konfidenz: konfidenzen["versorger"])
            feldZeile("Rechnungs-Nr", wert: v.rechnungsNr ?? "—",
                      konfidenz: konfidenzen["rechnungsNr"])
            feldZeile("Datum",        wert: v.dokumentDatum.map(formatiereDatum) ?? "—",
                      konfidenz: konfidenzen["dokumentDatum"])
            feldZeile("Betrag brutto",wert: v.betragBrutto.map(formatiereBetrag) ?? "—",
                      konfidenz: konfidenzen["betragBrutto"])
            feldZeile("MwSt %",       wert: v.mwstSatz.map { "\($0)" } ?? "—",
                      konfidenz: konfidenzen["mwstSatz"])
            feldZeile("Leistung von", wert: v.leistungszeitraumStart.map(formatiereDatum) ?? "—",
                      konfidenz: konfidenzen["leistungszeitraumStart"])
            feldZeile("Leistung bis", wert: v.leistungszeitraumEnde.map(formatiereDatum) ?? "—",
                      konfidenz: konfidenzen["leistungszeitraumEnde"])
            feldZeile("Kostenart-Vorschlag",
                      wert: v.kostenartVorschlag ?? "—",
                      konfidenz: konfidenzen["kostenartVorschlag"])
        }
    }

    private func feldZeile(_ label: String, wert: String, konfidenz: Double?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(wert)
                    .font(.callout)
            }
            Spacer()
            if let k = konfidenz {
                Label(
                    String(format: "%.0f %%", k * 100),
                    systemImage: iconFuerKonfidenz(k)
                )
                .labelStyle(.titleAndIcon)
                .font(.caption2.weight(.medium))
                .foregroundStyle(farbeFuerKonfidenz(k))
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Ebene 3 Übernehmen

    private var uebernahmeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.tint)
                Text("3 Validiert & übernehmen")
                    .font(.callout.weight(.semibold))
                Spacer()
            }
            Divider()
            if dokument.rechnungId != nil {
                Label("Bereits als Rechnung übernommen.",
                      systemImage: "checkmark.seal.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            } else {
                Text("Die App schlägt die Felder oben vor — nur durch Ihre Bestätigung werden sie zu einer Rechnung.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    zeigeUebernahme = true
                } label: {
                    Label("Als Rechnung übernehmen",
                          systemImage: "doc.text.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(dokument.aiVorschlag == nil)
                Button {
                    dismiss()
                } label: {
                    Label("Nur als Dokument speichern",
                          systemImage: "tray.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Helper

    private func ebenenHeader(
        titel: String,
        untertitel: String,
        aufgeklappt: Binding<Bool>
    ) -> some View {
        Button {
            withAnimation { aufgeklappt.wrappedValue.toggle() }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel).font(.callout.weight(.semibold))
                    Text(untertitel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: aufgeklappt.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func iconFuerKonfidenz(_ k: Double) -> String {
        if k >= 0.8 { return "checkmark.circle.fill" }
        if k >= 0.6 { return "questionmark.circle.fill" }
        return "exclamationmark.circle.fill"
    }

    private func farbeFuerKonfidenz(_ k: Double) -> Color {
        if k >= 0.8 { return .green }
        if k >= 0.6 { return .orange }
        return .red
    }

    private func formatiereDatum(_ d: Date) -> String {
        d.formatted(date: .numeric, time: .omitted)
    }

    private func formatiereBetrag(_ d: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "EUR"
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: NSDecimalNumber(decimal: d)) ?? "\(d) €"
    }

    // MARK: - Actions

    private func starteOCR() async {
        laeuftOCR = true
        defer { laeuftOCR = false }
        do {
            let ergebnis = try await OCRService.extrahiereText(aus: dokument)
            dokument.ocrVolltext = ergebnis.volltext
            dokument.ocrConfidence = ergebnis.confidence
            dokument.ocrDurchgefuehrtAm = Date()
            try? modelContext.save()
        } catch {
            fehler = error.localizedDescription
        }
    }

    private func starteAI() async {
        laeuftAI = true
        defer { laeuftAI = false }
        guard let text = dokument.ocrVolltext else {
            fehler = "OCR-Text fehlt."
            return
        }
        do {
            let json = try await AIExtraktionService.extrahiere(
                ocrText: text,
                typ: dokument.dokumenttyp,
                versorgerHint: dokument.versorger
            )
            let entity = dokument.aiVorschlag ?? AIVorschlag()
            AIExtraktionService.uebertrage(json, nach: entity)
            entity.dokument = dokument
            dokument.aiVorschlag = entity
            dokument.aiDurchgefuehrtAm = Date()
            modelContext.insert(entity)
            try? modelContext.save()
        } catch {
            fehler = error.localizedDescription
        }
    }
}
