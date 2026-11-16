import Foundation

/// An application-owned callback that captures its current handler at dispatch.
public final class BufferedHandler: Sendable {
    public typealias Callback = @Sendable (RequestEvent) async throws -> BufferedReply

    // The lock protects just the callback reference. User code executes after capture.
    private let storage: HandlerStorage

    public init(_ handler: @escaping Callback) {
        storage = HandlerStorage(handler)
    }

    public func swapHandler(_ replacement: @escaping Callback) {
        storage.replace(with: replacement)
    }

    public func dispatch(_ request: RequestEvent) async throws -> BufferedReply {
        let captured = storage.capture()
        return try await captured(request)
    }
}

private final class HandlerStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: BufferedHandler.Callback

    init(_ handler: @escaping BufferedHandler.Callback) { self.handler = handler }

    func capture() -> BufferedHandler.Callback {
        lock.withLock { handler }
    }

    func replace(with replacement: @escaping BufferedHandler.Callback) {
        // Keep the old closure alive until after unlocking: ARC can run user
        // deinitializers when the closure releases its captures.
        let previous = lock.withLock {
            let previous = handler
            handler = replacement
            return previous
        }
        withExtendedLifetime(previous) {}
    }
}

public struct BufferedReply: Sendable {
    public let status: UInt32
    public let body: [UInt8]
    public let headers: [HttpField]

    public init(status: UInt32, body: [UInt8], headers: [HttpField] = []) {
        self.status = status
        self.body = body
        self.headers = headers
    }
}
