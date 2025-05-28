# lightrenderer/main.rb
# Enhanced SketchUp Directional Light Renderer Plugin

require 'sketchup.rb'

module LightRenderer
  
  # Plugin information
  PLUGIN_NAME = "Light Renderer"
  PLUGIN_VERSION = "1.1.0"
  
  # Light state storage with better defaults
  @@light_position = Geom::Point3d.new(100, 100, 200)
  @@model_center = Geom::Point3d.new(0, 0, 0)
  @@light_intensity = 1.0
  @@light_color = Sketchup::Color.new(255, 255, 200)
  @@ambient_light = 0.3  # Ambient light factor
  @@is_rendering = false
  @@light_size = 20
  @@show_light_rays = true
  @@original_materials = {}  # Store original materials for better reset
  
  def self.light_position
    @@light_position
  end
  
  def self.light_position=(value)
    @@light_position = value
  end
  
  def self.model_center
    @@model_center
  end
  
  def self.model_center=(value)
    @@model_center = value
  end
  
  def self.light_intensity
    @@light_intensity
  end
  
  def self.light_intensity=(value)
    @@light_intensity = value
  end
  
  def self.light_color
    @@light_color
  end
  
  def self.light_color=(value)
    @@light_color = value
  end
  
  def self.ambient_light
    @@ambient_light
  end
  
  def self.ambient_light=(value)
    @@ambient_light = value
  end
  
  def self.is_rendering?
    @@is_rendering
  end
  
  def self.is_rendering=(value)
    @@is_rendering = value
  end
  
  def self.light_size
    @@light_size
  end
  
  def self.light_size=(value)
    @@light_size = value
  end
  
  def self.show_light_rays?
    @@show_light_rays
  end
  
  def self.show_light_rays=(value)
    @@show_light_rays = value
  end
  
  def self.original_materials
    @@original_materials
  end

  def self.original_materials=(value)
    @@original_materials = value
  end
  
  def self.light_materials
    @@light_materials
  end
  
  # Calculate light direction from position
  def self.calculate_light_direction
    direction = @@model_center - @@light_position
    return Geom::Vector3d.new(0, 0, -1) if direction.length == 0
    direction.normalize
  end
  
  # Update render if active
  def self.update_render
    return unless @@is_rendering
    DirectionalRenderer.apply_lighting
  end
  
  # Enhanced Light Control Tool
  class LightControlTool
    def initialize
      @ip = Sketchup::InputPoint.new
      @dragging = false
      @selected = false
      @drag_offset = Geom::Vector3d.new(0, 0, 0)
      @cursor_id = nil
      @positioning_mode = :click
      update_model_center
    end
    
    def activate
      update_model_center
      @cursor_id = UI.create_cursor(File.join(__dir__, "cursor_light.skp"), 8, 8) rescue nil
      
      # Force initial draw
      view = Sketchup.active_model.active_view
      view.invalidate
      
      # Debug output
      puts "Light Control Tool activated!"
      puts "Light position: #{LightRenderer.light_position}"
      puts "Model center: #{LightRenderer.model_center}"
      puts "Light size: #{LightRenderer.light_size}"
      
      UI.messagebox("Light Control Tool activated!\n• Look for the yellow sun icon\n• Drag it to change light direction\n• Right-click for options\n• Press 'R' to toggle light rays")
    end
    
    def deactivate(view)
      view.invalidate
    end
    
    def update_model_center
      model = Sketchup.active_model
      return if model.active_entities.count == 0
      
      # Calculate actual model center from geometry
      bounds = Geom::BoundingBox.new
      model.active_entities.each do |entity|
        bounds.add(entity.bounds) if entity.respond_to?(:bounds)
      end
      LightRenderer.model_center = bounds.valid? ? bounds.center : Geom::Point3d.new(0, 0, 0)
    end
    
    def onKeyDown(key, repeat, flags, view)
      case key
      when 82, 114 # 'R' or 'r'
        LightRenderer.show_light_rays = !LightRenderer.show_light_rays?
        view.invalidate
        status = LightRenderer.show_light_rays ? "shown" : "hidden"
        view.tooltip = "Light rays #{status}"
      when 27 # Escape
        Sketchup.active_model.select_tool(nil)
      end
    end
    
    def onMouseMove(flags, x, y, view)
      @ip.pick(view, x, y)
      
      # Check if mouse is near light object
      screen_pos = view.screen_coords(LightRenderer.light_position)
      mouse_distance = Math.sqrt((x - screen_pos.x)**2 + (y - screen_pos.y)**2)
      
      if mouse_distance < LightRenderer.light_size
        view.tooltip = "Drag to move light source (Right-click for options)"
        UI.set_cursor(@cursor_id) if @cursor_id
      else
        view.tooltip = "Press 'R' to toggle light rays"
        UI.set_cursor(0)
      end
      
      # Update light position while dragging
      if @dragging && @ip.position
        LightRenderer.light_position = @ip.position + @drag_offset
        
        # Constrain to reasonable bounds
        # [x, y, z]
        LightRenderer.light_position = [[[-1000, LightRenderer.light_position.x].max, 1000].min, 
                                       [[-1000, LightRenderer.light_position.y].max, 1000].min, 
                                       [[0, LightRenderer.light_position.z].max, 1000].min]
        
        # Update render in real-time if enabled
        LightRenderer.update_render if LightRenderer.is_rendering?
      end
      
      view.invalidate
    end
    
    def onLButtonDown(flags, x, y, view)
      @ip.pick(view, x, y)
      
      screen_pos = view.screen_coords(LightRenderer.light_position)
      mouse_distance = Math.sqrt((x - screen_pos.x)**2 + (y - screen_pos.y)**2)
      
      if mouse_distance < LightRenderer.light_size
        @dragging = true
        @selected = true
        
        # Calculate drag offset for smooth dragging
        if @ip.position && @ip.position.is_a?(Geom::Point3d) && LightRenderer.light_position.is_a?(Geom::Point3d)
          @drag_offset = LightRenderer.light_position - @ip.position
        else
          @drag_offset = Geom::Vector3d.new(0, 0, 0)
        end 

        puts "Light source selected - drag to reposition"
      else
        @selected = false
      end
    end
    
    def onLButtonUp(flags, x, y, view)
      if @dragging
        puts "Light position: #{LightRenderer.light_position.to_a.map{|v| v.round(1)}}"
        puts "Light direction: #{LightRenderer.calculate_light_direction.to_a.map{|v| v.round(3)}}"
      end
      
      @dragging = false
      view.invalidate
    end
    
    def draw(view)
      begin
        # Draw light visualization based on mode
        draw_light_rays(view) if LightRenderer.show_light_rays?
        draw_light_indicator(view)
        draw_info_text(view)
        
      rescue => e
        puts "Error in draw method: #{e.message}"
        # Fallback: Draw basic info
        view.drawing_color = [255, 255, 255]
        view.draw_text([10, 30], "Light Control Tool Active (#{@positioning_mode} mode)")
        view.draw_text([10, 50], "Error: #{e.message}")
      end
    end
    
    def draw_light_indicator(view)
      # Simple light position indicator
      view.drawing_color = [255, 255, 200]  # Yellow
      view.line_width = 4
      
      # Ensure base point is a Point3d
      base = LightRenderer.light_position
      base = Geom::Point3d.new(*base) unless base.is_a?(Geom::Point3d)

      # Draw a simple diamond shape at light position
      size = 15
      diamond_points = [
        base.offset(Geom::Vector3d.new(size, 0, 0)),
        base.offset(Geom::Vector3d.new(0, size, 0)),
        base.offset(Geom::Vector3d.new(-size, 0, 0)),
        base.offset(Geom::Vector3d.new(0, -size, 0)),
        base.offset(Geom::Vector3d.new(size, 0, 0))
      ]
      
      view.draw(GL_LINE_STRIP, diamond_points)
      
      # Draw vertical line to show light position clearly
      view.drawing_color = [255, 255, 0, 128]  # Semi-transparent yellow
      view.line_stipple = "."
      ground_point = Geom::Point3d.new(base.x, base.y, 0)
      view.draw(GL_LINES, [base, ground_point])
      view.line_stipple = ""
      
      # Draw mode-specific visual cues
      case @positioning_mode
      when :click
        if @ip.position
          # Show preview of where light would be placed
          preview_pos = @ip.position + Geom::Vector3d.new(0, 0, 100)
          view.drawing_color = [255, 255, 0, 100]
          view.line_stipple = "-"
          view.draw(GL_LINES, [@ip.position, preview_pos])
          view.line_stipple = ""
        end

      when :spherical
        # Draw orbit circle around model center
        view.drawing_color = [100, 255, 100, 80]  # Light green
        view.line_stipple = "."
        
        current_distance = (LightRenderer.light_position - LightRenderer.model_center).length
        circle_points = []
        
        32.times do |i|
          angle = i * 2 * Math::PI / 32
          x = LightRenderer.model_center.x + Math.cos(angle) * current_distance
          y = LightRenderer.model_center.y + Math.sin(angle) * current_distance
          z = LightRenderer.model_center.z
          circle_points << Geom::Point3d.new(x, y, z)
        end
        
        view.draw(GL_LINE_LOOP, circle_points)
        view.line_stipple = ""
      end
    end
    
    def draw_light_rays(view)
      return unless LightRenderer.show_light_rays?
      return unless LightRenderer.light_position && LightRenderer.model_center

      view.line_width = 2
      view.drawing_color = [255, 255, 150]
      view.line_stipple = "-"

      begin
        # Main light ray
        view.draw(GL_LINES, [LightRenderer.light_position, LightRenderer.model_center])

        # Additional rays for better visualization
        offsets = [
          Geom::Vector3d.new(15, 0, 0),
          Geom::Vector3d.new(-15, 0, 0),
          Geom::Vector3d.new(0, 15, 0),
          Geom::Vector3d.new(0, -15, 0)
        ]

        offsets.each do |offset|
          start_pt = LightRenderer.light_position.offset(offset)
          end_pt = LightRenderer.model_center.offset(offset)
          view.draw(GL_LINES, [start_pt, end_pt])
        end
      rescue => e
        puts "Error drawing light rays: #{e.message}"
      end

      view.line_stipple = ""
    end
    
    def draw_info_text(view)
      light_dir = LightRenderer.calculate_light_direction
      pos = LightRenderer.light_position.to_a.map{|v| v.round(1)}
      dir = light_dir.to_a.map{|v| v.round(3)}
      
      view.drawing_color = [255, 255, 255]
      
      info_lines = [
        "Light Control Mode: #{@positioning_mode.to_s.upcase}",
        "Position: [#{pos.join(', ')}]",
        "Direction: [#{dir.join(', ')}]",
        "Intensity: #{LightRenderer.light_intensity.round(2)}"
      ]
      
      case @positioning_mode
      when :click
        info_lines << "Click anywhere to position light"
        info_lines << "Press 'N' for numeric input"
      when :spherical
        distance = (LightRenderer.light_position - LightRenderer.model_center).length.round(1)
        info_lines << "Distance: #{distance}"
        info_lines << "Drag to orbit, scroll to adjust distance"
      end
      
      if LightRenderer.is_rendering?
        info_lines << "Rendering: ACTIVE"
      end
      
      if !LightRenderer.show_light_rays?
        info_lines << "Light rays: HIDDEN (Press 'R')"
      end
      
      info_lines.each_with_index do |line, i|
        view.draw_text([10, 50 + i * 20], line)
      end
    end
    
    def getMenu(menu)
      menu.add_item("Switch to Click Mode") {
        @positioning_mode = :click
        UI.messagebox("Switched to Click Mode\nClick anywhere to position the light")
        Sketchup.active_model.active_view.invalidate
      }
      
      menu.add_item("Switch to Spherical Mode") {
        @positioning_mode = :spherical
        UI.messagebox("Switched to Spherical Mode\nDrag to orbit light around model")
        Sketchup.active_model.active_view.invalidate
      }
      
      # incomplete
      menu.add_item("Numeric Input...") {
        show_numeric_positioning
      }
      
      menu.add_separator
      
      menu.add_item("Light Properties...") {
        LightRenderer.show_enhanced_light_dialog
      }
      
      menu.add_separator
      
      menu.add_item("Toggle Light Rays") {
        LightRenderer.show_light_rays = !LightRenderer.show_light_rays?
        Sketchup.active_model.active_view.invalidate
      }
      
      menu.add_separator
      
      presets_menu = menu.add_submenu("Quick Positions")
      
      presets_menu.add_item("Above Model (Top Light)") {
        LightRenderer.light_position = LightRenderer.model_center + Geom::Vector3d.new(0, 0, 150)
        LightRenderer.update_render if LightRenderer.is_rendering?
        Sketchup.active_model.active_view.invalidate
      }
      
      presets_menu.add_item("Side Light (45°)") {
        offset = Geom::Vector3d.new(100, 100, 100)
        LightRenderer.light_position = LightRenderer.model_center + offset
        LightRenderer.update_render if LightRenderer.is_rendering?
        Sketchup.active_model.active_view.invalidate
      }
      
      presets_menu.add_item("Front Light") {
        bounds = Sketchup.active_model.bounds
        depth = bounds.depth
        LightRenderer.light_position = LightRenderer.model_center + Geom::Vector3d.new(0, depth, 50)
        LightRenderer.update_render if LightRenderer.is_rendering?
        Sketchup.active_model.active_view.invalidate
      }
      
      presets_menu.add_item("Back Light (Rim)") {
        bounds = Sketchup.active_model.bounds
        depth = bounds.depth
        LightRenderer.light_position = LightRenderer.model_center + Geom::Vector3d.new(0, -depth, 80)
        LightRenderer.update_render if LightRenderer.is_rendering?
        Sketchup.active_model.active_view.invalidate
      }
    end
    
  end
  
  # Enhanced Directional Renderer
  class DirectionalRenderer
    
    def self.start_rendering
      store_original_materials
      LightRenderer.is_rendering = true
      apply_lighting
      UI.messagebox("Rendering started! Light effects applied.\nDrag the sun to see real-time updates.")
    end
    
    def self.stop_rendering
      LightRenderer.is_rendering = false
      restore_original_materials
      UI.messagebox("Rendering stopped! Original materials restored.")
    end
    
    def self.store_original_materials
      LightRenderer.original_materials.clear
      LightRenderer.original_materials = {}

      model = Sketchup.active_model
      
      model.active_entities.each do |entity|
        if entity.is_a?(Sketchup::Face)
          LightRenderer.original_materials[entity.object_id] = {
            front: entity.material,
            back: entity.back_material
          }
        end
      end
    end
    
    def self.restore_original_materials
      model = Sketchup.active_model
      
      model.start_operation('Restore Materials', true)
      
      begin
        # Remove light materials first
        materials_to_remove = []
        model.materials.each do |material|
          materials_to_remove << material if material.name.start_with?("light_material_")
        end
        
        # Restore original materials
        model.active_entities.each do |entity|
          if entity.is_a?(Sketchup::Face)
            original = LightRenderer.original_materials[entity.object_id]
            if original
              entity.material = original[:front]
              entity.back_material = original[:back]
            else
              entity.material = nil
              entity.back_material = nil
            end
          end
        end
        
        # Clean up light materials
        materials_to_remove.each { |mat| model.materials.remove(mat) }
        
        model.commit_operation
      rescue => e
        model.abort_operation
        puts "Error restoring materials: #{e.message}"
      end
      
      model.active_view.invalidate
    end
    
    def self.apply_lighting
      model = Sketchup.active_model
      entities = model.active_entities
      
      model.start_operation('Apply Lighting', true)
      
      begin
        entities.each do |entity|
          apply_light_to_face(entity) if entity.is_a?(Sketchup::Face)
        end
        
        model.commit_operation
      rescue => e
        model.abort_operation
        puts "Error applying lighting: #{e.message}"
      end
      
      model.active_view.invalidate
    end
    
    def self.apply_light_to_face(face)
      # Calculate angle between face normal and light direction
      face_normal = face.normal
      light_direction = LightRenderer.calculate_light_direction
      
      # Dot product for light intensity calculation
      dot_product = face_normal.dot(light_direction)
      
      # Ensure we don't get negative lighting (faces away from light)
      direct_light = [dot_product, 0].max
      
      # Combine direct and ambient lighting
      total_light = (direct_light * LightRenderer.light_intensity) + LightRenderer.ambient_light
      total_light = [total_light, 1.0].min  # Cap at 1.0
      
      # Apply light color influence
      base_r = LightRenderer.light_color.red * total_light
      base_g = LightRenderer.light_color.green * total_light  
      base_b = LightRenderer.light_color.blue * total_light
      
      # Create new color with gamma correction
      gamma = 0.8
      red = (base_r ** gamma).to_i
      green = (base_g ** gamma).to_i
      blue = (base_b ** gamma).to_i
      
      new_color = Sketchup::Color.new(red, green, blue)
      
      # Create or update material
      material_name = "light_material_#{face.object_id}"
      material = Sketchup.active_model.materials[material_name]
      
      if material.nil?
        material = Sketchup.active_model.materials.add(material_name)
      end
      
      material.color = new_color
      face.material = material
    end
    
  end
  
  # Enhanced UI Dialog
  def self.show_enhanced_light_dialog
    prompts = [
      "Light Intensity (0.1-3.0)", 
      "Ambient Light (0.0-1.0)",
      "Red (0-255)", 
      "Green (0-255)", 
      "Blue (0-255)", 
      "Light Icon Size"
    ]
    
    defaults = [
      @@light_intensity, 
      @@ambient_light,
      @@light_color.red, 
      @@light_color.green, 
      @@light_color.blue, 
      @@light_size
    ]
    
    input = UI.inputbox(prompts, defaults, "Enhanced Light Properties")
    
    if input
      @@light_intensity = [[input[0].to_f, 0.1].max, 3.0].min
      @@ambient_light = [[input[1].to_f, 0.0].max, 1.0].min
      @@light_color = Sketchup::Color.new(
        [[input[2].to_i, 0].max, 255].min,
        [[input[3].to_i, 0].max, 255].min, 
        [[input[4].to_i, 0].max, 255].min
      )
      LightRenderer.light_size = [[input[5].to_i, 10].max, 50].min
      
      # Update render if active
      update_render if LightRenderer.is_rendering?
      Sketchup.active_model.active_view.invalidate
    end
  end
  
  def self.update_render
    DirectionalRenderer.apply_lighting if LightRenderer.is_rendering?
  end
  
  # Enhanced Menu Creation
  def self.create_menu
    plugins_menu = UI.menu("Plugins")
    light_menu = plugins_menu.add_submenu("Light Renderer")
    
    light_menu.add_item("🌞 Light Control Tool") do
      Sketchup.active_model.select_tool(LightControlTool.new)
    end
    
    light_menu.add_separator
    
    light_menu.add_item("▶️ Start Rendering") do
      DirectionalRenderer.start_rendering
    end
    
    light_menu.add_item("⏹️ Stop Rendering") do
      DirectionalRenderer.stop_rendering
    end
    
    light_menu.add_separator
    
    light_menu.add_item("⚙️ Light Properties...") do
      LightRenderer.show_enhanced_light_dialog
    end
    
    light_menu.add_item("Toggle Light Rays") do
      @@show_light_rays = !@@show_light_rays
      Sketchup.active_model.active_view.invalidate
    end
    
    light_menu.add_separator
    
    help_menu = light_menu.add_submenu("Help & Info")
    help_menu.add_item("About") do
      UI.messagebox("Light Renderer Plugin v#{PLUGIN_VERSION}\n\nFeatures:\n• Drag the sun to change light direction\n• Real-time lighting updates\n• Multiple light presets\n• Ambient + directional lighting\n\nControls:\n• Drag sun icon to move light\n• Right-click for options\n• Press 'R' to toggle light rays\n• Press 'Esc' to exit tool")
    end
  end
  
  def self.create_toolbar
    toolbar = UI::Toolbar.new("Light Renderer")
    
    # Light Control Tool button
    cmd_light = UI::Command.new("Light Control") do
      Sketchup.active_model.select_tool(LightControlTool.new)
    end
    cmd_light.tooltip = "Light Direction Control - Interactive Sun"
    cmd_light.status_bar_text = "Drag the sun to control light direction in real-time"
    toolbar.add_item(cmd_light)
    
    # Start Render button  
    cmd_start = UI::Command.new("Start Render") do
      DirectionalRenderer.start_rendering
    end
    cmd_start.tooltip = "Start Light Rendering"
    cmd_start.status_bar_text = "Apply directional lighting effects to your model"
    toolbar.add_item(cmd_start)
    
    # Stop Render button
    cmd_stop = UI::Command.new("Stop Render") do
      DirectionalRenderer.stop_rendering  
    end
    cmd_stop.tooltip = "Stop Light Rendering"
    cmd_stop.status_bar_text = "Remove lighting effects and restore original materials"
    toolbar.add_item(cmd_stop)
    
    # Properties button
    cmd_props = UI::Command.new("Light Properties") do
      LightRenderer.show_enhanced_light_dialog
    end
    cmd_props.tooltip = "Light Properties"
    cmd_props.status_bar_text = "Adjust light intensity, color, and ambient lighting"
    toolbar.add_item(cmd_props)
    
    toolbar.show
  end
  
  # Initialize plugin
  unless file_loaded?(__FILE__)
    LightRenderer.create_menu
    LightRenderer.create_toolbar
  
    puts "✅ Light Renderer Plugin v#{LightRenderer::PLUGIN_VERSION} loaded successfully!"
    puts "🌞 Use Light Control Tool to see the interactive sun"  
    puts "⚡ Drag the sun for real-time lighting updates"
    puts "📚 Check Plugins > Light Renderer > Help & Info for more details"
  end
end