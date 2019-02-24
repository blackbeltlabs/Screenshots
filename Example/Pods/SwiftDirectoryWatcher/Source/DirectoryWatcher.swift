
import Foundation

public struct DirectoryChangeSet {
  public var newFiles: [URL]
  public var deletedFiles: [URL]
}

public protocol DirectoryWatcherDelegate {
  func directoryWatcher(_ watcher: DirectoryWatcher, changed: DirectoryChangeSet)
}

public class DirectoryWatcher {
  public var delegate: DirectoryWatcherDelegate?
  public var url: URL
  var lastFiles: [URL] = []
  var currentFiles: [URL] {
    return try! FileManager.default.contentsOfDirectory(
      at: url,
      includingPropertiesForKeys: [.creationDateKey, .typeIdentifierKey],
      options: [.skipsHiddenFiles]
    )
  }
  
  var path: String { return url.path }
  
  var dirFD : Int32 = -1 {
    didSet {
      if oldValue != -1 {
        close(oldValue)
      }
    }
  }
  
  public var isRunning: Bool {
    return dirFD != -1
  }
  
  private var dispatchSource : DispatchSourceFileSystemObject?
  
  public init(url: URL) {
    self.url = url
  }
  
  deinit {
    stop()
  }
  
  @discardableResult public func start() -> Bool {
    if isRunning {
      return false
    }
    
    lastFiles = currentFiles
    
    dirFD = open(path, O_EVTONLY)
    if dirFD < 0 {
      return false
    }
    
    let dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: dirFD, eventMask: .write, queue: DispatchQueue.main)
    
    dispatchSource.setEventHandler {[weak self] in
      self?.handleChangeEvent()
    }
    
    dispatchSource.setCancelHandler {[weak self] in
      self?.dirFD = -1
    }
    
    self.dispatchSource = dispatchSource
    
    dispatchSource.resume()
    
    return true
  }
  
  public func stop() {
    guard let dispatchSource = dispatchSource else {
      return
    }
    
    dispatchSource.setEventHandler(handler: nil)
    
    dispatchSource.cancel()
    self.dispatchSource = nil
  }
  
  func handleChangeEvent() {
    let currentFiles = self.currentFiles
    let newFiles = listNewFiles(lastFiles: lastFiles, currentFiles: currentFiles)
    let deletedFiles = listDeletedFiles(lastFiles: lastFiles, currentFiles: currentFiles)
    
    let changes = DirectoryChangeSet(newFiles: newFiles, deletedFiles: deletedFiles)
    delegate?.directoryWatcher(self, changed: changes)
    
    lastFiles = currentFiles
  }
  
  func listNewFiles(lastFiles: [URL], currentFiles: [URL]) -> [URL] {
    return createDiff(left: currentFiles, right: lastFiles)
  }
  
  func listDeletedFiles(lastFiles: [URL], currentFiles: [URL]) -> [URL] {
    return createDiff(left: lastFiles, right: currentFiles)
  }
  
  func createDiff(left: [URL], right: [URL]) -> [URL] {
    return Set(left).subtracting(right).sorted { (url1, url2) -> Bool in
      let date1 = try! url1.resourceValues(forKeys: [.creationDateKey]).creationDate!
      let date2 = try! url2.resourceValues(forKeys: [.creationDateKey]).creationDate!
      return date1 > date2
    }
  }
}
