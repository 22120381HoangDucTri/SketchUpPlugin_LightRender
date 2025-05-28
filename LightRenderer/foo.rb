require 'sketchup.rb'

module LightRendererExtension
  module LRE

    # Function to import sun.skp
    def self.import_sun_at_entity()
      model = Sketchup.active_model
      entities = model.entities
      selection = model.selection

      # Check the selection
      if selection.empty?
        UI.messagebox("Please select an object")
        return nil
      end

      entity = selection[0]
      position = entity.transformation.origin
      unless position
        UI.messagebox("Cannot get coordinates of object")
        return nil
      end
      temp_position = Geom::Point3d.new(position.x, position.y, position.z + 300)
      # Import file sun.skp
      sun_file_path = File.join(File.dirname(_FILE_), "sun.skp")
      unless File.exist?(sun_file_path)
        UI.messagebox("Cannot find file sun.skp on: #{sun_file_path}")
        return
      end
      begin
        definition = model.definitions.load(sun_file_path)
        transform = Geom::Transformation.new(temp_position)
        sun = entities.add_instance(definition, transform)
        sun.name = "sun"
        return sun
      rescue StandardError => e
        UI.messagebox("Error during import: #{e.message}")
        return nil
      end
    end
    # Function to update sun light direction based on sun and entity positions
    def self.update_sun_light(sun, entity)
      return unless sun && entity

      model = Sketchup.active_model
      shadow_info = model.shadow_info

      # Get positions
      sun_position = sun.transformation.origin
      entity_position = entity.transformation.origin
      unless entity_position
        UI.messagebox("Cannot get coordinates of selected object!")
        return
      end

      # Calculate direction vector from sun to entity
      sun_vector = entity_position - sun_position
      unless sun_vector.valid? && sun_vector.length > 0
        UI.messagebox("Invalid light direction!")
        return
      end

      # Normalize the vector to use as light direction
      sun_vector.normalize!

      begin
        # Update shadow settings
        shadow_info['UseSunForAllShading'] = false # Disable time/location-based sun
        shadow_info['Light'] = 1.0 # Full light intensity
        shadow_info['Dark'] = 0.0 # No darkness
        shadow_info['DisplayShadows'] = true # Enable shadows
        shadow_info['SunDirection'] = sun_vector # Set sun direction
      rescue StandardError => e
        UI.messagebox("Error updating sun light: #{e.message}")
      end
    end
    
    def self.isRender
      startRender = true;
    end
    
     # Main function to import sun and update light
    def self.main
      model = Sketchup.active_model
      selection = model.selection

      if selection.empty?
        UI.messagebox("Please select an object!")
        return
      end

      entity = selection[0]
      sun = import_sun_at_entity
      if sun
        origin = sun.transformation.origin
        UI.messagebox("Sun imported at coordinates: (#{origin.x}, #{origin.y}, #{origin.z})")
        update_sun_light(sun, entity)
      end
    end
    
    unless file_loaded?(_FILE_)
      UI.menu("Plugins").add_item("Light Render") { main }
      
      toolbar = UI::Toolbar.new "Render"
      cmd = UI::Command.new("Render") {
      
      }
      cmd.small_icon = "icon_render.png"
      cmd.large_icon = "icon_render.png"
      cmd.tooltip = "Render light extension"
      cmd.menu_text = "test"
      toolbar = toolbar.add_item cmd
      toolbar.show
      
      file_loaded(_FILE_)
    end

  end # module LRE
end # module LightRendererExtension
