require 'sketchup.rb'

module GCBOQ
  def self.show_about
    dlg = new_dialog('GC BOQ for SketchUp', 460, 300, resizable: false, min_width: 460, min_height: 300)
    dlg.set_file(asset_path('html/about.html'))

    dlg.add_action_callback('open_tutorial') do |_ctx, _arg|
      show_tutorial
    end

    dlg.add_action_callback('open_url') do |_ctx, url|
      UI.openURL(url)
    end

    dlg.show
  end
end
