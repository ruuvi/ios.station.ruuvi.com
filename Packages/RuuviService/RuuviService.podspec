Pod::Spec.new do |s|
  s.name             = 'RuuviService'
  s.version          = '0.0.1'
  s.summary          = 'Ruuvi Service'
  s.homepage         = 'https://ruuvi.com'
  s.author           = { 'Rinat Enikeev' => 'rinat@ruuvi.com' }
  s.license          = { :type => 'BSD 3-Clause', :file => '../../LICENSE' }
  s.platform         = :ios, '10.0'
  s.source           = { git: 'https://github.com/ruuvi/com.ruuvi.station.ios' }
  s.frameworks       = 'Foundation'
  s.requires_arc     = true
  s.ios.deployment_target = '10.0'
  s.swift_version    = '5.0'

  s.default_subspecs = 'Contract'

  s.subspec 'Contract' do |ss|
    ss.source_files = 'Sources/RuuviService/**/*.{h,m,swift}', 'Sources/RuuviService/*.{h,m,swift}'
    ss.dependency 'RuuviOntology'
    ss.dependency 'FutureX'
  end

  s.subspec 'CloudSync' do |ss|
    ss.source_files = 'Sources/RuuviServiceCloudSync/**/*.{h,m,swift}', 'Sources/RuuviServiceCloudSync/*.{h,m,swift}'
    ss.dependency 'RuuviService/Contract'
    ss.dependency 'RuuviOntology'
    ss.dependency 'RuuviPool'
    ss.dependency 'RuuviLocal'
    ss.dependency 'RuuviStorage'
    ss.dependency 'RuuviCloud'
    ss.dependency 'FutureX'
  end

  s.subspec 'Ownership' do |ss|
    ss.source_files = 'Sources/RuuviServiceOwnership/**/*.{h,m,swift}', 'Sources/RuuviServiceOwnership/*.{h,m,swift}'
    ss.dependency 'RuuviService/Contract'
    ss.dependency 'RuuviOntology'
    ss.dependency 'RuuviPool'
    ss.dependency 'RuuviStorage'
    ss.dependency 'RuuviCloud'
    ss.dependency 'FutureX'
  end

  s.subspec 'SensorProperties' do |ss|
    ss.source_files = 'Sources/RuuviServiceSensorProperties/**/*.{h,m,swift}', 'Sources/RuuviServiceSensorProperties/*.{h,m,swift}'
    ss.dependency 'RuuviService/Contract'
    ss.dependency 'RuuviOntology'
    ss.dependency 'RuuviPool'
    ss.dependency 'RuuviStorage'
    ss.dependency 'RuuviCloud'
    ss.dependency 'RuuviCore'
    ss.dependency 'FutureX'
  end

  s.subspec 'SensorRecords' do |ss|
    ss.source_files = 'Sources/RuuviServiceSensorRecords/**/*.{h,m,swift}', 'Sources/RuuviServiceSensorRecords/*.{h,m,swift}'
    ss.dependency 'RuuviService/Contract'
    ss.dependency 'RuuviOntology'
    ss.dependency 'RuuviPool'
    ss.dependency 'RuuviLocal'
    ss.dependency 'FutureX'
  end

  s.subspec 'AppSettings' do |ss|
    ss.source_files = 'Sources/RuuviServiceAppSettings/**/*.{h,m,swift}', 'Sources/RuuviServiceAppSettings/*.{h,m,swift}'
    ss.dependency 'RuuviService/Contract'
    ss.dependency 'RuuviOntology'
    ss.dependency 'RuuviLocal'
    ss.dependency 'RuuviCloud'
    ss.dependency 'FutureX'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{swift}', 'Tests/*.{swift}'
  end
end
