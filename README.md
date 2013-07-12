# motion-capture

Camera support for custom camera controllers

## Usage

``` ruby
motion_capture = Motion::Capture.new
motion_capture = Motion::Capture.new(device: :front) # specify camera

preview = motion_capture.capture_preview_view(frame: view.bounds)
view.addSubview(preview) # UIView containing AVCaptureVideoPreviewLayer

motion_capture.toggle_camera # Switch between front/rear cameras
motion_capture.toggle_flash  # Switch bettwen flash on/off

motion_capture.turn_flash_on
motion_capture.turn_flash_off

motion_capture.use_camera(:default)
motion_capture.use_camera(:front)
motion_capture.use_camera(:rear)

motion_capture.capture do |image_data|
  # Use NSData
end

motion_capture.capture_and_save do |asset_url|
  # Use NSURL
end
```

## Setup

Add this line to your application's Gemfile:

    gem 'motion-capture'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install motion-capture

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
