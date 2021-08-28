Pod::Spec.new do |s|

  s.name         = "DisplayKit"
  s.version      = "0.0.2"
  s.summary      = "DisplayKit FOR AsyncDisplayKit UI Elements"
  s.homepage     = "https://github.com/donik/DisplayKit"
  s.license      = "MIT"

  s.authors            = { "Daniyar Gabbassov" => "donik102@gmail.com" }

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = "10.7"

  s.source       = { :git => "https://github.com/donik/DisplayKit.git", :tag => s.version }
  s.source_files  = "Display/**/*.{h,m,swift}"
  s.requires_arc = true

  s.subspec 'AsyncDisplayKit' do |ask|
  	ask.dependency 'AsyncDisplayKit', :git => 'https://github.com/donik/ASDisplayKit.git'
  end

  s.subspec 'SSignalKit' do |ask|
  	ask.dependency 'SSignalKit', :git => "https://github.com/donik/Signals.git"
  end

end