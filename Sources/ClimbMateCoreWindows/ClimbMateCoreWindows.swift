import Foundation
import ClimbMateCore

public enum ClimbMateCoreWindows {
    public static let defaultConfiguration = PlatformBuildConfiguration.windows
}

public struct WindowsVideoRecord: Codable, Sendable {
    public let id: String
    public let createdAt: Date
    public let containerFormat: VideoContainerFormat
    public let routeType: RouteType
    public let grade: String
    public let markers: [NoteMarker]

    public init(
        id: String,
        createdAt: Date,
        containerFormat: VideoContainerFormat,
        routeType: RouteType,
        grade: String,
        markers: [NoteMarker] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.containerFormat = containerFormat
        self.routeType = routeType
        self.grade = grade
        self.markers = markers
    }

    public func toAsset() throws -> VideoAsset {
        let tag = try VideoTag(routeType: routeType, grade: grade)
        return VideoAsset(
            id: id,
            createdAt: createdAt,
            containerFormat: containerFormat,
            tags: [tag],
            markers: markers
        )
    }
}

public enum WindowsStoreError: Error {
    case invalidRecord
}

public struct WindowsVideoStore: Sendable {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load(from url: URL) throws -> [WindowsVideoRecord] {
        guard FileManager.default.fileExists(atPath: url.path()) else {
            return []
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode([WindowsVideoRecord].self, from: data)
    }

    public func save(_ records: [WindowsVideoRecord], to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try encoder.encode(records)
        try data.write(to: url, options: .atomic)
    }
}

public struct WindowsVideoService: Sendable {
    public init() {}

    public func listAssets(records: [WindowsVideoRecord]) throws -> [VideoAsset] {
        try records.map { try $0.toAsset() }
    }

    public func filterAssets(
        records: [WindowsVideoRecord],
        routeType: RouteType?,
        grade: String?,
        startDate: Date?,
        endDate: Date?
    ) throws -> [VideoAsset] {
        var assets = try listAssets(records: records)

        assets = VideoLibrary(videos: assets).compatible(with: ClimbMateCoreWindows.defaultConfiguration)

        var tags = Set<VideoTag>()
        if let routeType, let grade {
            tags.insert(try VideoTag(routeType: routeType, grade: grade))
        }

        let query = VideoFilterQuery(tags: tags, startDate: startDate, endDate: endDate)
        return VideoLibrary(videos: assets).filter(using: query)
    }

    public func sampleRecords(now: Date = Date()) -> [WindowsVideoRecord] {
        [
            WindowsVideoRecord(id: "win-001", createdAt: now, containerFormat: .mp4, routeType: .sport, grade: "5.10a"),
            WindowsVideoRecord(id: "win-002", createdAt: now.addingTimeInterval(-86400), containerFormat: .mov, routeType: .bouldering, grade: "V4")
        ]
    }
}
