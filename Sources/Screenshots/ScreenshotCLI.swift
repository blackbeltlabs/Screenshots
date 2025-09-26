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
  
  private func createScreenshotURL() -> URL? {
    return screenshotDirectory?
      .appendingPathComponent("Screen Shot " + UUID().uuidString)
      .appendingPathExtension("png")
  }
  
  private func createWindowCaptureURL() -> URL? {
    return screenshotDirectory?
      .appendingPathComponent("Window capture " + UUID().uuidString)
      .appendingPathExtension("png")
  }
  
  
  // MARK: - Public
  
  public func captureScreenshotImage(params: ScreenshotParams? = nil,
                                     soundEnabled: Bool) async throws(ScreenshotError) -> ScreenshotImage {
    
    // 1. take screenshot
    let screenshot = try await captureScreenshot(params: params, soundEnabled: soundEnabled)
    
    // 2. try to remove url on completion later (if screenshot was taken)
    defer {
        // remove screenshot file on the next run loop cycle
        // to prevent possible delay s in current flow
      Task {
          removeScreenshotFile(screenshot.url)
      }
    }
    
    // 3. try to create image
    guard let image = NSImage(contentsOf: screenshot.url) else {
      throw .cantCreateNSImageFromURL
    }
    
    Log.main.debug("Returning image created from path: \(screenshot.url.path)")
    
    return .init(image: image, rect: screenshot.rect)
  }
  
  
  public func captureScreenshot(params: ScreenshotParams? = nil, soundEnabled: Bool) async throws(ScreenshotError) -> Screenshot {
    guard let url = createScreenshotURL() else {
      throw .screenshotDirectoryIsInvalid
    }
    
    Log.main.debug("Start capturing screenshot to save into path: \(url.path)")
        
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
      let selectionRect = rect.integral
      Log.main.debug("Captured screenshot. Rect: \(selectionRect)")
      
      return .init(url: url, rect: selectionRect)
    } else {
      let selectionRect = screenshotRectHandler.screenshotRect()?.integral
      
      if let selectionRect {
        Log.main.debug("Captured screenshot. Rect: \(selectionRect)")
      } else {
        Log.main.warning("Captured screenshot. Couldn't get selection rect")
      }
      
      return .init(url: url, rect: selectionRect)
    }
  }
  
  public func captureWindowImage(soundEnabled: Bool, windowShadowEnabled: Bool) async throws(ScreenshotError) -> NSImage {
    // 1. take screenshot
    let windowURL = try await captureWindow(soundEnabled: soundEnabled, windowShadowEnabled: windowShadowEnabled)
    
    // 2. try to remove url on completion later (if screenshot was taken)
    defer {
      Task {
        removeScreenshotFile(windowURL)
      }
    }
    
    // 3. try to create image
    guard let image = NSImage(contentsOf: windowURL) else {
      throw .cantCreateNSImageFromURL
    }
    
    Log.main.debug("Returning window image created from path: \(windowURL.path)")

    return image
  }

  public func captureWindow(soundEnabled: Bool, windowShadowEnabled: Bool) async throws(ScreenshotError) -> URL {
    guard let url = createWindowCaptureURL() else {
      throw .cantCreateWindowCaptureURL
    }
    
    Log.main.debug("Start capturing window to save into path: \(url.path)")
    
    var args: String = "-w"
    
    if !soundEnabled {
      args.append("x")
    }
    
    if !windowShadowEnabled {
      args.append("o")
    }
  
    try runTask(args: args, url: url)
    
    Log.main.debug("Captured window.")
    
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
      throw .terminationStatusNotZero(Int(task.terminationStatus),
                                                     pipe.fileHandleForReading.availableData)
    }
    
    // if file doesn't exist then treat is as user cancelled
    // as there is not another way to know about it
    guard fileManager.fileExists(atPath: url.path) else {
      throw .userCancelled
    }
  }
  
  private func removeScreenshotFile(_ url: URL) {
    do {
      try FileManager.default.removeItem(at: url)
      Log.main.debug("Removed screenshot file: \(url.path)")
    } catch let error {
      Log.main.warning("Can't remove screenshot file: \(error.localizedDescription)")
    }
  }
}


// MARK: - Extensions
extension CGRect: @retroactive CustomStringConvertible {
  public var description: String {
    let p1 = "(\(minX), \(minY))"
    let p2 = "(\(maxX), \(maxY))"
    return "Min X, Y: \(p1) – Max X, Y: \(p2). Width: \(width). Height: \(height)"
  }
}
