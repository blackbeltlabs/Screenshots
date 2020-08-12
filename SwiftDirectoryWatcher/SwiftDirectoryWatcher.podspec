#
#  Be sure to run `pod spec lint DirectoryWatcher.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|
  spec.name         = "SwiftDirectoryWatcher"
  spec.version      = "0.0.8"
  spec.summary      = "Directory watcher for iOS and macOS written in Swift."

  spec.description  = <<-DESC
  A delegate-based directory watcher written in Swift.
  The module handles the identification of created and deleted files by diffing the folder content.
                   DESC

  spec.homepage     = "https://github.com/blackbeltlabs/SwiftDirectoryWatcher"

  spec.license      = "MIT"

  spec.author       = { "Mirko Kiefer" => "mail@mirkokiefer.com" }

  spec.swift_version = "5.0"

  spec.ios.deployment_target = "11.0"

  spec.osx.deployment_target = "10.13"

  spec.source = { :git => "https://github.com/blackbeltlabs/SwiftDirectoryWatcher.git", :tag => spec.version }

  spec.source_files = "Source/*.swift"
end
