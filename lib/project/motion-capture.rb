module Motion; class Capture
  CAMERA_POSITIONS = { rear: AVCaptureDevicePositionBack, front: AVCaptureDevicePositionFront }
  FLASH_MODES      = { on: AVCaptureFlashModeOn, off: AVCaptureFlashModeOff, auto: AVCaptureFlashModeAuto }

  attr_reader :options, :device, :preview_layer

  def initialize(options = {})
    @options = options
  end

  def on_error(&block)
    @error_callback = block
  end

  def start!
    return if session.running?
    if defined?(AVCapturePhotoOutput) # iOS 10+
      @starting = true
      authorize_camera do |success|
        if success
          Dispatch::Queue.new('motion-capture').async do
            configure_session
            session.startRunning
            @starting = false
          end
        else
          @starting = false
        end
      end
    else # iOS 4-9
      configure_session
      session.startRunning
    end
  end

  def authorize_camera(&block)
    AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: -> (success) {
      block.call(success)
    })
  end

  def configure_session
    session.beginConfiguration

    set_preset(options.fetch(:preset, AVCaptureSessionPresetPhoto))

    use_camera(options.fetch(:device, :default))

    if defined?(AVCapturePhotoOutput) # iOS 10+
      add_output(photo_output)
    else # iOS 4-9
      add_output(still_image_output)
    end

    session.commitConfiguration
  end

  def running?
    @session && session.running?
  end

  def stop!
    session.stopRunning

    remove_outputs
    remove_inputs

    preview_layer.removeFromSuperlayer if preview_layer && preview_layer.superlayer

    @still_image_output = nil
    @photo_output       = nil
    @session            = nil
    @preview_layer      = nil
  end

  def capture(&block)
    if defined?(AVCapturePhotoOutput) # iOS 10+
      Dispatch::Queue.new('motion-capture').async do
        ensure_running_session do
          update_video_orientation!
          @capture_callback = block
          capture_settings = AVCapturePhotoSettings.photoSettingsWithFormat(AVVideoCodecKey => AVVideoCodecJPEG)
          photo_output.capturePhotoWithSettings(capture_settings, delegate: self)
        end
      end
    else # iOS 4-9
      still_image_output.captureStillImageAsynchronouslyFromConnection(still_image_connection, completionHandler: -> (buffer, error) {
        if error
          error_callback.call(error)
        else
          image_data = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
          block.call(image_data)
        end
      })
    end
  end

  def ensure_running_session(&block)
    start! unless @starting || session.running?
    while @starting || !session.running?
      # wait for session to start...
    end
    block.call
  end

  # iOS 11+ AVCapturePhotoCaptureDelegate method
  def captureOutput(output, didFinishProcessingPhoto: photo, error: error)
    if error
      error_callback.call(error)
    else
      @capture_callback.call(photo.fileDataRepresentation)
    end
  end

  # iOS 10 AVCapturePhotoCaptureDelegate method
  def captureOutput(output, didFinishProcessingPhotoSampleBuffer: photo_sample_buffer, previewPhotoSampleBuffer: preview_photo_sample_buffer, resolvedSettings: resolved_settings, bracketSettings: bracket_settings, error: error)
    if error
      error_callback.call(error)
    else
      jpeg_data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(
        forJPEGSampleBuffer: photo_sample_buffer,
        previewPhotoSampleBuffer: preview_photo_sample_buffer
      )
      @capture_callback.call(jpeg_data)
    end
  end

  def capture_image(&block)
    capture do |jpeg_data|
      image = UIImage.imageWithData(jpeg_data)
      block.call(image)
    end
  end

  def capture_and_save(&block)
    capture do |jpeg_data|
      save_data(jpeg_data) do |asset_url|
        block.call(jpeg_data, asset_url)
      end
    end
  end

  def capture_image_and_save(&block)
    capture do |jpeg_data|
      save_data(jpeg_data) do |asset_url|
        image = UIImage.imageWithData(jpeg_data)
        block.call(image, asset_url)
      end
    end
  end

  def save_data(jpeg_data, &block)
    if defined?(PHPhotoLibrary) # iOS 8+
      save_to_photo_library(jpeg_data, &block)
    else # iOS 4-8
      save_to_assets_library(jpeg_data, &block)
    end
  end

  # iOS 4-8
  def save_to_assets_library(jpeg_data, &block)
    assets_library.writeImageDataToSavedPhotosAlbum(jpeg_data, metadata: nil, completionBlock: -> (asset_url, error) {
      error ? error_callback.call(error) : block.call(asset_url)
    })
  end

  # iOS 8+
  def save_to_photo_library(jpeg_data, &block)
    photo_library.performChanges(-> {
      image = UIImage.imageWithData(jpeg_data)
      PHAssetChangeRequest.creationRequestForAssetFromImage(image)
    }, completionHandler: -> (success, error) {
      if error
        error_callback.call(error)
      else
        block.call(nil) # asset url is not returned in completion block
      end
    })
  end

  def attach(view, options = {})
    @preview_layer = preview_layer_for_view(view, options)

    view.layer.addSublayer(preview_layer)
  end

  def use_camera(target_camera = :default)
    @device = camera_devices[target_camera]

    error_pointer = Pointer.new(:object)

    if input = AVCaptureDeviceInput.deviceInputWithDevice(device, error: error_pointer)
      set_input(input)
    else
      error_callback.call(error_pointer[0])
    end
  end

  def toggle_camera
    target_camera = using_rear_camera? ? :front : :rear

    use_camera(target_camera)
  end

  def toggle_flash
    if device && device.hasFlash
      target_mode = flash_on? ? :off : :on

      set_flash(target_mode)
    end
  end

  def can_set_preset?(preset)
    session.canSetSessionPreset(preset)
  end

  def set_preset(preset)
    session.sessionPreset = preset if can_set_preset? preset
  end

  def preset
    session.sessionPreset if @session
  end

  def flash
    device.flashMode if @device
  end

  # iOS 4-9
  def set_flash(mode = :auto)
    configure_with_lock { device.flashMode = FLASH_MODES[mode] } if flash_mode_available?(mode)
  end

  def flash_mode_available?(mode)
    FLASH_MODES.keys.include?(mode) && device.isFlashModeSupported(FLASH_MODES[mode])
  end

  private

  def error_callback
    @error_callback ||= -> (error) { p "An error occurred: #{error.localizedDescription}." }
  end

  # iOS 4-9
  def still_image_connection
    still_image_output.connectionWithMediaType(AVMediaTypeVideo).tap do |connection|
      device_orientation = UIDevice.currentDevice.orientation
      video_orientation  = orientation_mapping.fetch(device_orientation, AVCaptureVideoOrientationPortrait)

      connection.setVideoOrientation(video_orientation) if connection.videoOrientationSupported?
    end
  end

  # iOS 10+
  def update_video_orientation!
    photo_output.connectionWithMediaType(AVMediaTypeVideo).tap do |connection|
      device_orientation = UIDevice.currentDevice.orientation
      video_orientation  = orientation_mapping.fetch(device_orientation, AVCaptureVideoOrientationPortrait)

      connection.setVideoOrientation(video_orientation) if connection.videoOrientationSupported?
    end
  end

  def orientation_mapping
    { UIDeviceOrientationPortrait           => AVCaptureVideoOrientationPortrait,
      UIDeviceOrientationPortraitUpsideDown => AVCaptureVideoOrientationPortraitUpsideDown,
      UIDeviceOrientationLandscapeRight     => AVCaptureVideoOrientationLandscapeLeft,
      UIDeviceOrientationLandscapeLeft      => AVCaptureVideoOrientationLandscapeRight }
  end

  # iOS 4-8
  def assets_library
    @assets_library ||= ALAssetsLibrary.alloc.init
  end

  # iOS 8+
  def photo_library
    @photo_library ||= PHPhotoLibrary.sharedPhotoLibrary
  end

  def configure_with_lock(&block)
    error_pointer = Pointer.new(:object)

    if device.lockForConfiguration(error_pointer)
      block.call

      device.unlockForConfiguration
    else
      error_callback.call(error_pointer[0])
    end
  end

  def set_input(input)
    remove_inputs

    add_input(input)
  end

  def set_output(output)
    remove_outputs

    add_output(output)
  end

  def remove_inputs
    session.inputs.each do |input|
      remove_input(input)
    end
  end

  def remove_outputs
    session.outputs.each do |output|
      remove_output(output)
    end
  end

  def remove_input(input)
    session.removeInput(input)
  end

  def remove_output(output)
    session.removeOutput(output)
  end

  def add_input(input)
    session.addInput(input) if session.canAddInput(input)
  end

  def add_output(output)
    session.addOutput(output) if session.canAddOutput(output)
  end

  def default_camera
    AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
  end

  def rear_camera
    capture_devices.select { |device| device.position == CAMERA_POSITIONS[:rear] }.first
  end

  def front_camera
    capture_devices.select { |device| device.position == CAMERA_POSITIONS[:front] }.first
  end

  def using_rear_camera?
    device ? device.position == CAMERA_POSITIONS[:rear] : false
  end

  def camera_devices
    { default: default_camera, rear: rear_camera, front: front_camera }
  end

  def capture_devices
    @capture_devices ||= AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
  end

  def preview_layer_for_view(view, options = {})
    AVCaptureVideoPreviewLayer.layerWithSession(session).tap do |layer|
      layer_bounds = view.layer.bounds

      layer.bounds       = layer_bounds
      layer.position     = CGPointMake(CGRectGetMidX(layer_bounds), CGRectGetMidY(layer_bounds))
      layer.zPosition    = options.fetch(:z_position, -100)
      layer.videoGravity = options.fetch(:video_gravity, AVLayerVideoGravityResizeAspectFill)
    end
  end

  def flash_on?
    device ? [FLASH_MODES[:on], FLASH_MODES[:auto]].include?(device.flashMode) : false
  end

  def session
    @session ||= AVCaptureSession.alloc.init
  end

  # iOS 4-9
  def still_image_output
    @still_image_output ||= AVCaptureStillImageOutput.alloc.init.tap do |output|
      settings = { 'AVVideoCodecKey' => AVVideoCodecJPEG }
      output.setOutputSettings(settings)
    end
  end

  # iOS 10+
  def photo_output
    @photo_output ||= AVCapturePhotoOutput.alloc.init
  end
end; end
