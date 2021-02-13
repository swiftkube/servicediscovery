# Swiftkube:ServiceDiscovery

An implementation of the [Swift Service Discovery API](https://github.com/apple/swift-service-discovery) for Kubernetes based on [SwiftkubeClient](https://github.com/swiftkube/client).  

## Table of contents

* [Usage](#usage)
* [RBAC](#rbac)
* [Installation](#installation)
* [License](#license)

## Usage

### Creating a service discovery

To use this service discovery import `SwiftkubeServiceDiscovery` and init an instance.

```swift
import SwiftkubeServiceDiscovery

let discovery = SwiftkubeServiceDiscovery()
```

Underneath, `SwiftkubeServiceDiscovery` uses `SwiftkubeClient` for all Kubernets communication, which configures itself automatically for the environement it runs in.

You can also pass an existing client instance to the service discovery:

```swift
let client = KubernetesClient()
let discovery = SwiftkubeServiceDiscovery(client: client)
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

let discovery = SwiftkubeServiceDiscovery(config: config)
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
