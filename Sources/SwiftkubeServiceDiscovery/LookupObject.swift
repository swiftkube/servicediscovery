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

import SwiftkubeModel
import SwiftkubeClient

// MARK: - LookupObject

/// Specifies the objects to lookup in the cluster.
public struct LookupObject: Hashable, Sendable {

	/// The target GroupVersionResource
	public let gvr: GroupVersionResource?

	/// The namespace to search for objects.
	public let namespace: NamespaceSelector?

	/// List options to filter the desired objects.
	public let options: [ListOption]?

	public init(
		gvr: GroupVersionResource? = nil,
		namespace: NamespaceSelector? = nil,
		options: [ListOption]? = nil
	) {
		self.gvr = gvr
		self.namespace = namespace
		self.options = options
	}
}
