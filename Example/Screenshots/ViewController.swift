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
 // lazy var systemScreenshots = SystemScreenshotWatcher()
  
  override func viewDidLoad() {
    super.viewDidLoad()

    cliScreenshots.taskDelegate = self
    cliScreenshots.soundEnabled = soundEnabledField.state == .on
  }

  override var representedObject: Any? {
    didSet {
    // Update the view, if already loaded.
    }
  }

  @IBAction func didTapCreateScreenshot(sender: Any) {
    cliScreenshots.createScreenshot { (result) in
      switch result {
      case .success(let screenshot):
        DispatchQueue.main.async {
          self.textField.stringValue = "Success rect: \(screenshot.rect), retries: \(screenshot.retries)"
          let image = NSImage(byReferencing: screenshot.url)
          self.imageView.image = image
        }
      case .failure(let error):
        print(error.localizedDescription)
      }
    }
  }
  
  @IBAction func soundEnabledPressed(_ sender: Any) {
    cliScreenshots.soundEnabled = soundEnabledField.state == .on
  }
  
  @IBAction func captureWindowPressed(_ sender: Any) {
    cliScreenshots.captureWindow { [weak self] (url) in
      guard let self = self, let url = url else { return }
      self.imageView.image = NSImage(contentsOf: url)
    }
  }
  
}

extension ViewController: ScreenshotTaskDelegate {
  func screenshotCLITaskCompleted(_ screenshotCLI: ScreenshotCLI) {
    print("Screenshot task is completed")
  }
}
