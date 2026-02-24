import SwiftUI
import Screenshots

struct ContentView: View {

  // MARK: - State

  @State private var xText: String = ""
  @State private var yText: String = ""
  @State private var widthText: String = ""
  @State private var heightText: String = ""

  @State private var soundEnabled: Bool = true
  @State private var windowShadowEnabled: Bool = true

  @State private var statusText: String = ""
  @State private var capturedImage: NSImage?

  // MARK: - Private

  private let cli = ScreenshotCLI()

  private var selectionRect: CGRect? {
    guard
      let x = Int(xText),
      let y = Int(yText),
      let w = Int(widthText),
      let h = Int(heightText)
    else { return nil }
    return CGRect(x: x, y: y, width: w, height: h)
  }

  // MARK: - Body

  var body: some View {
    VStack(spacing: 12) {

      // MARK: Coordinate fields
      HStack(spacing: 8) {
        TextField("X", text: $xText)
          .textFieldStyle(.roundedBorder)
        TextField("Y", text: $yText)
          .textFieldStyle(.roundedBorder)
        TextField("Width", text: $widthText)
          .textFieldStyle(.roundedBorder)
        TextField("Height", text: $heightText)
          .textFieldStyle(.roundedBorder)
      }

      // MARK: Image preview
      Group {
        if let image = capturedImage {
          Image(nsImage: image)
            .resizable()
            .scaledToFit()
        } else {
          Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.2))
            .overlay(
              Text("No image captured")
                .foregroundStyle(.secondary)
            )
        }
      }
      .frame(height: 267)
      .frame(maxWidth: .infinity)

      // MARK: Status label
      Text(statusText.isEmpty ? " " : statusText)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .lineLimit(2)

      // MARK: Checkboxes
      HStack(spacing: 16) {
        Toggle("Sound", isOn: $soundEnabled)
        Toggle("Window shadow", isOn: $windowShadowEnabled)
        Spacer()
      }

      // MARK: Action buttons
      HStack(spacing: 8) {
        Button("Capture Window") {
          captureWindow()
        }

        Button("Take Screenshot") {
          takeScreenshot()
        }
        .keyboardShortcut(.return, modifiers: [])
      }
    }
    .padding()
    .frame(width: 640, height: 507)
  }

  // MARK: - Actions

  private func takeScreenshot() {
    let params = selectionRect.map { ScreenshotParams(selectionRect: $0) }
    Task { @MainActor in
      do {
        let screenshot = try await cli.captureScreenshotImage(
          params: params,
          soundEnabled: soundEnabled
        )
        capturedImage = screenshot.image
        statusText = "Screenshot rect: \(String(describing: screenshot.rect?.integral))"
      } catch {
        statusText = "Error: \(error.localizedDescription)"
      }
    }
  }

  private func captureWindow() {
    Task { @MainActor in
      do {
        let image = try await cli.captureWindowImage(
          soundEnabled: soundEnabled,
          windowShadowEnabled: windowShadowEnabled
        )
        capturedImage = image
        statusText = "Window captured"
      } catch {
        statusText = "Error: \(error.localizedDescription)"
      }
    }
  }
}

#Preview {
  ContentView()
}
