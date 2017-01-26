Pod::Spec.new do |s|
  s.name             = "ImagePicker"
  s.summary          = "Reinventing the way ImagePicker works."
  s.version          = "1.5.0"
  s.homepage         = "https://github.com/stanft/ImagePicker"
  s.license          = 'MIT'
  s.author           = { "Hyper Interaktiv AS" => "ios@hyper.no", "Stephan Anft" => "stephan.anft@lhind.dlh.de" }
  s.source           = { :git => "https://github.com/stanft/ImagePicker.git", :tag => s.version.to_s }
  s.platform     = :ios, '8.0'
  s.requires_arc = true
  s.source_files = 'Source/**/*'
  s.resource_bundles = { 'ImagePicker' => ['Images/*.{png}'] }
  s.frameworks = 'AVFoundation'
end
