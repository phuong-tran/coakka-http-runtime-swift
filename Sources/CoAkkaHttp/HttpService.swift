import CCoAkkaManagedHost
import Foundation

public struct CoreStatus: RawRepresentable, Equatable, Error {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let ok = Self(rawValue: Int32(COAKKA_MANAGED_OK))
    public static let invalidArgument = Self(rawValue: Int32(COAKKA_MANAGED_INVALID_ARGUMENT))
    public static let duplicateRouteID = Self(rawValue: 7)
    public static let outOfMemory = Self(rawValue: 6)
    public static let capacityExhausted = Self(rawValue: 4)
    public static let closed = Self(rawValue: Int32(COAKKA_MANAGED_CLOSED))
    public static let timeout = Self(rawValue: Int32(COAKKA_MANAGED_TIMEOUT))
    public static let unsupported = Self(rawValue: Int32(COAKKA_MANAGED_UNSUPPORTED))
    public static let staleExchange = Self(rawValue: Int32(COAKKA_MANAGED_STALE_EXCHANGE))
}

public struct EventKind: RawRepresentable, Equatable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let request = Self(rawValue: UInt32(COAKKA_MANAGED_REQUEST))
    public static let requestData = Self(rawValue: UInt32(COAKKA_MANAGED_REQUEST_DATA))
    public static let requestTrailers = Self(rawValue: UInt32(COAKKA_MANAGED_REQUEST_TRAILERS))
    public static let requestEnd = Self(rawValue: UInt32(COAKKA_MANAGED_REQUEST_END))
    public static let cancelled = Self(rawValue: UInt32(COAKKA_MANAGED_CANCELLED))
    public static let responseWritable = Self(rawValue: UInt32(COAKKA_MANAGED_RESPONSE_WRITABLE))
    public static let terminal = Self(rawValue: UInt32(COAKKA_MANAGED_TERMINAL))
}

public struct DrainState: RawRepresentable, Equatable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let pending = Self(rawValue: UInt32(COAKKA_MANAGED_DRAIN_PENDING))
    public static let complete = Self(rawValue: UInt32(COAKKA_MANAGED_DRAIN_COMPLETE))
    public static let expired = Self(rawValue: UInt32(COAKKA_MANAGED_DRAIN_EXPIRED))
    public static let aborted = Self(rawValue: UInt32(COAKKA_MANAGED_DRAIN_ABORTED))
}

public struct HttpProtocols: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let http11 = Self(rawValue: UInt32(COAKKA_MANAGED_HTTP_1_1))
    public static let http2 = Self(rawValue: UInt32(COAKKA_MANAGED_HTTP_2))
    public static let http3 = Self(rawValue: UInt32(COAKKA_MANAGED_HTTP_3))
}

public struct ListenerV1State: Sendable {
    public let port: UInt16
    public let admittingProtocols: HttpProtocols
}

final class ExchangeOwner: Sendable {}

public struct Exchange: Equatable, Sendable {
    let owner: ExchangeOwner

    private let slot: UInt64
    private let generation: UInt64

    init(native: coakka_http_host_exchange_t, owner: ExchangeOwner) {
        self.owner = owner
        slot = native.slot
        generation = native.generation
    }

    public static func == (left: Self, right: Self) -> Bool {
        left.owner === right.owner && left.slot == right.slot && left.generation == right.generation
    }

    var native: coakka_http_host_exchange_t {
        coakka_http_host_exchange_t(slot: slot, generation: generation)
    }
}

public struct RequestBodyDelivery: RawRepresentable, Equatable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let inline = Self(rawValue: UInt32(COAKKA_MANAGED_BODY_INLINE))
    public static let stream = Self(rawValue: UInt32(COAKKA_MANAGED_BODY_STREAM))
}

public struct RequestEvent: Sendable {
    public let kind: EventKind
    public let exchange: Exchange
    public let sequence: UInt64
    public let bodyDelivery: RequestBodyDelivery?
    public let method: String
    public let target: String
    public let body: [UInt8]
    public let scheme: String
    public let authority: String
    public let routeID: UInt64
    public let bindingID: UInt64
    public let routeGeneration: UInt64
    public let bindingRevision: UInt64
    public let headers: [HttpField]
    public let pathParameters: [HttpField]
    public let queryParameters: [HttpField]
    public let trailers: [HttpField]
}

/// A serialized service with one request event reader.
public final class HttpService {
    let lock = NSLock()
    let exchangeOwner = ExchangeOwner()
    private var owner: OpaquePointer?

    public init(listener: HttpListener, routes: [HttpRoute], staticMounts: [StaticMount] = [],
                fileAuthorities: [FileAuthority] = [], monitor: MonitorOptions? = nil) throws {
        guard routes.count <= 1024, staticMounts.count <= 32, fileAuthorities.count <= 32 else {
            throw CoreStatus.capacityExhausted
        }
        let arguments = NativeArguments()
        var input = coakka_managed_listener()
        let security: TlsOptions?
        switch listener {
        case let .standalone(version, address, port, tls):
            input.protocol = version?.rawValue ?? 0
            input.address = try arguments.add(address)
            input.port = port
            security = tls
        case let .multiProtocolListener(tls, address, port):
            input.multi_protocol = 1
            input.address = try arguments.add(address)
            input.port = port
            security = tls
        }
        if let tls = security {
            input.security = tls.clientTrustRootsFile == nil ? 2 : 3
            input.credential_generation = tls.generation
            input.credential_id = try arguments.add(tls.credentialID)
            input.certificate = try arguments.add(tls.certificateChainFile)
            input.key = try arguments.add(tls.privateKeyFile)
            input.trust_roots = try arguments.add(tls.clientTrustRootsFile)
        }
        if let monitor {
            input.monitor_collection = 1 // ABI 10 aggregate collection.
            input.monitor_categories = monitor.categories.rawValue
        }
        let definitions = try routes.map { route in
            var item = coakka_managed_route()
            item.route_id = route.routeID
            item.binding_id = route.bindingID
            item.method = try arguments.add(route.method)
            item.pattern = try arguments.add(route.pattern)
            item.stream_request = route.bodyMode == .streaming ? 1 : 0
            item.websocket = route.webSocket ? 1 : 0
            if let body = route.bodyPolicy {
                item.body_policy = 1
                item.max_body_bytes = body.maxBodyBytes
                item.accept_absent = body.acceptAbsent ? 1 : 0
                item.accept_other = body.acceptOther ? 1 : 0
                item.accept_form = body.acceptFormURLEncoded ? 1 : 0
                item.accept_multipart = body.acceptMultipartFormData ? 1 : 0
            }
            return item
        }
        let mounts = try staticMounts.map { mount in
            try coakka_managed_static_mount(
                url_prefix: arguments.add(mount.urlPrefix), root: arguments.add(mount.root),
                index: arguments.add(mount.indexFile), fallback: arguments.add(mount.spaFallbackFile),
                cache_control: arguments.add(mount.cacheControl, headerValue: true),
                include_dotfiles: mount.includeDotfiles ? 1 : 0)
        }
        let authorities = try fileAuthorities.map { authority in
            try coakka_managed_file_authority(id: authority.id, max_file_bytes: authority.maxFileBytes,
                                              root: arguments.add(authority.root),
                                              max_active_files: authority.maxActiveFiles)
        }
        var failed = UInt32.max
        // Keep all descriptor storage alive until Core has copied it.
        let status = withExtendedLifetime(arguments) {
            definitions.withUnsafeBufferPointer { routes in
                mounts.withUnsafeBufferPointer { mounts in
                    authorities.withUnsafeBufferPointer { authorities in
                        coakka_managed_create_with_files(
                            &input, routes.baseAddress, UInt32(routes.count),
                            mounts.baseAddress, UInt32(mounts.count),
                            authorities.baseAddress, UInt32(authorities.count), &owner, &failed)
                    }
                }
            }
        }
        guard status == CoreStatus.ok.rawValue else {
            throw ServiceError(status: CoreStatus(rawValue: status),
                               failedRouteIndex: failed == UInt32.max ? nil : failed)
        }
    }

    /// Returns Core's current admission snapshot for a V1 listener.
    public func inspectV1() throws -> ListenerV1State {
        try lock.withLock {
            var port: UInt16 = 0
            var admitting: UInt32 = 0
            try Self.check(coakka_managed_listener_v1_state(try handle(), &port, &admitting))
            return ListenerV1State(port: port, admittingProtocols: HttpProtocols(rawValue: admitting))
        }
    }

    deinit {
        // Explicit close reports failure while the caller can still retry.
        if owner != nil { _ = coakka_managed_close(&owner) }
    }

    public static var coreABI: UInt32 { coakka_managed_abi() }

    /// Returns an aggregate snapshot from Core.
    public func readMonitor() throws -> MonitorSnapshot {
        try lock.withLock {
            var snapshot = coakka_managed_monitor()
            try Self.check(coakka_managed_monitor_snapshot(try handle(), &snapshot))
            return MonitorSnapshot(generation: snapshot.generation, sequence: snapshot.sequence,
                admittedRequests: snapshot.admitted_requests, completed: snapshot.completed,
                failed: snapshot.failed, cancelled: snapshot.cancelled, collecting: snapshot.collecting != 0,
                stale: snapshot.stale != 0, partial: snapshot.partial != 0)
        }
    }

    /// Submits a Core binding change. Retry the exact request after an unresolved observation.
    public func rebindHandler(_ request: RebindRequest) throws -> RebindOutcome {
        try lock.withLock {
            var outcome = coakka_http_host_rebind_outcome_t()
            try Self.check(coakka_managed_rebind(
                try handle(), request.activationID, request.expectedRouteGeneration, request.routeID,
                request.expectedBindingRevision, request.newBindingID, &outcome))
            let retirement = outcome.request_retirement
            return RebindOutcome(
                code: RebindCode(rawValue: outcome.code), activationID: outcome.activation_id,
                operationDigest: outcome.operation_digest, routeGeneration: outcome.route_generation,
                bindingChangeSequence: outcome.binding_change_sequence, routeID: outcome.route_id,
                previousBindingID: outcome.previous_handler_binding_id,
                previousBindingRevision: outcome.previous_binding_revision,
                effectiveBindingID: outcome.effective_handler_binding_id,
                effectiveBindingRevision: outcome.effective_binding_revision,
                changed: outcome.changed != 0, replayed: outcome.replayed != 0,
                requestRetirement: RequestRetirement(state: retirement.state, code: retirement.code,
                    quiescentSources: retirement.quiescent_sources, sources: retirement.sources))
        }
    }

    public func start() throws {
        try lock.withLock {
            var issue = coakka_http_host_issue_t()
            let status = try coakka_managed_start_with_issue(handle(), &issue)
            guard status != CoreStatus.ok.rawValue else { return }
            let detail = withUnsafeBytes(of: issue.detail) {
                String(decoding: $0.prefix(while: { $0 != 0 }), as: UTF8.self)
            }
            throw ServiceError(status: CoreStatus(rawValue: status), startupIssue: StartupIssue(
                status: CoreStatus(rawValue: issue.status), reason: StartupIssueReason(rawValue: issue.reason),
                systemCode: issue.system_code,
                itemIndex: issue.item_index == UInt32.max ? nil : issue.item_index,
                actual: issue.actual, limit: issue.limit, detail: detail))
        }
    }

    public var port: UInt16 {
        get throws {
            try lock.withLock {
                var port: UInt16 = 0
                try Self.check(coakka_managed_port(try handle(), &port))
                return port
            }
        }
    }

    public func take(timeoutMilliseconds: UInt64) throws -> RequestEvent? {
        try lock.withLock {
            let handle = try handle()
            var event = coakka_managed_event()
            let status = coakka_managed_take(handle, timeoutMilliseconds, &event)
            if status == CoreStatus.timeout.rawValue { return nil }
            try Self.check(status)

            let request: RequestEvent
            do {
                request = try project(event, handle: handle)
            } catch {
                try Self.check(coakka_managed_release(handle))
                throw error
            }
            try Self.check(coakka_managed_release(handle))
            return request
        }
    }

    private func project(_ event: coakka_managed_event, handle: OpaquePointer) throws -> RequestEvent {
        let kind = EventKind(rawValue: event.kind)
        var meta = coakka_managed_metadata()
        if kind == .request {
            try Self.check(coakka_managed_metadata_read(handle, &meta))
        }
        return try RequestEvent(
            kind: kind, exchange: Exchange(native: event.exchange, owner: exchangeOwner),
            sequence: event.sequence,
            bodyDelivery: kind == .request ? RequestBodyDelivery(rawValue: meta.body_delivery) : nil,
            method: String(decoding: Self.span(event.method), as: UTF8.self),
            target: String(decoding: Self.span(event.target), as: UTF8.self),
            body: Array(Self.span(event.body)),
            scheme: String(decoding: Self.span(meta.scheme), as: UTF8.self),
            authority: String(decoding: Self.span(meta.authority), as: UTF8.self),
            routeID: meta.route_id, bindingID: event.binding_id,
            routeGeneration: meta.route_generation, bindingRevision: meta.binding_revision,
            headers: Self.fields(handle, COAKKA_MANAGED_HEADER, meta.headers, headerValue: true),
            pathParameters: Self.fields(handle, COAKKA_MANAGED_PATH_PARAMETER, meta.path_parameters),
            queryParameters: Self.fields(handle, COAKKA_MANAGED_QUERY_PARAMETER, meta.query_parameters),
            trailers: kind == .requestTrailers
                ? Self.fields(handle, COAKKA_MANAGED_STREAM_TRAILER, event.stream_trailers, headerValue: true)
                : Self.fields(handle, COAKKA_MANAGED_TRAILER, meta.trailers, headerValue: true))
    }

    private static func fields(_ handle: OpaquePointer, _ kind: coakka_managed_field_kind, _ count: UInt32,
                               headerValue: Bool = false) throws -> [HttpField] {
        guard count <= 65_536 else { throw CoreStatus.capacityExhausted }
        return try (0..<count).map { index in
            var name = coakka_http_host_bytes_t()
            var value = coakka_http_host_bytes_t()
            var present: UInt8 = 0
            try check(coakka_managed_field_read(handle, UInt32(kind.rawValue), index, &name, &value, &present))
            let fieldName = try String(decoding: span(name), as: UTF8.self)
            guard present != 0 else { return HttpField(fieldName, nil) }
            let bytes = try span(value)
            if headerValue {
                let scalars = bytes.map { Unicode.Scalar($0) }
                return HttpField(fieldName, String(String.UnicodeScalarView(scalars)))
            }
            return HttpField(fieldName, String(decoding: bytes, as: UTF8.self))
        }
    }

    public func respond(to exchange: Exchange, status: UInt32, body: [UInt8],
                        headers: [HttpField] = []) throws -> CoreStatus {
        try lock.withLock {
            let handle = try handle()
            guard exchange.owner === exchangeOwner else { return .invalidArgument }
            guard headers.count <= 65_536 else { return .capacityExhausted }
            let arguments = NativeArguments()
            let fields = try Self.projectFields(headers, arguments: arguments)
            return withExtendedLifetime(arguments) {
                fields.withUnsafeBufferPointer { projected in
                    body.withUnsafeBufferPointer { bytes in
                        CoreStatus(rawValue: coakka_managed_respond_buffered(
                            handle, exchange.native, status, bytes.baseAddress, bytes.count,
                            projected.baseAddress, UInt32(projected.count)))
                    }
                }
            }
        }
    }

    /// Submits a file selection. Core prepares and sends the file after the call returns.
    public func respondFile(to exchange: Exchange, status: UInt32, authorityID: UInt64,
                            encodedPath: String, headers: [HttpField] = []) throws -> CoreStatus {
        try lock.withLock {
            let handle = try handle()
            guard exchange.owner === exchangeOwner else { return .invalidArgument }
            guard headers.count <= 65_536 else { return .capacityExhausted }
            let arguments = NativeArguments()
            let path = try arguments.add(encodedPath)
            let fields = try Self.projectFields(headers, arguments: arguments)
            return withExtendedLifetime(arguments) {
                fields.withUnsafeBufferPointer { projected in
                    CoreStatus(rawValue: coakka_managed_respond_file(
                        handle, exchange.native, status, authorityID, path,
                        projected.baseAddress, UInt32(projected.count)))
                }
            }
        }
    }

    /// Submits the response head. Read Core's writable event before writing.
    public func startResponseStream(to exchange: Exchange, status: UInt32,
                                    headers: [HttpField] = []) throws -> CoreStatus {
        try lock.withLock {
            let handle = try handle()
            guard exchange.owner === exchangeOwner else { return .invalidArgument }
            guard headers.count <= 65_536 else { return .capacityExhausted }
            let arguments = NativeArguments()
            let fields = try Self.projectFields(headers, arguments: arguments)
            return withExtendedLifetime(arguments) {
                fields.withUnsafeBufferPointer { projected in
                    CoreStatus(rawValue: coakka_managed_start_response_stream(
                        handle, exchange.native, status, projected.baseAddress, UInt32(projected.count)))
                }
            }
        }
    }

    /// Starts an SSE response. Wait for Core's writable event before sending.
    public func startServerSentEvents(to exchange: Exchange, headers: [HttpField] = []) throws -> CoreStatus {
        try lock.withLock {
            let handle = try handle()
            guard exchange.owner === exchangeOwner else { return .invalidArgument }
            guard headers.count <= 65_536 else { return .capacityExhausted }
            let arguments = NativeArguments()
            let fields = try Self.projectFields(headers, arguments: arguments)
            return withExtendedLifetime(arguments) {
                fields.withUnsafeBufferPointer {
                    CoreStatus(rawValue: coakka_managed_start_sse(
                        handle, exchange.native, $0.baseAddress, UInt32($0.count)))
                }
            }
        }
    }

    /// Submits an event to Core. Finish with finishResponseStream.
    public func writeServerSentEvent(to exchange: Exchange, event: ServerSentEvent) throws -> CoreStatus {
        try lock.withLock {
            let handle = try handle()
            guard exchange.owner === exchangeOwner else { return .invalidArgument }
            let arguments = NativeArguments()
            let data = try arguments.add(event.data)
            let type = try arguments.add(event.eventType)
            let id = try arguments.add(event.id)
            return withExtendedLifetime(arguments) {
                CoreStatus(rawValue: coakka_managed_write_sse(
                    handle, exchange.native, data, type, id, event.retryMilliseconds ?? 0,
                    event.retryMilliseconds == nil ? 0 : 1))
            }
        }
    }

    /// Submits one chunk. Core copies accepted bytes before returning.
    public func writeResponseStream(to exchange: Exchange, chunk: [UInt8]) throws -> CoreStatus {
        try lock.withLock {
            let handle = try handle()
            guard exchange.owner === exchangeOwner else { return .invalidArgument }
            return chunk.withUnsafeBufferPointer { bytes in
                CoreStatus(rawValue: coakka_managed_write_response_stream(
                    handle, exchange.native, bytes.baseAddress, bytes.count))
            }
        }
    }

    /// Submits the end of the stream and optional trailers.
    public func finishResponseStream(to exchange: Exchange, trailers: [HttpField] = []) throws -> CoreStatus {
        try lock.withLock {
            let handle = try handle()
            guard exchange.owner === exchangeOwner else { return .invalidArgument }
            guard trailers.count <= 65_536 else { return .capacityExhausted }
            let arguments = NativeArguments()
            let fields = try Self.projectFields(trailers, arguments: arguments)
            return withExtendedLifetime(arguments) {
                fields.withUnsafeBufferPointer { projected in
                    CoreStatus(rawValue: coakka_managed_finish_response_stream(
                        handle, exchange.native, projected.baseAddress, UInt32(projected.count)))
                }
            }
        }
    }

    private static func projectFields(_ fields: [HttpField], arguments: NativeArguments)
        throws -> [coakka_http_host_header_t] {
        try fields.map { field in
            try coakka_http_host_header_t(name: arguments.add(field.name),
                                          value: arguments.add(field.value, headerValue: true))
        }
    }

    public func cancellation(of exchange: Exchange) throws -> (status: CoreStatus, cancelled: Bool) {
        try lock.withLock {
            var cancelled: UInt8 = 0
            let handle = try handle()
            guard exchange.owner === exchangeOwner else { return (.invalidArgument, false) }
            let status = coakka_managed_cancelled(handle, exchange.native, &cancelled)
            return (CoreStatus(rawValue: status), cancelled != 0)
        }
    }

    public func beginDrain() throws {
        try lock.withLock { try Self.check(coakka_managed_begin_drain(try handle())) }
    }

    public func waitDrained(timeoutMilliseconds: UInt64) throws -> (status: CoreStatus, state: DrainState) {
        try lock.withLock {
            var state: UInt32 = 0
            let status = try coakka_managed_wait_drained(handle(), timeoutMilliseconds, &state)
            return (CoreStatus(rawValue: status), DrainState(rawValue: state))
        }
    }

    public func stop() throws {
        try lock.withLock { try Self.check(coakka_managed_stop(try handle())) }
    }

    public func close() throws {
        try lock.withLock { try Self.check(coakka_managed_close(&owner)) }
    }

    func handle() throws -> OpaquePointer {
        guard let owner else { throw CoreStatus.closed }
        return owner
    }

    static func span(_ bytes: coakka_http_host_bytes_t) throws -> UnsafeBufferPointer<UInt8> {
        if bytes.size == 0 { return UnsafeBufferPointer(start: nil, count: 0) }
        guard bytes.size > 0, let data = bytes.data else {
            throw CoreStatus.invalidArgument
        }
        return UnsafeBufferPointer(start: data, count: bytes.size)
    }

    static func check(_ status: Int32) throws {
        guard status == CoreStatus.ok.rawValue else { throw CoreStatus(rawValue: status) }
    }
}
