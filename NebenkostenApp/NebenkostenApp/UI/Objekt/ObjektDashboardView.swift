//
//  ObjektDashboardView.swift
//  NebenkostenApp — UI/Objekt
//

import SwiftUI
import SwiftData

struct ObjektDashboardView: View {
    @Bindable var immobilie: Immobilie

    @Query(sort: \Immobilie.erstelltAm) private var alleImmobilien: [Immobilie]
    @Environment(ObjektWahl.self) private var objektWahl

    @State private var gewaehltePeriodeID: UUID?
    @State private var zeigeNeuesObjektSheet = false
    @State private var zeigeLimitAlert = false

    private static let maxObjekte = 4

    private let spalten = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                kopf
                periodePicker
                    .padding(.top, -16)
                ring
                kachelGrid
                wohneinheitenSektion
            }
            .padding(.top, 6)
            .padding(.bottom, 16)
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Objekt")
        .onAppear(perform: waehleDefaultPeriode)
        .sheet(isPresented: $zeigeNeuesObjektSheet) {
            NeuesObjektSheet { angelegt in
                objektWahl.setze(angelegt.id)
            }
        }
        .alert(
            "Objekt-Limit erreicht",
            isPresented: $zeigeLimitAlert,
            actions: { Button("OK", role: .cancel) {} },
            message: {
                Text("Im MVP können maximal \(Self.maxObjekte) Objekte angelegt werden. In Version 1.1 werden mehr Objekte möglich sein.")
            }
        )
    }

    // MARK: - Abgeleitete Werte

    private var perioden: [Abrechnungsperiode] {
        (immobilie.perioden ?? []).sorted(by: { $0.bis > $1.bis })
    }

    private var aktivePeriode: Abrechnungsperiode? {
        if let id = gewaehltePeriodeID, let treffer = perioden.first(where: { $0.id == id }) {
            return treffer
        }
        return defaultPeriode
    }

    /// Jüngste bereits abgeschlossene Periode (bis < heute). Ist meist die
    /// Periode, für die der User gerade abrechnen will — deren Daten liegen
    /// vollständig vor. Fallback: jüngste Periode überhaupt.
    private var defaultPeriode: Abrechnungsperiode? {
        let heute = Date()
        if let abgeschlossen = perioden.first(where: { $0.bis < heute }) {
            return abgeschlossen
        }
        return perioden.first
    }

    private var viewModel: ObjektDashboardViewModel {
        ObjektDashboardViewModel(immobilie: immobilie, aktivePeriode: aktivePeriode)
    }

    private func waehleDefaultPeriode() {
        if gewaehltePeriodeID == nil {
            gewaehltePeriodeID = defaultPeriode?.id
        }
    }

    // MARK: - Sektionen

    private var kopf: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(immobilie.adresse.isEmpty ? "Unbenanntes Objekt" : immobilie.adresse)
                    .font(.callout.weight(.semibold))
                if !immobilie.ort.isEmpty {
                    Text(immobilie.ort)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            objektWechselMenu
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var objektWechselMenu: some View {
        Menu {
            Section {
                ForEach(alleImmobilien) { objekt in
                    Button {
                        objektWahl.setze(objekt.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(objekt.adresse.isEmpty ? "Unbenanntes Objekt" : objekt.adresse)
                                if !objekt.ort.isEmpty {
                                    Text(objekt.ort).font(.caption)
                                }
                            }
                            Spacer()
                            if objekt.id == immobilie.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            Section {
                Button {
                    if alleImmobilien.count >= Self.maxObjekte {
                        zeigeLimitAlert = true
                    } else {
                        zeigeNeuesObjektSheet = true
                    }
                } label: {
                    Label("Neues Objekt anlegen…", systemImage: "plus")
                }
            }
        } label: {
            Image(systemName: "chevron.up.chevron.down")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Circle())
        }
        .accessibilityLabel("Objekt wechseln oder neu anlegen")
    }

    private var periodePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Abrechnungszeitraum")
                .font(.callout)

            if perioden.isEmpty {
                HStack {
                    Text("keine Periode")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Menu {
                    ForEach(perioden) { periode in
                        Button {
                            gewaehltePeriodeID = periode.id
                        } label: {
                            HStack {
                                Text(ObjektDashboardViewModel.formatiere(periode))
                                if periode.id == aktivePeriode?.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.periodeBezeichnung)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var ring: some View {
        let z = viewModel.zusammenfassung
        return CompletionBalken(
            erledigt: z.erfuellt,
            inArbeit: z.teilweise,
            offen: z.offen,
            headerText: viewModel.fortschrittsText,
            fussText: viewModel.bereitschaftsText,
            bereit: z.bereit
        )
        .padding(.top, -8)
        .padding(.bottom, 16)
    }

    private var kachelGrid: some View {
        LazyVGrid(columns: spalten, spacing: 12) {
            let m = viewModel.mieter
            NavigationLink(value: MieterListenZiel(immobilie: immobilie)) {
                StatusKachel(titel: "Mieter", symbol: "person.2", status: m.status,
                             erledigt: m.erledigt, inArbeit: m.inArbeit, offen: m.offen)
            }
            .buttonStyle(.plain)

            let z = viewModel.zaehler
            NavigationLink(value: ZaehlerUebersichtsZiel(immobilie: immobilie)) {
                StatusKachel(titel: "Zähler", symbol: "gauge", status: z.status,
                             erledigt: z.erledigt, inArbeit: z.inArbeit, offen: z.offen)
            }
            .buttonStyle(.plain)

            let r = viewModel.rechnungen
            NavigationLink(value: RechnungenListenZiel(immobilie: immobilie)) {
                StatusKachel(titel: "Rechnungen", symbol: "doc.text", status: r.status,
                             erledigt: r.erledigt, inArbeit: r.inArbeit, offen: r.offen)
            }
            .buttonStyle(.plain)

            let k = viewModel.kostenarten
            NavigationLink(value: KostenartenListenZiel(immobilie: immobilie)) {
                StatusKachel(titel: "Kostenarten", symbol: "list.bullet.rectangle", status: k.status,
                             erledigt: k.erledigt, inArbeit: k.inArbeit, offen: k.offen)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Wohneinheiten-Sektion

    private var wohneinheitenSektion: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wohneinheiten")
                .font(.title2.bold())
                .padding(.top, 8)

            ForEach(sortierteWohneinheiten) { einheit in
                NavigationLink(value: einheit) {
                    WohneinheitZeile(wohneinheit: einheit)
                }
                .buttonStyle(.plain)
            }

            if sortierteWohneinheiten.isEmpty {
                Text("Noch keine Wohneinheiten angelegt.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            }
        }
    }

    private var sortierteWohneinheiten: [Wohneinheit] {
        (immobilie.wohneinheiten ?? []).sorted { lhs, rhs in
            let rL = Self.sortierrang(lhs.bezeichnung)
            let rR = Self.sortierrang(rhs.bezeichnung)
            if rL != rR { return rL < rR }
            return lhs.bezeichnung.localizedStandardCompare(rhs.bezeichnung) == .orderedAscending
        }
    }

    /// Geschoss-Ordnung KG → EG → OG → DG (klein genug für MVP).
    private static func sortierrang(_ bezeichnung: String) -> Int {
        let key = bezeichnung
            .uppercased()
            .trimmingCharacters(in: .whitespaces)
        switch key {
        case "KG", "UG", "KELLER", "KELLERGESCHOSS", "UNTERGESCHOSS":
            return 0
        case "EG", "ERDGESCHOSS":
            return 1
        case "OG", "1. OG", "1.OG", "OBERGESCHOSS", "1. OBERGESCHOSS":
            return 2
        case "2. OG", "2.OG", "2. OBERGESCHOSS":
            return 3
        case "DG", "DACHGESCHOSS":
            return 4
        default:
            return 99
        }
    }
}
