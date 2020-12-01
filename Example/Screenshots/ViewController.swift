//
//  ViewController.swift
//  Screenshots
//
//  Created by Mirko Kiefer on 02/24/2019.
//  Copyright (c) 2019 Mirko Kiefer. All rights reserved.
//

import Cocoa
import Screenshots

class ViewController: NSViewController {

  @IBOutlet var imageView: NSImageView!
  @IBOutlet var textField: NSTextField!
  @IBOutlet weak var soundEnabledField: NSButton!
  
  lazy var cliScreenshots = ScreenshotCLI()
  lazy var systemScreenshots = SystemScreenshotWatcher()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    systemScreenshots.delegate = self
    systemScreenshots.start()
    
    cliScreenshots.delegate = self
    cliScreenshots.taskDelegate = self
    cliScreenshots.start()
    
    cliScreenshots.soundEnabled = soundEnabledField.state == .on
  }

  override var representedObject: Any? {
    didSet {
    // Update the view, if already loaded.
    }
  }

  @IBAction func didTapCreateScreenshot(sender: Any) {
    cliScreenshots.createScreenshot()
  }
  
  @IBAction func soundEnabledPressed(_ sender: Any) {
    cliScreenshots.soundEnabled = soundEnabledField.state == .on
  }
}

extension ViewController: ScreenshotWatcherDelegate {
  func screenshotWatcher(_ watcher: ScreenshotWatcher, didCapture screenshot: Screenshot) {
    if let error = screenshot.error {
      switch error {
      case .invalidImage: textField.stringValue = "Error: Failed reading screenshot"
      case .missingMetadataRectProperty:
        textField.stringValue = "Error: Failed reading screenshot coordinates"
        let image = NSImage(byReferencing: screenshot.url)
        imageView.image = image
      }
      
      return
    }
    
    textField.stringValue = "Success rect: \(screenshot.rect!), retries: \(screenshot.retries)"
    let image = NSImage(byReferencing: screenshot.url)
    imageView.image = image
  }
}

extension ViewController: ScreenshotTaskDelegate {
  func screenshotCLITaskCompleted(_ screenshotCLI: ScreenshotCLI) {
    print("Screenshot task is completed")
  }
}
