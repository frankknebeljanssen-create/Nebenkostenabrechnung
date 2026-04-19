//
//  ObjektTabRoot.swift
//  NebenkostenApp — UI/Objekt
//

import SwiftUI
import SwiftData

struct ObjektTabRoot: View {
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]
    @Environment(ObjektWahl.self) private var objektWahl

    @State private var zeigeNeuesObjekt = false
    @State private var zeigeLimitAlert = false

    private static let maxObjekte = 4

    var body: some View {
        NavigationStack {
            inhalt
                .navigationTitle("Objekt")
                .toolbar { pickerToolbar }
                .navigationDestination(for: Wohneinheit.self) { einheit in
                    WohneinheitDetailView(wohneinheit: einheit)
                }
                .navigationDestination(for: Zaehler.self) { zaehler in
                    ZaehlerDetailView(zaehler: zaehler)
                }
                .navigationDestination(for: KostenartenListenZiel.self) { ziel in
                    KostenartListeView(immobilie: ziel.immobilie)
                }
                .sheet(isPresented: $zeigeNeuesObjekt) {
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
                .onAppear {
                    objektWahl.bereinigeFallsUngueltig(verfuegbareIDs: Set(immobilien.map(\.id)))
                }
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        if let aktives = aktivesObjekt {
            ObjektDashboardView(immobilie: aktives)
        } else {
            TabPlatzhalterView(titel: "Objekt", symbol: "house")
        }
    }

    private var aktivesObjekt: Immobilie? {
        if let id = objektWahl.aktiveID,
           let match = immobilien.first(where: { $0.id == id }) {
            return match
        }
        return immobilien.first
    }

    // MARK: - Picker

    @ToolbarContentBuilder
    private var pickerToolbar: some ToolbarContent {
        if !immobilien.isEmpty {
            ToolbarItem(placement: .principal) {
                Menu {
                    Section {
                        ForEach(immobilien) { objekt in
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
                                    if objekt.id == aktivesObjekt?.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        Button {
                            if immobilien.count >= Self.maxObjekte {
                                zeigeLimitAlert = true
                            } else {
                                zeigeNeuesObjekt = true
                            }
                        } label: {
                            Label("Neues Objekt anlegen…", systemImage: "plus")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(aktivesObjekt?.adresse.isEmpty == false
                             ? aktivesObjekt!.adresse
                             : "Objekt wählen")
                            .font(.headline)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                }
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    zeigeNeuesObjekt = true
                } label: {
                    Label("Neues Objekt", systemImage: "plus")
                }
            }
        }
    }
}
