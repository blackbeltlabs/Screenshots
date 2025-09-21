import Foundation
import CoreGraphics

enum MouseEventType {
  case leftMouseUp
  case leftMouseDown
  
  case rightMouseUp
  case rightMouseDown
}

struct MouseEventsResult {
  let eventType: MouseEventType
  let locationInScreen: CGPoint
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

class MouseEventsHandler {
  
  // MARK: - Properties
  private var eventTap: CFMachPort?
  private var currentRunLoopSource: CFRunLoopSource?
  
  private var listeningCallback: ((MouseEventsResult) -> Void)?
  
  // MARK: - Start listening
  func startListening(listeningCallback: @escaping (MouseEventsResult) -> Void) throws {
    stopListening()
    
    let eventMask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue) | (1 << CGEventType.rightMouseDown.rawValue) | (1 << CGEventType.rightMouseUp.rawValue)
    
    
    
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
    
    self.listeningCallback = listeningCallback
    CGEvent.tapEnable(tap: eventTap, enable: true)
    
   // CFRunLoopRun()
  }
  
  func stopListening() {
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
    guard let listeningCallback = listeningCallback else {
      return
    }
    
    switch data.type {
    case .leftMouseDown:
      listeningCallback(.init(eventType: .leftMouseDown,
                              locationInScreen: data.event.location))
    case .leftMouseUp:
      listeningCallback(.init(eventType: .leftMouseUp,
                              locationInScreen: data.event.location))
    case .rightMouseUp:
      listeningCallback(.init(eventType: .rightMouseUp,
                              locationInScreen: data.event.location))
    case .rightMouseDown:
      listeningCallback(.init(eventType: .rightMouseDown,
                              locationInScreen: data.event.location))
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
