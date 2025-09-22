import Foundation

final class ScreenshotRectHandler {
  let mouseEventsHandler = MouseEventsHandler()
  
  private var mouseDownLocation: CGPoint?
  private var mouseUpLocation: CGPoint?
  
  func startEventsMonitor() {
    do {
      try mouseEventsHandler.startListening { [weak self] result in
        guard let self = self else { return }
        switch result.eventType {
        case .leftMouseDown, .rightMouseDown:
          self.mouseDownLocation = result.locationInScreen
        case .leftMouseUp, .rightMouseUp:
          self.mouseUpLocation = result.locationInScreen
        }
      }
    } catch let error {
      print(error.localizedDescription)
    }
  }
  
  func stopEventsMonitor() {
    mouseEventsHandler.stopListening()
  }
  
  func screenshotRect() -> CGRect? {
    guard let mouseDownLocation = mouseDownLocation,
          let mouseUpLocation = self.mouseUpLocation else {
      return nil
    }

    return rectangleFromTwoPoints(start: mouseDownLocation, end: mouseUpLocation)
  }
  
  deinit {
    mouseEventsHandler.stopListening()
  }
}

private extension ScreenshotRectHandler {
  func rectangleFromTwoPoints(start: CGPoint, end: CGPoint) -> CGRect? {
      if start == .zero && end == .zero {
          return nil
      }
      
      return CGRect(x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(start.x - end.x),
                    height: abs(start.y - end.y))
  }
}
