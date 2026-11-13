require 'sketchup.rb'

module GCBOQ
  DIR = File.dirname(__FILE__)
end

require File.join(GCBOQ::DIR, 'core.rb')
require File.join(GCBOQ::DIR, 'ui_common.rb')
require File.join(GCBOQ::DIR, 'selection_tool.rb')
require File.join(GCBOQ::DIR, 'calculate_tool.rb')
require File.join(GCBOQ::DIR, 'tutorial_tool.rb')
require File.join(GCBOQ::DIR, 'about_tool.rb')

module GCBOQ
  unless file_loaded?(__FILE__)
    # -------------------------------------------------------------------
    # MENU: Extensions > GC BOQ
    # -------------------------------------------------------------------
    menu = UI.menu('Extensions').add_submenu('GC BOQ')

    menu.add_item('Seleksi Objek')       { GCBOQ.show_selection_panel }
    menu.add_separator
    menu.add_item('Hitung BOQ Seleksi')  { GCBOQ.show_calculate(:selection) }
    menu.add_item('Hitung BOQ Semua')    { GCBOQ.show_calculate(:model) }
    menu.add_separator
    menu.add_item('Tutorial')            { GCBOQ.show_tutorial }
    menu.add_item('Tentang')             { GCBOQ.show_about }

    # -------------------------------------------------------------------
    # SHORTCUT KLIK KANAN: submenu GC BOQ muncul saat ada objek terpilih,
    # supaya menandai kategori & menghitung BOQ tidak perlu bolak-balik
    # ke menu Extensions.
    # -------------------------------------------------------------------
    UI.add_context_menu_handler do |context_menu|
      model = Sketchup.active_model
      next if model.selection.empty?

      has_group_or_component = model.selection.any? do |e|
        e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      end
      next unless has_group_or_component

      submenu = context_menu.add_submenu('GC BOQ')

      tag_menu = submenu.add_submenu('Tandai sebagai')
      CATEGORY_LIST.each do |cat|
        tag_menu.add_item(cat) { GCBOQ.assign_category_to_selection(cat) }
      end
      tag_menu.add_separator
      tag_menu.add_item('Hapus Penanda') { GCBOQ.clear_category_from_selection }

      submenu.add_separator
      submenu.add_item('Hitung BOQ Seleksi') { GCBOQ.show_calculate(:selection) }
      submenu.add_item('Buka Panel Seleksi Objek') { GCBOQ.show_selection_panel }
    end

    file_loaded(__FILE__)
  end
end
