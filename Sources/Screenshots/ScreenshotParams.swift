import Foundation

public struct ScreenshotParams: Sendable {
  let selectionRect: CGRect?
  
  public init(selectionRect: CGRect?) {
    self.selectionRect = selectionRect
  }
}
