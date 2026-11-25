import Foundation

enum BackendError: LocalizedError {
    case missing(String)
    case failed(String)
    var errorDescription: String? {
        switch self {
        case .missing(let what): return "\(what) could not be found."
        case .failed(let why): return why
        }
    }
}

/// Runs the bundled examination engine (server.py) as a child process and talks to it over localhost.
final class Backend: @unchecked Sendable {
    static let shared = Backend()

    let home = FileManager.default.homeDirectoryForCurrentUser
    var dataDir: URL { home.appendingPathComponent("Library/Application Support/Laurea") }
    var examsDir: URL { dataDir.appendingPathComponent("examinations") }
    var skillDir: URL { home.appendingPathComponent(".claude/skills/dissertation-examiner") }
    var calibrationNotes: URL { skillDir.appendingPathComponent("references/calibration-notes.md") }
    var signatureURL: URL { skillDir.appendingPathComponent("templates/signature.png") }

    private(set) var base: String?
    private var process: Process?
    private let lock = NSLock()

    static func findPython() -> String? {
        let fm = FileManager.default
        let candidates = [
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
            "/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3",
        ]
        return candidates.first { fm.isExecutableFile(atPath: $0) }
    }

    func start() async throws {
        if base != nil { return }
        guard let script = Bundle.main.url(forResource: "server", withExtension: "py") else { throw BackendError.missing("The examination engine (server.py)") }
        guard let python = Self.findPython() else { throw BackendError.missing("Python 3") }
        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        let logURL = dataDir.appendingPathComponent("engine.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: python)
        p.arguments = ["-u", script.path]
        var env = ProcessInfo.processInfo.environment
        env["DE_PORT"] = "0"
        env["DE_DATA"] = dataDir.path
        env["DE_PARENT_PID"] = String(ProcessInfo.processInfo.processIdentifier)
        p.environment = env
        let out = Pipe()
        p.standardOutput = out
        p.standardError = try? FileHandle(forWritingTo: logURL)
        try p.run()
        process = p

        let port: Int = try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global().async {
                let h = out.fileHandleForReading
                var buf = Data()
                while true {
                    let chunk = h.availableData
                    if chunk.isEmpty {
                        cont.resume(throwing: BackendError.failed("The examination engine stopped while starting. See ~/Library/Application Support/Laurea/engine.log."))
                        return
                    }
                    buf.append(chunk)
                    if let s = String(data: buf, encoding: .utf8),
                       let r = s.range(of: #"PORT=\d+"#, options: .regularExpression),
                       let n = Int(s[r].dropFirst(5)) {
                        cont.resume(returning: n)
                        while !h.availableData.isEmpty {}  // keep draining
                        return
                    }
                }
            }
        }
        base = "http://127.0.0.1:\(port)"
    }

    func stop() {
        process?.terminate()
        process = nil
    }

    // MARK: HTTP

    func data(_ method: String, _ path: String, body: Data? = nil, headers: [String: String] = [:], timeout: TimeInterval = 120) async throws -> Data {
        guard let base, let url = URL(string: base + path) else { throw BackendError.failed("The examination engine is not running.") }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method
        req.setValue("1", forHTTPHeaderField: "X-DE-App")
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        req.httpBody = body
        let (d, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
            let msg = (try? JSONSerialization.jsonObject(with: d) as? [String: Any])?["error"] as? String
            throw BackendError.failed(msg ?? "Request failed (\(http.statusCode)).")
        }
        return d
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        try JSONDecoder().decode(T.self, from: try await data("GET", path))
    }

    func send<T: Decodable, B: Encodable>(_ method: String, _ path: String, _ body: B) async throws -> T {
        let d = try await data(method, path, body: try JSONEncoder().encode(body), headers: ["Content-Type": "application/json"])
        return try JSONDecoder().decode(T.self, from: d)
    }

    func post(_ path: String) async throws {
        _ = try await data("POST", path)
    }
}

struct OK: Codable { let ok: Bool? }
