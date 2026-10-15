Pod::Spec.new do |s|
  s.name = 'TgCineTDLib'
  s.version = '1.8.68'
  s.summary = 'Locally verified TDLib JSON framework for TG Cine.'
  s.homepage = 'https://github.com/tdlib/td'
  s.license = { :type => 'BSL-1.0', :file => 'LICENSE_1_0.txt' }
  s.author = 'TDLib contributors'
  s.source = { :git => 'https://github.com/tdlib/td.git', :commit => 'c15d3f5a5de6e3ba5839822c451152e5e18bb700' }
  s.platform = :ios, '15.0'
  s.vendored_frameworks = 'Frameworks/tdjson.xcframework'
end
