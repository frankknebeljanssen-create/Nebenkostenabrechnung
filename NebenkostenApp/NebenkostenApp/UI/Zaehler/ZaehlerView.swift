//
//  ZaehlerView.swift
//  NebenkostenApp — UI/Zaehler
//
//  Zähler-Screen nach design_handoff meters-bills.jsx (MetersScreen,
//  MeterRow, MeterReading, Zeilen 3-151) + UI-Fix-3.
//
//  Aufbau einer Zähler-Card (eigene Worte, Selbstkontrolle):
//    Kopf: ScopePill (HAUS oder KG/EG/OG) · Location-Name
//          (anzeigename, z.B. "Heizraum KG") · rechts klein der
//          Typ (anzeigetyp, z.B. "Wärmemengenzähler zentral").
//    Körper: drei Spalten. Spalte 1 MeterReading "Anfang" mit
//          StatusDot + ANFANG-Label + Datum (DD.MM.) + Wert mono.
//          Mini-Pfeil "→". Spalte 2 MeterReading "Ende" gleicher
//          Aufbau. Spalte 3 VerbrauchAnzeige mit Label "VERBRAUCH",
//          Wert mono, Einheit mono klein. Fehlender Endstand =
//          Wert rot + Dot rot.
//
//  Screen-Aufbau:
//    1. Warn-Card ("N Endstände fehlen") nur wenn anzahl > 0.
//    2. Medium-Sections (Wärme, Warmwasser, Kaltwasser,
//       Allgemeinstrom, Gas, Öl) in fester Reihenfolge. Leere
//       Medien werden übersprungen.
//    3. Kein Tipp-Hinweis, kein Perioden-Summary-Block.
//
//  NavBar-Subtitle: "Alle Zähler · <Jahr>".
//

import SwiftUI
import SwiftData

struct ZaehlerView: View {
    @Environment(ScopeManager.self) private var scope
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var zeigeScopePicker = false
    @State private var zeigeEinstellungen = false
    @State private var erfassenZaehler: Zaehler?

    private var immobilie: Immobilie? { immobilien.first }

    private var aktivePeriode: Abrechnungsperiode? {
        let perioden = (immobilie?.perioden ?? []).sorted(by: { $0.bis > $1.bis })
        let heute = Date()
        return perioden.first(where: { $0.bis < heute }) ?? perioden.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if offeneEndstaende > 0 {
                    WarnCardEndstaende(anzahl: offeneEndstaende) {
                        // Scroll zur ersten offenen Section — aktuell
                        // öffnen wir das Erfassen-Sheet für den ersten
                        // Zähler ohne Endstand.
                        if let z = ersterZaehlerOhneEnde {
                            erfassenZaehler = z
                        }
                    }
                }

                ForEach(gruppiertNachMedium, id: \.medium) { g in
                    MediumSection(
                        medium: g.medium,
                        zaehler: g.zaehler,
                        periode: aktivePeriode,
                        onTapZaehler: { erfassenZaehler = $0 }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 20)
        }
        .background(DesignTokens.bgApp)
        .appShellChrome(
            titel: "Zähler",
            subtitel: subtitel,
            onAdresse: { zeigeScopePicker = true },
            onEinstellungen: { zeigeEinstellungen = true }
        )
        .sheet(isPresented: $zeigeScopePicker) { ScopePickerSheet() }
        .sheet(isPresented: $zeigeEinstellungen) { EinstellungenSheet() }
        .sheet(item: $erfassenZaehler) { z in
            NavigationStack { ZaehlerstandErfassenView(zaehler: z) }
        }
    }

    // MARK: - Daten-Logik

    private var subtitel: String? {
        guard let p = aktivePeriode else { return "Alle Zähler" }
        let jahr = Calendar(identifier: .gregorian).component(.year, from: p.bis)
        return "Alle Zähler · \(jahr)"
    }

    private var sichtbareZaehler: [Zaehler] {
        let paare = ScopeFilter.zaehlerGetrennt(
            hauptzaehler: immobilie?.hauptzaehler ?? [],
            einheiten: immobilie?.wohneinheiten ?? [],
            scope: scope.current
        )
        return paare.haupt + paare.wohnung
    }

    struct MediumGruppe {
        let medium: Medium
        let zaehler: [Zaehler]
    }

    private var gruppiertNachMedium: [MediumGruppe] {
        let alle = sichtbareZaehler
        let gruppiert = Dictionary(grouping: alle) { $0.medium }
        return MediumMeta.reihenfolge.compactMap { m -> MediumGruppe? in
            guard let liste = gruppiert[m], !liste.isEmpty else { return nil }
            let sortiert = liste.sorted { lhs, rhs in
                let lh = lhs.wohneinheit == nil ? 0 : 1  // Hauptzähler zuerst
                let rh = rhs.wohneinheit == nil ? 0 : 1
                if lh != rh { return lh < rh }
                return ScopeFilter.einheitRang(lhs.wohneinheit?.bezeichnung ?? "")
                    < ScopeFilter.einheitRang(rhs.wohneinheit?.bezeichnung ?? "")
            }
            return MediumGruppe(medium: m, zaehler: sortiert)
        }
    }

    private var offeneEndstaende: Int {
        guard let p = aktivePeriode else { return 0 }
        return sichtbareZaehler.filter { z in
            let inPeriode = (z.staende ?? []).filter {
                $0.ablesedatum >= p.von && $0.ablesedatum <= p.bis
            }
            return inPeriode.count < 2
        }.count
    }

    private var ersterZaehlerOhneEnde: Zaehler? {
        guard let p = aktivePeriode else { return nil }
        return sichtbareZaehler.first { z in
            let inPeriode = (z.staende ?? []).filter {
                $0.ablesedatum >= p.von && $0.ablesedatum <= p.bis
            }
            return inPeriode.count < 2
        }
    }
}
