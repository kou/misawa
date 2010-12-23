begin
  require 'gtk2'
rescue Gtk::InitError
end

class Misawa
  attr_accessor :scale
  def initialize(witticism)
    @witticism = witticism
    @scale = 1.0
    @width = 240
    @height = 320
    @font = "M+ 2m"
    @font_size = 16
  end

  def render(output_path)
    make_surface(output_path) do |surface|
      render_to_surface(surface)
    end
  end

  private
  def image_width
    @width * @scale
  end

  def image_height
    @height * @scale
  end

  def make_surface(output_path)
    Cairo::ImageSurface.new(image_width, image_height) do |surface|
      yield(surface)
      File.open(output_path, "wb") do |output|
        surface.write_to_png(output)
      end
    end
  end

  def make_context(surface)
    context = Cairo::Context.new(surface)
    context.scale(@scale, @scale)
    context.line_width = 1.0 / @scale

    context.save do
      context.set_source_color(:white)
      context.paint
    end

    context
  end

  def image_path
    Dir.glob("misawa_background.*").find do |path|
      File.exist?(path)
    end
  end

  def load_pixbuf(path)
    loader = Gdk::PixbufLoader.new
    File.open(path, "rb") do |file|
      loader.write(file.read)
    end
    loader.close
    loader.pixbuf
  end

  def render_image(context)
    path = image_path
    if path.nil?
      message = "misawa_backgorund.* doesn't exist in the current directory."
      message << " try: 'wget -O misawa_background.jpg http://a2.twimg.com/profile_images/461389564/aaa.jpg'"
      raise message
    end
    pixbuf = load_pixbuf(path)
    raise "failed to load image: <#{path}>" if pixbuf.nil?

    context.save do
      x_ratio = @width / pixbuf.width.to_f
      y_ratio = @height / pixbuf.height.to_f
      if x_ratio > y_ratio
        x_ratio = y_ratio
        translate_x = (@width - pixbuf.width * x_ratio) / 2.0
        translate_y = 0
      else
        y_ratio = x_ratio
        translate_x = 0
        translate_y = (@height - pixbuf.height * y_ratio) / 2.0
      end
      context.translate(translate_x, translate_y)
      context.scale(x_ratio, y_ratio)
      context.set_source_pixbuf(pixbuf, 0, 0)
      context.paint
    end
  end

  def make_layout(context, text, width)
    layout = context.create_pango_layout
    layout.text = text
    layout.width = width * Pango::SCALE
    layout.context.base_gravity = :east

    font_description = Pango::FontDescription.new("#{@font} #{@font_size}")
    layout.font_description = font_description

    context.update_pango_layout(layout)
    layout
  end

  def render_witticism_text(context, position, witticism)
    layout = make_layout(context, witticism, @height)

    x_margin = @width * 0.01
    y_margin = @height * 0.03
    case position
    when :right
      witticism_x = @width - x_margin
    when :left
      witticism_x = x_margin + layout.pixel_size[1]
    end
    witticism_y = y_margin
    context.save do
      context.move_to(witticism_x, witticism_y)
      context.rotate(Math::PI / 2)
      context.line_width *= 10
      context.line_join = :bevel
      context.set_source_color(:white)
      context.pango_layout_path(layout)
      context.stroke
    end
    context.save do
      context.move_to(witticism_x, witticism_y)
      context.rotate(Math::PI / 2)
      context.show_pango_layout(layout)
    end
  end

  def render_witticism(context)
    right_witicism, left_witicism, garbages = @witticism.split(/\n\n+/, 3)
    if right_witicism
      render_witticism_text(context, :right, right_witicism)
    end
    if left_witicism
      render_witticism_text(context, :left, left_witicism)
    end
  end

  def render_to_surface(surface)
    context = make_context(surface)
    render_image(context)
    render_witticism(context)
    context.show_page
  end
end

class Object
  def misawa(witticism)
    Misawa.new(witticism).render('misawa.png')
  end
end
