import XCTest
@testable import OpenCodeWebMenu

final class StatusCheckerTests: XCTestCase {
    func testDetectsHealthyOpenCodeResponse() {
        let healthy = CommandResult(output: "{\"healthy\":true,\"version\":\"1.18.3\"}", error: "", exitStatus: 0, timedOut: false)
        XCTAssertTrue(StatusChecker.openCodeHealthy(from: healthy))
    }

    func testDetectsOpenCodeServeProxy() {
        let configuration = """
        {
          "Web": {
            "macbook.tailf3d9b7.ts.net:443": {
              "Handlers": {
                "/": { "Proxy": "http://127.0.0.1:4096" }
              }
            }
          }
        }
        """
        let result = CommandResult(output: configuration, error: "", exitStatus: 0, timedOut: false)
        XCTAssertTrue(StatusChecker.remoteProxyEnabled(from: result))
    }

    func testRejectsUnrelatedServeProxy() {
        let configuration = """
        {
          "Web": {
            "macbook.tailf3d9b7.ts.net:443": {
              "Handlers": {
                "/": { "Proxy": "http://127.0.0.1:3000" }
              }
            }
          }
        }
        """
        let result = CommandResult(output: configuration, error: "", exitStatus: 0, timedOut: false)
        XCTAssertFalse(StatusChecker.remoteProxyEnabled(from: result))
    }
}
