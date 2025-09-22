import Cocoa

public class ScreenshotCLI: @unchecked Sendable {
    
  public lazy var screenshotDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
  
  // MARK: - Screenshot parameters
  
  public var soundEnabled: Bool = true
  public var windowShadowEnabled: Bool = true
      
  
  public init() {
    
  }
  
  static public func requestNeededPermissions() {
      if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeUnknown {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
      }
  }
  
  func createScreenshotURL() -> URL? {
    return screenshotDirectory?
      .appendingPathComponent("Screen Shot " + UUID().uuidString)
      .appendingPathExtension("png")
  }
  
  func createWindowCaptureURL() -> URL? {
    return screenshotDirectory?
      .appendingPathComponent("Window capture " + UUID().uuidString)
      .appendingPathExtension("png")
  }
  
  
  @MainActor
  public func createScreenshot(params: ScreenshotParams? = nil) async throws -> Screenshot {
    guard let url = createScreenshotURL() else {
      throw ScreenshotError.screenshotDirectoryIsInvalid
    }
    
    let soundEnabled = self.soundEnabled
    
    // this is needed to get rectangle of captured screenshot
    // as /usr/bin/xattr and kMDItemScreenCaptureGlobalRect doesn't work since macOS 12 release
    let screenshotRectHandler = ScreenshotRectHandler()
    screenshotRectHandler.startEventsMonitor()
    
    defer {
      screenshotRectHandler.stopEventsMonitor()
    }
    
    
    let pipe = Pipe()
    let task = Process()
    task.standardOutput = pipe
    
    task.launchPath = "/usr/sbin/screencapture"
  
    var args = "-"
    
    if !soundEnabled {
      if !soundEnabled {
        args.append("x")
      }
    }
  
    if let rect = params?.selectionRect {
      args.append(String(format: "R%d,%d,%d,%d",
                         Int(rect.origin.x),
                         Int(rect.origin.y),
                         Int(rect.size.width),
                         Int(rect.size.height)))
    } else {
      args.append("s")
    }
    
    task.arguments = [args, url.path]
    task.qualityOfService = .userInteractive
     
   
  
    task.launch()
    task.waitUntilExit()
    
    guard task.terminationStatus == 0 else {
      throw ScreenshotError.terminationStatusNotZero(Int(task.terminationStatus),
                                                     pipe.fileHandleForReading.availableData)
    }
    
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw ScreenshotError.userCancelled
    }
    
    if let rect = params?.selectionRect {
      return .init(url: url, rect: rect.integral)
    } else {
      let rect = screenshotRectHandler.screenshotRect()
      return .init(url: url, rect: rect?.integral)
    }
  }
  
  @MainActor
  public func captureWindow() async throws -> URL {
    guard let url = createWindowCaptureURL() else {
      throw ScreenshotError.cantCreateWindowCaptureURL
    }
    
    let soundEnabled = self.soundEnabled
    let windowShadowEnabled = self.windowShadowEnabled
    
    let pipe = Pipe()
    let task = Process()
    task.standardOutput = pipe
    task.launchPath = "/usr/sbin/screencapture"
    var args: String = "-w"
    
    if !soundEnabled {
      args.append("x")
    }
    
    if !windowShadowEnabled {
      args.append("o")
    }
  
    task.arguments = [args, url.path]
    task.qualityOfService = .userInteractive
  
    task.launch()
    task.waitUntilExit()
    
    guard task.terminationStatus == 0 else {
      throw ScreenshotError.terminationStatusNotZero(Int(task.terminationStatus),
                                                     pipe.fileHandleForReading.availableData)
    }
    
    return url
  }

}
