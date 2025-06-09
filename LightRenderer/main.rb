require 'sketchup.rb'
require 'date'
require 'time'

module LightRendererExtension
  module LRE
    @@light = nil
    @@light_pos = Geom::Point3d.new
    @@model_position = nil

    def self.light
      @@light
    end
    
    def self.light=(value)
      @@light = value
    end
    
    def self.model_position
      @@model_position
    end
    
    def self.model_position=(value)
      @@model_position = value
    end
    
    class LightControlTool
      def initialize
        @model = Sketchup.active_model
        @entities = @model.entities
        @selection = @model.selection
        @light_position_import = Geom::Point3d.new(0, 0, 0)
        @light_definition = nil
        @light_transform = nil
      end
      
      # Function select model to import sun
      def select_model
        # Check the selection
        if @selection.empty?
          UI.messagebox("Please select an object")
          return nil
        end

        entity = @selection[0]
        unless entity.transformation.origin
          UI.messagebox("Cannot get coordinates of object")
          return nil
        end
        LRE.model_position=(entity.transformation.origin)
        @light_position_import = Geom::Point3d.new(entity.transformation.origin.x, entity.transformation.origin.y, entity.transformation.origin.z + 300)
      end
      
      # Function to import light.skp
      def import_light_at_entity()
        light_file_path = File.join(File.dirname(__FILE__), "light.skp")
        unless File.exist?(light_file_path)
          UI.messagebox("Cannot find file light.skp on: #{light_file_path}")
          return
        end
        begin
          @light_definition = @model.definitions.load(light_file_path)
          @light_transform = Geom::Transformation.new(@light_position_import)
          instance = @entities.add_instance(@light_definition, @light_transform)
          instance.casts_shadows = false # Hide shadow for the sun object
          LRE.light = instance
        rescue StandardError => e
          UI.messagebox("Error during import: #{e.message}")
          return nil
        end
      end
    end
    
    class LightRender
      def initialize
        @light_vector = nil
        @lat = nil
        @lon = nil
        @t = nil
      end

      def sun_direction_from_geo(lat_deg, lon_deg, datetime)
        deg2rad = Math::PI / 180
        rad2deg = 180 / Math::PI

        # Convert latitude/longitude to radians
        lat = lat_deg * deg2rad
        lon = lon_deg * deg2rad

        # Julian Day
        jd = datetime.yday + (datetime.hour - 12) / 24.0 + datetime.min / 1440.0 + datetime.sec / 86400.0
        gamma = 2.0 * Math::PI / 365.0 * (jd - 1)

        # Equation of Time (EoT) in minutes
        eot = 229.18 * (0.000075 + 0.001868 * Math.cos(gamma) - 0.032077 * Math.sin(gamma) -
                        0.014615 * Math.cos(2 * gamma) - 0.040849 * Math.sin(2 * gamma))

        # Solar Declination (δ)
        decl = 0.006918 - 0.399912 * Math.cos(gamma) + 0.070257 * Math.sin(gamma) -
               0.006758 * Math.cos(2 * gamma) + 0.000907 * Math.sin(2 * gamma) -
               0.002697 * Math.cos(3 * gamma) + 0.00148 * Math.sin(3 * gamma)

        # Time offset (in minutes)
        time_offset = eot + 4 * lon_deg

        # True Solar Time (in minutes)
        tst = datetime.hour * 60 + datetime.min + datetime.sec / 60 + time_offset
        tst %= 1440

        # Hour Angle (degrees)
        ha = (tst / 4.0) - 180.0
        ha_rad = ha * deg2rad

        # Altitude angle (elevation)
        altitude = Math.asin(Math.sin(lat) * Math.sin(decl) + Math.cos(lat) * Math.cos(decl) * Math.cos(ha_rad))

        # Azimuth angle
        azimuth = Math.acos((Math.sin(decl) - Math.sin(altitude) * Math.sin(lat)) / (Math.cos(altitude) * Math.cos(lat)))
        if ha > 0
          azimuth = 2 * Math::PI - azimuth
        end

        # Convert altitude and azimuth to 3D vector
        x = Math.cos(altitude) * Math.sin(azimuth)
        y = Math.cos(altitude) * Math.cos(azimuth)
        z = Math.sin(altitude)

        return Geom::Vector3d.new(x, y, z)
      end

      # need utilize here
      def find_best_sun_position(light_vector)
        light_vector.normalize!
        best_diff = Float::INFINITY
        best_lat = nil
        best_lon = nil
        best_time = nil

        date = Date.new(2025, 1, 1)
        time_start = Time.local(date.year, date.month, date.day, 6, 0, 0)
        time_end = Time.local(date.year, date.month, date.day, 18, 0, 0)

        # Stage 1: Coarse search
        (-90..90).step(10) do |lat|
          (-180..180).step(10) do |lon|
            t = time_start
            while t <= time_end
              sun_vector = sun_direction_from_geo(lat, lon, t)
              diff = (light_vector.x - sun_vector.x)**2 +
                     (light_vector.y - sun_vector.y)**2 +
                     (light_vector.z - sun_vector.z)**2
              if diff < best_diff
                best_diff = diff
                best_lat = lat
                best_lon = lon
                best_time = t
              end
              t += 60 * 60 # 1 hour step
            end
          end
        end

        # Stage 2: Fine search around best result
        fine_lat_range = (best_lat-2..best_lat+2).step(1)
        fine_lon_range = (best_lon-2..best_lon+2).step(1)
        fine_time_range = (0..60).step(5).map { |m| best_time + m*60 }

        best_diff = Float::INFINITY
        fine_lat_range.each do |lat|
          fine_lon_range.each do |lon|
            fine_time_range.each do |t|
              sun_vector = sun_direction_from_geo(lat, lon, t)
              diff = (light_vector.x - sun_vector.x)**2 +
                     (light_vector.y - sun_vector.y)**2 +
                     (light_vector.z - sun_vector.z)**2
              if diff < best_diff
                best_diff = diff
                @lat = lat
                @lon = lon
                @t = t
              end
            end
          end
        end
      end
      
      def update_light 
        model = Sketchup.active_model
        shadow_info = model.shadow_info

        # Calculate direction vector from sun to entity
        model.start_operation("do light", true)
        @light_vector = LRE.light().transformation.origin - LRE.model_position()
        unless @light_vector.valid? && @light_vector.length > 0
          UI.messagebox("Invalid light direction!")
          return
        end

        # Normalize the vector to use as light direction
        @light_vector.normalize!
        
        find_best_sun_position(@light_vector)

        begin
          # Update shadow settings
          shadow_info['UseSunForAllShading'] = false
          shadow_info['Light'] = 50.0
          shadow_info['Dark'] = 50.0
          shadow_info['DisplayShadows'] = true   
          shadow_info['Latitude'] = @lat
          shadow_info['Longitude'] = @lon
          shadow_info['ShadowTime'] = @t
        rescue StandardError => e
          UI.messagebox("Error updating sun light: #{e.message}")
        end
        model.commit_operation
      end
    end
    
    class Coloring
      # @light_position = LRE.light.transformation.origin # Geom::Point3d.new(0, 0, 300) # x, y, z
      @@color = Sketchup::Color.new(250, 250, 210) # white yellow

      def self.getLightInputMenu()
        prompt = ['X', 'Y', 'Z']
        defaults = [LRE.light.transformation.origin.x, LRE.light.transformation.origin.y, LRE.light.transformation.origin.z]
        title = 'Input'
        input = UI.inputbox(prompt, defaults, title)

        return nil unless input  # Người dùng bấm Cancel

        x, y, z = input.map(&:to_i)
        Geom::Point3d.new(x, y, z)
      end

      def self.getColorInputMenu() 
        colors = {
          "AliceBlue"     => Sketchup::Color.new(240,248,255),
          "AntiqueWhite"  => Sketchup::Color.new(250,235,215),
          "Aqua"          => Sketchup::Color.new(0,255,255),
          "Default"       => Sketchup::Color.new(250,250,210),
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

        # Store original color if not already stored
        dict_name = "LightRendererOriginalColor"
        if entity.material.nil?
          entity.material = Sketchup::Color.new(255, 255, 255)
        end

        unless entity.attribute_dictionary(dict_name)
          orig_color = entity.material.color
          entity.set_attribute(dict_name, "r", orig_color.red)
          entity.set_attribute(dict_name, "g", orig_color.green)
          entity.set_attribute(dict_name, "b", orig_color.blue)
        end

        # Always use the original color for lighting
        orig_r = entity.get_attribute(dict_name, "r", 255)
        orig_g = entity.get_attribute(dict_name, "g", 255)
        orig_b = entity.get_attribute(dict_name, "b", 255)
        base_color = Sketchup::Color.new(orig_r, orig_g, orig_b)

        base_color.red = (base_color.red.to_f * @@color.red.to_f / 255).round
        base_color.green = (base_color.green.to_f * @@color.green.to_f / 255).round
        base_color.blue = (base_color.blue.to_f * @@color.blue.to_f / 255).round

        center = entity.bounds.center
        to_light = LRE.light.transformation.origin - center
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

=begin
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
=end

     # Main function to import sun and update light
    def self.main
      tool = LightControlTool.new
      if tool.select_model.nil?
        UI.messagebox("Please select a model to import light")
        return
      end
      tool.import_light_at_entity
    end
    
    unless file_loaded?(__FILE__)
      menu = UI.menu("Plugins")
      submenu = menu.add_submenu("Light Renderer")
      submenu.add_item("Light Render") {main}
      submenu.add_item("Choose light color") {Coloring.getColorInputMenu}

      toolbar = UI::Toolbar.new "Render"
      cmd = UI::Command.new("Render") {
        coloring = Coloring.new
        coloring.applyLightingSelect
        # apply shader/shadow
        render = LightRender.new
        render.update_light
      }
      cmd.small_icon = "icon_render.png"
      cmd.large_icon = "icon_render.png"
      cmd.tooltip = "Render light extension"
      cmd.menu_text = "test"
      toolbar = toolbar.add_item cmd
      toolbar.show
      
      file_loaded(__FILE__)
    end

  end # module LRE
end # module LightRendererExtension
