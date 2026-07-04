import SwiftUI

@main
@MainActor
struct HumanCultureApp: App {
    @State private var savedStore = SavedStore()
    private let repository: any CultureRepository = CultureRepositoryFactory.make()

    var body: some Scene {
        WindowGroup {
            RootView(repository: repository, savedStore: savedStore)
        }
    }
}

