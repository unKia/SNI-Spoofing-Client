import Foundation

class XrayManager: ObservableObject {
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var isRunning = false
    @Published var lastStatusMessage = "Xray idle"
    
    private var xrayProcess: Process?
    private let outputLock = NSLock()
    private var recentOutput = ""
    
    static let shared = XrayManager()
    
    private let xrayBaseURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/SniSpoofingMac", isDirectory: true)
    
    private var xrayBinaryURL: URL {
        xrayBaseURL.appendingPathComponent("xray")
    }
    
    private var xrayConfigURL: URL {
        xrayBaseURL.appendingPathComponent("xray-config.json")
    }

    private var bundledXrayURL: URL? {
        if let exactName = Bundle.main.url(forResource: "xray", withExtension: "bin") {
            return exactName
        }

        return Bundle.main.url(forResource: "xray", withExtension: nil)
    }
    
    var isXrayInstalled: Bool {
        FileManager.default.fileExists(atPath: xrayBinaryURL.path)
            && FileManager.default.isExecutableFile(atPath: xrayBinaryURL.path)
    }
    
    func ensureXrayInstalled() async throws {
        if isXrayInstalled { return }
        
        await MainActor.run { isDownloading = true }
        defer { Task { @MainActor in isDownloading = false } }
        
        try? FileManager.default.createDirectory(at: xrayBaseURL, withIntermediateDirectories: true)
        
        // Extract Xray from app bundle
        guard let bundledXrayURL else {
            throw NSError(domain: "XrayManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Xray binary is missing from the application bundle."])
        }

        if FileManager.default.fileExists(atPath: xrayBinaryURL.path) {
            try FileManager.default.removeItem(at: xrayBinaryURL)
        }
        
        // Copy to Application Support
        try FileManager.default.copyItem(at: bundledXrayURL, to: xrayBinaryURL)
        
        // Make binary executable
        let chmod = Process()
        chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmod.arguments = ["+x", xrayBinaryURL.path]
        try chmod.run()
        chmod.waitUntilExit()
        await MainActor.run {
            self.lastStatusMessage = "Xray binary prepared"
        }
    }
    
    func start(configString: String) throws {
        stop()
        
        try configString.write(to: xrayConfigURL, atomically: true, encoding: .utf8)
        
        let process = Process()
        process.executableURL = xrayBinaryURL
        process.arguments = ["run", "-c", xrayConfigURL.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        recentOutput = ""
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else {
                return
            }
            self?.appendOutput(chunk)
        }
        
        try process.run()

        // If Xray exits immediately, surface the startup error instead of silently
        // continuing with the native helper only.
        Thread.sleep(forTimeInterval: 0.7)
        if !process.isRunning {
            pipe.fileHandleForReading.readabilityHandler = nil
            let output = drainOutput(from: pipe).trimmingCharacters(in: .whitespacesAndNewlines)
            let message = output.isEmpty ? "Xray exited immediately after launch." : output
            throw NSError(domain: "XrayManager", code: 3, userInfo: [NSLocalizedDescriptionKey: message])
        }

        xrayProcess = process
        
        DispatchQueue.main.async {
            self.isRunning = true
            self.lastStatusMessage = "Xray is running"
        }
        
        process.terminationHandler = { [weak self] _ in
            pipe.fileHandleForReading.readabilityHandler = nil
            _ = self?.drainOutput(from: pipe)
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.lastStatusMessage = "Xray stopped"
            }
        }
    }
    
    func stop() {
        if let process = xrayProcess, process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        xrayProcess = nil
        DispatchQueue.main.async {
            self.isRunning = false
            self.lastStatusMessage = "Xray stopped"
        }
    }

    func recentOutputSnapshot() -> String {
        outputLock.lock()
        defer { outputLock.unlock() }
        return recentOutput
    }

    private func appendOutput(_ chunk: String) {
        outputLock.lock()
        defer { outputLock.unlock() }
        recentOutput += chunk
        if recentOutput.count > 8192 {
            recentOutput = String(recentOutput.suffix(8192))
        }
    }

    private func drainOutput(from pipe: Pipe) -> String {
        let trailingData = pipe.fileHandleForReading.availableData
        if !trailingData.isEmpty, let chunk = String(data: trailingData, encoding: .utf8) {
            appendOutput(chunk)
        }

        outputLock.lock()
        defer { outputLock.unlock() }
        return recentOutput
    }
}
