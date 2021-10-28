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
        case .leftMouseDown:
          self.mouseDownLocation = result.locationInScreen
        case .leftMouseUp:
          self.mouseUpLocation = result.locationInScreen
          if self.mouseDownLocation != nil {
            self.mouseEventsHandler.stopListening()
          }
        }
      }
    } catch let error {
      print(error.localizedDescription)
    }
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
      guard start != .zero && end != .zero else {
          return nil
      }
      
      return CGRect(x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(start.x - end.x),
                    height: abs(start.y - end.y))
  }
}
