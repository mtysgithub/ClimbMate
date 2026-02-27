import XCTest
@testable import ClimbMateCore

final class ClimbMateCoreTests: XCTestCase {
    func testRouteTypeProvidesDifferentGradeOptions() {
        XCTAssertEqual(RouteType.sport.gradeOptions.first, "5.8")
        XCTAssertEqual(RouteType.sport.gradeOptions.last, "5.14d")

        XCTAssertEqual(RouteType.bouldering.gradeOptions.first, "V0")
        XCTAssertEqual(RouteType.bouldering.gradeOptions.last, "V16")
    }

    func testInvalidGradeRejectedByTagFactory() {
        XCTAssertThrowsError(try VideoTag(routeType: .sport, grade: "V5"))
    }

    func testFilterByTagAndDateRange() throws {
        let calendar = Calendar(identifier: .gregorian)
        let jan1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let jan10 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!
        let jan20 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 20))!

        let sportTag = try VideoTag(routeType: .sport, grade: "5.11a")
        let boulderTag = try VideoTag(routeType: .bouldering, grade: "V6")

        let videos: [VideoAsset] = [
            VideoAsset(id: "a", createdAt: jan1, tags: [sportTag], markers: []),
            VideoAsset(id: "b", createdAt: jan10, tags: [sportTag, boulderTag], markers: []),
            VideoAsset(id: "c", createdAt: jan20, tags: [boulderTag], markers: [])
        ]

        let query = VideoFilterQuery(
            tags: [sportTag],
            startDate: jan5(calendar: calendar),
            endDate: jan15(calendar: calendar)
        )

        let result = VideoLibrary(videos: videos).filter(using: query)
        XCTAssertEqual(result.map(\ .id), ["b"])
    }

    func testFilterByPlatformConfiguration() throws {
        let now = Date()
        let sportTag = try VideoTag(routeType: .sport, grade: "5.10a")
        let videos = [
            VideoAsset(id: "mov", createdAt: now, containerFormat: .mov, tags: [sportTag], markers: []),
            VideoAsset(id: "mp4", createdAt: now, containerFormat: .mp4, tags: [sportTag], markers: [])
        ]

        let iOSCompatible = VideoLibrary(videos: videos).compatible(with: .iOS)
        let windowsCompatible = VideoLibrary(videos: videos).compatible(with: .windows)

        XCTAssertEqual(iOSCompatible.map(\ .id), ["mov", "mp4"])
        XCTAssertEqual(windowsCompatible.map(\ .id), ["mov", "mp4"])
        XCTAssertEqual(PlatformBuildConfiguration.iOS.defaultImportContainer, .mov)
        XCTAssertEqual(PlatformBuildConfiguration.windows.defaultImportContainer, .mp4)
    }

    func testMarkersAreSortedAndNavigable() {
        let timeline = NoteTimeline(markers: [
            NoteMarker(id: "m2", atSecond: 30, text: "top hold", imagePath: nil),
            NoteMarker(id: "m1", atSecond: 10, text: "start foot", imagePath: "a.png"),
            NoteMarker(id: "m3", atSecond: 45, text: "dyno", imagePath: nil)
        ])

        XCTAssertEqual(timeline.markers.map(\ .id), ["m1", "m2", "m3"])
        XCTAssertEqual(timeline.nextMarker(after: 10)?.id, "m2")
        XCTAssertEqual(timeline.previousMarker(before: 30)?.id, "m1")
    }

    func testPauseOnMarkerPlaybackStopsAtMarkerUntilResumed() {
        let timeline = NoteTimeline(markers: [
            NoteMarker(id: "m1", atSecond: 15, text: "crux", imagePath: nil)
        ])

        var controller = PlaybackController(mode: .pauseOnMarker, timeline: timeline)

        let tick1 = controller.advance(from: 12, to: 20)
        XCTAssertEqual(tick1.state, .pausedAtMarker)
        XCTAssertEqual(tick1.currentSecond, 15)
        XCTAssertEqual(tick1.markerID, "m1")

        let resumed = controller.resume(afterMarkerID: "m1", from: 15, to: 20)
        XCTAssertEqual(resumed.state, .playing)
        XCTAssertEqual(resumed.currentSecond, 20)
    }

    func testSeekAllowedInAllPlaybackModes() {
        let timeline = NoteTimeline(markers: [
            NoteMarker(id: "m1", atSecond: 5, text: "entry", imagePath: nil)
        ])

        var pauseMode = PlaybackController(mode: .pauseOnMarker, timeline: timeline)
        let seekResult = pauseMode.seek(to: 100)

        XCTAssertEqual(seekResult.currentSecond, 100)
        XCTAssertEqual(seekResult.state, .playing)
    }

    private func jan5(calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
    }

    private func jan15(calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    }
}
