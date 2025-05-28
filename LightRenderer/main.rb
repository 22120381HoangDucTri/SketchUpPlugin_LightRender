require 'sketchup.rb'

module LightRenderer
  extend self
  @@light_position = Geom::Point3d.new(0, 0, 300) # x, y, z
  @@color = Sketchup::Color.new(255, 215, 0) # gold
  @@original_color = []

=begin
  1. nhập vị trí của nguồn sáng
  2. tô màu các object 
    2.1 rgb -> hsv
    2.2 
    2.3 
=end
  def getLightInputMenu()
    prompt = ['X', 'Y', 'Z']
    defaults = [@@light_position.x, @@light_position.y, @@light_position.z]
    title = 'Input'
    input = UI.inputbox(prompt, defaults, title)

    return nil unless input  # Người dùng bấm Cancel

    x, y, z = input.map(&:to_i)
    Geom::Point3d.new(x, y, z)
  end

  def getColorInputMenu() 
    colors = {
      "AliceBlue"     => Sketchup::Color.new(240,248,255),
      "AntiqueWhite"  => Sketchup::Color.new(250,235,215),
      "Aqua"          => Sketchup::Color.new(0,255,255),
      "Gold"          => Sketchup::Color.new(255,215,0),
      "Cyan"          => Sketchup::Color.new(0, 255, 255),
      "Magenta"       => Sketchup::Color.new(255, 0, 255),
      "Orange"        => Sketchup::Color.new(255, 165, 0),
      "DeepPink"      => Sketchup::Color.new(255,20,147),
      "White"         => Sketchup::Color.new(255, 255, 255),
      "Black"         => Sketchup::Color.new(0, 0, 0)
    }
    prompts = ["Choose Color"]
    defaults = ["Gold"]
    list = [colors.keys.join("|")]
    input = UI.inputbox(prompts, defaults, list, "Select Light Color")
    return nil unless input
    colors[input[0]]
  end

  def convertRGB2HSV(rgb_color)
    return nil unless rgb_color.is_a?(Sketchup::Color)
    r = rgb_color.red.to_f / 255
    g = rgb_color.green.to_f / 255
    b = rgb_color.blue.to_f / 255

    max = [r, g, b].max
    min = [r, g, b].min
    delta = max - min
     
    # Hue
    h = if delta == 0
          0 
        elsif max == r
          60 * (((g - b) / delta) % 6)
        elsif max == g
          60 * (((b - r) / delta) + 2)
        else
          60 * (((r - g) / delta) + 4)
        end
        
    # Saturation 
    s = max == 0 ? 0 : delta / max

    # Value
    v = max

    [h % 360, s, v]
  end

  def convertHSV2RGB(hsv_color)
    h, s, v = hsv_color

    c = v * s
    x = c * (1 - ((h / 60.0) % 2 - 1).abs)
    m = v - c

    r1, g1, b1 = case h
                when 0...60 then [c, x, 0]
                when 60...120 then [x, c, 0]
                when 120...180 then [0, c, x]
                when 180...240 then [0, x, c]
                when 240...300 then [x, 0, c]
                when 300...360 then [c, 0, x]
                else [0, 0, 0]
                end

    r = ((r1 + m) * 255).round
    g = ((g1 + m) * 255).round
    b = ((b1 + m) * 255).round
    Sketchup::Color.new(r, g, b)
  end

  def draw_sphere(radius = 10.0)
    model = Sketchup.active_model
    entities = model.active_entities

    model.start_operation('Draw light source', true)
    # Remove previous sphere if needed (optional, not implemented here)
    
    center = @@light_position
    # Draw a circle for the profile (in the YZ plane)
    profile = entities.add_circle(center, Geom::Vector3d.new(1, 0, 0), radius, 24)
    profile_face = entities.add_face(profile)
    return unless profile_face

    # Draw a path circle (in the XY plane)
    path = entities.add_circle(center, Geom::Vector3d.new(0, 0, 1), radius, 24)

    # Use follow-me to create the sphere
    profile_face.followme(path)

    # Optionally erase the path and profile edges
    (profile + path).each { |e| e.erase! if e.valid? }
    model.commit_operation
  end

  def applyLighting(entity)
    # light vector: entity center point and light_position subtraction
    # dot_product: 0 - 1, and V in HSV value will match that 
    if !entity
      puts "entity is nil"
      return
    end
    
    if entity.material.nil?
      entity.material = Sketchup::Color.new(255, 255, 255) # white
    end
    
    color = entity.material.color
    h1, s1, v1 = convertRGB2HSV(color)
    h2, s2, v2 = convertRGB2HSV(@@color)

    # Hue: lean toward original color of object
    h = h1 * 0.8 + h2 * 0.2
    
    # Saturation
    s = [s1, s2].max
    
    # Value: dot product of object vector and vector of light source - object bound center
    center = entity.bounds.center
    to_light = @@light_position - center
    to_light.normalize!

    normal = if entity.respond_to?(:normal)
      entity.normal
    else
      Geom::Vector3d.new(0, 0, 1)
    end
    normal.normalize!

    dot = normal.dot(to_light)
    v = [[dot, 0].max, 1].min
    v = if v < 0.5
          0.5
        elsif v > 0.8
          1
        else 
          v
        end

    # result color
    # res_color = convertHSV2RGB([h,s,v])
    res_color = Sketchup::Color.new(r, g, b)
    entity.material = res_color
  end

  def applyLightingRecursive(entity)
    if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      # Recursively apply to all entities inside the group/component
      entity.definition.entities.each { |e| applyLightingRecursive(e) }
    elsif entity.is_a?(Sketchup::Face)
      applyLighting(entity)
    end
  end
  
  def applyLightingSelect()
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      UI.messagebox("Please select an object")
      return nil
    end
    model.start_operation("Render", true)
    selection.each do |entity| # note: component and group is a entity
      applyLightingRecursive(entity)
    end
    model.commit_operation
  end

  unless file_loaded?(__FILE__)
    menu = UI.menu('Plugins')
    submenu = menu.add_submenu('Light Renderer')

    submenu.add_item('Input position') {
      @@light_position = getLightInputMenu
    }
    submenu.add_item('Input light color') {
      color = getColorInputMenu
      @@color = color if color
    }
    submenu.add_item('Show Light Source') {
      draw_sphere
    }

    submenu.add_item('Render') {
      applyLightingSelect
    }
  end
end