import XCTest

@MainActor final class WorkflowTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  func testFavoriteAndRelaunch() {
    let app = XCUIApplication()
    app.launchEnvironment["CINEMA_TEST_STORE"] = UUID().uuidString
    app.launch()
    let title = app.buttons["title-orbit"]
    XCTAssertTrue(title.waitForExistence(timeout: 30), app.debugDescription)
    select(title, in: app)
    let favorite = app.buttons["favorite"]
    XCTAssertTrue(favorite.waitForExistence(timeout: 10))
    select(favorite, in: app)
    XCTAssertTrue(app.buttons["Remove favorite"].waitForExistence(timeout: 10))
    app.terminate()
    app.launch()
    select(app.buttons["title-orbit"], in: app)
    XCTAssertTrue(app.buttons["Remove favorite"].waitForExistence(timeout: 10))
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Cinema title"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    select(app.buttons["play"], in: app)
    XCTAssertFalse(app.staticTexts["Playback unavailable"].waitForExistence(timeout: 5))
    let playback = XCTAttachment(screenshot: app.screenshot())
    playback.name = "Offline playback"
    playback.lifetime = .keepAlways
    add(playback)
    XCUIRemote.shared.press(.menu)
    XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 10), app.debugDescription)
    app.terminate()
    app.launch()
    select(app.buttons["title-orbit"], in: app)
    XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 10), app.debugDescription)
  }
  private func select(_ target: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<24 {
      if target.hasFocus {
        XCUIRemote.shared.press(.select)
        return
      }
      let focused = app.descendants(matching: .any).matching(
        NSPredicate(format: "hasFocus == true")
      ).firstMatch
      guard focused.exists else {
        XCUIRemote.shared.press(.down)
        continue
      }
      let dx = target.frame.midX - focused.frame.midX
      let dy = target.frame.midY - focused.frame.midY
      if abs(dy) > 70 {
        XCUIRemote.shared.press(dy > 0 ? .down : .up)
      } else {
        XCUIRemote.shared.press(dx > 0 ? .right : .left)
      }
    }
    XCTFail("Could not focus \(target.identifier): \(app.debugDescription)")
  }
}
