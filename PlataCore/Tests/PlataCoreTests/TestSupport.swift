import Foundation

let bogota: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Bogota")!
    return calendar
}()

func fecha(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
    bogota.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}
