import Foundation
import Testing

@testable import CinemaCore

@Test func bookmarksAndFavoritesSurviveAndHistoryClearsIndependently() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let url = root.appendingPathComponent("library.json")
  let store = CinemaStore(url: url)
  _ = try await store.favorite("orbit", enabled: true)
  _ = try await store.bookmark("orbit", seconds: 8, duration: 24)
  let restored = try await CinemaStore(url: url).load()
  #expect(restored.favorites.contains("orbit"))
  #expect(restored.bookmarks["orbit"]?.resumePosition == 8)
  let cleared = try await store.clearHistory()
  #expect(cleared.bookmarks.isEmpty)
  #expect(cleared.favorites.contains("orbit"))
}
@Test func finishedTitlesRestartAndInvalidInputPreservesHistory() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let url = root.appendingPathComponent("library.json")
  let store = CinemaStore(url: url)
  let value = try await store.bookmark("orbit", seconds: 23, duration: 24)
  #expect(value.bookmarks["orbit"]?.resumePosition == 0)
  let bytes = try Data(contentsOf: url)
  await #expect(throws: CinemaError.self) {
    try await store.bookmark("orbit", seconds: .nan, duration: 24)
  }
  #expect(try Data(contentsOf: url) == bytes)
}
@Test func catalogUsesOnlyBundledOrSecureExplicitMedia() {
  #expect(Set(CinemaTitle.catalog.map(\.id)).count == CinemaTitle.catalog.count)
  for title in CinemaTitle.catalog {
    #expect((title.file == nil) != (title.remote == nil))
    if let remote = title.remote { #expect(remote.scheme == "https") }
  }
}
