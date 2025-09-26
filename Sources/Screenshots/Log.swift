import Foundation
import OSLog

final class Log {
  
  private init() { }
  
  static let subsystem = Bundle.main.bundleIdentifier!
  
  static let main = Logger(subsystem: subsystem, category: "Screenshots framework")
}
