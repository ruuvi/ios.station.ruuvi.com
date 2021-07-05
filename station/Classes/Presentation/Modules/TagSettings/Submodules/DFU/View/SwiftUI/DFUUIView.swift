import SwiftUI
import Localize_Swift

struct DFUUIView: View {
    @ObservedObject var viewModel: DFUViewModel

    var body: some View {
        VStack {
            content
                .navigationBarTitle(
                    "Firmware Update",
                    displayMode: .inline
                )
        }
        .onAppear { self.viewModel.send(event: .onAppear) }
    }

    private var content: some View {
        switch viewModel.state {
        case .idle:
            return Color.clear.eraseToAnyView()
        case .loading:
            return VStack(alignment: .leading, spacing: 16) {
                Text("Latest available Ruuvi Firmware version:").bold()
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }
            .padding()
            .eraseToAnyView()
        case .error(let error):
            return Text(error.localizedDescription).eraseToAnyView()
        case let .loaded(latestRelease):
            return VStack(alignment: .leading, spacing: 16) {
                Text("Latest available Ruuvi Firmware version:").bold()
                Text(latestRelease.version)
                Text("Current version:").bold()
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }
            .padding()
            .onAppear { self.viewModel.send(event: .onLoaded(latestRelease)) }
            .eraseToAnyView()
        case let .serving(latestRelease):
            return VStack(alignment: .leading, spacing: 16) {
                Text("Latest available Ruuvi Firmware version:").bold()
                Text(latestRelease.version)
                Text("Current version:").bold()
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }
            .padding()
            .eraseToAnyView()
        case let .checking(latestRelease, currentRelease):
            return VStack(alignment: .leading, spacing: 16) {
                Text("Latest available Ruuvi Firmware version:").bold()
                Text(latestRelease.version)
                Text("Current version:").bold()
                if let currentVersion = currentRelease?.version {
                    Text(currentVersion)
                } else {
                    Text("Your sensor doesn't report it's current firmware version. That means that it's probably running an old firmware version and updating is recommended")
                }
            }
            .padding()
            .onAppear { self.viewModel.send(event: .onLoadedAndServed(latestRelease, currentRelease)) }
            .eraseToAnyView()
        case let .noNeedToUpgrade(latestRelease, _):
            return Text("You are running the latest firmware version \(latestRelease.version), no need to upgrade")
                .multilineTextAlignment(.center)
                .padding()
                .eraseToAnyView()
        case let .isAbleToUpgrade(latestRelease, currentRelease):
            return VStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Latest available Ruuvi Firmware version:").bold()
                    Text(latestRelease.version)
                    Text("Current version:").bold()
                    if let currentVersion = currentRelease?.version {
                        Text(currentVersion)
                    } else {
                        Text("Your sensor doesn't report it's current firmware version. That means that it's probably running an old firmware version and updating is recommended")
                    }
                }
            }.onAppear(perform: { self.viewModel.send(
                event: .onStartUpgrade(latestRelease, currentRelease)
            ) })
            .padding()
            .eraseToAnyView()
        case .reading:
            return VStack {
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }.eraseToAnyView()
        case .downloading:
            return VStack(alignment: .center, spacing: 16) {
                Text("Downloading the latest firmware to be updated...")
                ProgressBar(value: $viewModel.downloadProgress)
                    .frame(height: 20)
                    .padding()
                Text("\(Int(viewModel.downloadProgress * 100))%")
            }.eraseToAnyView()
        case let .listening(latestRelease, currentRelease, _):
            return VStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Latest available Ruuvi Firmware version:").bold().opacity(0.5)
                    Text(latestRelease.version).opacity(0.5)
                    Text("Current version:").bold().opacity(0.5)
                    Text(currentRelease?.version ??
                            "Your sensor doesn't report it's current firmware version. That means that it's probably running an old firmware version and updating is recommended"
                    ).opacity(0.5)
                    Text("Prepare your sensor").bold()
                    Text("1. Open the cover of your Ruuvi sensor")
                    Collapsible(
                        label: { Text("2. Set the sensor to updating mode") },
                        content: {
                            Image("ruuvi-tag-firmware-update")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .allowsHitTesting(false)
                        }
                    )
                    Text("If your sensor has two buttons, press the R button while keeping pressed the B button")
                    Text("If your sensor has one button, keep the button pressed for ten seconds")
                    Text("3. When successful you will see a continuous red light")
                }

                Button(
                    action: {},
                    label: {
                        HStack {
                            Text("Searching for a sensor")
                            Spinner(isAnimating: true, style: .medium).eraseToAnyView()
                        }.frame(maxWidth: .infinity)
                    }
                )
                .buttonStyle(
                    LargeButtonStyle(
                        backgroundColor: RuuviColor.purple,
                        foregroundColor: Color.white,
                        isDisabled: true
                    )
                )
                .disabled(true)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .eraseToAnyView()
        case let .readyToUpdate(latestRelease, currentRelease, uuid, fileUrl):
            return VStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Latest available Ruuvi Firmware version:").bold().opacity(0.5)
                    Text(latestRelease.version).opacity(0.5)
                    Text("Current version:").bold().opacity(0.5)
                    Text(currentRelease?.version ??
                            "Your sensor doesn't report it's current firmware version. That means that it's probably running an old firmware version and updating is recommended"
                    ).opacity(0.5)
                    Text("Prepare your sensor").bold()
                    Text("1. Open the cover of your Ruuvi sensor")
                    Collapsible(
                        label: { Text("2. Set the sensor to updating mode") },
                        content: {
                            Image("ruuvi-tag-firmware-update")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .allowsHitTesting(false)
                        }
                    )
                    Text("If your sensor has two buttons, press the R button while keeping pressed the B button")
                    Text("If your sensor has one button, keep the button pressed for ten seconds")
                    Text("3. When successful you will see a continuous red light")
                }
                Button(
                    action: {
                        self.viewModel.send(
                            event: .onUserDidConfirmToFlash(
                                latestRelease,
                                currentRelease,
                                uuid: uuid,
                                fileUrl: fileUrl
                            )
                        )
                    },
                    label: {
                        Text("Start the update")
                            .frame(maxWidth: .infinity)
                    }
                )
                .buttonStyle(
                    LargeButtonStyle(
                        backgroundColor: RuuviColor.purple,
                        foregroundColor: Color.white,
                        isDisabled: false
                    )
                )
                .frame(maxWidth: .infinity)
            }
            .padding()
            .eraseToAnyView()
        case let .flashing(latestRelease, currentRelease, _, _):
            return VStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Latest available Ruuvi Firmware version:").bold()
                    Text(latestRelease.version)
                    Text("Current version:").bold()
                    Text(currentRelease?.version ??
                            "Your sensor doesn't report it's current firmware version. That means that it's probably running an old firmware version and updating is recommended"
                    )
                    Text("Prepare your sensor").bold()
                    Text("1. Open the cover of your Ruuvi sensor")
                    Collapsible(
                        label: { Text("2. Set the sensor to updating mode") },
                        content: {
                            Image("ruuvi-tag-firmware-update")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .allowsHitTesting(false)
                        }
                    )
                    Text("If your sensor has two buttons, press the R button while keeping pressed the B button")
                    Text("If your sensor has one button, keep the button pressed for ten seconds")
                    Text("3. When successful you will see a continuous red light")
                }
                .opacity(0.5)

                ZStack {
                    ProgressBar(value: $viewModel.flashProgress)
                    Button(
                        action: {},
                        label: {
                            Text("Updating...")
                        }
                    )
                    .buttonStyle(
                        LargeButtonStyle(
                            backgroundColor: Color.clear,
                            foregroundColor: Color.white,
                            isDisabled: false
                        )
                    )
                    .disabled(true)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, maxHeight: 56)

                Text("Do not close or power off the sensor during the update.")
                    .bold()
                    .multilineTextAlignment(.center)

            }
            .padding()
            .eraseToAnyView()
        case .successfulyFlashed:
            return Text("Update successful").eraseToAnyView()
        }
    }
}