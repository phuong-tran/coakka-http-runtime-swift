# CoAkka HTTP Runtime for Swift changelog

## [Unreleased]

### 2.3.1

- Add the `CoAkkaHttp` SwiftPM product for Swift 6.0 or later.
- Serve HTTP/1.1, HTTP/2 and HTTP/3 on one TLS port through
  `HttpListener.multiProtocolListener(tls:address:port:)`.
- Use Core SDK 2.3.0 (ABI 10) on macOS ARM64, Linux ARM64 and x86_64,
  and Windows ARM64 and x86_64.
- Add examples for basic requests and each listener mode in [CoAkka Samples](https://github.com/phuong-tran/coakka-samples/tree/main/coakka-http-runtime/protocol-listeners/swift).
