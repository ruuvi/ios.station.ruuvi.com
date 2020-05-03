import RealmSwift
import Future
import BTKit
import Foundation

class RuuviTagPersistenceRealm: RuuviTagPersistence {

    var context: RealmContext!

    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(ruuviTag.mac == nil)
        assert(ruuviTag.luid != nil)
        context.bgWorker.enqueue {
            do {
                let realmTag = RuuviTagRealm(ruuviTag: ruuviTag)
                try self.context.bg.write {
                    self.context.bg.add(realmTag, update: .error)
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(ruuviTag.mac == nil)
        assert(ruuviTag.luid != nil)
        context.bgWorker.enqueue {
            do {
                let realmTag = RuuviTagRealm(ruuviTag: ruuviTag)
                try self.context.bg.write {
                    self.context.bg.add(realmTag, update: .modified)
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(ruuviTag.mac == nil)
        assert(ruuviTag.luid != nil)
        context.bgWorker.enqueue {
            do {
                if let realmTag = self.context.bg.object(ofType: RuuviTagRealm.self, forPrimaryKey: ruuviTag.id) {
                    try self.context.bg.write {
                        self.context.bg.delete(realmTag)
                    }
                    promise.succeed(value: true)
                } else {
                    promise.fail(error: .unexpected(.failedToFindRuuviTag))
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(record.mac == nil)
        context.bgWorker.enqueue {
            do {
                if let ruuviTag = self.context.bg.object(ofType: RuuviTagRealm.self, forPrimaryKey: record.ruuviTagId) {
                    let data = RuuviTagDataRealm(ruuviTag: ruuviTag, record: record)
                    try self.context.bg.write {
                        self.context.bg.add(data, update: .all)
                    }
                    promise.succeed(value: true)
                } else {
                    promise.fail(error: .unexpected(.failedToFindRuuviTag))
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        context.bgWorker.enqueue {
            do {
                var failed = false
                for record in records {
                    assert(record.mac == nil)
                    if let ruuviTag = self.context.bg.object(ofType: RuuviTagRealm.self, forPrimaryKey: record.ruuviTagId) {
                        let data = RuuviTagDataRealm(ruuviTag: ruuviTag, record: record)
                        try self.context.bg.write {
                            self.context.bg.add(data, update: .all)
                        }
                    } else {
                        failed = true
                    }
                }
                if failed {
                    promise.fail(error: .unexpected(.failedToFindRuuviTag))
                } else {
                    promise.succeed(value: true)
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    func readAll() -> Future<[RuuviTagSensor], RUError> {
        let promise = Promise<[RuuviTagSensor], RUError>()
        context.bgWorker.enqueue {
            let realmEntities = self.context.bg.objects(RuuviTagRealm.self)
            let result: [RuuviTagSensor] = realmEntities.map { ruuviTagRealm in
                return RuuviTagSensorStruct(version: ruuviTagRealm.version,
                                            luid: ruuviTagRealm.uuid,
                                            mac: ruuviTagRealm.mac,
                                            isConnectable: ruuviTagRealm.isConnectable,
                                            name: ruuviTagRealm.name)
            }
            promise.succeed(value: result)
        }
        return promise.future
    }

    func readAll(_ ruuviTagId: String) -> Future<[RuuviTagSensorRecord], RUError> {
        let promise = Promise<[RuuviTagSensorRecord], RUError>()
        context.bgWorker.enqueue {
            let realmRecords = self.context.bg.objects(RuuviTagDataRealm.self)
                                   .filter("ruuviTag.uuid == %@", ruuviTagId)
                                   .sorted(byKeyPath: "date")
            let result: [RuuviTagSensorRecord] = realmRecords.map { realmRecord in
                return RuuviTagSensorRecordStruct(ruuviTagId: ruuviTagId,
                                                  date: realmRecord.date,
                                                  mac: nil,
                                                  rssi: realmRecord.rssi.value,
                                                  temperature: realmRecord.unitTemperature,
                                                  humidity: realmRecord.unitHumidity,
                                                  pressure: realmRecord.unitPressure,
                                                  acceleration: realmRecord.acceleration,
                                                  voltage: realmRecord.unitVoltage,
                                                  movementCounter: realmRecord.movementCounter.value,
                                                  measurementSequenceNumber: realmRecord.measurementSequenceNumber.value,
                                                  txPower: realmRecord.txPower.value)
            }
            promise.succeed(value: result)
        }
        return promise.future
    }

    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RUError> {
        assert(ruuviTag.mac == nil)
        assert(ruuviTag.luid != nil)
        let promise = Promise<RuuviTagSensorRecord?, RUError>()
        guard let luid = ruuviTag.luid else {
            promise.fail(error: .unexpected(.attemptToReadDataFromRealmWithoutLUID))
            return promise.future
        }

        context.bgWorker.enqueue {
            let realmRecords = self.context.bg.objects(RuuviTagDataRealm.self)
                                   .filter("ruuviTag.uuid == %@", luid)
                                   .sorted(byKeyPath: "date", ascending: false)
            if let record = realmRecords.first {
                let result = RuuviTagSensorRecordStruct(ruuviTagId: luid,
                                                       date: record.date,
                                                       mac: nil,
                                                       rssi: record.rssi.value,
                                                       temperature: record.unitTemperature,
                                                       humidity: record.unitHumidity,
                                                       pressure: record.unitPressure,
                                                       acceleration: record.acceleration,
                                                       voltage: record.unitVoltage,
                                                       movementCounter: record.movementCounter.value,
                                                       measurementSequenceNumber: record.measurementSequenceNumber.value,
                                                       txPower: record.txPower.value)
                promise.succeed(value: result)
            } else {
                promise.succeed(value: nil)
            }
        }
        return promise.future
    }

    @discardableResult
    func persist(ruuviTagData: RuuviTagDataRealm, realm: Realm) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        do {
            try autoreleasepool {
                try realm.write {
                    realm.add(ruuviTagData, update: .modified)
                }
                promise.succeed(value: true)
            }
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    @discardableResult
    func persist(ruuviTag: RuuviTagRealmProtocol, data: RuuviTag) -> Future<RuuviTag, RUError> {
        let promise = Promise<RuuviTag, RUError>()
        if ruuviTag.realm == context.bg,
            let existingTag = ruuviTag as? RuuviTagRealm {
            context.bgWorker.enqueue {
                do {
                    try autoreleasepool {
                        let tagData = RuuviTagDataRealm(ruuviTag: existingTag, data: data)
                        try self.context.bg.write {
                            self.context.bg.add(tagData)
                        }
                        promise.succeed(value: data)
                    }
                } catch {
                    promise.fail(error: .persistence(error))
                }
            }
        } else {
            do {
                try autoreleasepool {
                    guard let existingTag = ruuviTag as? RuuviTagRealm else {
                        throw RUError.persistence(RUError.unexpected(.callbackErrorAndResultAreNil))

                    }
                    let tagData = RuuviTagDataRealm(ruuviTag: existingTag, data: data)
                    try ruuviTag.realm?.write {
                        self.context.main.add(tagData)
                    }
                    promise.succeed(value: data)
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future

    }

    func persist(ruuviTag: RuuviTag,
                 name: String,
                 humidityOffset: Double,
                 humidityOffsetDate: Date?) -> Future<RuuviTag, RUError> {
        let promise = Promise<RuuviTag, RUError>()
        context.bgWorker.enqueue {
            do {
                try autoreleasepool {
                    if let existingTag = self.fetch(uuid: ruuviTag.uuid) {
                        try self.context.bg.write {
                            if existingTag.isInvalidated {
                                let realmTag = RuuviTagRealm(ruuviTag: ruuviTag, name: name)
                                realmTag.humidityOffset = humidityOffset
                                realmTag.humidityOffsetDate = humidityOffsetDate
                                self.context.bg.add(realmTag, update: .all)
                                let tagData = RuuviTagDataRealm(ruuviTag: realmTag, data: ruuviTag)
                                self.context.bg.add(tagData)
                            } else {
                                guard let tag = existingTag as? RuuviTagRealm else {
                                    promise.fail(error: .persistence(RUError.unexpected(.callbackErrorAndResultAreNil)))
                                    return
                                }
                                tag.name = name
                                tag.humidityOffset = humidityOffset
                                tag.humidityOffsetDate = humidityOffsetDate
                                if tag.version != ruuviTag.version {
                                    tag.version = ruuviTag.version
                                }
                                if tag.mac != ruuviTag.mac {
                                    tag.mac = ruuviTag.mac
                                }
                                let tagData = RuuviTagDataRealm(ruuviTag: tag, data: ruuviTag)
                                self.context.bg.add(tagData)
                            }
                        }
                    } else {
                        let realmTag = RuuviTagRealm(ruuviTag: ruuviTag, name: name)
                        realmTag.humidityOffset = humidityOffset
                        realmTag.humidityOffsetDate = humidityOffsetDate
                        let tagData = RuuviTagDataRealm(ruuviTag: realmTag, data: ruuviTag)
                        try self.context.bg.write {
                            self.context.bg.add(realmTag, update: .all)
                            self.context.bg.add(tagData)
                        }
                    }
                    promise.succeed(value: ruuviTag)
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }

        return promise.future
    }

    func delete(ruuviTag: RuuviTagRealmProtocol) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        if ruuviTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try autoreleasepool {
                        try self.context.bg.write {
                            self.context.bg.delete(ruuviTag)
                        }
                        promise.succeed(value: true)
                    }
                } catch {
                    promise.fail(error: .persistence(error))
                }
            }
        } else {
            do {
                try context.main.write {
                    self.context.main.delete(ruuviTag)
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    func clearHumidityCalibration(of ruuviTag: RuuviTagRealmProtocol) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        if ruuviTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try autoreleasepool {
                        try self.context.bg.write {
                            ruuviTag.humidityOffset = 0
                            ruuviTag.humidityOffsetDate = nil
                        }
                        promise.succeed(value: true)
                    }
                } catch {
                    promise.fail(error: .persistence(error))
                }
            }
        } else {
            do {
                try context.main.write {
                    ruuviTag.humidityOffset = 0
                    ruuviTag.humidityOffsetDate = nil
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    private func fetch(uuid: String) -> RuuviTagRealmProtocol? {
        return context.bg.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid)
    }

    func persist(logs: [RuuviTagEnvLogFull], for uuid: String) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        context.bgWorker.enqueue {
            do {
                try autoreleasepool {
                    if let existingTag = self.fetch(uuid: uuid) {
                        try self.context.bg.write {
                            if !existingTag.isInvalidated,
                                let existingTag = existingTag as? RuuviTagRealm {
                                for log in logs {
                                    let tagData = RuuviTagDataRealm(ruuviTag: existingTag, data: log)
                                    self.context.bg.add(tagData, update: .modified)
                                }
                                promise.succeed(value: true)
                            } else {
                                promise.fail(error: .core(.objectInvalidated))
                            }
                        }
                    } else {
                        promise.fail(error: .core(.objectNotFound))
                    }
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }

        return promise.future
    }

    func clearHistory(uuid: String) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        context.bgWorker.enqueue {
            do {
                try autoreleasepool {
                    if let existingTag = self.fetch(uuid: uuid) {
                        try self.context.bg.write {
                            if !existingTag.isInvalidated {
                                self.context.bg.delete(existingTag.data)
                                promise.succeed(value: true)
                            } else {
                                promise.fail(error: .core(.objectInvalidated))
                            }
                        }
                    } else {
                        promise.fail(error: .core(.objectNotFound))
                    }
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }

        return promise.future
    }
}

// MARK: - Update
extension RuuviTagPersistenceRealm {
    @discardableResult
    func update(mac: String?, of ruuviTag: RuuviTagRealmProtocol, realm: Realm) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        do {
            try autoreleasepool {
                try realm.write {
                    ruuviTag.mac = mac
                }
                promise.succeed(value: true)
            }
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    func update(humidityOffset: Double, date: Date, of ruuviTag: RuuviTagRealmProtocol) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        if ruuviTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try autoreleasepool {
                        try self.context.bg.write {
                            ruuviTag.humidityOffset = humidityOffset
                            ruuviTag.humidityOffsetDate = date
                        }
                        promise.succeed(value: true)
                    }
                } catch {
                    promise.fail(error: .persistence(error))
                }
            }
        } else {
            do {
                try context.main.write {
                    ruuviTag.humidityOffset = humidityOffset
                    ruuviTag.humidityOffsetDate = date
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    func update(name: String, of ruuviTag: RuuviTagRealmProtocol) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        if ruuviTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try autoreleasepool {
                        try self.context.bg.write {
                            ruuviTag.name = name
                        }
                        promise.succeed(value: true)
                    }
                } catch {
                    promise.fail(error: .persistence(error))
                }
            }
        } else {
            do {
                try context.main.write {
                    ruuviTag.name = name
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    @discardableResult
    func update(isConnectable: Bool, of ruuviTag: RuuviTagRealmProtocol, realm: Realm) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        do {
            try autoreleasepool {
                try realm.write {
                    ruuviTag.isConnectable = isConnectable
                }
                promise.succeed(value: true)
            }
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    @discardableResult
    func update(version: Int, of ruuviTag: RuuviTagRealmProtocol, realm: Realm) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        do {
            try autoreleasepool {
                try realm.write {
                    ruuviTag.version = version
                }
                promise.succeed(value: true)
            }
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }
}
