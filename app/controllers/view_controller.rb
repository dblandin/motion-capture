class ViewController < UIViewController
  def viewDidLoad
    super

    view.addSubview(flash_control_button)
    view.addSubview(camera_toggle_button)
    view.addSubview(capture_button)

    motion_capture.attach(view)

    motion_capture.start!
  end

  def capture(sender)
    motion_capture.capture_image_and_save do |image, asset_url|
      image_view.image = image

      view.addSubview(image_view)
      view.addSubview(reset_button)
    end
  end

  def reset(sender)
    reset_button.removeFromSuperview
    image_view.removeFromSuperview
  end

  def toggle_camera(sender)
    motion_capture.toggle_camera
  end

  def toggle_flash(sender)
    sender.selected = !sender.isSelected

    motion_capture.toggle_flash
  end

  def motion_capture
    @motion_capture ||= Motion::Capture.new(device: :rear)
  end

  def image_view
    @image_view ||= UIImageView.alloc.initWithFrame(view.bounds).tap do |image_view|
      image_view.contentMode = UIViewContentModeScaleAspectFill
    end
  end

  def camera_toggle_button
    UIButton.buttonWithType(UIButtonTypeCustom).tap do |button|
      x, y, w, h = 110, 0, 100, 100
      image_name = 'toggle-camera'
      action_selector = 'toggle_camera:'

      button.frame = [[x, y], [w, h]]
      button.setImage(UIImage.imageNamed(image_name), forState: UIControlStateNormal)
      button.setImage(UIImage.imageNamed("#{image_name}-highlight"), forState: UIControlStateHighlighted)
      button.addTarget(self, action: action_selector, forControlEvents: UIControlEventTouchUpInside)
      button.adjustsImageWhenHighlighted = false
    end
  end

  def capture_button
    UIButton.buttonWithType(UIButtonTypeCustom).tap do |button|
      button.size = CGSizeMake(100, 100)
      button.center = CGPointMake(view.size.width / 2, view.size.height - 100)
      button.setImage(UIImage.imageNamed('capture'), forState: UIControlStateNormal)
      button.setImage(UIImage.imageNamed('capture-highlight'),  forState: UIControlStateHighlighted)
      button.adjustsImageWhenHighlighted = false
      button.addTarget(self, action: 'capture:', forControlEvents: UIControlEventTouchUpInside)
    end
  end

  def reset_button
    @reset_button ||= UIButton.buttonWithType(UIButtonTypeCustom).tap do |button|
      button.size = CGSizeMake(100, 100)
      button.center = CGPointMake(view.size.width / 2, view.size.height - 100)
      button.setImage(UIImage.imageNamed('capture'), forState: UIControlStateNormal)
      button.setImage(UIImage.imageNamed('capture-highlight'),  forState: UIControlStateHighlighted)
      button.adjustsImageWhenHighlighted = false
      button.addTarget(self, action: 'reset:', forControlEvents: UIControlEventTouchUpInside)
    end
  end

  def flash_control_button
    UIButton.buttonWithType(UIButtonTypeCustom).tap do |button|
      button.frame = [[0, 0], [100, 100]]
      button.setImage(UIImage.imageNamed('flash-off'), forState: UIControlStateNormal)
      button.setImage(UIImage.imageNamed('flash-on'),  forState: UIControlStateHighlighted)
      button.setImage(UIImage.imageNamed('flash-on'),  forState: UIControlStateSelected)
      button.adjustsImageWhenHighlighted = false
      button.addTarget(self, action: 'toggle_flash:', forControlEvents: UIControlEventTouchUpInside)
    end
  end
end
