Pod::Spec.new do |s|

  s.name         = "DisplayKit"
  s.version      = "0.0.1"
  s.summary      = "DisplayKit FOR AsyncDisplayKit UI Elements"
  s.homepage     = "https://github.com/donik/DisplayKit"
  s.license      = "MIT"

  s.authors            = { "Daniyar Gabbassov" => "donik102@gmail.com" }

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = "10.7"

  s.source       = { :git => "https://github.com/donik/DisplayKit.git", :tag => s.version }
  c.source_files  = "Display/**/*.{h,m,swift}"
  s.requires_arc = true
end
