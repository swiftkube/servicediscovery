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
import SwiftkubeModel
@testable import SwiftkubeServiceDiscovery

final class InMemoryTests: XCTestCase {

	func testInMemory() {
		let lookup = expectation(description: "lookup")
		let lookupObject = LookupObject(namespace: .default)

		let serviceDiscovery = SwiftkubeServiceDiscovery<core.v1.Pod>.inMemory(
			lookup: lookupObject,
			ips: ["10.10.0.1", "10.10.0.2"]
		)

		serviceDiscovery.lookup(lookupObject) { (result) in
			switch result {
			case let .success(pods):
				XCTAssertEqual(pods.map { $0.status?.podIP }, [
					"10.10.0.1",
					"10.10.0.2",
				])
			case .failure:
				XCTFail()
			}

			lookup.fulfill()
		}

		wait(for: [lookup], timeout: 1)
	}
}
