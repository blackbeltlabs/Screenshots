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
    
    cliScreenshots.createScreenshot(params: params) { [weak self] (result) in
      guard let self = self else { return }
      switch result {
      case .success(let screenshot):
        DispatchQueue.main.async {
          self.textField.stringValue = "Success rect: \(String(describing: screenshot.rect?.integral))"
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
  
  @IBAction func windowShadowEnabledPressed(_ sender: Any) {
    cliScreenshots.windowShadowEnabled = windowShadowEnabledField.state == .on
  }
  
  @IBAction func captureWindowPressed(_ sender: Any) {
    cliScreenshots.captureWindow { [weak self] (url) in
      guard let self = self, let url = url else { return }
        self.imageView.image = NSImage(contentsOf: url)?.resizeTo(width: 500, height: 500)
    }
  }
  
}

extension NSImage {
    func resizeTo(width: CGFloat, height: CGFloat) -> NSImage {
           let ratioX = width / size.width
           let ratioY = height / size.height
           let ratio = ratioX < ratioY ? ratioX : ratioY
           let newHeight = size.height * ratio
           let newWidth = size.width * ratio
           let canvasSize = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
           let img = NSImage(size: canvasSize)
           img.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
           draw(in: NSRect(origin: CGPoint(x: (canvasSize.width - (size.width * ratio)) / 2, y: (canvasSize.height - (size.height * ratio)) / 2), size: NSSize(width: newWidth,height: newHeight)), from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1)
           img.unlockFocus()
           return img

   }
}
