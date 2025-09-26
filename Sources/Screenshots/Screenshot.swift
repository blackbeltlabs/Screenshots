import Cocoa

public struct Screenshot: Sendable {
  public let url: URL
  public let rect: CGRect?
}

public struct ScreenshotImage: Sendable {
  public let image: NSImage
  public let rect: CGRect?
}
