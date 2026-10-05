import SwiftData

extension ModelContext {
    func all<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? fetch(FetchDescriptor<T>())) ?? []
    }
}
