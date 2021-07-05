import Foundation
import Combine
import RuuviOntology

final class DFUViewModel: ObservableObject {
    @Published private(set) var state: State = .idle
    @Published var downloadProgress: Double = 0
    @Published var flashProgress: Double = 0

    private var bag = Set<AnyCancellable>()
    private let input = PassthroughSubject<Event, Never>()
    private let interactor: DFUInteractorInput
    private let ruuviTag: RuuviTagSensor

    init(
        interactor: DFUInteractorInput,
        ruuviTag: RuuviTagSensor
    ) {
        self.interactor = interactor
        self.ruuviTag = ruuviTag
        Publishers.system(
            initial: state,
            reduce: Self.reduce,
            scheduler: RunLoop.main,
            feedbacks: [
                self.whenLoading(),
                self.whenServing(),
                self.whenReading(),
                self.whenDownloading(),
                self.whenListening(),
                self.whenFlashing(),
                self.userInput(input: input.eraseToAnyPublisher())
            ]
        )
        .assign(to: \.state, on: self)
        .store(in: &bag)
    }

    deinit {
        bag.removeAll()
    }

    func send(event: Event) {
        input.send(event)
    }
}

extension DFUViewModel {
    enum State {
        case idle
        case loading
        case loaded(LatestRelease)
        case serving(LatestRelease)
        case checking(LatestRelease, CurrentRelease?)
        case noNeedToUpgrade(LatestRelease, CurrentRelease?)
        case isAbleToUpgrade(LatestRelease, CurrentRelease?)
        case reading(LatestRelease, CurrentRelease?)
        case downloading(LatestRelease, CurrentRelease?)
        case listening(LatestRelease, CurrentRelease?, fileUrl: URL)
        case readyToUpdate(LatestRelease, CurrentRelease?, uuid: String, fileUrl: URL)
        case flashing(LatestRelease, CurrentRelease?, uuid: String, fileUrl: URL)
        case successfulyFlashed
        case error(Error)
    }

    enum Event {
        case onAppear
        case onLoaded(LatestRelease)
        case onDidFailLoading(Error)
        case onServed(CurrentRelease?)
        case onLoadedAndServed(LatestRelease, CurrentRelease?)
        case onStartUpgrade(LatestRelease,  CurrentRelease?)
        case onRead(LatestRelease,  CurrentRelease?, fileUrl: URL)
        case onDidFailReading(LatestRelease, CurrentRelease?, Error)
        case onDownloading(LatestRelease, CurrentRelease?, Double)
        case onDownloaded(LatestRelease, CurrentRelease?, fileUrl: URL)
        case onDidFailDownloading(Error)
        case onHeardRuuviBootDevice(
                LatestRelease,
                CurrentRelease?,
                uuid: String,
                fileUrl: URL
             )
        case onUserDidConfirmToFlash(
                LatestRelease,
                CurrentRelease?,
                uuid: String,
                fileUrl: URL
             )
        case onSuccessfullyFlashedFirmware
        case onDidFailFlashingFirmware(Error)
    }
}

extension DFUViewModel {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func reduce(_ state: State, _ event: Event) -> State {
        switch state {
        case .idle:
            switch event {
            case .onAppear:
                return .loading
            default:
                return state
            }
        case .loading:
            switch event {
            case let .onDidFailLoading(error):
                return .error(error)
            case let .onLoaded(latestRelease):
                return .loaded(latestRelease)
            default:
                return state
            }
        case let .loaded(latestRelease):
            return .serving(latestRelease)
        case let .serving(latestRelease):
            switch event {
            case let .onServed(currentRelease):
                return .checking(latestRelease, currentRelease)
            default:
                return state
            }
        case let .checking(latestRelease, currentRelease):
            if isRecommendedToUpdate(
                latestRelease: latestRelease,
                currentRelease: currentRelease
            ) {
                return .isAbleToUpgrade(latestRelease, currentRelease)
            } else {
                return .noNeedToUpgrade(latestRelease, currentRelease)
            }
        case .noNeedToUpgrade:
            return state
        case let .isAbleToUpgrade(latestRelease, currentRelease):
            return .reading(latestRelease, currentRelease)
        case .reading:
            switch event {
            case let .onRead(latestRelease, currentRelease, fileUrl):
                return .listening(latestRelease, currentRelease, fileUrl: fileUrl)
            case let .onDidFailReading(latestRelease, currentRelease, _):
                return .downloading(latestRelease, currentRelease)
            default:
                return state
            }
        case .downloading:
            switch event {
            case let .onDownloaded(latestRelease, currentRelease, fileUrl):
                return .listening(latestRelease, currentRelease, fileUrl: fileUrl)
            default:
                return state
            }
        case .listening:
            switch event {
            case let .onHeardRuuviBootDevice(latestRelease, currentRelease, uuid, fileUrl):
                return .readyToUpdate(latestRelease, currentRelease, uuid: uuid, fileUrl: fileUrl)
            default:
                return state
            }
        case .readyToUpdate:
            switch event {
            case let .onUserDidConfirmToFlash(latestRelease, currentRelease, uuid, fileUrl):
                return .flashing(latestRelease, currentRelease, uuid: uuid, fileUrl: fileUrl)
            default:
                return state
            }
        case .flashing:
            switch event {
            case .onSuccessfullyFlashedFirmware:
                return .successfulyFlashed
            case .onDidFailFlashingFirmware(let error):
                return .error(error)
            default:
                return state
            }
        case .successfulyFlashed:
            return state
        case .error:
            return state
        }
    }

    static func isRecommendedToUpdate(
        latestRelease: LatestRelease,
        currentRelease: CurrentRelease?
    ) -> Bool {
        guard let currentRelease = currentRelease else { return true }
        return !currentRelease.version.contains(latestRelease.version)
    }

    func whenFlashing() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .flashing(_, _, uuid, fileUrl) = state, let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.flash(uuid: uuid, fileUrl: fileUrl)
                .receive(on: RunLoop.main)
                .compactMap({ [weak sSelf] response in
                    switch response {
                    case .done:
                        return Event.onSuccessfullyFlashedFirmware
                    case .progress(let percentage):
                        sSelf?.flashProgress = percentage
                        return nil
                    case .log:
                        return nil
                    }
                })
                .catch { Just(Event.onDidFailFlashingFirmware($0)) }
                .eraseToAnyPublisher()
        }
    }

    func whenListening() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .listening(latestRelease, currentRelease, fileUrl) = state,
                  let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.listen()
                .receive(on: RunLoop.main)
                .map { uuid in
                    return Event.onHeardRuuviBootDevice(
                        latestRelease,
                        currentRelease,
                        uuid: uuid,
                        fileUrl: fileUrl
                    )
                }
                .eraseToAnyPublisher()
        }
    }

    func whenReading() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .reading(latestRelease, currentRelease) = state,
                  let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.read(release: latestRelease)
                .receive(on: RunLoop.main)
                .map { fileUrl in
                    return Event.onRead(
                        latestRelease,
                        currentRelease,
                        fileUrl: fileUrl
                    )
                }
                .catch { error in Just(Event.onDidFailReading(latestRelease, currentRelease, error)) }
                .eraseToAnyPublisher()
        }
    }

    func whenServing() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case .serving = state, let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.serveCurrentRelease(for: sSelf.ruuviTag)
                .receive(on: RunLoop.main)
                .map(Event.onServed)
                .catch { _ in Just(Event.onServed(nil)) }
                .eraseToAnyPublisher()
        }
    }

    func whenLoading() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case .loading = state, let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.loadLatestRelease()
                .receive(on: RunLoop.main)
                .map(Event.onLoaded)
                .catch { Just(Event.onDidFailLoading($0)) }
                .eraseToAnyPublisher()
        }
    }

    func whenDownloading() -> Feedback<State, Event> {
        Feedback { [weak self] (state: State) -> AnyPublisher<Event, Never> in
            guard case let .downloading(latestRelease, currentRelease) = state, let sSelf = self else {
                return Empty().eraseToAnyPublisher()
            }
            return sSelf.interactor.download(release: latestRelease)
                .receive(on: RunLoop.main)
                .compactMap({ [weak sSelf] response in
                    switch response {
                    case .response(let fileUrl):
                        return Event.onDownloaded(latestRelease, currentRelease, fileUrl: fileUrl)
                    case .progress(let percentage):
                        sSelf?.downloadProgress = percentage
                        return nil
                    }
                })
                .catch { Just(Event.onDidFailDownloading($0)) }
                .eraseToAnyPublisher()
        }
    }

    func userInput(input: AnyPublisher<Event, Never>) -> Feedback<State, Event> {
        Feedback(run: { _ in
            return input
        })
    }
}