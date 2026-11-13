require 'sketchup.rb'
require 'json'

module GCBOQ
  def self.show_calculate(mode)
    rows = build_boq(mode)

    if rows.empty?
      UI.messagebox(
        mode == :selection ?
          "Tidak ada Group/Component pada seleksi.\nPilih dulu elemen (dinding/lantai/dll), lalu jalankan kembali." :
          "Model tidak berisi Group/Component yang terdeteksi."
      )
      return
    end

    summary = summarize(rows)
    total = grand_total(rows)

    dlg = new_dialog('Hitung BOQ - GC BOQ', 1040, 680, resizable: true, min_width: 720, min_height: 480)
    dlg.set_file(asset_path('html/calculate.html'))

    dlg.add_action_callback('ready') do |_ctx|
      data = { rows: rows, summary: summary, total: total, mode: mode.to_s }
      dlg.execute_script("GCCalc.loadData(#{data.to_json});")
    end

    dlg.add_action_callback('select_entity') do |_ctx, entity_id|
      select_and_zoom(entity_id)
    end

    dlg.add_action_callback('export_csv') do |_ctx, csv_string|
      path = UI.savepanel('Simpan BOQ sebagai CSV', '', 'GC_BOQ.csv')
      if path
        path += '.csv' unless path.downcase.end_with?('.csv')
        File.open(path, 'w:UTF-8') { |f| f.write(csv_string) }
        UI.messagebox("BOQ berhasil disimpan:\n#{path}")
      end
    end

    dlg.add_action_callback('recalculate') do |_ctx, new_mode|
      new_rows = build_boq(new_mode.to_sym)
      new_summary = summarize(new_rows)
      new_total = grand_total(new_rows)
      data = { rows: new_rows, summary: new_summary, total: new_total, mode: new_mode }
      dlg.execute_script("GCCalc.loadData(#{data.to_json});")
    end

    dlg.show
  end
end
