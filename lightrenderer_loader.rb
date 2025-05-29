require 'sketchup.rb'
require 'extensions.rb'

module LightRendererExtension
  module LRE
    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new('My Cube', 'LightRenderer/my_extension_file.rb')
      ex.description = 'Render Light'
      ex.version     = '1.0.0'
      ex.copyright   = 'Tri & Tri 2025'
      ex.creator     = 'Tri'

      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end
  end 
end