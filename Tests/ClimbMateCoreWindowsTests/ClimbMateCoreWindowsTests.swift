import XCTest
@testable import ClimbMateCore
@testable import ClimbMateCoreWindows

final class ClimbMateCoreWindowsTests: XCTestCase {
    func testStoreRoundTrip() throws {
        let store = WindowsVideoStore()
        let service = WindowsVideoService()
        let records = service.sampleRecords(now: Date(timeIntervalSince1970: 1_700_000_000))

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = tempDir.appendingPathComponent("climbmate_windows_store_test.json")

        try store.save(records, to: fileURL)
        let loaded = try store.load(from: fileURL)

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.first?.containerFormat, .mp4)
    }

    func testFilterAssetsByRouteAndGrade() throws {
        let service = WindowsVideoService()
        let records = [
            WindowsVideoRecord(id: "1", createdAt: Date(), containerFormat: .mp4, routeType: .sport, grade: "5.10a"),
            WindowsVideoRecord(id: "2", createdAt: Date(), containerFormat: .mov, routeType: .bouldering, grade: "V4")
        ]

        let result = try service.filterAssets(
            records: records,
            routeType: .sport,
            grade: "5.10a",
            startDate: nil,
            endDate: nil
        )

        XCTAssertEqual(result.map(\ .id), ["1"])
    }

    func testManagerCanBeUsedByWindowsAdapter() throws {
        let service = WindowsVideoService()
        let records = service.sampleRecords(now: Date(timeIntervalSince1970: 1_700_000_000))
        let assets = try service.listAssets(records: records)

        let manager = CoreVideoManager(platformConfiguration: ClimbMateCoreWindows.defaultConfiguration)
        let compatible = manager.compatibleVideos(from: assets)

        XCTAssertEqual(compatible.count, 2)
    }
}
