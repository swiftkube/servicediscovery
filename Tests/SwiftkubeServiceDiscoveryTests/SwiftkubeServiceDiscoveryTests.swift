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

import XCTest
@testable import SwiftkubeServiceDiscovery

final class SwiftkubeServiceDiscoveryTests: XCTestCase {

	func testInMemory() {
		let lookup = expectation(description: "lookup")
		let object = LookupObject(namespace: .default)

		let sd = KubernetesServiceDiscovery.inMemory(lookup: object, ips: ["10.10.0.1", "10.10.0.2"])

		sd.lookup(LookupObject(namespace: .default)) { (result) in
			switch result {
			case let .success(pods):
				XCTAssertEqual(pods, [
					KubernetesPod(host: "10.10.0.1"),
					KubernetesPod(host: "10.10.0.2"),
				])
			case .failure:
				XCTFail()
			}

			lookup.fulfill()
		}

		wait(for: [lookup], timeout: 1)
	}
}
