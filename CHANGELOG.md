# CoAkka HTTP Runtime for Swift changelog

## 2.3.1

- Add the `CoAkkaHttp` SwiftPM product for Swift 6.0 or later.
- Serve HTTP/1.1, HTTP/2 and HTTP/3 on one TLS port through
  `HttpListener.multiProtocolListener(tls:address:port:)`.
- Use standalone listeners for streamed requests and responses, trailers,
  SSE, WebSockets and file delivery. Read aggregate monitoring counters
  and use handler rebind on supported standalone profiles.
- Use Core SDK 2.3.0 (ABI 10) on macOS ARM64, Linux ARM64 and x86_64,
  and Windows ARM64 and x86_64.
- Document SwiftPM installation, the first request and protocol checks in
  the README. The [CoAkka Samples](https://github.com/phuong-tran/coakka-samples/tree/main/coakka-http-runtime/protocol-listeners/swift)
  project runs every listener mode.

- Expose outbound HTTP requests, cancellation and typed terminal outcomes,
  plus supported standalone TLS/mTLS credential observation and reload.
- Include the full installation and standalone/MultiProtocol examples,
  upstream client example, version explanation, benchmark link and both
  GitHub Sponsors and Ko-fi. GitHub releases provide a package archive
  and SHA-256 checksums; SwiftPM consumes the versioned Git tag.
