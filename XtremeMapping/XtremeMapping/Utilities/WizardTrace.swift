// Temporary diagnostic — appends wizard-flow trace messages to
// /tmp/xtreme-wizard-trace.log so we can verify the document-routing
// path end-to-end. Bypasses macOS unified logging because NSLog from
// signed apps is filtered by default. Delete after the wizard "no save
// to open window" bug is closed.
import Foundation

enum WizardTrace {
    // Sandbox-safe: NSTemporaryDirectory() returns the container's tmp.
    // The wrapper symlink at $HOME/Library/Containers/<bundle>/Data/tmp
    // is what file-system browsing tools see.
    private static let path: String = {
        return (NSTemporaryDirectory() as NSString).appendingPathComponent("xtreme-wizard-trace.log")
    }()
    private static let lock = NSLock()
    private static var didLogPath = false

    static func write(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(stamp) [WIZARD-TRACE] \(message)\n"
        if let data = line.data(using: .utf8) {
            let url = URL(fileURLWithPath: path)
            // FileHandle requires the file to exist first
            if !FileManager.default.fileExists(atPath: path) {
                try? data.write(to: url)
                if !didLogPath {
                    didLogPath = true
                    NSLog("[WIZARD-TRACE-PATH] %@", path)
                }
            } else if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        }
    }

    static var logPath: String { path }
}
