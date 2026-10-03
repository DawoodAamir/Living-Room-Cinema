import AVKit
import Observation
import SwiftUI

@MainActor @Observable final class CinemaPlayback {
  let player = AVPlayer()
  var loading = true
  var error: String?
  var elapsed: Double = 0
  var duration: Double = 0
  private var generation = UUID()
  private var monitor: Task<Void, Never>?
  func open(_ title: CinemaTitle, position: Double, model: CinemaModel) async {
    let token = UUID()
    generation = token
    loading = true
    error = nil
    do {
      let url: URL
      if let file = title.file {
        guard
          let local = Bundle.main.url(
            forResource: file, withExtension: "mp4", subdirectory: "Samples")
        else { throw PlaybackError.missing }
        url = local
      } else if let remote = title.remote {
        url = remote
      } else {
        throw PlaybackError.missing
      }
      let asset = AVURLAsset(url: url)
      let playable = try await asset.load(.isPlayable)
      let time = try await asset.load(.duration)
      try Task.checkCancellation()
      guard generation == token else { return }
      guard playable else { throw PlaybackError.unplayable }
      let length = time.seconds
      duration = length.isFinite && length > 0 ? length : 0
      player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
      if position > 0, duration > position {
        await player.seek(to: CMTime(seconds: position, preferredTimescale: 600))
      }
      try Task.checkCancellation()
      guard generation == token else { return }
      loading = false
      player.play()
      monitor?.cancel()
      monitor = Task { [weak self] in
        var ticks = 0
        while !Task.isCancelled {
          guard let self, self.generation == token else { return }
          if self.player.currentItem?.status == .failed {
            self.error = self.player.currentItem?.error?.localizedDescription ?? "Playback failed."
            return
          }
          let seconds = self.player.currentTime().seconds
          if seconds.isFinite { self.elapsed = max(0, seconds) }
          ticks += 1
          if ticks % 5 == 0 { self.save(title, model: model) }
          do { try await Task.sleep(for: .seconds(1)) } catch { return }
        }
      }
    } catch is CancellationError {} catch {
      if generation == token {
        self.error = error.localizedDescription
        loading = false
      }
    }
  }
  func save(_ title: CinemaTitle, model: CinemaModel) {
    guard !loading, duration > 0, player.currentItem != nil else { return }
    let current = player.currentTime().seconds
    guard current.isFinite, current >= 0 else { return }
    elapsed = current
    model.save(title.id, seconds: elapsed, duration: duration)
  }
  func stop(_ title: CinemaTitle, model: CinemaModel) {
    save(title, model: model)
    generation = UUID()
    monitor?.cancel()
    monitor = nil
    player.pause()
    player.replaceCurrentItem(with: nil)
  }
  enum PlaybackError: LocalizedError {
    case missing, unplayable
    var errorDescription: String? {
      self == .missing
        ? "The bundled video could not be found." : "This media is not playable on this device."
    }
  }
}
