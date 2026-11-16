import CCoAkkaManagedHost

public struct WebSocketEventKind: RawRepresentable, Equatable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let open = Self(rawValue: 1)
    public static let text = Self(rawValue: 2)
    public static let binary = Self(rawValue: 3)
    public static let ping = Self(rawValue: 4)
    public static let pong = Self(rawValue: 5)
    public static let writable = Self(rawValue: 6)
    public static let close = Self(rawValue: 7)
    public static let acceptFailed = Self(rawValue: 8)
}

public struct WebSocketSession: Equatable, Sendable {
    fileprivate let owner: ExchangeOwner
    fileprivate let slot: UInt64
    fileprivate let generation: UInt64

    fileprivate var native: coakka_http_host_websocket_t {
        coakka_http_host_websocket_t(slot: slot, generation: generation)
    }

    public static func == (left: Self, right: Self) -> Bool {
        left.owner === right.owner && left.slot == right.slot && left.generation == right.generation
    }
}

public struct WebSocketEvent: Sendable {
    public let kind: WebSocketEventKind
    public let session: WebSocketSession
    public let origin: Exchange
    public let data: [UInt8]
    public let closeCode: UInt32
}

extension HttpService {
    public func acceptWebSocket(_ exchange: Exchange, subprotocol: String? = nil) throws -> CoreStatus {
        try lock.withLock {
            let handle = try handle()
            guard exchange.owner === exchangeOwner else { return .invalidArgument }
            let arguments = NativeArguments()
            let protocolBytes = try arguments.add(subprotocol)
            return withExtendedLifetime(arguments) {
                CoreStatus(rawValue: coakka_managed_accept_websocket(handle, exchange.native, protocolBytes))
            }
        }
    }

    /// Reads one event and releases the Core lease before returning owned data.
    public func takeWebSocket(timeoutMilliseconds: UInt64) throws -> WebSocketEvent? {
        try lock.withLock {
            let handle = try handle()
            var value = coakka_managed_socket_event()
            let status = coakka_managed_take_websocket(handle, timeoutMilliseconds, &value)
            if status == CoreStatus.timeout.rawValue { return nil }
            try Self.check(status)
            let event = Result {
                try WebSocketEvent(kind: WebSocketEventKind(rawValue: value.kind),
                    session: WebSocketSession(owner: exchangeOwner, slot: value.session.slot,
                                              generation: value.session.generation),
                    origin: Exchange(native: value.origin, owner: exchangeOwner),
                    data: Array(Self.span(value.data)), closeCode: value.close_code)
            }
            try Self.check(coakka_managed_release_websocket(handle))
            return try event.get()
        }
    }

    public func sendWebSocket(to session: WebSocketSession, kind: WebSocketEventKind,
                              data: [UInt8]) throws -> CoreStatus {
        try lock.withLock {
            let handle = try handle()
            guard session.owner === exchangeOwner else { return .invalidArgument }
            return data.withUnsafeBufferPointer {
                CoreStatus(rawValue: coakka_managed_send_websocket(handle, session.native, kind.rawValue,
                    coakka_http_host_bytes_t(data: $0.baseAddress, size: $0.count)))
            }
        }
    }

    public func closeWebSocket(_ session: WebSocketSession, code: UInt32 = 1000,
                               reason: String? = nil) throws -> CoreStatus {
        try lock.withLock {
            let handle = try handle()
            guard session.owner === exchangeOwner else { return .invalidArgument }
            let arguments = NativeArguments()
            let bytes = try arguments.add(reason)
            return withExtendedLifetime(arguments) {
                CoreStatus(rawValue: coakka_managed_close_websocket(handle, session.native, code, bytes))
            }
        }
    }
}
