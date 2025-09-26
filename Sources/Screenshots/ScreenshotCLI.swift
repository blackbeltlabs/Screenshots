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
        // to prevent possible delays in current flow
      Task {
          removeScreenshotFile(screenshot.url)
      }
    }
    
    // 3. try to create image
    guard let image = NSImage(contentsOf: screenshot.url) else {
      throw .cantCreateNSImageFromURL
    }
    
    return .init(image: image, rect: screenshot.rect)
  }
  
  
  public func captureScreenshot(params: ScreenshotParams? = nil, soundEnabled: Bool) async throws(ScreenshotError) -> Screenshot {
    guard let url = createScreenshotURL() else {
      throw .screenshotDirectoryIsInvalid
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
    
    return image
  }

  public func captureWindow(soundEnabled: Bool, windowShadowEnabled: Bool) async throws(ScreenshotError) -> URL {
    guard let url = createWindowCaptureURL() else {
      throw .cantCreateWindowCaptureURL
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
      } catch let error {
        print("Warning: can't remove screenshot file: \(error.localizedDescription)")
      }
  }
}
