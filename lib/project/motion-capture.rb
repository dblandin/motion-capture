class Motion
  class Capture
    DEFAULT_OPTIONS  = { device: :default }

    attr_accessor :options, :device

    def initialize(options = {})
      self.options = options.merge(DEFAULT_OPTIONS)
    end

    def start!
      use_camera(options[:device])

      add_ouput(still_image_output)
    end

    def capture(&block)
      still_image_connection = still_image_output.connections.first

      still_image_output.captureStillImageAsynchronouslyFromConnection(still_image_connection, completionHandler: lambda { |image_data_sample_buffer, error|
        if image_data_sample_buffer
          image_data = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(image_data_sample_buffer)

          image = UIImage.alloc.initWithData(image_data)

          block.call(image)
        else
          p "Error capturing image: #{error[0].description}"
        end
      })
    end

    def capture_preview_view(options)
      @_capture_preview_view ||= begin
        start!

        UIView.alloc.initWithFrame(options.fetch(:frame, CGRectZero)).tap do |view|
          view.backgroundColor = UIColor.whiteColor

          view.layer.addSublayer(preview_layer_for_view(view))
        end
      end
    end

    def use_camera(camera)
      device = camera_devices[camera]

      error = Pointer.new(:object)

      self.device = device
      input = AVCaptureDeviceInput.deviceInputWithDevice(device, error: error)

      if input
        set_input(input)
      else
        p error[0].description
      end
    end

    def toggle_camera
      if using_rear_camera?
        use_camera(:front)
      else
        use_camera(:rear)
      end
    end

    def toggle_flash
      if device && device.hasFlash
        error = Pointer.new(:object)
        if device.lockForConfiguration(error)
          if flash_on?
            turn_flash_off
          else
            turn_flash_on
          end

          device.unlockForConfiguration
        else
          p error[0].description
        end
      end
    end

    private

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
      session.addInput(input)
    end

    def add_ouput(output)
      session.addOutput(output)
    end

    def default_camera
      AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
    end

    def rear_camera
      capture_devices.select { |device| device.position == camera_position_mapping[:rear] }.first
    end

    def front_camera
      capture_devices.select { |device| device.position == camera_position_mapping[:front] }.first
    end

    def using_rear_camera?
      device.position == AVCaptureDevicePositionBack
    end

    def camera_position_mapping
      { rear: AVCaptureDevicePositionBack, front: AVCaptureDevicePositionFront }
    end

    def camera_devices
      { default: default_camera, rear: rear_camera, front: front_camera }
    end

    def capture_devices
      @_capture_devices ||= AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
    end

    def preview_layer_for_view(view)
      AVCaptureVideoPreviewLayer.layerWithSession(session).tap do |layer|
        layer_bounds = view.layer.bounds

        layer.bounds       = layer_bounds
        layer.position     = CGPointMake(CGRectGetMidX(layer_bounds), CGRectGetMidY(layer_bounds))
        layer.videoGravity = AVLayerVideoGravityResizeAspectFill
      end
    end

    def flash_on?
      device.flashMode == AVCaptureFlashModeOn
    end

    def turn_flash_on
      device.flashMode = AVCaptureFlashModeOn
    end

    def turn_flash_off
      device.flashMode = AVCaptureFlashModeOff
    end

    def session
      @_session ||= AVCaptureSession.alloc.init.tap do |session|
        session.sessionPreset = AVCaptureSessionPresetMedium

        session.startRunning
      end
    end

    def still_image_output
      @_still_image_output ||= AVCaptureStillImageOutput.alloc.init.tap do |output|
        settings = { 'AVVideoCodeKey' => AVVideoCodecJPEG }

        output.setOutputSettings(settings)
      end
    end
  end
end
