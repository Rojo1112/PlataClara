import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "tag"
    var colorHex: String = "#607D8B"
    var isIncome: Bool = false
    var sortOrder: Int = 0

    init(name: String, icon: String, colorHex: String, isIncome: Bool, sortOrder: Int) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isIncome = isIncome
        self.sortOrder = sortOrder
    }
}
