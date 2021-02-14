# Swiftkube:ServiceDiscovery

<p align="center">
	<img src="https://img.shields.io/badge/Swift-5.2-orange.svg" />
	<a href="https://v1-18.docs.kubernetes.io/docs/reference/generated/kubernetes-api/v1.18/">
		<img src="https://img.shields.io/badge/Kubernetes-1.18.13-blue.svg" alt="Kubernetes 1.18.13"/>
	</a>
	<img src="https://img.shields.io/badge/SwiftkubeClient-0.6.0-blue.svg" />
	<a href="https://swift.org/package-manager">
		<img src="https://img.shields.io/badge/swiftpm-compatible-brightgreen.svg?style=flat" alt="Swift Package Manager" />
	</a>
	<img src="https://img.shields.io/badge/platforms-mac+linux-brightgreen.svg?style=flat" alt="Mac + Linux" />
	<a href="https://github.com/swiftkube/servicediscovery/actions">
		<img src="https://github.com/swiftkube/servicediscovery/workflows/swiftkube-servicediscovery-ci/badge.svg" alt="CI Status">
	</a>
</p>

An implementation of the [Swift Service Discovery API](https://github.com/apple/swift-service-discovery) for Kubernetes based on [SwiftkubeClient](https://github.com/swiftkube/client).  

## Table of contents

* [Overview](#overview)
* [Usage](#usage)
* [RBAC](#rbac)
* [Installation](#installation)
* [License](#license)

#Overview

- [x] Auto-configuration for different environments 
- [x] Support for all K8s `ListOptions`
- [x] Support for reconnect and retry
- [x] Discovery for K8s Pod objects
- [ ] Discovery for K8s Service objects
- [ ] Complete documentation
- [ ] End-to-end tests

## Usage

### Creating a service discovery

To use this service discovery import `SwiftkubeServiceDiscovery` and init an instance.

```swift
import SwiftkubeServiceDiscovery

let discovery = KubernetesServiceDiscovery()
```

Underneath, `SwiftkubeServiceDiscovery` uses `SwiftkubeClient` for all Kubernets communication, which configures itself automatically for the environement it runs in.

You can also pass an existing client instance to the service discovery:

```swift
let client = KubernetesClient()
let discovery = KubernetesServiceDiscovery(client: client)
```

You should shut down the `SwiftkubeServiceDiscovery ` instance, which in turn shuts down the underlying `SwiftkubeClient`. You can shutdown either in a synchronius way or asynchronously by providing a `DispatchQueue` for the completion callback.

```swift
// when finished close the client
 try discovery.syncShutdown()
 
// or asynchronously
let queue: DispatchQueue = ...
discovery.shutdown(queue: queue) { (error: Error?) in 
    print(error)
}
```

### Configuration

You can configure the service discovery by passing a `Configuration` instance.

`SwiftkubeServiceDiscovery` supports the following configuration options:

- `RetryStrategy`: A retry strategy to control the reconnect behaviour for the underlying client  in case of non-recoverable errors when serving service discovery subsriptions.

```swift
let strategy = RetryStrategy(
    policy: .maxAttemtps(20),
    backoff: .exponentiaBackoff(maxDelay: 60, multiplier: 2.0),
    initialDelay = 5.0,
    jitter = 0.2
)

let config = Configuration(retryStrategy: strategy)

let discovery = KubernetesServiceDiscovery(config: config)
```

### Service lookup

To lookup Kubernetes "services" you have to pass an instance of `LookupObject`. You can specify the namespaces to search and provide a list of selectors to filter the desired objects.

`SwiftkubeServiceDiscovery` lookups return a list of `KubernetesPods` describing all of the matching pod objects that have an IP assigned.

```swift
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
             print("\(pod.name), \(pod.namespace): \(pod.ip)")
         }
    case let .failure(error):
        // handle error
    }
}
```

### Service subsription

You can subscribe to service lookups the same way, by providing a `LookupObject`:


```swift
let token = discovery.subscribe(to: object) { result in
    switch result {
    case let .success(pods):
        pods.forEach {
            print("\(pod.name), \(pod.namespace): \(pod.ip)")
        }
    case let .failure(error):
        print(error)
    }
} onComplete: { reason in
    print(reason)
}

token.cancel()
```

The client will try to reconnect to the API server according to the configured `RetryStrategy` and will serve updates until the subsription token is cancelled.

## RBAC

TBD

## Installation

To use the `SwiftkubeModel` in a SwiftPM project, add the following line to the dependencies in your `Package.swift` file:

```swift
.package(name: "SwiftkubeServiceDiscovery", url: "https://github.com/swiftkube/servicediscovery.git", from: "0.1.0"),
```

then include it as a dependency in your target:

```swift
import PackageDescription

let package = Package(
    // ...
    dependencies: [
        .package(name: "SwiftkubeServiceDiscovery", url: "https://github.com/swiftkube/servicediscovery.git", from: "0.1.0")
    ],
    targets: [
        .target(name: "<your-target>", dependencies: [
            .product(name: "SwiftkubeServiceDiscovery", package: "SwiftkubeServiceDiscovery"),
        ])
    ]
)
```

Then run `swift build`.

## License

Swiftkube project is licensed under version 2.0 of the [Apache License](https://www.apache.org/licenses/LICENSE-2.0). See [LICENSE](./LICENSE) for more details.
