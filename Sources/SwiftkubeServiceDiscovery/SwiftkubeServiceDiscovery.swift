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
import Foundation
import Logging
import ServiceDiscovery
import SwiftkubeClient
import SwiftkubeModel

// MARK: - SwiftkubeServiceDiscovery

/// Service Discovery implementation for Kubernetes objects.
public actor SwiftkubeServiceDiscovery<Resource: KubernetesAPIResource & ListableResource>: @preconcurrency ServiceDiscovery {

	public var defaultLookupTimeout: DispatchTimeInterval = .seconds(1)

	public typealias Service = LookupObject
	public typealias Instance = Resource.List.Item

	private let client: KubernetesClient
	private let config: SwiftkubeDiscoveryConfiguration
	private let logger: Logger

	private var watchlist: Set<Resource> = []
	private var subscriptions: Dictionary<UUID, SwiftkubeClientTask<WatchEvent<Resource>>> = [:]

	public init?() {
		self.init(config: .default)
	}

	public init?(config: SwiftkubeDiscoveryConfiguration) {
		guard let clientConfig = KubernetesClientConfig.initialize() else {
			return nil
		}

		let client = KubernetesClient(config: clientConfig)

		self.init(client: client, config: config)
	}

	public init(
		client: KubernetesClient,
		config: SwiftkubeDiscoveryConfiguration = SwiftkubeDiscoveryConfiguration.default,
		logger: Logger = Logger(label: "sksd-do-not-log")
	) {
		self.client = client
		self.config = config
		self.logger = logger
	}

	public func lookup(
		_ service: LookupObject,
		deadline: DispatchTime?,
		callback: @Sendable @escaping (Result<[Instance], any Error>) -> Void
	) {
		Task {
			let namespace = service.namespace ?? .default
			do {
				let resourceClient: GenericKubernetesClient<Resource>
				if let gvr = service.gvr {
					resourceClient = client.for(Resource.self, gvr: gvr)
				} else {
					resourceClient = client.for(Resource.self)
				}

				logger.info("Performing lookup for: \(service)")
				let resourceList = try await resourceClient.list(in: namespace, options: service.options)
				let result: Result<[Instance], any Error> = .success(resourceList.items)
				callback(result)
			} catch {
				let result: Result<[Instance], any Error> = .failure(error)
				logger.error("Error performing lookup: \(error)")
				callback(result)
			}
		}
	}

	public func subscribe(
		to service: LookupObject,
		onNext nextResultHandler: @Sendable @escaping (Result<[Instance], any Error>) -> Void,
		onComplete completionHandler: @Sendable @escaping (CompletionReason) -> Void
	) -> CancellationToken {
		let identifier = UUID()
		let token = CancellationToken { reason in
			Task {
				await self.handleCancelation(identifier: identifier)
				completionHandler(reason)
			}
		}

		Task {
			let namespace = service.namespace ?? .default
			do {
				let resourceClient: GenericKubernetesClient<Resource>
				if let gvr = service.gvr {
					resourceClient = client.for(Resource.self, gvr: gvr)
				} else {
					resourceClient = client.for(Resource.self)
				}

				logger.info("Starting watch task [\(identifier)] for: \(service)")
				let task = try await resourceClient.watch(in: namespace, retryStrategy: config.retryStrategy)
				subscriptions[identifier] = task

				for try await event in await task.start() {
					if (token.isCancelled) {
						break
					}

					switch event.type {
					case .added:
						fallthrough
					case .modified:
						guard !watchlist.contains(event.resource) else {
							logger.debug("Resource already tracked: \(event)")
							continue
						}

						logger.debug("Received resource: \(event)")
						let result: Result<[Instance], any Error> = .success([event.resource as! Instance])
						nextResultHandler(result)
					case .deleted:
						watchlist.remove(event.resource)
					case .error:
						logger.warning("Received error event: \(event)")
					}
				}
			} catch {
				let result: Result<[Instance], any Error> = .failure(error)
				nextResultHandler(result)
			}
		}

		return token
	}

	private func handleCancelation(identifier: UUID) async {
		guard let task = subscriptions[identifier] else {
			return
		}

		await task.cancel()
		logger.info("Cancelling watch task [\(identifier)] due to token cancellation")
		subscriptions.removeValue(forKey: identifier)
	}

	nonisolated public func shutdown(queue: DispatchQueue, _ callback: @Sendable @escaping (Error?) -> Void) {
		client.shutdown(queue: queue, callback)
	}

	nonisolated public func syncShutdown() throws {
		try client.syncShutdown()
	}

	public func shutdown() async throws {
		try await client.shutdown()
	}
}
