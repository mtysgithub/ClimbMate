import Foundation
import ClimbMateCore
import ClimbMateCoreWindows

enum CLIError: Error {
    case invalidArguments(String)
}

struct ClimbMateWindowsCLI {
    private let store = WindowsVideoStore()
    private let service = WindowsVideoService()

    func run(arguments: [String]) throws {
        guard let command = arguments.dropFirst().first else {
            printHelp()
            return
        }

        switch command {
        case "interactive":
            let file = try requiredOption("--file", in: arguments)
            try interactive(file: file)
        case "init-sample":
            let file = try requiredOption("--file", in: arguments)
            try initializeSample(file: file)
        case "list":
            let file = try requiredOption("--file", in: arguments)
            try list(file: file)
        case "filter":
            let file = try requiredOption("--file", in: arguments)
            let route = optionalOption("--route", in: arguments)
            let grade = optionalOption("--grade", in: arguments)
            let from = optionalOption("--from", in: arguments)
            let to = optionalOption("--to", in: arguments)
            try filter(file: file, route: route, grade: grade, from: from, to: to)
        default:
            throw CLIError.invalidArguments("Unknown command: \(command)")
        }
    }

    private func initializeSample(file: String) throws {
        let url = URL(fileURLWithPath: file)
        try store.save(service.sampleRecords(), to: url)
        print("Sample data created at: \(url.path)")
    }

    private func list(file: String) throws {
        let url = URL(fileURLWithPath: file)
        let records = try store.load(from: url)
        let assets = try service.listAssets(records: records)

        if assets.isEmpty {
            print("No videos found.")
            return
        }

        for asset in assets {
            let tag = asset.tags.first
            print("\(asset.id) | \(asset.containerFormat.rawValue) | \(tag?.routeType.rawValue ?? "unknown") | \(tag?.grade ?? "unknown")")
        }
    }

    private func filter(file: String, route: String?, grade: String?, from: String?, to: String?) throws {
        let url = URL(fileURLWithPath: file)
        let records = try store.load(from: url)

        let routeType = route.flatMap(RouteType.init(rawValue:))
        let startDate = try from.map(parseDate(_:))
        let endDate = try to.map(parseDate(_:))

        let assets = try service.filterAssets(
            records: records,
            routeType: routeType,
            grade: grade,
            startDate: startDate,
            endDate: endDate
        )

        for asset in assets {
            print(asset.id)
        }

        if assets.isEmpty {
            print("No matched videos.")
        }
    }

    private func parseDate(_ raw: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        guard let date = formatter.date(from: raw) else {
            throw CLIError.invalidArguments("Invalid date: \(raw). Use YYYY-MM-DD.")
        }

        return date
    }

    private func interactive(file: String) throws {
        let url = URL(fileURLWithPath: file)
        print("Entering interactive mode. Data file: \(url.path)")

        var shouldQuit = false
        while !shouldQuit {
            print("""

            ===== ClimbMate Windows Interactive =====
            1) Initialize sample data
            2) List videos
            3) Filter by route + grade
            4) Filter by date range
            5) Add marker to a video
            0) Exit
            """)

            guard let choice = readLine(strippingNewline: true) else {
                continue
            }

            switch choice {
            case "1":
                try initializeSample(file: file)
            case "2":
                try list(file: file)
            case "3":
                print("Route (sport/bouldering): ", terminator: "")
                let routeRaw = readLine(strippingNewline: true) ?? ""
                print("Grade (e.g. 5.10a or V4): ", terminator: "")
                let grade = readLine(strippingNewline: true) ?? ""
                try filter(file: file, route: routeRaw, grade: grade, from: nil, to: nil)
            case "4":
                print("From date (YYYY-MM-DD): ", terminator: "")
                let from = readLine(strippingNewline: true)
                print("To date (YYYY-MM-DD): ", terminator: "")
                let to = readLine(strippingNewline: true)
                try filter(file: file, route: nil, grade: nil, from: from, to: to)
            case "5":
                try addMarker(file: file)
            case "0":
                shouldQuit = true
                print("Bye.")
            default:
                print("Unknown option: \(choice)")
            }
        }
    }

    private func addMarker(file: String) throws {
        let url = URL(fileURLWithPath: file)
        var records = try store.load(from: url)

        if records.isEmpty {
            print("No videos found. Run init-sample first.")
            return
        }

        print("Video ID: ", terminator: "")
        let videoID = readLine(strippingNewline: true) ?? ""
        print("At second (int): ", terminator: "")
        let secondRaw = readLine(strippingNewline: true) ?? "0"
        print("Marker text: ", terminator: "")
        let text = readLine(strippingNewline: true) ?? ""

        guard let index = records.firstIndex(where: { $0.id == videoID }) else {
            print("Video not found: \(videoID)")
            return
        }

        let second = Int(secondRaw) ?? 0
        let marker = NoteMarker(
            id: UUID().uuidString,
            atSecond: second,
            text: text,
            imagePath: nil
        )

        let old = records[index]
        records[index] = WindowsVideoRecord(
            id: old.id,
            createdAt: old.createdAt,
            containerFormat: old.containerFormat,
            routeType: old.routeType,
            grade: old.grade,
            markers: old.markers + [marker]
        )

        try store.save(records, to: url)
        print("Marker added to \(videoID).")
    }

    private func requiredOption(_ name: String, in arguments: [String]) throws -> String {
        guard let value = optionalOption(name, in: arguments) else {
            throw CLIError.invalidArguments("Missing required option: \(name)")
        }
        return value
    }

    private func optionalOption(_ name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }

    private func printHelp() {
        print("""
        ClimbMateWindowsCLI

        Commands:
          interactive --file <path>
          init-sample --file <path>
          list --file <path>
          filter --file <path> [--route sport|bouldering] [--grade <grade>] [--from YYYY-MM-DD] [--to YYYY-MM-DD]
        """)
    }
}

do {
    try ClimbMateWindowsCLI().run(arguments: CommandLine.arguments)
} catch {
    let message = "Error: \(error)\n"
    if let data = message.data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
    exit(1)
}
