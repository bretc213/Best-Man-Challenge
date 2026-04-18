import Foundation
import FirebaseFirestore


@MainActor
final class BMCCoinConfigStore: ObservableObject {
    @Published var config = BMCCoinConfig()
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func start() {
        isLoading = true
        errorMessage = nil

        listener?.remove()
        listener = db.collection("coin_config")
            .document("global")
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                do {
                    if let config = try snap?.data(as: BMCCoinConfig.self) {
                        self.config = config
                    }
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
    }
}
