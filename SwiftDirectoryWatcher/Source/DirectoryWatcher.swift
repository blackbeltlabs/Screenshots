
import Foundation

public struct DirectoryChangeSet {
  public var newFiles: [URL]
  public var deletedFiles: [URL]
}

public protocol DirectoryWatcherDelegate {
  func directoryWatcher(_ watcher: DirectoryWatcher, changed: DirectoryChangeSet)
  func directoryWatcher(_ watcher: DirectoryWatcher, error: Error)
}

public extension DirectoryWatcherDelegate {
  func directoryWatcher(_ watcher: DirectoryWatcher, error: Error) {}
}

public class DirectoryWatcher {
  public var delegate: DirectoryWatcherDelegate?
  public var url: URL
  var lastFiles: [URL] = []
  var currentFiles: [URL] {
    getCurrentFiles()
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
    
    dispatchSource.setEventHandler { [weak self] in
      guard let self = self else { return }
      
      do {
        try self.handleChangeEvent()
      } catch {
        self.delegate?.directoryWatcher(self, error: error)
      }
    }
    
    dispatchSource.setCancelHandler { [weak self] in
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
  
  func getCurrentFiles() -> [URL] {
    do {
      return try FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [.creationDateKey, .typeIdentifierKey],
        options: [.skipsHiddenFiles]
      )
    } catch {
      delegate?.directoryWatcher(self, error: error)
      return []
    }
  }
  
  func handleChangeEvent() throws {
    let currentFiles = self.currentFiles
    let newFiles = try listNewFiles(lastFiles: lastFiles, currentFiles: currentFiles)
    let deletedFiles = try listDeletedFiles(lastFiles: lastFiles, currentFiles: currentFiles)
    
    let changes = DirectoryChangeSet(newFiles: newFiles, deletedFiles: deletedFiles)
    delegate?.directoryWatcher(self, changed: changes)
    
    lastFiles = currentFiles
  }
  
  func listNewFiles(lastFiles: [URL], currentFiles: [URL]) throws -> [URL] {
    try createDiff(left: currentFiles, right: lastFiles)
  }
  
  func listDeletedFiles(lastFiles: [URL], currentFiles: [URL]) throws -> [URL] {
    try createDiff(left: lastFiles, right: currentFiles)
  }
  
  func createDiff(left: [URL], right: [URL]) throws -> [URL] {
    try Set(left).subtracting(right).sorted { try $0.creationDate() > $1.creationDate() }
  }
}

private extension URL {
  func creationDate() throws -> Date {
    try resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast
  }
}
