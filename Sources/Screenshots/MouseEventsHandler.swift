import Foundation
import CoreGraphics

enum MouseEventType {
  case leftMouseUp
  case leftMouseDown
  
  case rightMouseUp
  case rightMouseDown
}

struct MouseEventsResult {
  let initialCoordinate: CGPoint
  let endCoordinate: CGPoint
}


enum MouseEventsHandlerError: Int, LocalizedError {
  case cantCreateEventTap = 0
  case cantCreateMuchPortRunLoopSource
  
  var errorDescription: String? {
    return "Can't start listening mouse events. Error code = \(self.rawValue)"
  }
}

private struct CGEventCallbackData {
  let proxy: CGEventTapProxy
  let type: CGEventType
  let event: CGEvent
  let userInfo: UnsafeMutableRawPointer?
}

final class MouseEventsHandler {
  
  // MARK: - Properties
  private var eventTap: CFMachPort?
  private var currentRunLoopSource: CFRunLoopSource?
      
  let spaceButtonKey = 49
  var spaceButtonPressed: Bool = false
  
  var initialCoordinate: CGPoint?
  var endCoordinate: CGPoint?
  var currentCoordinate: CGPoint?
    
  var mouseEventCallback: ((MouseEventsResult) -> Void)?
    
  
  // MARK: - Start listening
  func startListening(listeningCallback: @escaping (MouseEventsResult) -> Void) throws {
    stopListening()
    
    self.mouseEventCallback = listeningCallback
    
    let eventTypes: [CGEventType] = [
        .leftMouseDown,
        .leftMouseUp,
        .rightMouseDown,
        .rightMouseUp,
        .keyDown,
        .keyUp,
        .leftMouseDragged,
        .rightMouseDragged
    ]
    
    let eventMask = eventTypes.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }

    // need this trick to extract `self` later in C-function where we can't pass it directly
    let mySelf = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

    guard let eventTap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .listenOnly,
        eventsOfInterest: CGEventMask(eventMask),
        callback: callback,
        userInfo: mySelf
    ) else {
      throw MouseEventsHandlerError.cantCreateEventTap
    }
    
    self.eventTap = eventTap
    
    guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
      self.eventTap = nil
      throw MouseEventsHandlerError.cantCreateMuchPortRunLoopSource
    }
    
    CFRunLoopAddSource(CFRunLoopGetMain(),
                       runLoopSource,
                       .commonModes)
    self.currentRunLoopSource = runLoopSource
    
    CGEvent.tapEnable(tap: eventTap, enable: true)
  }
  
  func stopListening() {
    spaceButtonPressed = false
    
    mouseEventCallback = nil
    
    guard let eventTap = eventTap else {
      return
    }
    
    CGEvent.tapEnable(tap: eventTap, enable: false)
    if let currentRunLoopSource = currentRunLoopSource {
      CFRunLoopSourceInvalidate(currentRunLoopSource)
      self.currentRunLoopSource = nil
    }
    self.eventTap = nil
  }
  
  // MARK: - Callback
  fileprivate func handleCallback(data: CGEventCallbackData) {
    guard let listeningCallback = mouseEventCallback else {
      return
    }
    
    switch data.type {
    case .leftMouseDown, .rightMouseDown:
      
      let loc = data.event.location
      
      initialCoordinate = loc
      currentCoordinate = loc
      
      Log.main.debug("Mouse down at \(loc.x), \(loc.y)")

    case .leftMouseUp, .rightMouseUp:
      let loc = data.event.location
      
      endCoordinate = data.event.location
      
      if let initialCoordinate, let endCoordinate {
        listeningCallback(.init(initialCoordinate: initialCoordinate,
                                endCoordinate: endCoordinate))
      }
      
      Log.main.debug("Mouse up at \(loc.x), \(loc.y)")
    case .leftMouseDragged, .rightMouseDragged:
      let loc = data.event.location
      defer {
        self.currentCoordinate = loc
      }
      
      guard let lastCurrentCoordinate = currentCoordinate, let initialCoordinate = self.initialCoordinate else {
        return
      }
      
      guard spaceButtonPressed else { return }
        
      
      let delta: CGPoint = .init(x: loc.x - lastCurrentCoordinate.x,
                                 y: loc.y - lastCurrentCoordinate.y)
      
      self.initialCoordinate = .init(x: initialCoordinate.x + delta.x,
                                     y: initialCoordinate.y + delta.y)
          
    case .keyDown:
      let event = data.event
      let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
      if keyCode == spaceButtonKey {
        spaceButtonPressed = true
      }
        
    case .keyUp:
        let event = data.event
        
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == spaceButtonKey {
          spaceButtonPressed = false
        }
    default:
      break
    }
  }
}

// MARK: - C callback
// C-supported callback to pass into CGEvent.tapCreate
private func callback(proxy: CGEventTapProxy,
                      type: CGEventType,
                      event: CGEvent,
                      userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
  
  guard let userInfo = userInfo else {
    return nil
  }
  
  let mySelf = Unmanaged<MouseEventsHandler>.fromOpaque(userInfo).takeUnretainedValue()
  
  mySelf.handleCallback(data: .init(proxy: proxy,
                                    type: type,
                                    event: event,
                                    userInfo: userInfo))
  
  return Unmanaged.passUnretained(event)
}
