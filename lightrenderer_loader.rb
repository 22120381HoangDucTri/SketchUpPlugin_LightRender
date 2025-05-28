require 'sketchup.rb'
require 'extensions.rb'

module LightRenderer
  unless file_loaded?(__FILE__)
    ex = SketchupExtension.new('My Cube', 'LightRenderer/main.rb')
    ex.description = 'Render Light'
    ex.version     = '1.0.0'
    ex.copyright   = 'Tri & Tri 2025'
    ex.creator     = 'Tri'

    Sketchup.register_extension(ex, true)
    file_loaded(__FILE__)
  end
=begin
  def self.reload
    original_verbose = $VERBOSE
    $VERBOSE = nil
    pattern = File.join(__dir__, '**/*.rb')

    Dir.glob(pattern).each { |file|
      load file
    }.size
  ensure
    $VERBOSE = original_verbose
  end
=end
end