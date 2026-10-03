import AVKit
import Observation
import SwiftUI

@MainActor @Observable final class CinemaModel {
  private(set) var library = CinemaLibrary()
  var error: String?
  private let store: CinemaStore
  private var queue: Task<Void, Never>?
  private var loaded = false
  init() {
    var root = URL.applicationSupportDirectory.appendingPathComponent("LivingRoomCinema")
    #if DEBUG
      if let test = ProcessInfo.processInfo.environment["CINEMA_TEST_STORE"],
        UUID(uuidString: test) != nil
      {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(test)
      }
    #endif
    store = CinemaStore(url: root.appendingPathComponent("Library.json"))
  }
  func load() {
    guard !loaded else { return }
    loaded = true
    perform { try await $0.load() }
  }
  func favorite(_ id: String) {
    let enabled = !library.favorites.contains(id)
    perform { try await $0.favorite(id, enabled: enabled) }
  }
  func save(_ id: String, seconds: Double, duration: Double) {
    perform { try await $0.bookmark(id, seconds: seconds, duration: duration) }
  }
  func clearHistory() { perform { try await $0.clearHistory() } }
  private func perform(_ work: @escaping @Sendable (CinemaStore) async throws -> CinemaLibrary) {
    let previous = queue
    queue = Task { [weak self] in
      await previous?.value
      guard let self else { return }
      do { self.library = try await work(self.store) } catch {
        self.error = error.localizedDescription
      }
    }
  }
}

@main struct LivingRoomCinemaApp: App {
  @State private var model = CinemaModel()
  var body: some Scene { WindowGroup { CinemaHome(model: model) } }
}
struct CinemaHome: View {
  @Bindable var model: CinemaModel
  @State private var search = ""
  @State private var favoritesOnly = false
  @State private var clear = false
  var titles: [CinemaTitle] {
    CinemaTitle.catalog.filter {
      (!favoritesOnly || model.library.favorites.contains($0.id))
        && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
    }
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 36) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
              Text("Living Room Cinema").font(.largeTitle.bold())
              Text("A small collection. A proper playback experience.").font(.title3)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button(
              favoritesOnly ? "Show all" : "Favorites",
              systemImage: favoritesOnly ? "square.grid.2x2" : "heart"
            ) { favoritesOnly.toggle() }
          }
          TextField("Search titles", text: $search)
          if titles.isEmpty {
            ContentUnavailableView(
              "No titles found", systemImage: "film",
              description: Text("Try another search or show the full collection."))
          }
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 36)], spacing: 44) {
            ForEach(titles) { title in
              NavigationLink(value: title) {
                VStack(alignment: .leading, spacing: 16) {
                  CinemaArtwork(title: title).aspectRatio(16 / 9, contentMode: .fit)
                  Text(title.name).font(.headline)
                  Text(title.subtitle).font(.caption).foregroundStyle(.secondary)
                  if let bookmark = model.library.bookmarks[title.id], bookmark.resumePosition > 0 {
                    ProgressView(value: bookmark.seconds, total: bookmark.duration)
                    Text("Continue from \(Int(bookmark.seconds)) seconds").font(.caption)
                  }
                }.padding(20)
              }.buttonStyle(.card).accessibilityIdentifier("title-" + title.id)
            }
          }.focusSection()
          Text(
            "Original offline studies and an explicitly labelled Apple developer stream. No account or subscription."
          ).font(.footnote).foregroundStyle(.secondary)
          Button("Clear viewing history", role: .destructive) { clear = true }.disabled(
            model.library.bookmarks.isEmpty)
        }.padding(64)
      }.navigationDestination(for: CinemaTitle.self) { CinemaDetail(title: $0, model: model) }
        .task { model.load() }
        .confirmationDialog("Clear viewing history?", isPresented: $clear) {
          Button("Clear history", role: .destructive) { model.clearHistory() }
        }
        .alert(
          "Library unavailable",
          isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
        ) {
          Button("OK") { model.error = nil }
        } message: {
          Text(model.error ?? "")
        }
    }
  }
}
struct CinemaArtwork: View {
  let title: CinemaTitle
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.06, green: 0.15, blue: 0.19))
      Image(systemName: title.symbol).font(.system(size: 100, weight: .ultraLight)).foregroundStyle(
        title.id == "orbit" ? Color.orange.opacity(0.8) : .mint)
    }.accessibilityHidden(true)
  }
}
struct CinemaDetail: View {
  let title: CinemaTitle
  @Bindable var model: CinemaModel
  @State private var playback: PlaybackRequest?
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        CinemaArtwork(title: title).frame(height: 300)
        Text(title.name).font(.largeTitle.bold())
        Text(title.subtitle).foregroundStyle(.secondary)
        Text(title.detail).font(.title3)
        HStack(spacing: 30) {
          Button("Play from start", systemImage: "play.fill") {
            playback = PlaybackRequest(position: 0)
          }.accessibilityIdentifier("play")
          if let position = model.library.bookmarks[title.id]?.resumePosition, position > 0 {
            Button("Resume", systemImage: "play.circle") {
              playback = PlaybackRequest(position: position)
            }
          }
          Button(
            model.library.favorites.contains(title.id) ? "Remove favorite" : "Add favorite",
            systemImage: "heart"
          ) { model.favorite(title.id) }.accessibilityIdentifier("favorite")
        }
        Text(
          "Use the native player for seeking, audio tracks, and subtitles where the media provides them. Press Back to return to this title."
        ).font(.footnote).foregroundStyle(.secondary)
      }.padding(64)
    }.fullScreenCover(item: $playback) { request in
      CinemaPlayerScreen(title: title, position: request.position, model: model)
    }
  }
  struct PlaybackRequest: Identifiable {
    let id = UUID()
    let position: Double
  }
}
struct CinemaPlayerScreen: View {
  let title: CinemaTitle
  let position: Double
  let model: CinemaModel
  @State private var playback = CinemaPlayback()
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    ZStack {
      NativeCinemaPlayer(player: playback.player).ignoresSafeArea()
      if playback.loading {
        ProgressView("Preparing playback").padding().background(.regularMaterial, in: .capsule)
      }
      if let error = playback.error {
        VStack(spacing: 24) {
          Text("Playback unavailable").font(.title)
          Text(error)
          Button("Back to title") { dismiss() }
        }.padding(60).background(.regularMaterial)
      }
    }.task { await playback.open(title, position: position, model: model) }
      .onDisappear { playback.stop(title, model: model) }
  }
}
struct NativeCinemaPlayer: UIViewControllerRepresentable {
  let player: AVPlayer
  func makeUIViewController(context: Context) -> AVPlayerViewController {
    let controller = AVPlayerViewController()
    controller.player = player
    return controller
  }
  func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
    controller.player = player
  }
}
