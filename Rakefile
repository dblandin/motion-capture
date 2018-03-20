# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project/template/ios'
require './lib/motion-capture'

Motion::Project::App.setup do |app|
  app.name = 'motion-capture'

  app.interface_orientations = [:portrait]

  app.frameworks += %w(AVFoundation Photos)

  app.info_plist['NSCameraUsageDescription'] = 'Camera will be used to display a preview and take a photo.'
  app.info_plist['NSPhotoLibraryUsageDescription'] = 'Photos taken will be saved to your library.'

  app.codesign_certificate = ENV['DEVELOPMENT_CERTIFICATE']
  app.provisioning_profile = ENV['PROVISIONING_PROFILE']
end
