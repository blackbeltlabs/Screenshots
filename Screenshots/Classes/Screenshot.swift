import Cocoa

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

public class ScreenshotCLI {

  public static var shared = ScreenshotCLI()
  
  public var delegate: ScreenshotWatcherDelegate?
  public var taskDelegate: ScreenshotTaskDelegate?
  
  public lazy var screenshotDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
  
  var task: Process?
    
    
  // MARK: - Screenshot parameters
  
  public var soundEnabled: Bool = true
  
  public init() {
    
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
  
  public func createScreenshot(completion: @escaping (Result<Screenshot, Error>) -> Void) {
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
      
     
      
      self.taskDelegate?.screenshotCLITaskCompleted(self)
      
      self.task = nil
      
      if task.terminationStatus != 0 {
        print("Error: task.terminationStatus != 0")
        return
      } else {
        // FIXME: - Check if url exists otherwise it means that a user cancelled the execution
        let attributes = getAttributes(for: url)
        completion(.success(.init(url: url, rect: attributes, error: nil, retries: 0)))
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
