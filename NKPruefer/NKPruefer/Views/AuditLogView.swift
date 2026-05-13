import SwiftUI
import SwiftData

struct AuditLogView: View {
    @Query(sort: \APIAuditEntry.zeitpunkt, order: .reverse)
    private var entries: [APIAuditEntry]

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "Kein Protokoll",
                    systemImage: "doc.text",
                    description: Text("Es wurden noch keine API-Calls getätigt.")
                )
            } else {
                List {
                    ForEach(entries) { entry in
                        eintrag(entry)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("API-Protokoll")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func eintrag(_ entry: APIAuditEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.agent)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(entry.zeitpunkt, style: .relative)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Text(entry.zweck)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text(entry.datenGesendet)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            HStack(spacing: 10) {
                if entry.anonymisiert {
                    Label("Anonymisiert", systemImage: "checkmark.shield")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                }
                if entry.statsNamen > 0 {
                    badge("\(entry.statsNamen) Namen")
                }
                if entry.statsIBANs > 0 {
                    badge("\(entry.statsIBANs) IBANs")
                }
                if entry.statsEmails > 0 {
                    badge("\(entry.statsEmails) Emails")
                }
                if entry.statsTelefon > 0 {
                    badge("\(entry.statsTelefon) Telefon")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
    }
}

#Preview {
    NavigationStack { AuditLogView() }
        .modelContainer(for: [Mietobjekt.self, GespeicherteAbrechnung.self, APIAuditEntry.self], inMemory: true)
}
