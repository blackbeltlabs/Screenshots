
Pod::Spec.new do |s|
  s.name             = 'Screenshots'
  s.version          = '0.4.0'
  s.summary          = 'Create screenshots on macOS via the screencapture CLI.'

  s.description      = <<-DESC
This lib allows you to create screenshots including screen coordinates via the screencapture CLI.
It also supports watching Desktop for any system screenshots.
                       DESC

  s.homepage         = 'https://github.com/blackbeltlabs/Screenshots'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Mirko Kiefer' => 'mail@mirkokiefer.com' }
  s.source           = { :git => 'https://github.com/blackbeltlabs/Screenshots.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/mirkokiefer'
  s.platform = :osx
  s.osx.deployment_target = "10.13"
  s.swift_version = "5.0"
  s.source_files = 'Screenshots/Classes/**/*'
end
