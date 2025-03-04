# Swiftkube:ServiceDiscovery

<p align="center">
	<a href="https://swiftpackageindex.com/swiftkube/client">
		<img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fswiftkube%2Fservicediscovery%2Fbadge%3Ftype%3Dswift-versions"/>
	</a>
	<a href="https://swiftpackageindex.com/swiftkube/client">
		<img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fswiftkube%2Fservicediscovery%2Fbadge%3Ftype%3Dplatforms"/>
	</a>
	<a href="https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.32/">
		<img src="https://img.shields.io/badge/Kubernetes-1.32.0-blue.svg" alt="Kubernetes 1.32.0"/>
	</a>
	<img src="https://img.shields.io/badge/SwiftkubeClient-0.21.0-blue.svg" />
	<a href="https://swift.org/package-manager">
		<img src="https://img.shields.io/badge/swiftpm-compatible-brightgreen.svg?style=flat" alt="Swift Package Manager" />
	</a>
	<a href="https://github.com/swiftkube/servicediscovery/actions">
		<img src="https://github.com/swiftkube/servicediscovery/workflows/swiftkube-servicediscovery-ci/badge.svg" alt="CI Status">
	</a>
</p>

An implementation of the [Swift Service Discovery API](https://github.com/apple/swift-service-discovery) for 
Kubernetes based on [SwiftkubeClient](https://github.com/swiftkube/client).  

## Table of contents

* [Overview](#overview)
* [Usage](#usage)
  * [Creating a service discovery](#creating-a-service-discovery)
  * [Configuration](#Configuration)
  * [Lookup resources](#lookup-resources)
  * [Subscribtions](#subscriptions)
  * [Custom Resources](#custom-resources)
* [Strict Concurrency](#strict-concurrency)
* [RBAC](#rbac)
* [Installation](#installation)
* [License](#license)

#Overview

- [x] Auto-configuration for different environments 
- [x] Support for all Kubernetes `ListOptions`
- [x] Discovery for any listable Kubernetes resource
- [x] Support for reconnect and retry
- [ ] Complete documentation
- [ ] End-to-end tests

## Usage

### Creating a service discovery

To use this service discovery import `SwiftkubeServiceDiscovery` and init an instance.

`SwiftkubeServiceDiscovery` is generic. Thus, instances must be specialized and are therefore bound to
a specific `KubernetesResouce` type and its `GroupVersionResource`.

```swift
import SwiftkubeServiceDiscovery

let podDiscovery = SwiftkubeServiceDiscovery<core.v1.Pod>()
let serviceDiscovery = SwiftkubeServiceDiscovery<core.v1.Service>()
```

Underneath, `SwiftkubeServiceDiscovery` uses `SwiftkubeClient` for all Kubernetes communication, which configures 
itself automatically for the environment it runs in.

However, you can also pass an existing client instance to the service discovery:

```swift
let config = KubernetesClientConfig(
   masterURL: "https://kubernetesmaster",
   namespace: "default",
   authentication: authentication,
   trustRoots: NIOSSLTrustRoots.certificates(caCert),
   insecureSkipTLSVerify: false,
   timeout: HTTPClient.Configuration.Timeout.init(connect: .seconds(1), read: .seconds(10)),
   redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration.follow(max: 5, allowCycles: false)
)
let client = KubernetesClient(config: config)

let discovery = SwiftkubeServiceDiscovery<core.v1.Service>(client: client)
```

You should shut down the `SwiftkubeServiceDiscovery` instance when you're done using it, which in turn shuts down the 
underlying `SwiftkubeClient`. Thus, you shouldn't call `discovery.shutdown()` before all requests have finished.

You can also shut down the client asynchronously in an async/await context or by providing a `DispatchQueue` for the 
completion callback.

```swift
// when finished close the client
 try discovery.syncShutdown()
 
// async/await
try await discovery.shutdown()

// DispatchQueue
let queue: DispatchQueue = ...
discovery.shutdown(queue: queue) { (error: Error?) in 
    print(error)
}
```

### Configuration

You can configure the service discovery by passing a `SwiftkubeDiscoveryConfiguration` instance.

Currently, the following configuration options are supported:

- `RetryStrategy`: A retry strategy to control the reconnect-behaviour for the underlying client in case of 
non-recoverable errors when serving service discovery subscriptions.

```swift
let strategy = RetryStrategy(
    policy: .maxAttemtps(20),
    backoff: .exponentiaBackoff(maxDelay: 60, multiplier: 2.0),
    initialDelay = 5.0,
    jitter = 0.2
)

let config = Configuration(retryStrategy: strategy)
let discovery = SwiftkubeServiceDiscovery<core.v1.Service>(config: config)
```

### Lookup resources

To lookup Kubernetes resources you have to pass an instance of `LookupObject`. You can specify the namespaces to 
search and provide a list of selectors to filter the desired objects.

`SwiftkubeServiceDiscovery` lookups return a list of resources of the type specified by the generic specialization:

```swift
let podDiscovery = SwiftkubeServiceDiscovery<core.v1.Pod>()

let object = LookupObject(
    namespace: .allNamespaces,
    options: [
        .labelSelector(.exists(["app", "env"])),
        .labelSelector(.eq(["app": "nginx"])),
        .labelSelector(.notIn(["env": ["dev", "staging"]])),    
    ]
)

discovery.lookup(object) { result in
    switch result {
    case let .success(pods):
         pods.forEach { pod in
             print("\(pod.name), \(pod.namespace): \(pod.status?.podIP)")
         }
    case let .failure(error):
        // handle error
    }
}
```

### Subscribtions

You can subscribe to service lookups the same way, by providing a `LookupObject`:

```swift
let serviceDiscovery = SwiftkubeServiceDiscovery<core.v1.Service>()

let token = discovery.subscribe(to: object) { result in
    switch result {
    case let .success(service):
        pods.forEach {
            print("\(service.name), \(service.namespace): \(service.spec?.ports)")
        }
    case let .failure(error):
        print(error)
    }
} onComplete: { reason in
    print(reason)
}

token.cancel()
```

The client will try to reconnect to the API server according to the configured `RetryStrategy` and will serve updates
until the subscription token is cancelled.

### Custom Resources

TBD

## Strict Concurrency

TBD

## RBAC

TBD

## Installation

To use the `SwiftkubeServiceDiscovery` in a SwiftPM project, add the following line to the dependencies in your `Package.swift` file:

```swift
.package(name: "SwiftkubeServiceDiscovery", url: "https://github.com/swiftkube/servicediscovery.git", from: "0.3.0")
```

then include it as a dependency in your target:

```swift
import PackageDescription

let package = Package(
    // ...
    dependencies: [
        .package(name: "SwiftkubeServiceDiscovery", url: "https://github.com/swiftkube/servicediscovery.git", from: "0.3.0")
    ],
    targets: [
        .target(name: "<your-target>", dependencies: [
            .product(name: "SwiftkubeServiceDiscovery", package: "servicediscovery"),
        ])
    ]
)
```

Then run `swift build`.

## License

Swiftkube project is licensed under version 2.0 of the [Apache License](https://www.apache.org/licenses/LICENSE-2.0).
See [LICENSE](./LICENSE) for more details.
