import UIKit
import RuuviOntology

protocol TagChartsRouterInput {
    func dismiss(completion: (() -> Void)?)
    func openDiscover(output: DiscoverModuleOutput)
    func openSettings()
    func openAbout()
    func openRuuviWebsite()
    func openSignIn(output: SignInModuleOutput)
    func openMenu(output: MenuModuleOutput)
    func openTagSettings(ruuviTag: RuuviTagSensor,
                         temperature: Temperature?,
                         humidity: Humidity?,
                         sensor: SensorSettings?,
                         output: TagSettingsModuleOutput)
    func openWebTagSettings(webTag: WebTagRealm,
                            temperature: Temperature?)
    func macCatalystExportFile(with path: URL, delegate: UIDocumentPickerDelegate?)
}
extension TagChartsRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
