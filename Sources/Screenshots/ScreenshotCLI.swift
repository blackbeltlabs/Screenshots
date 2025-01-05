import Cocoa

public class ScreenshotCLI: @unchecked Sendable {
    
  public lazy var screenshotDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
  
  // MARK: - Screenshot parameters
  
  public var soundEnabled: Bool = true
  public var windowShadowEnabled: Bool = true
  
  public init() {
    
  }
  
  static public func requestNeededPermissions() {
    if #available(macOS 10.15, *) {
      if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeUnknown {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
      }
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
  
  public func createScreenshot(params: ScreenshotParams? = nil,
                               completion: @escaping @MainActor @Sendable (Result<Screenshot, Error>) -> Void) {
    guard let url = createScreenshotURL() else {
      DispatchQueue.main.async {
        completion(.failure(ScreenshotError.screenshotDirectoryIsInvalid))
      }
      return
    }
    
    let soundEnabled = self.soundEnabled
    
    DispatchQueue.global(qos: .userInteractive).async { [weak self] in
      guard let self = self else { return }
      
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
       
      let screenshotRectHandler = ScreenshotRectHandler()
      if #available(macOS 12.0, *) {
        DispatchQueue.main.async {
          screenshotRectHandler.startEventsMonitor()
        }
      }
    
      task.launch()
      task.waitUntilExit()
      
      if task.terminationStatus != 0 {
        print("Error: task.terminationStatus != 0")
          DispatchQueue.main.async {
            completion(.failure(ScreenshotError.terminationStatusNotZero(Int(task.terminationStatus),
                                                                         pipe.fileHandleForReading.availableData)))
          }
      } else {
        // FIXME: - Check if url exists otherwise it means that a user cancelled the execution
        guard FileManager.default.fileExists(atPath: url.path) else {
          DispatchQueue.main.async {
            completion(.failure(ScreenshotError.userCancelled))
          }
          return
        }
        
        self.handleSuccessfulScreenshotCapture(url: url,
                                               rect: params?.selectionRect,
                                               screenshotRectHandler: screenshotRectHandler,
                                               completion: completion)
      }
    }
  }
  
  private func handleSuccessfulScreenshotCapture(url: URL,
                                                 rect: CGRect?,
                                                 screenshotRectHandler: ScreenshotRectHandler,
                                                 completion: @escaping @MainActor @Sendable (Result<Screenshot, Error>) -> Void) {
    if let rect = rect {
      DispatchQueue.main.async {
        completion(.success(.init(url: url, rect: rect.integral)))
      }
    } else {
      if #available(macOS 12.0, *) {
        DispatchQueue.main.async {
          let rect = screenshotRectHandler.screenshotRect()
          completion(.success(.init(url: url, rect: rect?.integral)))
        }
      } else {
        let attributes = self.getAttributes(for: url)
        DispatchQueue.main.async {
          completion(.success(.init(url: url, rect: attributes?.integral)))
        }
      }
    }
    screenshotRectHandler.stopEventsMonitor()
  }
  
  public func captureWindow(completion: @escaping (@MainActor @Sendable (URL?) -> Void)) {
   
    guard let url = createWindowCaptureURL() else {
      DispatchQueue.main.async {
        completion(nil)
      }
      return
    }
    
    let soundEnabled = self.soundEnabled
    let windowShadowEnabled = self.windowShadowEnabled
    
      DispatchQueue.global(qos: .userInteractive).async {
        let task = Process()
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
                  
        if task.terminationStatus == 0 {
          DispatchQueue.main.async {
            completion(url)
            return
          }
        } else {
      
          if task.terminationStatus != 0 {
            DispatchQueue.main.async {
              print("Error: task.terminationStatus != 0")
              completion(nil)
            }
            return
          }
        }
      }
  }
  
  private func getAttributes(for url: URL) -> CGRect? {
    let task = Process()
    let pipe = Pipe()
    
    task.standardOutput = pipe
    task.launchPath = "/usr/bin/xattr"
    
    task.arguments = ["-p", "com.apple.metadata:kMDItemScreenCaptureGlobalRect", url.path]
    task.qualityOfService = .userInteractive
    task.launch()
    task.waitUntilExit()
    
    let output = pipe.fileHandleForReading.availableData
        
    let outputString = String(data: output, encoding: String.Encoding.utf8) ?? ""
    
    guard task.terminationStatus == 0 else {
      print("Can't get file attributes. Termination status is \(task.terminationStatus). Output = \(output)")
      return nil
    }
    
    guard let hexademical = outputString.hexadecimal else {
      print("Can't convert attributes HEX string to Data")
      return nil
    }
    
    do {
      var format = PropertyListSerialization.PropertyListFormat.binary
      let attributesPlist = try PropertyListSerialization.propertyList(from: hexademical,
                                                                          format: &format)
        
      guard let attributesArray = attributesPlist as? [Int] else {
        print("Attributes plist is not [Int] array as required")
        return nil
      }
     
      if attributesArray.count == 4 {
        return CGRect(x: attributesArray[0],
                      y: attributesArray[1],
                      width: attributesArray[2],
                      height: attributesArray[3])
      } else {
        return nil
      }
    } catch let error {
      print("Error getting property list from xattr returned value. \(error.localizedDescription)")
      return nil
    }
  }
}
