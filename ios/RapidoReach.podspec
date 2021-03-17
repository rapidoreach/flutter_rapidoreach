#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint RapidoReach.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'RapidoReach'
  s.version          = '1.0.2'
  s.summary          = 'Monetize your users through rewarded surveys!'
  s.description      = <<-DESC
  Monetize your users through rewarded surveys.
                       DESC
  s.homepage         = 'http://rapidoreach.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'RapidoReach' => 'info@rapidoreach.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'RapidoReachSDK', '1.0.1'
  s.platform = :ios, '8.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
