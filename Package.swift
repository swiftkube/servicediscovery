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
		.package(name: "SwiftkubeClient", url: "https://github.com/swiftkube/client.git", from: "0.9.0"),
		.package(url: "https://github.com/apple/swift-service-discovery.git", from: "1.0.0")
	],
	targets: [
		.target(
			name: "SwiftkubeServiceDiscovery",
			dependencies: [
				.product(name: "SwiftkubeClient", package: "SwiftkubeClient"),
				.product(name: "ServiceDiscovery", package: "swift-service-discovery")
			]),
		.testTarget(
			name: "SwiftkubeServiceDiscoveryTests",
			dependencies: ["SwiftkubeServiceDiscovery"]),
	],
	swiftLanguageVersions: [.v5, .version("6")]
)
