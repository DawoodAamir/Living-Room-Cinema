import Foundation

struct CinemaTitle: Identifiable, Hashable, Sendable {
  let id: String
  let name: String
  let subtitle: String
  let detail: String
  let symbol: String
  let file: String?
  let remote: URL?
  static let catalog: [Self] = [
    .init(
      id: "orbit", name: "Orbit Study", subtitle: "Original motion study · 24 seconds",
      detail:
        "A quiet geometric orbit, generated entirely for this project. Available offline with no audio track.",
      symbol: "circle.hexagongrid", file: "Orbit", remote: nil),
    .init(
      id: "tidal", name: "Tidal Lines", subtitle: "Original motion study · 24 seconds",
      detail:
        "A field of flowing lines. Original procedural artwork, bundled for offline playback. No audio track.",
      symbol: "water.waves", file: "Tidal", remote: nil),
    .init(
      id: "bipbop", name: "Apple HLS Example", subtitle: "Developer test stream · network required",
      detail:
        "Apple’s Bip Bop developer stream demonstrates adaptive video, audio renditions, and subtitles. This is test content, not a licensed entertainment catalog. Network requests go directly to Apple’s CDN.",
      symbol: "play.rectangle", file: nil,
      remote: URL(
        string:
          "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8"
      )),
  ]
}
struct PlaybackBookmark: Codable, Sendable, Equatable {
  var seconds: Double
  var duration: Double
  var updated: Date
  var isFinished: Bool { duration > 0 && seconds >= max(0, duration - 3) }
  var resumePosition: Double { isFinished ? 0 : seconds }
}
struct CinemaLibrary: Codable, Sendable {
  var format = 1
  var favorites: Set<String> = []
  var bookmarks: [String: PlaybackBookmark] = [:]
  func validated() throws -> Self {
    let allowed = Set(CinemaTitle.catalog.map(\.id))
    guard format == 1, favorites.isSubset(of: allowed), Set(bookmarks.keys).isSubset(of: allowed)
    else { throw CinemaError.invalid }
    for record in bookmarks.values {
      guard record.seconds.isFinite, record.duration.isFinite, record.seconds >= 0,
        record.duration > 0, record.duration <= 86_400, record.seconds <= record.duration,
        record.updated.timeIntervalSince1970.isFinite
      else { throw CinemaError.invalid }
    }
    return self
  }
}
enum CinemaError: LocalizedError {
  case invalid
  var errorDescription: String? {
    "The saved library is invalid. Its original file has been preserved."
  }
}
actor CinemaStore {
  let url: URL
  private var state: CinemaLibrary?
  init(url: URL) { self.url = url }
  func load() throws -> CinemaLibrary {
    if let state { return state }
    if FileManager.default.fileExists(atPath: url.path) {
      let data = try Data(contentsOf: url)
      guard data.count < 100_000 else { throw CinemaError.invalid }
      state = try JSONDecoder().decode(CinemaLibrary.self, from: data).validated()
    } else {
      state = CinemaLibrary()
    }
    return state!
  }
  func favorite(_ id: String, enabled: Bool) throws -> CinemaLibrary {
    var next = try load()
    if enabled { next.favorites.insert(id) } else { next.favorites.remove(id) }
    return try save(next)
  }
  func bookmark(_ id: String, seconds: Double, duration: Double) throws -> CinemaLibrary {
    var next = try load()
    guard seconds.isFinite, duration.isFinite, seconds >= 0, duration > 0 else {
      throw CinemaError.invalid
    }
    next.bookmarks[id] = PlaybackBookmark(
      seconds: min(seconds, duration), duration: duration, updated: Date())
    return try save(next)
  }
  func clearHistory() throws -> CinemaLibrary {
    var next = try load()
    next.bookmarks = [:]
    return try save(next)
  }
  private func save(_ next: CinemaLibrary) throws -> CinemaLibrary {
    _ = try next.validated()
    let data = try JSONEncoder().encode(next)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
    state = next
    return next
  }
}
