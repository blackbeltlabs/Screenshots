import Foundation

public enum ScreenshotError: Error {
  case userCancelled
  case terminationStatusNotZero(_ status: Int, _ outputData: Data)
//  case invalidImage
//  case missingMetadataRectProperty
}
