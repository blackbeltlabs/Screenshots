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
  @IBOutlet weak var windowShadowEnabledField: NSButton!
  
  @IBOutlet weak var xTextField: NSTextField!
  @IBOutlet weak var yTextField: NSTextField!
  @IBOutlet weak var widthTextField: NSTextField!
  @IBOutlet weak var heightTextField: NSTextField!
  
  lazy var cliScreenshots = ScreenshotCLI()
  
  override func viewDidLoad() {
    super.viewDidLoad()

    cliScreenshots.soundEnabled = soundEnabledField.state == .on
  }

  override var representedObject: Any? {
    didSet {
    // Update the view, if already loaded.
    }
  }
  
  // MARK: - Actions
  
  @IBAction func didTapCreateScreenshot(sender: Any) {
    let screenshotRect: CGRect?
    
    if let x = Int(xTextField.stringValue),
       let y = Int(yTextField.stringValue),
       let width = Int(widthTextField.stringValue),
       let height = Int(heightTextField.stringValue) {
      screenshotRect = CGRect(x: x,
                              y: y,
                              width: width,
                              height: height)
    } else {
      screenshotRect = nil
    }
    
    let params: ScreenshotParams?
    
    if let screenshotRect = screenshotRect {
      params = ScreenshotParams(selectionRect: screenshotRect)
    } else {
      params = nil
    }
    
    Task { @MainActor in
      do {
        let screenshot = try await cliScreenshots.createScreenshot(params: params)
        
        self.textField.stringValue = "Success rect: \(String(describing: screenshot.rect?.integral))"
        let image = NSImage(byReferencing: screenshot.url)
        self.imageView.image = image
        
      } catch let error {
        print(error.localizedDescription)
      }
    }
  }
  
  @IBAction func soundEnabledPressed(_ sender: Any) {
    cliScreenshots.soundEnabled = soundEnabledField.state == .on
  }
  
  @IBAction func windowShadowEnabledPressed(_ sender: Any) {
    cliScreenshots.windowShadowEnabled = windowShadowEnabledField.state == .on
  }
  
  @IBAction func captureWindowPressed(_ sender: Any) {
    Task { @MainActor in
      do {
        let url = try await cliScreenshots.captureWindow()
        self.imageView.image = NSImage(contentsOf: url)
      } catch let error {
        print(error.localizedDescription)
      }
    }
  }
}
