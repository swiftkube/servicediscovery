// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "SwiftkubeServiceDiscovery",
	platforms: [
		.macOS(.v12)
	],
	products: [
		.library(
			name: "SwiftkubeServiceDiscovery",
			targets: ["SwiftkubeServiceDiscovery"]),
	],
	dependencies: [
		.package(url: "https://github.com/swiftkube/client.git", from: "0.22.0"),
		.package(url: "https://github.com/apple/swift-service-discovery.git", from: "1.4.0"),
		.package(url: "https://github.com/apple/swift-log.git", from: "1.6.2"),
	],
	targets: [
		.target(
			name: "SwiftkubeServiceDiscovery",
			dependencies: [
				.product(name: "Logging", package: "swift-log"),
				.product(name: "ServiceDiscovery", package: "swift-service-discovery"),
				.product(name: "SwiftkubeClient", package: "client"),
			]),
		.testTarget(
			name: "SwiftkubeServiceDiscoveryTests",
			dependencies: ["SwiftkubeServiceDiscovery"]),
	],
	swiftLanguageVersions: [.v5, .version("6")]
)
