
import Cocoa
import SwiftDirectoryWatcher

let DEFAULT_MAX_RETRIES: Int = 10
let DEFAULT_RETRY_WAIT: Double = 0.1

public enum ScreenshotError: String, Error {
  case invalidImage
  case missingMetadataRectProperty
}

public protocol ScreenshotWatcher: class {
  var delegate: ScreenshotWatcherDelegate? { get set }
  var maxRetries: Int { get set }
  var retryWait: Double { get set }
  
  func start()
  func stop()
}

public struct Screenshot {
  public var url: URL
  public var rect: CGRect?
  public var error: ScreenshotError?
  public var retries: Int
  
  public func delete() {
    try? FileManager.default.removeItem(at: url)
  }
}

public protocol ScreenshotTaskDelegate {
  func screenshotCLITaskCompleted(_ screenshotCLI: ScreenshotCLI)
}

public protocol ScreenshotWatcherDelegate {
  func screenshotWatcher(_ watcher: ScreenshotWatcher, didCapture screenshot: Screenshot)
}

protocol ScreenshotURL {
  var screenCaptureRect: CGRect? { get }
}

func readUntilDefined<T>(
  retries: Int, retryAcc: Int = 0, wait: Double,
  read: @escaping () -> T?,
  callback: @escaping (_ result: T?, _ retries: Int) -> Void
  ) {
  if let result = read() {
    callback(result, retryAcc)
    return
  }
  
  if retries == 0 {
    callback(nil, retryAcc)
    return
  }
  
  DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
    readUntilDefined(
      retries: retries - 1, retryAcc: retryAcc + 1,
      wait: wait, read: read, callback: callback
    )
  }
}

func getAttributes(for url: URL) -> CGRect? {
  let task = Process()
  let pipe = Pipe()
  
  task.standardOutput = pipe
  task.launchPath = "/usr/bin/xattr"
  
  task.arguments = ["-p", "com.apple.metadata:kMDItemScreenCaptureGlobalRect", url.path]
  //task.arguments = [url.path]
  task.qualityOfService = .userInteractive
  task.launch()
  task.waitUntilExit()
  
  guard task.terminationStatus == 0 else { return nil}
  
  let output = pipe.fileHandleForReading.availableData
  
  print(output.count)
  
  let outputString = String(data: output, encoding: String.Encoding.utf8) ?? ""
  
  guard let hexademical = outputString.hexadecimal else {
    return nil
  }
  print(outputString)
  
  do {
    var format = PropertyListSerialization.PropertyListFormat.binary
    guard let attributes = try PropertyListSerialization.propertyList(from: hexademical,
                                                                        format: &format) as? [Int] else {
      return nil
    }
    
    
    if attributes.count == 4 {
      return CGRect(x: attributes[0],
                    y: attributes[1],
                    width: attributes[2],
                    height: attributes[3])
    } else {
      return nil
    }
  } catch let error {
    print(error)
    return nil
  }
 
}


extension URL: ScreenshotURL {
  var screenCaptureRect: CGRect? {
    return getAttributes(for: self)
//    guard let item = NSMetadataItem(url: self) else {
//      return nil
//    }
//
//    guard let attributes = item.value(forAttribute: "kMDItemScreenCaptureGlobalRect") as? [Int] else {
//      return nil
//    }
//
//    return CGRect(x: attributes[0], y: attributes[1], width: attributes[2], height: attributes[3])
  }
  
  func readScreenCaptureRect(retries: Int, wait: Double, result: @escaping (CGRect?, Int) -> Void) {
    readUntilDefined(retries: retries, wait: wait, read: { () -> CGRect? in
      return self.screenCaptureRect
    }) { (rect: CGRect?, retries: Int) in
      result(rect, retries)
    }
  }
}

public class SystemScreenshotWatcher: ScreenshotWatcher {
  public var maxRetries = DEFAULT_MAX_RETRIES
  public var retryWait = DEFAULT_RETRY_WAIT
  
  public static var shared = SystemScreenshotWatcher()
  
  public var delegate: ScreenshotWatcherDelegate?
  
  lazy var screenshotDirectory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
  
  lazy var directoryWatcher: DirectoryWatcher = {
    let watcher = DirectoryWatcher(url: screenshotDirectory)
    watcher.delegate = self
    return watcher
  }()
  
  public init() {
    
  }
  
  public func start() {
    directoryWatcher.start()
  }
  
  public func stop() {
    directoryWatcher.stop()
  }
}

extension SystemScreenshotWatcher: DirectoryWatcherDelegate {
  public func directoryWatcher(_ watcher: DirectoryWatcher, changed: DirectoryChangeSet) {
    guard let screenshotURL = (changed.newFiles.first {
      $0.pathExtension == "png" && $0.lastPathComponent.contains("Screen Shot")
    }) else {
      return
    }
    
    screenshotURL.readScreenCaptureRect(retries: maxRetries, wait: retryWait) { (rect, retries) in
      var screenshot = Screenshot(url: screenshotURL, rect: rect, error: nil, retries: retries)

      if rect == nil {
        screenshot.error = ScreenshotError.missingMetadataRectProperty
      }
      
      self.delegate?.screenshotWatcher(self, didCapture: screenshot)
    }
  }
}

public class ScreenshotCLI: ScreenshotWatcher {
  public var maxRetries = DEFAULT_MAX_RETRIES
  public var retryWait = DEFAULT_RETRY_WAIT

  public static var shared = ScreenshotCLI()
  
  public var delegate: ScreenshotWatcherDelegate?
  public var taskDelegate: ScreenshotTaskDelegate?
  
  public lazy var screenshotDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
  
  lazy var directoryWatcher: DirectoryWatcher = {
    let watcher = DirectoryWatcher(url: screenshotDirectory)
    watcher.delegate = self
    return watcher
  }()
  
  var task: Process?
    
    
  // MARK: - Screenshot parameters
  
  public var soundEnabled: Bool = true
  
  public init() {
    
  }
  
  public func start() {
    directoryWatcher.start()
  }
  
  public func stop() {
    directoryWatcher.stop()
  }
  
  func createScreenshotURL() -> URL {
    return screenshotDirectory
      .appendingPathComponent("Screen Shot " + UUID().uuidString)
      .appendingPathExtension("png")
  }
  
  func createWindowCaptureURL() -> URL {
    return screenshotDirectory
      .appendingPathComponent("Window capture " + UUID().uuidString)
      .appendingPathExtension("png")
  }
  
  public func createScreenshot() {
    if task != nil {
      return
    }
    
    let url = createScreenshotURL()
    let soundEnabled = self.soundEnabled
    
    DispatchQueue.global(qos: .userInteractive).async {
      let task = Process()
      task.launchPath = "/usr/sbin/screencapture"
      
      var args: String = "-s"
      
      if !soundEnabled {
        args.append("x")
      }
      
      task.arguments = [args, url.path]
      task.qualityOfService = .userInteractive
      
      self.task = task
      
      task.launch()
      task.waitUntilExit()
      
     // getAttributes(for: url)
      
      self.taskDelegate?.screenshotCLITaskCompleted(self)
      
      self.task = nil
      
      if task.terminationStatus != 0 {
        print("Error: task.terminationStatus != 0")
        return
      }
    }
  }
  
  
  public func captureWindow(completion: @escaping ((URL?) -> Void)) {
    if task != nil {
      completion(nil)
      return
    }
    
    let url = createWindowCaptureURL()
    let soundEnabled = self.soundEnabled
    
      DispatchQueue.global(qos: .userInteractive).async {
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        var args: String = "-w"
        
        if !soundEnabled {
          args.append("x")
        }
      
        task.arguments = [args, url.path]
        task.qualityOfService = .userInteractive
      
        self.task = task
      
        task.launch()
        task.waitUntilExit()
          
        self.task = nil
        
        if task.terminationStatus == 0 {
          DispatchQueue.main.async {
            completion(url)
            return
          }
        } else {
      
          if task.terminationStatus != 0 {
            print("Error: task.terminationStatus != 0")
            completion(nil)
            return
          }
        }
      }
  }
}

extension ScreenshotCLI: DirectoryWatcherDelegate {
  public func directoryWatcher(_ watcher: DirectoryWatcher, changed: DirectoryChangeSet) {
    guard let screenshotURL = (changed.newFiles.first {
      $0.pathExtension == "png" && $0.lastPathComponent.contains("Screen Shot")
    }) else {
      return
    }
    
    screenshotURL.readScreenCaptureRect(retries: maxRetries, wait: retryWait) { (rect, retries) in
      var screenshot = Screenshot(url: screenshotURL, rect: rect, error: nil, retries: retries)
      
      if rect == nil {
        screenshot.error = ScreenshotError.missingMetadataRectProperty
      }
      
      self.delegate?.screenshotWatcher(self, didCapture: screenshot)
    }
  }
}


extension String {

    /// Create `Data` from hexadecimal string representation
    ///
    /// This creates a `Data` object from hex string. Note, if the string has any spaces or non-hex characters (e.g. starts with '<' and with a '>'), those are ignored and only hex characters are processed.
    ///
    /// - returns: Data represented by this hexadecimal string.

    var hexadecimal: Data? {
        var data = Data(capacity: count / 2)

        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self)) { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }

        guard data.count > 0 else { return nil }

        return data
    }

}
