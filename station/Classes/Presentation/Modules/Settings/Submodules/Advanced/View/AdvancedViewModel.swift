import Foundation

struct AdvancedViewModel {
    let sections: [AdvancedSection]
}

struct AdvancedSection {
    let title: String?
    let cells: [AdvancedCell]
}

struct AdvancedCell {
    var type: AdvancedCellType
    var boolean: Observable<Bool?> = Observable<Bool?>()
    var integer: Observable<Int?> = Observable<Int?>()
}

enum AdvancedIntegerUnit {
    case hours
    case minutes
    case seconds

    var unitString: String {
        switch self {
        case .hours:
            return "Advanced.Interval.Hour.string".localized()
        case .minutes:
            return "Advanced.Interval.Min.string".localized()
        case .seconds:
            return "Advanced.Interval.Sec.string".localized()
        }
    }
}

enum AdvancedCellType {
    case disclosure(title: String)
    case stepper(title: String, value: Int, unit: AdvancedIntegerUnit)
    case switcher(title: String, value: Bool)
}
