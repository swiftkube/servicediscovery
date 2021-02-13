import Dispatch
import ServiceDiscovery
import SwiftkubeModel
import SwiftkubeClient

public struct DiscoveryObject: Hashable {
	public let namespace: NamespaceSelector?
	public let options: [ListOption]?

	public init(
		namespace: NamespaceSelector? = nil,
		options: [ListOption]? = nil
	) {
		self.namespace = namespace
		self.options = options
	}
}

public struct KubernetesPod: Hashable {
	public let uid: String
	public let resourceVersion: String
	public let name: String
	public let namespace: String

	public let labels: [String: String]?
	public let ip: String

	internal init?(from pod: core.v1.Pod) {
		guard
			let uid = pod.metadata?.uid,
			let resourceVersion = pod.metadata?.resourceVersion,
			let name = pod.metadata?.name,
			let namespace = pod.metadata?.namespace,
			let podIp = pod.status?.podIP
		else {
			return nil
		}

		self.uid = uid
		self.resourceVersion = resourceVersion
		self.name = name
		self.namespace = namespace
		self.labels = pod.metadata?.labels
		self.ip = podIp
	}
}

// MARK: - Configuration

public struct Configuration {

	/// Default configuration
	public static var `default`: Configuration {
		.init()
	}

	/// Lookup timeout in case `deadline` is not specified.
	///
	/// Currently not used.
	public var defaultLookupTimeout: DispatchTimeInterval = .milliseconds(100)

	/// Retry strategy to control the reconnect behaviour for service discovery subsriptions in case of non-recoverable errors.
	public let retryStrategy: RetryStrategy

	public init(
		retryStrategy: RetryStrategy = RetryStrategy.init(policy: .always, backoff: .fixedDelay(10))
	) {
		self.retryStrategy = retryStrategy
	}
}

// MARK: - KubernetesServiceDiscovery

/// Service Discovery implementation for Kuberentes objects.
public class KubernetesServiceDiscovery: ServiceDiscovery {

	public var defaultLookupTimeout: DispatchTimeInterval = .milliseconds(100)

	public typealias Service = LookupObject
	public typealias Instance = KubernetesPod

	private let client: KubernetesClient

	public convenience init?() {
		guard let client = KubernetesClient() else {
			return nil
		}
		self.init(client: client)
	}

	public convenience init?(config: Configuration) {
		guard let client = KubernetesClient() else {
			return nil
		}
		self.init(client: client, config: config)
	}

	public init(
		client: KubernetesClient,
		config: Configuration = Configuration.default
	) {
		self.client = client
		self.config = config
	}

	public func lookup(
		_ service: Service,
		deadline: DispatchTime?,
		callback: @escaping (Result<[Instance], Error>) -> Void
	) {
		client.pods.list(in: service.namespace, options: service.options).whenComplete { (result: Result<core.v1.PodList, Error>) in
			switch result {
			case let .failure(error):
				callback(.failure(error))
			case let .success(podList):
				let pods = podList.compactMap(KubernetesPod.init(from:))
				callback(.success(pods))
			}
		}
	}

	public func subscribe(
		to service: Service,
		onNext nextResultHandler: @escaping (Result<[Instance], Error>) -> Void,
		onComplete completionHandler: @escaping (CompletionReason) -> Void
	) -> CancellationToken {
		let delegate = ServiceDiscoveryDelegate(onNext: nextResultHandler, onComplete: completionHandler)

		do {
			let task = try client.pods.watch(
				in: service.namespace,
				options: service.options,
				retryStrategy: config.retryStrategy,
				delegate: delegate
			)
			return CancellationToken(isCancelled: false) { _ in
				task.cancel()
			}
		} catch {
			completionHandler(.serviceDiscoveryUnavailable)
			return CancellationToken(isCancelled: true)
		}
	}

	public func shutdown(queue: DispatchQueue, _ callback: @escaping (Error?) -> Void) {
		client.shutdown(queue: queue, callback)
	}

	public func syncShutdown() throws {
		try client.syncShutdown()
	}
}


		nextResultHandler(.success(Array(currentPods)))
	}

	func onError(error: SwiftkubeClientError) {
		completionHandler(.serviceDiscoveryUnavailable)
	}
}
