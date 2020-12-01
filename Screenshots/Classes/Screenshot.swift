
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

extension URL: ScreenshotURL {
  var screenCaptureRect: CGRect? {
    guard let item = NSMetadataItem(url: self) else {
      return nil
    }
    
    guard let attributes = item.value(forAttribute: "kMDItemScreenCaptureGlobalRect") as? [Int] else {
      return nil
    }
    
    return CGRect(x: attributes[0], y: attributes[1], width: attributes[2], height: attributes[3])
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
  
  public lazy var screenshotDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
  
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
  
  public func createScreenshot() {
    if task != nil {
      return
    }
    
    let url = createScreenshotURL()
    let soundEnabled = self.soundEnabled
    
    DispatchQueue.global(qos: .userInteractive).async {
      let task = Process()
      task.launchPath = "/usr/sbin/screencapture"
      
      var args: String = "-i"
      
      if !soundEnabled {
        args.append("x")
      }
      
      task.arguments = [args, url.path]
      task.qualityOfService = .userInteractive
      
      self.task = task
      
      task.launch()
      task.waitUntilExit()
      
      self.taskDelegate?.screenshotCLITaskCompleted(self)
      
      self.task = nil
      
      if task.terminationStatus != 0 {
        print("Error: task.terminationStatus != 0")
        return
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
