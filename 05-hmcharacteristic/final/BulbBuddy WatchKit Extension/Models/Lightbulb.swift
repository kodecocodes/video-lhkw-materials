/// Copyright (c) 2021 Razeware LLC
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

import Combine
import HomeKit
import struct SwiftUI.Binding

struct Lightbulb {
  /// A `Double` that should be in the range `0...1`.
  typealias NormalizedValue = Double

  @Binding var isOn: Bool

  @Binding var hue: NormalizedValue
  @Binding var saturation: NormalizedValue
  @Binding var brightness: NormalizedValue

  private let cancellables: Set<AnyCancellable>
}

// MARK: - internal
extension Lightbulb {
  init?(_ service: HMService) {
    func characteristic(name: String) -> HMCharacteristic? {
      service.characteristics
        .first { $0.metadata?.manufacturerDescription == name }
    }

    var cancellables: Set<AnyCancellable> = []

    func binding(name: String) -> Binding<NormalizedValue>? {
      characteristic(name: name).flatMap {
        Binding(characteristic: $0, cancellables: &cancellables)
      }
    }

    guard
      service.serviceType == HMServiceTypeLightbulb,

      let isOn = characteristic(name: "Power State"),

      let hue = binding(name: "Hue"),
      let saturation = binding(name: "Saturation"),
      let brightness = binding(name: "Brightness")
    else { return nil }

    _isOn = .init(
      get: { isOn.value as? Bool ?? .init() },
      set: {
        isOn.writeValue($0) { _ in }
      }
    )

    _hue = hue
    _saturation = saturation
    _brightness = brightness

    self.cancellables = cancellables
  }
}

// MARK: - private
private extension Binding where Value == Lightbulb.NormalizedValue {
  init?(
    characteristic: HMCharacteristic,
    cancellables: inout Set<AnyCancellable>
  ) {
    guard
      let metadata = characteristic.metadata,
      [HMCharacteristicMetadataFormatFloat, HMCharacteristicMetadataFormatInt]
        .contains(metadata.format),
      let min = metadata.minimumValue?.doubleValue,
      let span = ( (metadata.maximumValue?.doubleValue).map { $0 - min } ),
      let step = metadata.stepValue?.doubleValue
    else { return nil }

    let subject = PassthroughSubject<Value, Never>()

    subject
      .throttle(for: .milliseconds(500), scheduler: DispatchQueue.global(), latest: true)
      .sink {
        characteristic.writeValue($0) { _ in }
      }
      .store(in: &cancellables)

    self.init(
      get: { ((characteristic.value as? Double ?? .init()) - min) / span },
      set: {
        subject.send(
          min + ($0 * span).rounded(toNearestMultipleOf: step)
        )
      }
    )
  }
}

private extension FloatingPoint {
  func rounded(toNearestMultipleOf step: Self) -> Self {
    (self / step).rounded() * step
  }
}
