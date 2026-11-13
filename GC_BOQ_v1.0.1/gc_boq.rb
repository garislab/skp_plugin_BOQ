# =============================================================================
# GC BOQ - Plugin Perhitungan Bill of Quantity untuk SketchUp
# R&D Garis Cerita
# =============================================================================
# Loader ekstensi. File ini WAJIB berada di top-level folder Plugins agar
# SketchUp bisa mengenali & mendaftarkan ekstensi (konvensi SketchUp
# Extension: <nama>.rb + folder <nama>/ berisi source sesungguhnya).
# =============================================================================

require 'sketchup.rb'
require 'extensions.rb'

module GCBOQ
  VERSION    = '1.0.1'
  BUILD_DATE = '23/07/2026 10:00 (WIB)'
  AUTHOR     = 'R&D Garis Cerita'

  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new(
      'GC BOQ',
      File.join(File.dirname(__FILE__), 'gc_boq', 'main.rb')
    )
    ext.description = 'GC BOQ - Menghitung Bill of Quantity (volume & luas) ' \
                       'untuk pekerjaan arsitektur langsung dari model SketchUp. ' \
                       'Dikembangkan oleh R&D Garis Cerita.'
    ext.version   = VERSION
    ext.creator   = 'Garis Cerita'
    ext.copyright = '2026, Garis Cerita'

    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
