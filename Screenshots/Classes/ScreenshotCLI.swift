import Cocoa

public class ScreenshotCLI {
    
  public lazy var screenshotDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
  
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
    let url = createScreenshotURL()
    let soundEnabled = self.soundEnabled
    
    DispatchQueue.global(qos: .userInteractive).async { [weak self] in
      guard let self = self else { return }
      
      let pipe = Pipe()
      let task = Process()
      task.standardOutput = pipe
      
      task.launchPath = "/usr/sbin/screencapture"
      
      var args: String = "-s"
      
      if !soundEnabled {
        args.append("x")
      }
      
      task.arguments = [args, url.path]
      task.qualityOfService = .userInteractive
      
      //self.task = task
      
      task.launch()
      task.waitUntilExit()
      
    
     // self.task = nil
      
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
        
        let attributes = self.getAttributes(for: url)
        DispatchQueue.main.async {
          completion(.success(.init(url: url, rect: attributes)))
        }
      }
    }
  }
  
  public func captureWindow(completion: @escaping ((URL?) -> Void)) {
   
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
      
        task.launch()
        task.waitUntilExit()
                  
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
