import Foundation

public struct ScreenshotParams {
  let selectionRect: CGRect?
  
  public init(selectionRect: CGRect?) {
    self.selectionRect = selectionRect
  }
}
