import Foundation

enum SecureConfig {
    static func value(for key: String) -> String? {
        if let envValue = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !envValue.isEmpty {
            return envValue
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let trimmed = plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if let xcconfigValue = valueFromBundledSecretsXCConfig(for: key) {
            return xcconfigValue
        }

        return nil
    }

    private static func valueFromBundledSecretsXCConfig(for key: String) -> String? {
        guard
            let path = Bundle.main.path(forResource: "Secrets", ofType: "xcconfig"),
            let contents = try? String(contentsOfFile: path, encoding: .utf8)
        else {
            return nil
        }

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("//") || line.hasPrefix("#") {
                continue
            }

            let parts = line.split(separator: "=", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            guard parts.count == 2 else { continue }
            if parts[0] == key, !parts[1].isEmpty {
                return parts[1]
            }
        }

        return nil
    }
}

enum NetworkSecurity {
    static let allowedAIHosts: Set<String> = [
        "api.openai.com",
        "api.groq.com",
        "generativelanguage.googleapis.com"
    ]

    static func validateSecureURL(_ url: URL, allowedHosts: Set<String>) throws {
        guard url.scheme?.lowercased() == "https" else {
            throw APIServiceError.insecureTransport
        }

        guard let host = url.host?.lowercased(), allowedHosts.contains(host) else {
            throw APIServiceError.untrustedHost
        }
    }
}
