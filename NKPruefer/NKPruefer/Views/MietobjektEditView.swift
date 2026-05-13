import SwiftUI
import SwiftData

struct MietobjektEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var bestehendesObjekt: Mietobjekt?

    @State private var adresse = ""
    @State private var bezeichnung = ""
    @State private var flaecheQm: Decimal? = nil
    @State private var personenzahl = 1
    @State private var kaltmiete: Decimal? = nil
    @State private var nkVorauszahlung: Decimal? = nil

    @State private var vermieterName = ""
    @State private var vermieterAdresse = ""
    @State private var vermieterEmail = ""
    @State private var vermieterTelefon = ""

    @State private var zeigeFehler = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Wohnung") {
                    TextField("Adresse", text: $adresse)
                        .textContentType(.fullStreetAddress)
                    TextField("Bezeichnung (optional)", text: $bezeichnung)
                    HStack {
                        Text("Wohnfläche")
                        Spacer()
                        TextField("m²", value: $flaecheQm, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    Stepper("Personen: \(personenzahl)", value: $personenzahl, in: 1...10)
                }

                Section("Miete (optional)") {
                    HStack {
                        Text("Kaltmiete")
                        Spacer()
                        TextField("€", value: $kaltmiete, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("NK-Vorauszahlung/Monat")
                        Spacer()
                        TextField("€", value: $nkVorauszahlung, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section("Vermieter (optional)") {
                    TextField("Name / Hausverwaltung", text: $vermieterName)
                    TextField("Adresse", text: $vermieterAdresse)
                    TextField("E-Mail", text: $vermieterEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Telefon", text: $vermieterTelefon)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle(bestehendesObjekt == nil ? "Neue Wohnung" : "Wohnung bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { speichern() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Adresse und Wohnfläche sind Pflicht.", isPresented: $zeigeFehler) {
                Button("OK", role: .cancel) {}
            }
            .onAppear(perform: ladeBestehendes)
        }
    }

    private func ladeBestehendes() {
        guard let obj = bestehendesObjekt else { return }
        adresse = obj.adresse
        bezeichnung = obj.bezeichnung ?? ""
        flaecheQm = obj.flaecheQm
        personenzahl = obj.personenzahl
        kaltmiete = obj.kaltmiete
        nkVorauszahlung = obj.nkVorauszahlungMonatlich
        vermieterName = obj.vermieterName ?? ""
        vermieterAdresse = obj.vermieterAdresse ?? ""
        vermieterEmail = obj.vermieterEmail ?? ""
        vermieterTelefon = obj.vermieterTelefon ?? ""
    }

    private func speichern() {
        let trimmed = adresse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let fl = flaecheQm, fl > 0 else {
            zeigeFehler = true
            return
        }
        let ziel = bestehendesObjekt ?? Mietobjekt(adresse: trimmed, flaecheQm: fl, personenzahl: personenzahl)
        if bestehendesObjekt == nil { modelContext.insert(ziel) }

        ziel.adresse = trimmed
        ziel.bezeichnung = bezeichnung.nilIfEmpty
        ziel.flaecheQm = fl
        ziel.personenzahl = personenzahl
        ziel.kaltmiete = kaltmiete
        ziel.nkVorauszahlungMonatlich = nkVorauszahlung
        ziel.vermieterName = vermieterName.nilIfEmpty
        ziel.vermieterAdresse = vermieterAdresse.nilIfEmpty
        ziel.vermieterEmail = vermieterEmail.nilIfEmpty
        ziel.vermieterTelefon = vermieterTelefon.nilIfEmpty

        NKHaptic.success()
        dismiss()
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

#Preview {
    MietobjektEditView()
        .modelContainer(for: [Mietobjekt.self, GespeicherteAbrechnung.self], inMemory: true)
}
