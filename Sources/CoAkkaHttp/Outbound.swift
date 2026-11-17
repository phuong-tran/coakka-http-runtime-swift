import CCoAkkaManagedHost
import Foundation

public enum OutboundSecurity: UInt32, Sendable {
    case plaintext = 1
    case tls = 2
    case mutualTLS = 3
}

public enum OutboundStrategy: UInt32, Sendable {
    case singleOwner = 1
    case weightedRoundRobin = 2
}

/// A connection destination in a named target. Omitted values use Core defaults.
public struct OutboundEndpoint: Sendable {
    public let nodeID: String
    public let connectHost: String
    public let connectPort: UInt16
    public let httpAuthority: String
    public let weight: UInt32?
    public let security: OutboundSecurity?
    public let available: Bool?
    public let tlsPeerIdentity: String?
    public let tlsTrustGeneration: UInt64
    public let tlsClientIdentityGeneration: UInt64

    public init(nodeID: String, connectHost: String, connectPort: UInt16, httpAuthority: String,
                weight: UInt32? = nil, security: OutboundSecurity? = nil, available: Bool? = nil,
                tlsPeerIdentity: String? = nil, tlsTrustGeneration: UInt64 = 0,
                tlsClientIdentityGeneration: UInt64 = 0) {
        self.nodeID = nodeID
        self.connectHost = connectHost
        self.connectPort = connectPort
        self.httpAuthority = httpAuthority
        self.weight = weight
        self.security = security
        self.available = available
        self.tlsPeerIdentity = tlsPeerIdentity
        self.tlsTrustGeneration = tlsTrustGeneration
        self.tlsClientIdentityGeneration = tlsClientIdentityGeneration
    }
}

public struct OutboundTarget: Sendable {
    public let name: String
    public let generation: UInt64
    public let endpoints: [OutboundEndpoint]
    public let strategy: OutboundStrategy?

    public init(name: String, generation: UInt64, endpoints: [OutboundEndpoint], strategy: OutboundStrategy? = nil) {
        self.name = name
        self.generation = generation
        self.endpoints = endpoints
        self.strategy = strategy
    }
}

public struct OutboundTrust: Sendable {
    public let generation: UInt64
    public let caPEM: String

    public init(generation: UInt64, caPEM: String) {
        self.generation = generation
        self.caPEM = caPEM
    }
}

public struct OutboundIdentity: Sendable {
    public let generation: UInt64
    public let certificateChainPEM: String
    public let privateKeyPEM: String

    public init(generation: UInt64, certificateChainPEM: String, privateKeyPEM: String) {
        self.generation = generation
        self.certificateChainPEM = certificateChainPEM
        self.privateKeyPEM = privateKeyPEM
    }
}

/// Immutable startup declarations for Core's standalone outbound lane.
public struct OutboundOptions: Sendable {
    public let targets: [OutboundTarget]
    public let trusts: [OutboundTrust]
    public let identities: [OutboundIdentity]

    public init(targets: [OutboundTarget], trusts: [OutboundTrust] = [], identities: [OutboundIdentity] = []) {
        self.targets = targets
        self.trusts = trusts
        self.identities = identities
    }
}

/// One buffered request to a logical target with an origin-form path and query.
public struct OutboundRequest: Sendable {
    public let logicalTarget: String
    public let method: String
    public let target: String
    public let timeoutMilliseconds: UInt32
    public let headers: [HttpField]
    public let body: [UInt8]

    public init(logicalTarget: String, method: String, target: String, timeoutMilliseconds: UInt32,
                headers: [HttpField] = [], body: [UInt8] = []) {
        self.logicalTarget = logicalTarget
        self.method = method
        self.target = target
        self.timeoutMilliseconds = timeoutMilliseconds
        self.headers = headers
        self.body = body
    }
}

public struct OutboundCall: Equatable, Sendable {
    let owner: ExchangeOwner
    private let slot: UInt64
    private let generation: UInt64

    init(native: coakka_http_host_outbound_call_t, owner: ExchangeOwner) {
        self.owner = owner
        slot = native.slot
        generation = native.generation
    }

    public static func == (left: Self, right: Self) -> Bool {
        left.owner === right.owner && left.slot == right.slot && left.generation == right.generation
    }

    var native: coakka_http_host_outbound_call_t {
        coakka_http_host_outbound_call_t(slot: slot, generation: generation)
    }
}

public struct OutboundReason: RawRepresentable, Equatable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let response = Self(rawValue: 1)
    public static let providerFailure = Self(rawValue: 2)
    public static let providerRejected = Self(rawValue: 3)
    public static let cancelled = Self(rawValue: 4)
    public static let deadlineExceeded = Self(rawValue: 5)
    public static let stopped = Self(rawValue: 6)
    public static let responseHeadLimit = Self(rawValue: 7)
    public static let responseBodyLimit = Self(rawValue: 8)
    public static let responseAggregateLimit = Self(rawValue: 9)
    public static let outOfMemory = Self(rawValue: 10)
    public static let clockFailure = Self(rawValue: 11)
    public static let invalidProviderResult = Self(rawValue: 12)
}

public struct OutboundPhase: RawRepresentable, Equatable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let admission = Self(rawValue: 1)
    public static let providerAdoption = Self(rawValue: 2)
    public static let transport = Self(rawValue: 3)
    public static let response = Self(rawValue: 4)
    public static let cancellation = Self(rawValue: 5)
    public static let shutdown = Self(rawValue: 6)
}

public struct OutboundRetry: RawRepresentable, Equatable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let never = Self(rawValue: 1)
    public static let ifSafe = Self(rawValue: 2)
    public static let deliveryUncertain = Self(rawValue: 3)
}

public struct OutboundCertainty: RawRepresentable, Equatable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let noRequestBytesSent = Self(rawValue: 1)
    public static let requestUncertain = Self(rawValue: 2)
    public static let responseHeadObserved = Self(rawValue: 3)
    public static let completeResponse = Self(rawValue: 4)
}

/// Core's terminal result with app-owned headers and body.
public struct OutboundResult: Sendable {
    public let call: OutboundCall
    public let reason: OutboundReason
    public let logicalTarget: String
    public let targetGeneration: UInt64
    public let selectedNodeID: String
    public let phase: OutboundPhase
    public let retry: OutboundRetry
    public let certainty: OutboundCertainty
    public let responseStatus: UInt16
    public let providerCode: Int32
    public let headers: [HttpField]
    public let body: [UInt8]
    public let diagnostic: String
}

public enum OutboundReadError: Error {
    case readerAlreadyActive
}

extension HttpService {
    /// Submits a request and returns Core's service-scoped call identity on admission.
    public func submitOutbound(_ request: OutboundRequest) throws -> OutboundCall {
        try lock.withLock {
            let handle = try handle()
            guard request.headers.count <= 65_536 else { throw CoreStatus.capacityExhausted }
            let arguments = NativeArguments()
            let logicalTarget = try arguments.add(request.logicalTarget)
            let method = try arguments.add(request.method)
            let target = try arguments.add(request.target)
            let headers = try Self.projectFields(request.headers, arguments: arguments)
            var call = coakka_http_host_outbound_call_t()
            let status = withExtendedLifetime(arguments) {
                headers.withUnsafeBufferPointer { fields in
                    request.body.withUnsafeBufferPointer { body in
                        coakka_managed_submit_outbound(handle, request.timeoutMilliseconds, logicalTarget, method,
                            target, fields.baseAddress, UInt32(fields.count),
                            coakka_http_host_bytes_t(data: body.baseAddress, size: body.count), &call)
                    }
                }
            }
            try Self.check(status)
            return OutboundCall(native: call, owner: exchangeOwner)
        }
    }

    /// Asks Core to cancel an admitted call. Read its terminal result to observe the outcome.
    public func cancelOutbound(_ call: OutboundCall) throws -> CoreStatus {
        try lock.withLock {
            let handle = try handle()
            guard call.owner === exchangeOwner else { return .invalidArgument }
            return CoreStatus(rawValue: coakka_managed_cancel_outbound(handle, call.native))
        }
    }

    /// Reads one owned result, or nil when this read times out. Use one reader per service.
    /// A request deadline is a separate terminal cause. Closing the service wakes the reader.
    public func takeOutbound(timeoutMilliseconds: UInt64) throws -> OutboundResult? {
        let handle = try lock.withLock {
            let handle = try self.handle()
            guard outboundReader.try() else { throw OutboundReadError.readerAlreadyActive }
            return handle
        }
        defer { outboundReader.unlock() }
        var event = coakka_managed_outbound_result()
        let status = coakka_managed_take_outbound(handle, timeoutMilliseconds, &event)
        if status == CoreStatus.timeout.rawValue { return nil }
        try Self.check(status)
        let result: OutboundResult
        do {
            result = try projectOutbound(event, handle: handle)
        } catch {
            try Self.check(coakka_managed_release_outbound(handle))
            throw error
        }
        try Self.check(coakka_managed_release_outbound(handle))
        return result
    }

    private func projectOutbound(_ event: coakka_managed_outbound_result, handle: OpaquePointer) throws
        -> OutboundResult {
        guard event.header_count <= 65_536 else { throw CoreStatus.capacityExhausted }
        let fields = try (0..<event.header_count).map { index in
            var field = coakka_http_host_header_t()
            guard coakka_managed_outbound_header(handle, index, &field) != 0 else {
                throw CoreStatus.invalidArgument
            }
            let name = try String(decoding: Self.span(field.name), as: UTF8.self)
            let scalars = try Self.span(field.value).map { Unicode.Scalar($0) }
            return HttpField(name, String(String.UnicodeScalarView(scalars)))
        }
        return try OutboundResult(call: OutboundCall(native: event.call, owner: exchangeOwner),
            reason: OutboundReason(rawValue: event.reason),
            logicalTarget: String(decoding: Self.span(event.logical_target), as: UTF8.self),
            targetGeneration: event.target_generation,
            selectedNodeID: String(decoding: Self.span(event.node_id), as: UTF8.self),
            phase: OutboundPhase(rawValue: event.phase), retry: OutboundRetry(rawValue: event.retry),
            certainty: OutboundCertainty(rawValue: event.certainty), responseStatus: event.response_status,
            providerCode: event.provider_code, headers: fields, body: Array(Self.span(event.body)),
            diagnostic: String(decoding: Self.span(event.diagnostic), as: UTF8.self))
    }

    static func withOutboundConfig<T>(_ options: OutboundOptions?, arguments: NativeArguments,
                                     _ body: (UnsafePointer<coakka_managed_outbound_config>?) -> T) throws -> T {
        guard let options else { return body(nil) }
        guard options.targets.count <= 64, options.trusts.count <= 16, options.identities.count <= 16,
              options.targets.allSatisfy({ $0.endpoints.count <= 64 }) else {
            throw CoreStatus.capacityExhausted
        }
        var endpoints: [coakka_http_host_outbound_endpoint_t] = []
        let trusts = try options.trusts.map { input in
            var value = coakka_http_host_outbound_trust_t()
            coakka_managed_outbound_trust_init(&value)
            value.generation = input.generation
            value.ca_pem = try arguments.add(input.caPEM)
            return value
        }
        let identities = try options.identities.map { input in
            var value = coakka_http_host_outbound_identity_t()
            coakka_managed_outbound_identity_init(&value)
            value.generation = input.generation
            value.certificate_chain_pem = try arguments.add(input.certificateChainPEM)
            value.private_key_pem = try arguments.add(input.privateKeyPEM)
            return value
        }
        endpoints.reserveCapacity(options.targets.reduce(0) { $0 + $1.endpoints.count })
        for target in options.targets {
            for endpoint in target.endpoints {
                endpoints.append(try projectEndpoint(endpoint, arguments: arguments))
            }
        }
        return try endpoints.withUnsafeBufferPointer { flat in
            var offset = 0
            let targets = try options.targets.map { input in
                var value = coakka_http_host_outbound_target_t()
                coakka_managed_outbound_target_init(&value)
                value.name = try arguments.add(input.name)
                value.generation = input.generation
                if let strategy = input.strategy { value.strategy = strategy.rawValue }
                value.endpoint_count = UInt32(input.endpoints.count)
                if !input.endpoints.isEmpty { value.endpoints = flat.baseAddress?.advanced(by: offset) }
                offset += input.endpoints.count
                return value
            }
            return targets.withUnsafeBufferPointer { targets in
                trusts.withUnsafeBufferPointer { trusts in
                    identities.withUnsafeBufferPointer { identities in
                        var config = coakka_managed_outbound_config(
                            targets: targets.isEmpty ? nil : targets.baseAddress, target_count: UInt32(targets.count),
                            trusts: trusts.isEmpty ? nil : trusts.baseAddress, trust_count: UInt32(trusts.count),
                            identities: identities.isEmpty ? nil : identities.baseAddress,
                            identity_count: UInt32(identities.count))
                        return body(&config)
                    }
                }
            }
        }
    }

    private static func projectEndpoint(_ input: OutboundEndpoint, arguments: NativeArguments) throws
        -> coakka_http_host_outbound_endpoint_t {
        var value = coakka_http_host_outbound_endpoint_t()
        coakka_managed_outbound_endpoint_init(&value)
        value.node_id = try arguments.add(input.nodeID)
        value.connect_host = try arguments.add(input.connectHost)
        value.connect_port = input.connectPort
        value.http_authority = try arguments.add(input.httpAuthority)
        value.tls_peer_identity = try arguments.add(input.tlsPeerIdentity)
        value.tls_trust_generation = input.tlsTrustGeneration
        value.tls_client_identity_generation = input.tlsClientIdentityGeneration
        if let weight = input.weight { value.weight = weight }
        if let security = input.security { value.security = security.rawValue }
        if let available = input.available { value.available = available ? 1 : 0 }
        return value
    }
}
