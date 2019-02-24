# Swift DirectoryWatcher

[![Build Status](https://travis-ci.org/mirkokiefer/SwiftDirectoryWatcher.svg?branch=master)](https://travis-ci.org/mirkokiefer/SwiftDirectoryWatcher)

Directory watcher for iOS and macOS written in Swift.

## Usage

**Example:**

```swift
import DirectoryWatcher

class ViewController: UIViewController {
  lazy var url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
  lazy var watcher = DirectoryWatcher(url: url)

  override func viewDidLoad() {
    super.viewDidLoad()
    
    watcher.delegate = self
  }
}

extension ViewController: DirectoryWatcherDelegate {
  func directoryWatcher(_ watcher: DirectoryWatcher, changed: DirectoryChangeSet) {
    print("new files \(changed.newFiles), deleted files \(changed.deletedFiles)")
  }
}
```

## Installation

### CocoaPods

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate DirectoryWatcher into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'DirectoryWatcher', '~> 0.0.4'
```

### Manually

If you prefer not to use any of the aforementioned dependency managers, you can integrate DirectoryWatcher into your project manually.

#### Embedded Framework

Download this repository into a folder at the same level of your project folder.
From your Xcode project drag the DirectoryWatcher.xcodeproj file into your project at the top level.

In your project target scroll down to the Embedded Binaries setting and drag `DirectoryWatcher.framework` from `DirectoryWatcher.xcodeproj/Products`. The top framework is for macOS, the bottom one is for iOS (they are name identically).

Build your project and you are good to go.
