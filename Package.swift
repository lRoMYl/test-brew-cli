// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "dh-graphql-codegen-ios",
  platforms: [.macOS(.v10_15)],
  products: [
    .library(name: "GraphQLAST", targets: ["GraphQLAST"]),
    .library(name: "GraphQLDownloader", targets: ["GraphQLDownloader"]),
    .library(name: "GraphQLCodegenConfig", targets: ["GraphQLCodegenConfig"]),
    .library(name: "GraphQLCodegenUtil", targets: ["GraphQLCodegenUtil"]),
    .library(name: "GraphQLSwiftCodegen", targets: ["GraphQLSwiftCodegen"]),
    .library(name: "GraphQLDHApiClientCodegen", targets: ["GraphQLDHApiClientCodegen"]),
    .executable(name: "dh-graphql-codegen-ios", targets: ["GraphQLCodegenCLI"])
  ],
  dependencies: [
    .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.41.2"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "0.3.0")
  ],
  targets: [
    .target(
      name: "GraphQLAST",
      dependencies: []
    ),
    .target(
      name: "GraphQLCodegenConfig",
      dependencies: []
    ),
    .target(
      name: "GraphQLCodegenUtil",
      dependencies: ["SwiftFormat"]
    ),
    .target(
      name: "GraphQLSwiftCodegen",
      dependencies: ["SwiftFormat", "GraphQLAST", "GraphQLCodegenConfig", "GraphQLCodegenUtil"]
    ),
    .target(
      name: "GraphQLDHApiClientCodegen",
      dependencies: ["SwiftFormat", "GraphQLAST", "GraphQLCodegenConfig", "GraphQLCodegenUtil"]
    ),
    .target(
      name: "GraphQLCodegenCLI",
      dependencies: [
        "GraphQLSwiftCodegen",
        "GraphQLDHApiClientCodegen",
        "GraphQLDownloader",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ]
    ),
    .target(
      name: "GraphQLDownloader",
      dependencies: [
        "GraphQLAST"
      ]
    ),
    .testTarget(
      name: "GraphQLCodegenCLITests",
      dependencies: ["GraphQLCodegenCLI"]
    ),
    .testTarget(
      name: "GraphQLSwiftCodegenTests",
      dependencies: ["GraphQLSwiftCodegen", "GraphQLDownloader"],
      resources: [
        .process("Resources")
      ]
    )
  ]
)
