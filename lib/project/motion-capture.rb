module Motion; class Capture
  CAMERA_POSITIONS = { rear: AVCaptureDevicePositionBack, front: AVCaptureDevicePositionFront }
  FLASH_MODES      = { on: AVCaptureFlashModeOn, off: AVCaptureFlashModeOff, auto: AVCaptureFlashModeAuto }

  attr_reader :options, :device, :preview_layer

  def initialize(options = {})
    @options = options
  end

  def on_error(block)
    @error_callback = block
  end

  def start!(preset = AVCaptureSessionPresetPhoto)
    use_camera(options.fetch(:device, :default))

    set_preset(preset)

    add_ouput(still_image_output)

    session.startRunning
  end

  def stop!
    session.stopRunning

    remove_outputs
    remove_inputs

    preview_layer.removeFromSuperlayer if preview_layer && preview_layer.superlayer

    @still_image_output = nil
    @session            = nil
    @preview_layer      = nil
  end

  def running?
    @session && session.running?
  end

  def capture(&block)
    still_image_output.captureStillImageAsynchronouslyFromConnection(still_image_connection, completionHandler: -> (buffer, error) {
      if error
        error_callback.call(error)
      else
        image_data = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)

        block.call(image_data)
      end
    })
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
    assets_library.writeImageDataToSavedPhotosAlbum(jpeg_data, metadata: nil, completionBlock: -> (asset_url, error) {
      error ? error_callback.call(error) : block.call(asset_url)
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
    session.captureSession if @session
  end

  def flash
    device.flashMode if @device
  end

  def set_flash(mode = :auto)
    configure_with_lock do
      device.flashMode = FLASH_MODES[mode] if FLASH_MODES.keys.include? mode
    end
  end

  private

  def error_callback
    @error_callback ||= -> (error) { p "An error occurred: #{error.localizedDescription}." }
  end

  def still_image_connection
    still_image_output.connectionWithMediaType(AVMediaTypeVideo).tap do |connection|
      connection.setVideoOrientation(UIDevice.currentDevice.orientation) if connection.videoOrientationSupported?
    end
  end

  def assets_library
    @assets_library ||= ALAssetsLibrary.alloc.init
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

  def add_ouput(output)
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

  def still_image_output
    @still_image_output ||= AVCaptureStillImageOutput.alloc.init.tap do |output|
      settings = { 'AVVideoCodeKey' => AVVideoCodecJPEG }

      output.setOutputSettings(settings)
    end
  end
end; end
