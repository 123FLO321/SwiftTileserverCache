import Foundation
import Vapor

public class LeafCacheCleaner {

    private let logger: Logger
    private let folder: URL
    private let app: Application
    private var templates = [String: Date]()

    public init(app: Application, folder: String, clearDelaySeconds: UInt32=60) {
        self.app = app
        self.folder = URL(fileURLWithPath: folder)
        self.logger = Logger(label: "LeafCacheCleaner-\(folder)")
        let thread = DispatchQueue(label: "LeafCacheCleaner-\(folder)")
        thread.async {
            while true {
                self.runOnce()
                sleep(clearDelaySeconds)
            }
        }
    }

    private func runOnce() {
        do {
            try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]).forEach { (url) in
                guard url.pathExtension == "json",
                      let fileName = url.pathComponents.last,
                      let modificationDate = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                        return
                }
                let oldModificationDate = self.templates[fileName]
                if oldModificationDate != nil && modificationDate != oldModificationDate {
                    app.leaf.cache.remove("Templates/\(fileName)", on: app.eventLoopGroup.next()).whenComplete { _ in
                        self.logger.info("Removed \(fileName) from cache because it changed")
                    }
                }
                self.templates[fileName] = modificationDate
            }
        } catch {
            logger.warning("Failed to update templates")
        }
    }

}
