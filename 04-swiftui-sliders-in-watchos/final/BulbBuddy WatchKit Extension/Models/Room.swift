/// Copyright (c) 2020 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import HomeKit

final class Room: Identifiable, ObservableObject {
  let name: String

  @Published var lightbulbsAreOn: Bool {
    didSet {
      lightbulbs
        .filter { $0.isOn != lightbulbsAreOn }
        .forEach { $0.isOn = lightbulbsAreOn }
    }
  }

  @Published var hue: Lightbulb.NormalizedValue
  @Published var saturation: Lightbulb.NormalizedValue
  @Published var brightness: Lightbulb.NormalizedValue

  init(name: String, lightbulbs: [Lightbulb] = []) {
    self.name = name
    self.lightbulbs = lightbulbs
    lightbulbsAreOn = lightbulbs.allSatisfy(\.isOn)

    let (hue, saturation, brightness) =
      lightbulbs.first.map { ($0.hue, $0.saturation, $0.brightness) }
      ?? (0.5, 0.5, 0.5)

    _hue = .init(initialValue: hue)
    _saturation = .init(initialValue: saturation)
    _brightness = .init(initialValue: brightness)
  }

  private let lightbulbs: [Lightbulb]
}

// MARK: - internal
extension Room {
  final class Store: NSObject, ObservableObject {
    @Published private(set) var rooms: [Room] = []

    override init() {
      super.init()
      manager.delegate = self
    }

    private let manager = HMHomeManager()
  }
}

// MARK: - private
private extension Room {
  convenience init?(room: HMRoom) {
    let lightbulbs =
      room.accessories
      .flatMap(\.services)
      .compactMap(Lightbulb.init)

    guard !lightbulbs.isEmpty
    else { return nil }

    self.init(
      name: room.name,
      lightbulbs: lightbulbs
    )
  }
}

// MARK: - HMHomeManagerDelegate
extension Room.Store: HMHomeManagerDelegate {
  func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
    rooms = manager.primaryHome?.rooms.compactMap(Room.init) ?? []
  }
}
