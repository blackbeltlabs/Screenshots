
Pod::Spec.new do |s|
  s.name             = 'Screenshots'
  s.version          = '0.3.1'
  s.summary          = 'Create screenshots on macOS via the screencapture CLI.'

  s.description      = <<-DESC
This lib allows you to create screenshots includin screen coordinates via the screencapture CLI.
It also supports watching Desktop for any system screenshots.
                       DESC

  s.homepage         = 'https://github.com/mirkokiefer/Screenshots'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Mirko Kiefer' => 'mail@mirkokiefer.com' }
  s.source           = { :git => 'https://github.com/mirkokiefer/Screenshots.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/mirkokiefer'
  s.platform = :osx
  s.osx.deployment_target = "10.13"
  s.swift_version = "4.2"
  s.source_files = 'Screenshots/Classes/**/*'
  s.dependency 'SwiftDirectoryWatcher', '0.0.7'
end
