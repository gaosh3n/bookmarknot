// swift-tools-version: 6.3

import PackageDescription

var targets: [Target] = []
targets.append(.target(name: "Domain"))
targets.append(
  .target(
    name: "Application",
    dependencies: ["Domain"]
  )
)
targets.append(
  .target(
    name: "Infrastructure",
    dependencies: ["Application", "Domain"]
  )
)
targets.append(
  .executableTarget(
    name: "UI",
    dependencies: ["Application", "Domain", "Infrastructure"]
  )
)
targets.append(
  .testTarget(
    name: "ApplicationTests",
    dependencies: ["Application"]
  )
)
targets.append(
  .testTarget(
    name: "DomainTests",
    dependencies: ["Domain"]
  )
)
targets.append(
  .testTarget(
    name: "InfrastructureTests",
    dependencies: ["Infrastructure"]
  )
)
targets.append(
  .testTarget(
    name: "UITests",
    dependencies: ["UI"]
  )
)

let package = Package(
  name: "Bookmarknot",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .library(name: "Domain", targets: ["Domain"]),
    .library(name: "Application", targets: ["Application"]),
    .library(name: "Infrastructure", targets: ["Infrastructure"]),
    .executable(name: "bookmarknot", targets: ["UI"]),
  ],
  targets: targets
)
