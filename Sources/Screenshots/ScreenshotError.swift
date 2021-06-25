import Foundation

public enum ScreenshotError: Error {
  case screenshotDirectoryIsInvalid
  case userCancelled
  case terminationStatusNotZero(_ status: Int, _ outputData: Data)
}
