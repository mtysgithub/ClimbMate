import Foundation

public enum RouteType: String, Codable, CaseIterable, Sendable {
    case sport
    case bouldering

    public var gradeOptions: [String] {
        switch self {
        case .sport:
            return ["5.8", "5.9", "5.10a", "5.10b", "5.10c", "5.10d", "5.11a", "5.11b", "5.11c", "5.11d", "5.12a", "5.12b", "5.12c", "5.12d", "5.13a", "5.13b", "5.13c", "5.13d", "5.14a", "5.14b", "5.14c", "5.14d"]
        case .bouldering:
            return (0...16).map { "V\($0)" }
        }
    }
}

public enum VideoContainerFormat: String, Codable, CaseIterable, Sendable {
    case mov
    case mp4
}

public enum AppPlatform: String, Codable, Sendable {
    case ios
    case windows
}

public struct PlatformBuildConfiguration: Equatable, Codable, Sendable {
    public let platform: AppPlatform
    public let supportedContainers: Set<VideoContainerFormat>
    public let defaultImportContainer: VideoContainerFormat

    public init(
        platform: AppPlatform,
        supportedContainers: Set<VideoContainerFormat>,
        defaultImportContainer: VideoContainerFormat
    ) {
        self.platform = platform
        self.supportedContainers = supportedContainers
        self.defaultImportContainer = defaultImportContainer
    }

    public static let iOS = PlatformBuildConfiguration(
        platform: .ios,
        supportedContainers: [.mov, .mp4],
        defaultImportContainer: .mov
    )

    public static let windows = PlatformBuildConfiguration(
        platform: .windows,
        supportedContainers: [.mov, .mp4],
        defaultImportContainer: .mp4
    )

    public func supports(_ format: VideoContainerFormat) -> Bool {
        supportedContainers.contains(format)
    }
}

public enum VideoTagError: Error, Sendable {
    case invalidGradeForRouteType
}

public struct VideoTag: Equatable, Hashable, Codable, Sendable {
    public let routeType: RouteType
    public let grade: String

    public init(routeType: RouteType, grade: String) throws {
        guard routeType.gradeOptions.contains(grade) else {
            throw VideoTagError.invalidGradeForRouteType
        }

        self.routeType = routeType
        self.grade = grade
    }
}

public struct NoteMarker: Equatable, Codable, Sendable {
    public let id: String
    public let atSecond: Int
    public let text: String
    public let imagePath: String?

    public init(id: String, atSecond: Int, text: String, imagePath: String?) {
        self.id = id
        self.atSecond = max(0, atSecond)
        self.text = text
        self.imagePath = imagePath
    }
}

public struct NoteTimeline: Equatable, Sendable {
    public let markers: [NoteMarker]

    public init(markers: [NoteMarker]) {
        self.markers = markers.sorted(by: { $0.atSecond < $1.atSecond })
    }

    public func nextMarker(after second: Int) -> NoteMarker? {
        markers.first(where: { $0.atSecond > second })
    }

    public func previousMarker(before second: Int) -> NoteMarker? {
        markers.last(where: { $0.atSecond < second })
    }

    func firstMarker(in range: ClosedRange<Int>, excluding excludedMarkerID: String?) -> NoteMarker? {
        markers.first {
            range.contains($0.atSecond) && $0.id != excludedMarkerID
        }
    }
}

public struct VideoAsset: Equatable, Codable, Sendable {
    public let id: String
    public let createdAt: Date
    public let containerFormat: VideoContainerFormat
    public let tags: Set<VideoTag>
    public let markers: [NoteMarker]

    public init(
        id: String,
        createdAt: Date,
        containerFormat: VideoContainerFormat = .mov,
        tags: Set<VideoTag>,
        markers: [NoteMarker]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.containerFormat = containerFormat
        self.tags = tags
        self.markers = markers
    }
}

public struct VideoFilterQuery: Sendable {
    public let tags: Set<VideoTag>
    public let startDate: Date?
    public let endDate: Date?

    public init(tags: Set<VideoTag> = [], startDate: Date? = nil, endDate: Date? = nil) {
        self.tags = tags
        self.startDate = startDate
        self.endDate = endDate
    }
}

public struct VideoLibrary: Sendable {
    public let videos: [VideoAsset]

    public init(videos: [VideoAsset]) {
        self.videos = videos
    }

    public func filter(using query: VideoFilterQuery) -> [VideoAsset] {
        videos.filter { video in
            let tagMatch = query.tags.isEmpty || query.tags.isSubset(of: video.tags)
            let dateMatch = dateInRange(video.createdAt, startDate: query.startDate, endDate: query.endDate)
            return tagMatch && dateMatch
        }
    }

    public func compatible(with configuration: PlatformBuildConfiguration) -> [VideoAsset] {
        videos.filter { configuration.supports($0.containerFormat) }
    }

    private func dateInRange(_ date: Date, startDate: Date?, endDate: Date?) -> Bool {
        if let startDate, date < startDate { return false }
        if let endDate, date > endDate { return false }
        return true
    }
}

/// Cross-platform application service for iOS / Windows UI layers.
/// UI can call this shared service without duplicating core logic per platform.
public struct CoreVideoManager: Sendable {
    public let platformConfiguration: PlatformBuildConfiguration

    public init(platformConfiguration: PlatformBuildConfiguration) {
        self.platformConfiguration = platformConfiguration
    }

    public func compatibleVideos(from videos: [VideoAsset]) -> [VideoAsset] {
        VideoLibrary(videos: videos).compatible(with: platformConfiguration)
    }

    public func filteredVideos(from videos: [VideoAsset], query: VideoFilterQuery) -> [VideoAsset] {
        let compatible = compatibleVideos(from: videos)
        return VideoLibrary(videos: compatible).filter(using: query)
    }

    public func addMarker(_ marker: NoteMarker, to video: VideoAsset) -> VideoAsset {
        var updatedMarkers = video.markers
        updatedMarkers.append(marker)
        return VideoAsset(
            id: video.id,
            createdAt: video.createdAt,
            containerFormat: video.containerFormat,
            tags: video.tags,
            markers: updatedMarkers
        )
    }

    public func makePlaybackController(for video: VideoAsset, mode: PlaybackMode) -> PlaybackController {
        PlaybackController(mode: mode, timeline: NoteTimeline(markers: video.markers))
    }
}

public enum PlaybackMode: Sendable {
    case linear
    case pauseOnMarker
}

public enum PlaybackState: Equatable, Sendable {
    case playing
    case pausedAtMarker
}

public struct PlaybackTick: Equatable, Sendable {
    public let currentSecond: Int
    public let state: PlaybackState
    public let markerID: String?
}

public struct PlaybackController: Sendable {
    public let mode: PlaybackMode
    public let timeline: NoteTimeline
    private var consumedMarkerIDs: Set<String> = []

    public init(mode: PlaybackMode, timeline: NoteTimeline) {
        self.mode = mode
        self.timeline = timeline
    }

    public mutating func advance(from start: Int, to end: Int) -> PlaybackTick {
        let normalizedRange = min(start, end)...max(start, end)

        guard mode == .pauseOnMarker,
              let marker = timeline.firstMarker(in: normalizedRange, excluding: nil),
              !consumedMarkerIDs.contains(marker.id)
        else {
            return PlaybackTick(currentSecond: end, state: .playing, markerID: nil)
        }

        return PlaybackTick(currentSecond: marker.atSecond, state: .pausedAtMarker, markerID: marker.id)
    }

    public mutating func resume(afterMarkerID markerID: String, from start: Int, to end: Int) -> PlaybackTick {
        consumedMarkerIDs.insert(markerID)
        return advance(from: start, to: end)
    }

    public mutating func seek(to second: Int) -> PlaybackTick {
        PlaybackTick(currentSecond: max(0, second), state: .playing, markerID: nil)
    }
}
