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

import Foundation
import ServiceDiscovery
import SwiftkubeClient
import SwiftkubeModel

extension ServiceDiscoveryBox where Service == LookupObject, Instance == KubernetesPod {

	public func shutdown(queue: DispatchQueue, _ callback: @escaping (Error?) -> Void) {
		guard let serviceDiscovery = try? unwrapAs(KubernetesServiceDiscovery.self) else {
			return
		}
		serviceDiscovery.shutdown(queue: queue, callback)
	}

	public func syncShutdown() throws {
		guard let serviceDiscovery = try? unwrapAs(KubernetesServiceDiscovery.self) else {
			return
		}
		try serviceDiscovery.syncShutdown()
	}
}
