import Foundation

public enum ScreenshotError: Error, Sendable {
  case screenshotDirectoryIsInvalid
  case userCancelled
  case terminationStatusNotZero(_ status: Int, _ outputData: Data)
}
