import Foundation

protocol DiscoverViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidSelect(device: DiscoverDeviceViewModel)
    func viewDidTriggerContinue()
}
