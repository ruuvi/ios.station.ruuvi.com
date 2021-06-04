import Foundation
import Future
import RuuviOntology
import RuuviStorage
import RuuviCloud
import RuuviPool
import RuuviLocal

// swiftlint:disable:next type_body_length
final class RuuviServiceCloudSyncImpl: RuuviServiceCloudSync {
    private let ruuviStorage: RuuviStorage
    private let ruuviCloud: RuuviCloud
    private let ruuviPool: RuuviPool
    private var ruuviLocalSettings: RuuviLocalSettings
    private var ruuviLocalSyncState: RuuviLocalSyncState
    private let ruuviLocalImages: RuuviLocalImages

    init(
        ruuviStorage: RuuviStorage,
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool,
        ruuviLocalSettings: RuuviLocalSettings,
        ruuviLocalSyncState: RuuviLocalSyncState,
        ruuviLocalImages: RuuviLocalImages
    ) {
        self.ruuviStorage = ruuviStorage
        self.ruuviCloud = ruuviCloud
        self.ruuviPool = ruuviPool
        self.ruuviLocalSettings = ruuviLocalSettings
        self.ruuviLocalSyncState = ruuviLocalSyncState
        self.ruuviLocalImages = ruuviLocalImages
    }

    @discardableResult
    func syncSettings() -> Future<RuuviCloudSettings, RuuviServiceError> {
        let promise = Promise<RuuviCloudSettings, RuuviServiceError>()
        ruuviCloud.getCloudSettings()
            .on(success: { [weak self] cloudSettings in
                guard let sSelf = self else { return }
                if let unitTemperature = cloudSettings.unitTemperature {
                    sSelf.ruuviLocalSettings.temperatureUnit = unitTemperature
                }
                if let unitHumidity = cloudSettings.unitHumidity {
                    sSelf.ruuviLocalSettings.humidityUnit = unitHumidity
                }
                if let unitPressure = cloudSettings.unitPressure {
                    sSelf.ruuviLocalSettings.pressureUnit = unitPressure
                }
                promise.succeed(value: cloudSettings)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    func syncImage(sensor: CloudSensor) -> Future<URL, RuuviServiceError> {
        let promise = Promise<URL, RuuviServiceError>()
        guard let pictureUrl = sensor.picture else {
            promise.fail(error: .pictureUrlIsNil)
            return promise.future
        }
        URLSession
            .shared
            .dataTask(with: pictureUrl, completionHandler: { [weak self] data, _, error in
                guard let sSelf = self else { return }
                if let error = error {
                    promise.fail(error: .networking(error))
                } else if let data = data {
                    if let image = UIImage(data: data) {
                        sSelf.ruuviLocalImages
                            .setCustomBackground(image: image, for: sensor.id.mac)
                            .on(success: { [weak sSelf] fileUrl in
                                guard let ssSelf = sSelf else { return }
                                ssSelf.ruuviLocalImages.setPictureIsCached(for: sensor)
                                promise.succeed(value: fileUrl)
                            }, failure: { error in
                                promise.fail(error: .ruuviLocal(error))
                            })
                    } else {
                        promise.fail(error: .failedToParseNetworkResponse)
                    }
                } else {
                    promise.fail(error: .failedToParseNetworkResponse)
                }
            }).resume()
        return promise.future
    }

    @discardableResult
    func syncAll() -> Future<Set<AnyRuuviTagSensor>, RuuviServiceError> {
        let promise = Promise<Set<AnyRuuviTagSensor>, RuuviServiceError>()
        let sensors = syncSensors()
        let settings = syncSettings()
        sensors.on(success: { [weak self] updatedSensors in
            guard let sSelf = self else { return }
            let syncs = updatedSensors.map({ sSelf.sync(sensor: $0) })
            Future.zip(syncs).on(success: { _ in
                settings.on(success: { _ in
                    promise.succeed(value: updatedSensors)
                }, failure: { error in
                    promise.fail(error: error)
                })
            }, failure: { error in
                promise.fail(error: error)
            })
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    @discardableResult
    func syncAllRecords() -> Future<[AnyRuuviTagSensorRecord], RuuviServiceError> {
        let promise = Promise<[AnyRuuviTagSensorRecord], RuuviServiceError>()
        ruuviStorage.readAll().on(success: { [weak self] localSensors in
            guard let sSelf = self else { return }
            let syncs = localSensors
                .filter({ $0.isCloud })
                .map({ sSelf.sync(sensor: $0) })
            Future.zip(syncs).on(success: { remoteSensorRecords in
                promise.succeed(value: remoteSensorRecords.reduce([], +))
            }, failure: { error in
                promise.fail(error: error)
            })
        }, failure: { error in
            promise.fail(error: .ruuviStorage(error))
        })
        return promise.future
    }

    @discardableResult
    // swiftlint:disable:next function_body_length
    func syncSensors() -> Future<Set<AnyRuuviTagSensor>, RuuviServiceError> {
        let promise = Promise<Set<AnyRuuviTagSensor>, RuuviServiceError>()
        var updatedSensors = Set<AnyRuuviTagSensor>()
        ruuviStorage.readAll().on(success: { localSensors in
            self.ruuviCloud.loadSensors().on(success: { cloudSensors in
                let updateSensors: [Future<Bool, RuuviPoolError>] = localSensors
                    .compactMap({ localSensor in
                        if let cloudSensor = cloudSensors.first(where: {$0.id == localSensor.id }) {
                            updatedSensors.insert(localSensor)
                            return self.ruuviPool.update(localSensor.with(cloudSensor: cloudSensor))
                        } else {
                            let unclaimed = localSensor.unclaimed()
                            if unclaimed.any != localSensor {
                                updatedSensors.insert(localSensor)
                                return self.ruuviPool.update(unclaimed)
                            } else {
                                return nil
                            }
                        }
                    })
                let createSensors: [Future<Bool, RuuviPoolError>] = cloudSensors
                    .filter { cloudSensor in
                        !localSensors.contains(where: { $0.id == cloudSensor.id })
                    }.map { newCloudSensor in
                        let newLocalSensor = newCloudSensor.ruuviTagSensor
                        updatedSensors.insert(newLocalSensor.any)
                        return self.ruuviPool.create(newLocalSensor)
                    }

                let syncImages = cloudSensors
                    .filter({ !self.ruuviLocalImages.isPictureCached(for: $0) })
                    .map({ self.syncImage(sensor: $0) })

                Future.zip([Future.zip(createSensors), Future.zip(updateSensors)])
                    .on(success: { _ in

                        Future.zip(syncImages).on()
                        let syncOffsets = self.offsetSyncs(
                            cloudSensors: cloudSensors,
                            updatedSensors: updatedSensors
                        )

                        Future.zip(syncOffsets)
                            .on(success: { _ in
                                promise.succeed(value: updatedSensors)
                            }, failure: { error in
                                promise.fail(error: .ruuviPool(error))
                            })

                    }, failure: { error in
                        promise.fail(error: .ruuviPool(error))
                    })
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        }, failure: { error in
            promise.fail(error: .ruuviStorage(error))
        })
        return promise.future
    }

    private func offsetSyncs(
        cloudSensors: [CloudSensor],
        updatedSensors: Set<AnyRuuviTagSensor>
    ) -> [Future<SensorSettings, RuuviPoolError>] {
        let temperatureSyncs: [Future<SensorSettings, RuuviPoolError>]
            = cloudSensors.compactMap { cloudSensor in
            if let updatedSensor = updatedSensors
                .first(where: { $0.id == cloudSensor.id }) {
                return self.ruuviPool.updateOffsetCorrection(
                    type: .temperature,
                    with: cloudSensor.offsetTemperature,
                    of: updatedSensor
                )
            } else {
                return nil
            }
        }

        let humiditySyncs: [Future<SensorSettings, RuuviPoolError>]
            = cloudSensors.compactMap { cloudSensor in
            if let updatedSensor = updatedSensors
                .first(where: { $0.id == cloudSensor.id }) {
                return self.ruuviPool.updateOffsetCorrection(
                    type: .humidity,
                    with: cloudSensor.offsetHumidity,
                    of: updatedSensor
                )
            } else {
                return nil
            }
        }

        let pressureSyncs: [Future<SensorSettings, RuuviPoolError>]
            = cloudSensors.compactMap { cloudSensor in
            if let updatedSensor = updatedSensors
                .first(where: { $0.id == cloudSensor.id }) {
                return self.ruuviPool.updateOffsetCorrection(
                    type: .pressure,
                    with: cloudSensor.offsetPressure,
                    of: updatedSensor
                )
            } else {
                return nil
            }
        }

        return temperatureSyncs + humiditySyncs + pressureSyncs
    }

    @discardableResult
    func sync(sensor: RuuviTagSensor) -> Future<[AnyRuuviTagSensorRecord], RuuviServiceError> {
        let promise = Promise<[AnyRuuviTagSensorRecord], RuuviServiceError>()
        let networkPruningOffset = -TimeInterval(ruuviLocalSettings.networkPruningIntervalHours * 60 * 60)
        let networkPuningDate = Date(timeIntervalSinceNow: networkPruningOffset)
        let since: Date = ruuviLocalSyncState.getSyncDate(for: sensor.macId)
            ?? networkPuningDate
        syncRecordsOperation(for: sensor, since: since)
            .on(success: { [weak self] result in
                self?.ruuviLocalSyncState.setSyncDate(Date(), for: sensor.macId)
                promise.succeed(value: result)
             }, failure: { error in
                promise.fail(error: error)
             })
        return promise.future
    }

    private lazy var syncRecordsQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()

    private func syncRecordsOperation(
        for sensor: RuuviTagSensor,
        since: Date
    ) -> Future<[AnyRuuviTagSensorRecord], RuuviServiceError> {
        let promise = Promise<[AnyRuuviTagSensorRecord], RuuviServiceError>()
        guard let macId = sensor.macId else {
            promise.fail(error: .macIdIsNil)
            return promise.future
        }
        let operation = RuuviServiceCloudSyncRecordsOperation(
            macId: macId,
            since: since,
            ruuviCloud: ruuviCloud,
            ruuviPool: ruuviPool,
            syncState: ruuviLocalSyncState
        )
        operation.completionBlock = { [unowned operation] in
            if let error = operation.error {
                promise.fail(error: error)
            } else {
                promise.succeed(value: operation.records)
            }
        }
        syncRecordsQueue.addOperation(operation)
        return promise.future
    }
}
