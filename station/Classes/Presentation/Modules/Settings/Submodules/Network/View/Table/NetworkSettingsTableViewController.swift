import UIKit

enum NetworkSettingsSection: Int, CaseIterable {
    case common
    case whereOS
    case kaltiot
//    case aws

    init(indexPath: IndexPath) {
        guard let section = NetworkSettingsSection(rawValue: indexPath.section) else {
            fatalError()
        }
        self = section
    }
}

class NetworkSettingsTableViewController: UITableViewController {
    var output: NetworkSettingsViewOutput!
    var viewModel: NetworkSettingsViewModel = NetworkSettingsViewModel() {
        didSet {
            updateUI()
        }
    }
    private var networkFeatureEnabled: Bool {
        return viewModel.networkFeatureEnabled.value ?? false
    }
}

// MARK: - KaltiotSettingsViewInput
extension NetworkSettingsTableViewController: NetworkSettingsViewInput {
    func localize() {
        title = "NetworkSettings.title".localized()
        tableView.reloadData()
    }
}

// MARK: - View lifecycle
extension NetworkSettingsTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        output.viewDidLoad()
        setupLocalization()
        updateUI()
    }
}

// MARK: - UITableViewDelegate
extension NetworkSettingsTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return networkFeatureEnabled ? NetworkSettingsSection.allCases.count : 1
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = NetworkSettingsSection(rawValue: section)
        switch section {
        case .common:
            return networkFeatureEnabled ? 2 : 1
        case .whereOS:
            return 1
        case .kaltiot:
            return viewModel.kaltiotNetworkEnabled.value == true ? 2 : 1
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch NetworkSettingsSection(indexPath: indexPath) {
        case .common:
            switch indexPath.row {
            case 0:
                return getNetworkTogglerCell(tableView, indexPath)
            case 1:
                return getNetworkStepperCell(tableView, indexPath)
            default:
                fatalError()
            }
        case .whereOS:
            return getWhereOsTogglerCell(tableView, indexPath)
        case .kaltiot:
            switch indexPath.row {
            case 0:
                return getKaltiotTogglerCell(tableView, indexPath)
            case 1:
                return getKaltiotApiKeyInputCell(tableView, indexPath)
            default:
                fatalError()
            }
        }
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch NetworkSettingsSection(rawValue: section) {
        case .whereOS?:
            return "NetworkSettings.WhereOS".localized()
        case .kaltiot:
            return "NetworkSettings.Kaltiot".localized()
        default:
            return nil
        }
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
         if let section = NetworkSettingsSection(rawValue: section),
            section == .kaltiot,
            viewModel.kaltiotNetworkEnabled.value == true {
            return "KaltiotSettings.FooterTextView.text".localized()
        } else {
            return nil
        }
    }
}

// MARK: - Private
extension NetworkSettingsTableViewController {
    private func updateUI() {
        tableView.reloadData()
    }
    @objc func didChangeNetworkFeatureEnabled(_ sender: UISwitch) {
        output.viewDidTriggerNetworkFeatureSwitch(sender.isOn)
        updateUI()
    }
    @objc func didChangeWhereOSNetworkEnabled(_ sender: UISwitch) {
        output.viewDidTriggerWhereOsSwitch(sender.isOn)
        updateUI()
    }
    @objc func didChangeKaltiotNetworkEnabled(_ sender: UISwitch) {
        output.viewDidTriggerKaltiotSwitch(sender.isOn)
        tableView.beginUpdates()
        tableView.reloadSections(IndexSet(arrayLiteral: NetworkSettingsSection.kaltiot.rawValue), with: .automatic)
        tableView.endUpdates()
    }
}

extension NetworkSettingsTableViewController: NetworkSettingsStepperTableViewCellDelegate {
    func foregroundStepper(cell: NetworkSettingsStepperTableViewCell, didChange value: Int) {
        viewModel.networkRefreshInterval.value = value
    }
}

// MARK: - Private
extension NetworkSettingsTableViewController {
    private func getNetworkTogglerCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(with: NetworkSettingsSwitchTableViewCell.self, for: indexPath)
        cell.settingsSwitch.isOn = networkFeatureEnabled
        cell.settingsSwitch.addTarget(self,
                                      action: #selector(didChangeNetworkFeatureEnabled(_:)),
                                      for: .valueChanged)
        cell.settingsTitleLabel.text = "NetworkSettings.NetworkFeature".localized()
        return cell
    }

    private func getNetworkStepperCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(with: NetworkSettingsStepperTableViewCell.self, for: indexPath)
        if let minInterval = viewModel.minNetworkRefreshInterval.value {
            cell.stepper.minimumValue = minInterval
        }
        if let refreshInterval = viewModel.networkRefreshInterval.value {
            cell.stepper.value = Double(refreshInterval)
            cell.setTitle(withValue: refreshInterval)
        }
        cell.delegate = self
        return cell
    }

    private func getWhereOsTogglerCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(with: NetworkSettingsSwitchTableViewCell.self, for: indexPath)
        cell.settingsSwitch.isOn = viewModel.whereOSNetworkEnabled.value ?? false
        cell.settingsSwitch.addTarget(self,
                                      action: #selector(didChangeWhereOSNetworkEnabled(_:)),
                                      for: .valueChanged)
        cell.settingsTitleLabel.text = "NetworkSettings.WhereOS".localized()
        return cell
    }

    private func getKaltiotTogglerCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(with: NetworkSettingsSwitchTableViewCell.self, for: indexPath)
        cell.settingsSwitch.isOn = viewModel.kaltiotNetworkEnabled.value ?? false
        cell.settingsSwitch.addTarget(self,
                                      action: #selector(didChangeKaltiotNetworkEnabled(_:)),
                                      for: .valueChanged)
        cell.settingsTitleLabel.text = "NetworkSettings.Kaltiot".localized()
        return cell
    }

    private func getKaltiotApiKeyInputCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(with: KaltiotApiKeyTableViewCell.self, for: indexPath)
        cell.apiKeyTextField.text = viewModel.kaltiotApiKey.value
        cell.apiKeyTextField.placeholder = "KaltiotSettings.ApiKeyTextField.placeholder".localized()
        cell.apiKeyTextField.delegate = self
        return cell
    }
}
extension NetworkSettingsTableViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        output.viewDidEnterApiKey(textField.text)
    }
}