import XCTest
@testable import PlataCore

final class BackupRotationTests: XCTestCase {
    func testFileNameUsesLocalDate() {
        XCTAssertEqual(BackupRotation.fileName(for: fecha(2026, 10, 4, 23, 30), calendar: bogota), "PlataClara-2026-10-04.json")
    }

    func testRecognizesOnlyOwnFiles() {
        XCTAssertTrue(BackupRotation.isBackupFile("PlataClara-2026-10-04.json"))
        XCTAssertFalse(BackupRotation.isBackupFile("foto.json"))
        XCTAssertFalse(BackupRotation.isBackupFile("PlataClara-respaldo-2026-10-04.json"))
        XCTAssertFalse(BackupRotation.isBackupFile("PlataClara-2026-10-04.json.icloud"))
    }

    func testKeepsNewestAndDeletesOlder() {
        let names = (1...10).map { "PlataClara-2026-10-\(String(format: "%02d", $0)).json" } + ["notas.txt"]
        let toDelete = BackupRotation.filesToDelete(names: names, keep: 7)
        XCTAssertEqual(Set(toDelete), ["PlataClara-2026-10-01.json", "PlataClara-2026-10-02.json", "PlataClara-2026-10-03.json"])
    }

    func testNothingToDeleteWhenFewFiles() {
        XCTAssertEqual(BackupRotation.filesToDelete(names: ["PlataClara-2026-10-01.json"], keep: 7), [])
    }

    func testLatestPicksNewestDate() {
        XCTAssertEqual(BackupRotation.latest(names: ["x.json", "PlataClara-2026-09-30.json", "PlataClara-2026-10-02.json"]),
                       "PlataClara-2026-10-02.json")
        XCTAssertNil(BackupRotation.latest(names: ["x.json"]))
    }

    func testNeverWritesEmptyBackup() {
        XCTAssertFalse(BackupRotation.shouldWrite(accounts: 0, movements: 0))
        XCTAssertTrue(BackupRotation.shouldWrite(accounts: 1, movements: 0))
        XCTAssertTrue(BackupRotation.shouldWrite(accounts: 0, movements: 3))
    }
}
