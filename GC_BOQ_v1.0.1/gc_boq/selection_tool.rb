require 'sketchup.rb'
require 'json'

module GCBOQ
  # ===========================================================================
  # OBSERVER: memantau perubahan seleksi selagi panel "Seleksi Objek" terbuka,
  # supaya info jumlah/daftar terpilih ter-update otomatis (real-time) tanpa
  # perlu menekan tombol refresh manual.
  # ===========================================================================
  class SelectionInfoObserver < Sketchup::SelectionObserver
    def initialize(dialog)
      @dialog = dialog
    end

    def onSelectionBulkChange(_selection)
      push
    end

    def onSelectionCleared(_selection)
      push
    end

    def push
      return unless @dialog && @dialog.visible?
      data = GCBOQ.current_selection_info
      @dialog.execute_script("GCSelection.updateSelection(#{data.to_json});")
    end
  end

  @@selection_dialog = nil
  @@selection_observer = nil

  def self.current_selection_info
    model = Sketchup.active_model
    items = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
    {
      jumlah: items.length,
      elemen: items.first(50).map do |e|
        @@id_map[e.entityID] = e
        {
          id: e.entityID,
          nama: begin
                  n = e.name.to_s
                  n = (e.is_a?(Sketchup::ComponentInstance) ? e.definition.name.to_s : 'Group') if n.empty?
                  n
                rescue
                  'Group'
                end,
          kategori: classify(e),
          tag: e.layer ? e.layer.name.to_s : 'Layer0'
        }
      end
    }
  end

  def self.show_selection_panel
    if @@selection_dialog && @@selection_dialog.visible?
      @@selection_dialog.bring_to_front
      return
    end

    dlg = new_dialog('Seleksi Objek - GC BOQ', 480, 620, resizable: true)
    html_path = asset_path('html/selection.html')
    dlg.set_file(html_path)

    dlg.add_action_callback('ready') do |_ctx|
      data = {
        categories: CATEGORY_LIST,
        selection: current_selection_info,
        inventory: build_inventory
      }
      dlg.execute_script("GCSelection.init(#{data.to_json});")
    end

    dlg.add_action_callback('assign_category') do |_ctx, category|
      assign_category_to_selection(category)
      dlg.execute_script("GCSelection.updateSelection(#{current_selection_info.to_json});")
      dlg.execute_script("GCSelection.updateInventory(#{build_inventory.to_json});")
    end

    dlg.add_action_callback('clear_category') do |_ctx, _arg|
      clear_category_from_selection
      dlg.execute_script("GCSelection.updateSelection(#{current_selection_info.to_json});")
      dlg.execute_script("GCSelection.updateInventory(#{build_inventory.to_json});")
    end

    dlg.add_action_callback('select_entity') do |_ctx, entity_id|
      select_and_zoom(entity_id)
    end

    dlg.add_action_callback('refresh_inventory') do |_ctx, _arg|
      dlg.execute_script("GCSelection.updateInventory(#{build_inventory.to_json});")
    end

    dlg.add_action_callback('open_calculate') do |_ctx, mode|
      show_calculate(mode.to_sym)
    end

    model = Sketchup.active_model
    @@selection_observer = SelectionInfoObserver.new(dlg)
    model.selection.add_observer(@@selection_observer)

    dlg.set_on_closed do
      begin
        model.selection.remove_observer(@@selection_observer)
      rescue
        # model mungkin sudah ditutup
      end
      @@selection_observer = nil
    end

    @@selection_dialog = dlg
    dlg.show
  end

  def self.assign_category_to_selection(category)
    model = Sketchup.active_model
    sel = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
    return if sel.empty?

    layer_name = "#{TAG_PREFIX}#{category}"
    layers = model.layers
    layer = layers[layer_name] || layers.add(layer_name)

    model.start_operation("Tandai sebagai #{category}", true)
    sel.each { |e| e.layer = layer }
    model.commit_operation
  end

  def self.clear_category_from_selection
    model = Sketchup.active_model
    sel = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
    return if sel.empty?

    default_layer = model.layers[0]
    model.start_operation('Hapus penanda kategori', true)
    sel.each { |e| e.layer = default_layer }
    model.commit_operation
  end

  def self.select_and_zoom(entity_id)
    e = @@id_map[entity_id.to_i]
    return unless e
    model = Sketchup.active_model
    model.selection.clear
    model.selection.add(e)
    begin
      model.active_view.zoom(model.selection)
    rescue
      # abaikan jika zoom gagal
    end
  end
end
