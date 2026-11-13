require 'sketchup.rb'

module GCBOQ
  def self.root_dir
    File.dirname(__FILE__)
  end

  def self.asset_path(relative)
    File.join(root_dir, relative)
  end

  # Wrapper standar UI::HtmlDialog supaya seluruh jendela GC BOQ punya
  # perilaku & ukuran default yang konsisten.
  def self.new_dialog(title, width, height, resizable: true, min_width: 380, min_height: 300)
    UI::HtmlDialog.new(
      dialog_title: title,
      preferences_key: "gc_boq_#{title.downcase.gsub(/[^a-z0-9]+/, '_')}",
      scrollable: true,
      resizable: resizable,
      width: width,
      height: height,
      min_width: min_width,
      min_height: min_height,
      style: UI::HtmlDialog::STYLE_DIALOG
    )
  end
end
