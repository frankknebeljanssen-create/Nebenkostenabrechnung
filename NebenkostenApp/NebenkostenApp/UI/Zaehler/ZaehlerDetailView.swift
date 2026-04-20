//
//  ZaehlerDetailView.swift
//  NebenkostenApp — UI/Zaehler
//

import SwiftUI
import SwiftData

struct ZaehlerDetailView: View {
    @Bindable var zaehler: Zaehler
    @State private var zeigeErfassen = false
    @State private var zeigeScan = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                staendeSektion
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(kurzerTitel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    zeigeScan = true
                } label: {
                    Label("Zählerstand fotografieren",
                          systemImage: "camera.viewfinder")
                }
            }
        }
        .sheet(isPresented: $zeigeErfassen) {
            ZaehlerstandErfassenView(zaehler: zaehler)
        }
        .sheet(isPresented: $zeigeScan) {
            ScanEntryView(autoZaehlerstand: sortierteStaende.first) { _ in }
        }
    }

    // MARK: - Abgeleitete Werte

    private var sortierteStaende: [Zaehlerstand] {
        (zaehler.staende ?? []).sorted { $0.ablesedatum > $1.ablesedatum }
    }

    private var kurzerTitel: String {
        mediumBezeichnung(zaehler.medium)
    }

    // MARK: - Sektionen

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: icon(fuer: zaehler.medium))
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(kurzerTitel)
                        .font(.title2.bold())
                    Text(typBezeichnung(zaehler.typ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if !zaehler.seriennummer.isEmpty {
                    zeile(label: "Seriennummer", wert: zaehler.seriennummer)
                }
                if !zaehler.bezeichnung.isEmpty {
                    zeile(label: "Kennzeichen", wert: zaehler.bezeichnung)
                }
                zeile(label: "Einheit", wert: zaehler.einheit.isEmpty ? "—" : zaehler.einheit)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var staendeSektion: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Zählerstände")
                    .font(.title3.bold())
                Spacer()
                if !sortierteStaende.isEmpty {
                    Text("\(sortierteStaende.count)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                }
            }

            if sortierteStaende.isEmpty {
                leerzustand
            } else {
                VStack(spacing: 10) {
                    ForEach(sortierteStaende) { stand in
                        standZeile(stand)
                    }
                }
                Button {
                    zeigeErfassen = true
                } label: {
                    Label("Neuer Stand", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var leerzustand: some View {
        VStack(spacing: 16) {
            Image(systemName: "gauge.with.dots.needle.0percent")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Noch kein Stand erfasst")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                zeigeErfassen = true
            } label: {
                Label("Ersten Stand erfassen", systemImage: "plus.circle.fill")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func standZeile(_ s: Zaehlerstand) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(s.ablesedatum.formatted(date: .numeric, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                Text(s.quelle.anzeigeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(wertMitEinheit(s))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func zeile(label: String, wert: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(wert)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }

    // MARK: - Helfer

    private func wertMitEinheit(_ s: Zaehlerstand) -> String {
        let zahl = NSDecimalNumber(decimal: s.stand).stringValue
        return zaehler.einheit.isEmpty ? zahl : "\(zahl) \(zaehler.einheit)"
    }

    private func icon(fuer medium: Medium) -> String {
        switch medium {
        case .strom:                 return "bolt"
        case .warmwasser:            return "drop.halffull"
        case .kaltwasser:            return "drop"
        case .waermeenergie:         return "flame"
        case .gas:                   return "fuelpump"
        case .oel:                   return "drop.triangle"
        }
    }

    private func mediumBezeichnung(_ medium: Medium) -> String {
        switch medium {
        case .strom:         return "Strom"
        case .warmwasser:    return "Warmwasser"
        case .kaltwasser:    return "Kaltwasser"
        case .waermeenergie: return "Wärmemengenzähler"
        case .gas:           return "Gas"
        case .oel:           return "Öl"
        }
    }

    private func typBezeichnung(_ typ: Zaehlertyp) -> String {
        switch typ {
        case .haupt:    return "Hauptzähler"
        case .wohnung:  return "Wohnungszähler"
        case .zwischen: return "Zwischenzähler"
        }
    }
}
