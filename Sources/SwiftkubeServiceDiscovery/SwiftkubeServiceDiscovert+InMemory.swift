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

import ServiceDiscovery
import SwiftkubeModel

// MARK: - SwiftkubeServiceDiscovery + InMemory

public extension SwiftkubeServiceDiscovery {

	static func inMemory<C: Collection>(
		lookup lookupObject: LookupObject,
		ips: C
	) -> ServiceDiscoveryBox<LookupObject, core.v1.Pod> where C.Element == String {
		let pods = ips.map {
			core.v1.Pod(
				metadata: .init(
					name: $0,
					namespace: "default",
					resourceVersion: "1",
					uid: "uid-[\($0)]"
				),
				status: .init(
					podIP: $0
				)
			)
		}
		return inMemory(lookup: lookupObject, pods: pods)
	}

	static func inMemory<C: Collection>(
		lookup lookupObject: LookupObject,
		pods: C
	) -> ServiceDiscoveryBox<LookupObject, core.v1.Pod> where C.Element == core.v1.Pod {
		let instances = [lookupObject: Array(pods)]
		let configuration = InMemoryServiceDiscovery<LookupObject, core.v1.Pod>.Configuration(serviceInstances: instances)
		let inMemory = InMemoryServiceDiscovery(configuration: configuration)
		return ServiceDiscoveryBox<LookupObject, core.v1.Pod>(inMemory)
	}
}
