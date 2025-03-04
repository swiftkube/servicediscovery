//
// Copyright 2025 Swiftkube Project
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
import SwiftkubeClient

// MARK: - SwiftkubeDiscoveryConfiguration

/// Configuration object for the Swiftkube Discovery
public struct SwiftkubeDiscoveryConfiguration: Sendable {

	/// Default configuration
	public static var `default`: SwiftkubeDiscoveryConfiguration {
		.init()
	}

	/// Lookup timeout in case `deadline` is not specified.
	///
	/// Currently not used.
	public var defaultLookupTimeout: DispatchTimeInterval = .seconds(1)

	/// Retry strategy to control the reconnect behaviour for service discovery subscriptions in case of non-recoverable errors.
	public let retryStrategy: RetryStrategy

	public init(
		retryStrategy: RetryStrategy = RetryStrategy(policy: .always, backoff: .fixedDelay(10))
	) {
		self.retryStrategy = retryStrategy
	}
}
