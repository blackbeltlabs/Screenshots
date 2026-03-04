import Foundation

public enum ScreenshotError: LocalizedError, Sendable {
  case screenshotDirectoryIsInvalid
  case userCancelled
  case terminationStatusNotZero(_ status: Int, _ outputData: Data)
  case processLaunchFailed(NSError)
  case cantCreateWindowCaptureURL
  case cantCreateNSImageFromURL
  
  public var errorDescription: String? {
    switch self {
    case .screenshotDirectoryIsInvalid:
      return "Screenshot directory is invalid"
    case .userCancelled:
      return "User cancelled taking screenshot"
    case .terminationStatusNotZero(let status, _):
      return "Error. Termination status code = \(status)"
    case .cantCreateWindowCaptureURL:
      return "Can't create url for window capture"
    case .cantCreateNSImageFromURL:
      return "Can't create image from file"
    case .processLaunchFailed(let nsError):
      return "Error running capture tool. Error message: \(nsError.localizedDescription). Domain: \(nsError.domain). Code: \(nsError.code)"
    }
  }
}
