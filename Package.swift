// swift-tools-version: 6.0
import PackageDescription

#if os(macOS) && arch(arm64)
let managed: Target = .binaryTarget(name: "CCoAkkaManagedHost", path: "Artifacts/Managed.xcframework")
let core: Target = .binaryTarget(name: "CoAkkaHttpCore", path: "Artifacts/Core.xcframework")
let dependencies: [Target.Dependency] = ["CCoAkkaManagedHost", "CoAkkaHttpCore"]
let platforms: [SupportedPlatform]? = [.macOS(.v14)]
let binaryTargets = [managed, core]
#else
#if os(Windows) && arch(arm64)
let rid = "win-arm64"
#elseif os(Windows) && arch(x86_64)
let rid = "win-x64"
#elseif os(Linux) && arch(arm64)
let rid = "linux-arm64"
#elseif os(Linux) && arch(x86_64)
let rid = "linux-x64"
#else
#error("CoAkka HTTP Runtime does not provide a native artifact for this target")
#endif

// SwiftPM's pkg-config reader accepts an absolute .pc path. Resolve it
// inside this checkout so a tagged dependency requires no global search path.
let manifestPath = #filePath
let separator = manifestPath.lastIndex { $0 == "/" || $0 == "\\" }!
let nativeDirectory = ["Native", rid, "coakka-http-managed-host.pc"]
    .joined(separator: String(manifestPath[separator]))
let metadata = String(manifestPath[...separator]) + nativeDirectory

let binaryTargets: [Target] = [
    .systemLibrary(name: "CCoAkkaManagedHost", pkgConfig: metadata),
]
let dependencies: [Target.Dependency] = ["CCoAkkaManagedHost"]
let platforms: [SupportedPlatform]? = nil
#endif

#if os(Windows)
let library: Product = .library(name: "CoAkkaHttp", type: .dynamic, targets: ["CoAkkaHttp"])
#else
let library: Product = .library(name: "CoAkkaHttp", targets: ["CoAkkaHttp"])
#endif

let package = Package(
    name: "coakka-http-runtime-swift",
    platforms: platforms,
    products: [library],
    targets: binaryTargets + [.target(name: "CoAkkaHttp", dependencies: dependencies)]
)
