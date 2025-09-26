import Foundation
import OSLog

final class Log {
  
  private init() { }
  
  static let subsystem = Bundle.main.bundleIdentifier ?? "Screenshots"
  
  static let main = Logger(subsystem: subsystem, category: "Screenshots framework")
}
