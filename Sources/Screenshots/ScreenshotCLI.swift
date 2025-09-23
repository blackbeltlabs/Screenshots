import Cocoa

@MainActor
public final class ScreenshotCLI: Sendable {
  
  private var fileManager: FileManager {
    FileManager.default
  }
  
  // MARK: - Screenshot parameters
  private var screenshotDirectory: URL? {
    fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
  }
      
  public init() { }
  
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
  
  
  public func createScreenshot(params: ScreenshotParams? = nil, soundEnabled: Bool) async throws(ScreenshotError) -> Screenshot {
    guard let url = createScreenshotURL() else {
      throw ScreenshotError.screenshotDirectoryIsInvalid
    }
        
    // this is needed to get rectangle of captured screenshot
    // as /usr/bin/xattr and kMDItemScreenCaptureGlobalRect doesn't work since macOS 12 release
    let screenshotRectHandler = ScreenshotRectHandler()
    screenshotRectHandler.startEventsMonitor()
    
    defer {
      screenshotRectHandler.stopEventsMonitor()
    }
    

    var args = "-"
    
    if !soundEnabled {
        args.append("x")
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
    
    try runTask(args: args, url: url)
    
    if let rect = params?.selectionRect {
      return .init(url: url, rect: rect.integral)
    } else {
      let rect = screenshotRectHandler.screenshotRect()
      return .init(url: url, rect: rect?.integral)
    }
  }
  

  public func captureWindow(soundEnabled: Bool, windowShadowEnabled: Bool) async throws(ScreenshotError) -> URL {
    guard let url = createWindowCaptureURL() else {
      throw ScreenshotError.cantCreateWindowCaptureURL
    }
    
    var args: String = "-w"
    
    if !soundEnabled {
      args.append("x")
    }
    
    if !windowShadowEnabled {
      args.append("o")
    }
  
    try runTask(args: args, url: url)
    
    return url
  }
  
  private func runTask(args: String, url: URL) throws(ScreenshotError) {
    let pipe = Pipe()
    let task = Process()
    task.standardOutput = pipe
    
    task.launchPath = "/usr/sbin/screencapture"
    
    task.arguments = [args, url.path]
    task.qualityOfService = .userInteractive
    
    task.launch()
    task.waitUntilExit()
    
    guard task.terminationStatus == 0 else {
      throw ScreenshotError.terminationStatusNotZero(Int(task.terminationStatus),
                                                     pipe.fileHandleForReading.availableData)
    }
    
    // if file doesn't exist then treat is as user cancelled
    // as there is not another way to know about it
    guard fileManager.fileExists(atPath: url.path) else {
      throw ScreenshotError.userCancelled
    }
  }
}
