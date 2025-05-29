require 'sketchup.rb'

module LightRenderer
  extend self
  class Coloring
    @@light_position = Geom::Point3d.new(0, 0, 300) # x, y, z
    @@color = Sketchup::Color.new(255, 215, 0) # gold

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

    def applyLighting(entity)
      # apply lambertian formula
      # input (factors): light color, light source position
      return unless entity
      
      if entity.material.nil?
        entity.material = Sketchup::Color.new(255, 255, 255) # white
      end

      base_color = entity.material.color
      base_color.red = (base_color.red.to_f * @@color.red.to_f / 255).round
      base_color.green = (base_color.green.to_f * @@color.green.to_f / 255).round
      base_color.blue = (base_color.blue.to_f * @@color.blue.to_f / 255).round

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
      intensity = [[dot, 0].max, 1].min

      ambient = 0.4
      lambert = ambient + (1 - ambient) * intensity
      lambert = [[lambert, 0].max, 1].min

      r = (base_color.red * lambert).round
      g = (base_color.green * lambert).round
      b = (base_color.blue * lambert).round

      entity.material = Sketchup::Color.new(r, g, b)
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