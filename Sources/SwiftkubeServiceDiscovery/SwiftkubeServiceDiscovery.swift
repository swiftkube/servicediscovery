//
// Copyright 2020 Swiftkube Project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

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

// MARK: - KubernetesPod

/// Represents a discovered Kuberenetes Pod.
public struct KubernetesPod: Hashable {

	/// The UID of this Pod object.
	public let uid: String

	/// The version of this Pod object.
	public let resourceVersion: String

	/// The name of this Pod object.
	public let name: String

	/// The namespace of this Pod object.
	public let namespace: String

	/// The labels of this Pod object.
	public let labels: [String: String]?

	/// The Pod IP address.
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

	internal init(host: String) {
		self.uid = "uid-[\(host)]"
		self.resourceVersion = "1"
		self.name = host
		self.namespace = "default"
		self.labels = nil
		self.ip = host
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(uid)
		hasher.combine(name)
		hasher.combine(namespace)
		hasher.combine(ip)
	}

	public static func ==(lhs: KubernetesPod, rhs: KubernetesPod) -> Bool {
		lhs.uid == rhs.uid && lhs.name == rhs.name && lhs.namespace == rhs.namespace && lhs.ip == rhs.ip
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
	private let config: Configuration

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

public extension KubernetesServiceDiscovery {

	static func inMemory<C: Collection>(lookup lookupObject: LookupObject, ips: C) -> ServiceDiscoveryBox<LookupObject, KubernetesPod> where C.Element == String {
		let pods = ips.map(KubernetesPod.init(host:))
		return inMemory(lookup: lookupObject, pods: pods)
	}

	static func inMemory<C: Collection>(lookup lookupObject: LookupObject, pods: C) -> ServiceDiscoveryBox<LookupObject, KubernetesPod> where C.Element == KubernetesPod {
		let instances = [lookupObject: Array(pods)]
		let configuration = InMemoryServiceDiscovery<LookupObject, KubernetesPod>.Configuration(serviceInstances: instances)
		let inMemory = InMemoryServiceDiscovery(configuration: configuration)
		return ServiceDiscoveryBox<LookupObject, KubernetesPod>(inMemory)
	}
}
