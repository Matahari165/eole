#if canImport(EoleApp)
import EoleApp
#endif
import SwiftUI

/// Point d'entrée iPhone. Le reste (moteur, vues, persistance) vit dans le package SPM.
@main
struct EolePhoneApp: App {
    @StateObject private var store: SessionStore

    init() {
        _store = StateObject(wrappedValue: SessionStore(sync: SyncClient()))
    }

    var body: some Scene {
        WindowGroup {
            EoleRootView(store: store)
        }
    }
}
