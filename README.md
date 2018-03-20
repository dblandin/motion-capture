# motion-capture

Camera support for custom camera controllers

## Usage

``` ruby
motion_capture = Motion::Capture.new
motion_capture = Motion::Capture.new(device: :front) # specify camera
motion_capture = Motion::Capture.new(preset: AVCaptureSessionPreset640x480) # specify a different preset (defaults to high resolution photo)

motion_capture.attach(view) # apply a AVCaptureVideoPreviewLayer to the specified view

motion_capture.toggle_camera # Switch between front/rear cameras
motion_capture.toggle_flash  # Switch bettwen flash on/off

motion_capture.turn_flash_on
motion_capture.turn_flash_off

motion_capture.use_camera(:default)
motion_capture.use_camera(:front)
motion_capture.use_camera(:rear)

# When you're ready to start the capture session:
motion_capture.start!

# Capturing Single Photos

motion_capture.capture do |image_data|
  # Use NSData
end

motion_capture.capture_image do |image|
  # Use UIImage
end

# Saving captured images to the Photos library

motion_capture.capture_and_save do |image_data, asset_url|
  # Use NSData and NSURL
end

motion_capture.capture_image_and_save do |image, asset_url|
  # Use UIImage and NSURL
end

# When you're done using the camera and are ready to stop the capture session:
motion_capture.stop!
```


## Setup

Add this line to your application's Gemfile:

    gem 'motion-capture'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install motion-capture

Add the necessary frameworks to your app configuration in your Rakefile:

    app.frameworks << 'AVFoundation'
    app.frameworks << 'Photos' # if you will be saving to the Photo library and targeting iOS 8+
    app.frameworks << 'AssetsLibrary' # if you will be targeting iOS 4-7

Then update your app configuration in your Rakefile to specify the message that will be displayed when asking the user for permission to use the camera:

    app.info_plist['NSCameraUsageDescription'] = 'Camera will be used for taking your profile photo.'

If you will be saving photos to the Photo Library, you will also need to specify the message that will be displayed to the user:

    app.info_plist['NSPhotoLibraryUsageDescription'] = 'Photos taken will be saved to your library.'

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
