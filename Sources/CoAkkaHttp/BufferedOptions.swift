import CCoAkkaManagedHost
import Foundation

public enum HttpProtocol: UInt32, Sendable {
    case http11 = 1
    case http2 = 2
    case http3 = 3
}

public struct TlsOptions: Sendable {
    public let credentialID: String
    public let generation: UInt64
    public let certificateChainFile: String
    public let privateKeyFile: String
    public let clientTrustRootsFile: String?

    public init(credentialID: String, generation: UInt64, certificateChainFile: String,
                privateKeyFile: String, clientTrustRootsFile: String? = nil) {
        self.credentialID = credentialID
        self.generation = generation
        self.certificateChainFile = certificateChainFile
        self.privateKeyFile = privateKeyFile
        self.clientTrustRootsFile = clientTrustRootsFile
    }
}

public enum HttpListener: Sendable {
    case standalone(protocol: HttpProtocol? = nil, address: String? = nil, port: UInt16 = 0, tls: TlsOptions? = nil)
    case multiProtocolListener(tls: TlsOptions, address: String? = nil, port: UInt16 = 0)
}

public struct BufferedBodyPolicy: Sendable {
    public let maxBodyBytes: UInt64
    public let acceptAbsent: Bool
    public let acceptOther: Bool
    public let acceptFormURLEncoded: Bool
    public let acceptMultipartFormData: Bool

    public init(maxBodyBytes: UInt64, acceptAbsent: Bool = false, acceptOther: Bool = false,
                acceptFormURLEncoded: Bool = false, acceptMultipartFormData: Bool = false) {
        self.maxBodyBytes = maxBodyBytes
        self.acceptAbsent = acceptAbsent
        self.acceptOther = acceptOther
        self.acceptFormURLEncoded = acceptFormURLEncoded
        self.acceptMultipartFormData = acceptMultipartFormData
    }
}

public enum RequestBodyMode: Sendable {
    case buffered
    case streaming
}

public struct HttpRoute: Sendable {
    public let routeID: UInt64
    public let bindingID: UInt64
    public let method: String
    public let pattern: String
    public let bodyPolicy: BufferedBodyPolicy?
    public let bodyMode: RequestBodyMode
    public let webSocket: Bool

    public init(routeID: UInt64, bindingID: UInt64, method: String, pattern: String,
                bodyPolicy: BufferedBodyPolicy? = nil, bodyMode: RequestBodyMode = .buffered,
                webSocket: Bool = false) {
        self.routeID = routeID
        self.bindingID = bindingID
        self.method = method
        self.pattern = pattern
        self.bodyPolicy = bodyPolicy
        self.bodyMode = bodyMode
        self.webSocket = webSocket
    }
}

/// Declares a directory that Core serves before an unmatched request reaches the app.
public struct StaticMount: Sendable {
    public let urlPrefix: String
    public let root: String
    public let indexFile: String?
    public let spaFallbackFile: String?
    public let cacheControl: String?
    public let includeDotfiles: Bool

    public init(urlPrefix: String, root: String, indexFile: String? = nil,
                spaFallbackFile: String? = nil, cacheControl: String? = nil, includeDotfiles: Bool = false) {
        self.urlPrefix = urlPrefix
        self.root = root
        self.indexFile = indexFile
        self.spaFallbackFile = spaFallbackFile
        self.cacheControl = cacheControl
        self.includeDotfiles = includeDotfiles
    }
}

/// Declares a root and explicit limits for files selected by the app and opened by Core.
public struct FileAuthority: Sendable {
    public let id: UInt64
    public let root: String
    public let maxActiveFiles: UInt32
    public let maxFileBytes: UInt64

    public init(id: UInt64, root: String, maxActiveFiles: UInt32, maxFileBytes: UInt64) {
        self.id = id
        self.root = root
        self.maxActiveFiles = maxActiveFiles
        self.maxFileBytes = maxFileBytes
    }
}

public struct MonitorCategories: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let lifecycle = Self(rawValue: 1)
    public static let exchange = Self(rawValue: 2)
    public static let control = Self(rawValue: 4)
}

/// Requests aggregate collection. Core validates the selected categories.
public struct MonitorOptions: Sendable {
    public let categories: MonitorCategories
    public init(categories: MonitorCategories) { self.categories = categories }
}

public struct MonitorSnapshot: Sendable {
    public let generation: UInt64
    public let sequence: UInt64
    public let admittedRequests: UInt64
    public let completed: UInt64
    public let failed: UInt64
    public let cancelled: UInt64
    public let collecting: Bool
    public let stale: Bool
    public let partial: Bool
}

/// One server-sent event. Core encodes the event framing.
public struct ServerSentEvent: Sendable {
    public let data: String
    public let eventType: String?
    public let id: String?
    public let retryMilliseconds: UInt64?

    public init(data: String, eventType: String? = nil, id: String? = nil, retryMilliseconds: UInt64? = nil) {
        self.data = data
        self.eventType = eventType
        self.id = id
        self.retryMilliseconds = retryMilliseconds
    }
}

public struct RebindRequest: Sendable {
    public let activationID: UInt64
    public let expectedRouteGeneration: UInt64
    public let routeID: UInt64
    public let expectedBindingRevision: UInt64
    public let newBindingID: UInt64

    public init(activationID: UInt64, expectedRouteGeneration: UInt64, routeID: UInt64,
                expectedBindingRevision: UInt64, newBindingID: UInt64) {
        self.activationID = activationID
        self.expectedRouteGeneration = expectedRouteGeneration
        self.routeID = routeID
        self.expectedBindingRevision = expectedBindingRevision
        self.newBindingID = newBindingID
    }
}

public struct RebindCode: RawRepresentable, Equatable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let applied = Self(rawValue: 0)
    public static let activationConflict = Self(rawValue: 3)
    public static let generationMismatch = Self(rawValue: 7)
    public static let revisionMismatch = Self(rawValue: 8)
    public static let timeout = Self(rawValue: 13)
    public static let wakeupFailed = Self(rawValue: 14)
    public static let busy = Self(rawValue: 15)
}

/// Core's observation of request captures. Application callbacks have their own lifetime.
public struct RequestRetirement: Sendable {
    public let state: UInt32
    public let code: UInt32
    public let quiescentSources: UInt32
    public let sources: UInt32
}

public struct RebindOutcome: Sendable {
    public let code: RebindCode
    public let activationID: UInt64
    public let operationDigest: UInt64
    public let routeGeneration: UInt64
    public let bindingChangeSequence: UInt64
    public let routeID: UInt64
    public let previousBindingID: UInt64
    public let previousBindingRevision: UInt64
    public let effectiveBindingID: UInt64
    public let effectiveBindingRevision: UInt64
    public let changed: Bool
    public let replayed: Bool
    public let requestRetirement: RequestRetirement
}

/// An ordered HTTP field. An absent query value is nil; an explicit empty value is "".
public struct HttpField: Equatable, Sendable {
    public let name: String
    public let value: String?

    public init(_ name: String, _ value: String?) {
        self.name = name
        self.value = value
    }
}

public struct StartupIssueReason: RawRepresentable, Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let listenerStart = Self(rawValue: 8)
    public static let transportSecurity = Self(rawValue: 9)
}

public struct StartupIssue: Sendable {
    public let status: CoreStatus
    public let reason: StartupIssueReason
    public let systemCode: Int32
    public let itemIndex: UInt32?
    public let actual: UInt64
    public let limit: UInt64
    /// Operator-facing diagnostic. Do not return this value directly in an HTTP response.
    public let detail: String
}

public struct ServiceError: Error {
    public let status: CoreStatus
    public let failedRouteIndex: UInt32?
    public let startupIssue: StartupIssue?

    init(status: CoreStatus, failedRouteIndex: UInt32? = nil, startupIssue: StartupIssue? = nil) {
        self.status = status
        self.failedRouteIndex = failedRouteIndex
        self.startupIssue = startupIssue
    }
}

/// Owns synchronously borrowed strings for one call. The byte budget bounds connector allocations.
final class NativeArguments {
    private var pointers: [UnsafeMutablePointer<UInt8>] = []
    private var remaining = 16 * 1024 * 1024

    deinit {
        for pointer in pointers { free(pointer) }
    }

    func add(_ text: String?, headerValue: Bool = false) throws -> coakka_http_host_bytes_t {
        guard let text else { return coakka_http_host_bytes_t() }
        let length = headerValue ? text.unicodeScalars.count : text.utf8.count
        let capacity = max(length, 1)
        guard capacity <= remaining else { throw CoreStatus.capacityExhausted }
        if headerValue && text.unicodeScalars.contains(where: { $0.value > 255 }) {
            throw CoreStatus.invalidArgument
        }
        guard let memory = malloc(capacity) else { throw CoreStatus.outOfMemory }
        let buffer = memory.bindMemory(to: UInt8.self, capacity: capacity)
        pointers.append(buffer)
        if headerValue {
            for (index, scalar) in text.unicodeScalars.enumerated() {
                buffer.advanced(by: index).initialize(to: UInt8(scalar.value))
            }
        } else {
            for (index, byte) in text.utf8.enumerated() {
                buffer.advanced(by: index).initialize(to: byte)
            }
        }
        remaining -= capacity
        return coakka_http_host_bytes_t(data: UnsafePointer(buffer), size: length)
    }
}
