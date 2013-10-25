# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project/template/ios'
require './lib/motion-capture'

Motion::Project::App.setup do |app|
  app.name = 'motion-capture'

  app.interface_orientations = [:portrait]

  app.frameworks += %w(AVFoundation AssetsLibrary)

  app.codesign_certificate = ENV['DEVELOPMENT_CERTIFICATE']
  app.provisioning_profile = ENV['PROVISIONING_PROFILE']
end
