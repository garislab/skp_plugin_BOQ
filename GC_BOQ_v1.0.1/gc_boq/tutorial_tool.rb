require 'sketchup.rb'

module GCBOQ
  def self.show_tutorial
    dlg = new_dialog('Tutorial - GC BOQ', 860, 640, resizable: true, min_width: 640, min_height: 420)
    dlg.set_file(asset_path('html/tutorial.html'))
    dlg.show
  end
end
