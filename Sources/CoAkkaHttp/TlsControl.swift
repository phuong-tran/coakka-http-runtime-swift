import CCoAkkaManagedHost

// The Swift importer does not expose the ABI header’s UINT32_C constants.

/// Transport security of a secure listener.
public struct TlsSecurity: RawRepresentable, Equatable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let tls = Self(rawValue: 2)
    public static let mutualTls = Self(rawValue: 3)
}

/// Controls how Core handles connections using older credentials.
public struct TlsReloadMode: RawRepresentable, Equatable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let graceful = Self(rawValue: 0)
    public static let drainExisting = Self(rawValue: 1)
}

/// The outcome of attempting to publish credentials in Core.
public struct TlsReloadReason: RawRepresentable, Equatable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let applied = Self(rawValue: 0)
    public static let invalidCredential = Self(rawValue: 1)
    public static let securityChange = Self(rawValue: 2)
    public static let staleGeneration = Self(rawValue: 3)
    public static let generationConflict = Self(rawValue: 4)
    public static let busy = Self(rawValue: 5)
    public static let retainedCapacity = Self(rawValue: 6)
    public static let preparationRejected = Self(rawValue: 7)
    public static let outOfMemory = Self(rawValue: 8)
    public static let closed = Self(rawValue: 9)
    public static let internalError = Self(rawValue: 10)
}

/// File-backed credentials to publish if the expected generation still matches.
public struct TlsReloadRequest: Sendable {
    public let expectedGeneration: UInt64
    public let security: TlsSecurity
    public let credentials: TlsOptions
    public let mode: TlsReloadMode

    public init(expectedGeneration: UInt64, security: TlsSecurity, credentials: TlsOptions,
                mode: TlsReloadMode = .graceful) {
        self.expectedGeneration = expectedGeneration
        self.security = security
        self.credentials = credentials
        self.mode = mode
    }
}

/// Core's effective credential state. No credential paths or key material are returned.
public struct TlsCredentials: Sendable {
    public let security: TlsSecurity
    public let reloadMode: TlsReloadMode
    public let generation: UInt64
    public let credentialID: String
    public let drainBeforeGeneration: UInt64
    public let retiredGenerations: UInt32
    public let maximumRetiredGenerations: UInt32
    public let closed: Bool
    public let preparing: Bool

    fileprivate init(_ snapshot: coakka_http_host_tls_credentials_t) throws {
        security = TlsSecurity(rawValue: snapshot.security)
        reloadMode = TlsReloadMode(rawValue: snapshot.reload_mode)
        generation = snapshot.generation
        credentialID = try withUnsafeBytes(of: snapshot.credential_id) { bytes in
            guard let end = bytes.firstIndex(of: 0) else { throw CoreStatus.invalidArgument }
            return String(decoding: bytes.prefix(end), as: UTF8.self)
        }
        drainBeforeGeneration = snapshot.drain_before_generation
        retiredGenerations = snapshot.retired_generations
        maximumRetiredGenerations = snapshot.maximum_retired_generations
        closed = snapshot.closed != 0
        preparing = snapshot.preparing != 0
    }
}

/// A publication attempt and the effective state reported by Core, including on refusal.
public struct TlsReloadOutcome: Sendable {
    public let reason: TlsReloadReason
    public let changed: Bool
    public let effective: TlsCredentials
}

extension HttpService {
    /// Reads the effective credential state from Core.
    public func readTlsCredentials() throws -> TlsCredentials {
        try lock.withLock {
            var snapshot = coakka_http_host_tls_credentials_t()
            try Self.check(coakka_managed_tls_credentials(try handle(), &snapshot))
            return try TlsCredentials(snapshot)
        }
    }

    /// Synchronously prepares and attempts to publish a new credential generation.
    /// Inspect the returned reason for refusal. Success does not wait for peer retirement.
    public func reloadTls(_ request: TlsReloadRequest) throws -> TlsReloadOutcome {
        let arguments = NativeArguments()
        let credentials = request.credentials
        let id = try arguments.add(credentials.credentialID)
        let certificate = try arguments.add(credentials.certificateChainFile)
        let key = try arguments.add(credentials.privateKeyFile)
        let trustRoots = try arguments.add(credentials.clientTrustRootsFile)
        return try lock.withLock {
            var outcome = coakka_http_host_tls_reload_outcome_t()
            // The C descriptor holds borrowed spans, so the arena must outlive the call.
            try withExtendedLifetime(arguments) {
                try Self.check(coakka_managed_reload_tls(try handle(), request.security.rawValue,
                    request.mode.rawValue, request.expectedGeneration, credentials.generation,
                    id, certificate, key, trustRoots, &outcome))
            }
            return try TlsReloadOutcome(reason: TlsReloadReason(rawValue: outcome.reason),
                changed: outcome.changed != 0, effective: TlsCredentials(outcome.effective))
        }
    }
}
