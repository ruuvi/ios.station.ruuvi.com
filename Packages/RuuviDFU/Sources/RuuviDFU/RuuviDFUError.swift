import Foundation

public struct RuuviDfuError: Error {
    public static let invalidFirmwareFile = RuuviDfuError(description: "RuuviDfuError.invalidFirmwareFile")
    public let description: String
    public init(description: String) {
        self.description = description
    }
}