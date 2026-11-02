import Foundation

enum Log {
    static let directory = Bundle.main.bundleURL.deletingLastPathComponent()
    private static let queue = DispatchQueue(label: "log")
    private static let started = Date()
    private static let handle: FileHandle? = {
        let url = directory.appendingPathComponent("spike.log")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let file = try? FileHandle(forWritingTo: url)
        _ = try? file?.seekToEnd()
        return file
    }()

    static func write(_ message: String) {
        let line = String(format: "%9.3f %@\n", Date().timeIntervalSince(started), message)
        // Synchronous so the last lines survive a crash or the timeout's exit().
        queue.sync { try? handle?.write(contentsOf: Data(line.utf8)) }
    }
}
