import SwiftUI
import SwiftData

extension Notification.Name {
    static let nkResetToHome = Notification.Name("nkResetToHome")
}

struct ContentView: View {
    @AppStorage("hatOnboardingGesehen") private var hatOnboardingGesehen = false
    @State private var resetId = UUID()

    var body: some View {
        Group {
            if hatOnboardingGesehen {
                HomeView()
                    .id(resetId)
            } else {
                OnboardingView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nkResetToHome)) { _ in
            resetId = UUID()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Mietobjekt.self, GespeicherteAbrechnung.self], inMemory: true)
}
