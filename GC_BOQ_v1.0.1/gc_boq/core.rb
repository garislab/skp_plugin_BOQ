require 'sketchup.rb'

module GCBOQ
  # ===========================================================================
  # KONSTANTA KONVERSI SATUAN (SketchUp internal = inci)
  # ===========================================================================
  M2_PER_IN2 = 0.00064516      # 1 in^2 -> m^2
  M3_PER_IN3 = 1.6387064e-5    # 1 in^3 -> m^3
  M_PER_IN   = 0.0254          # 1 in   -> m

  # Prefix Tag yang dipakai untuk menandai kategori secara eksplisit &
  # otoritatif, misalnya "ARS-Dinding", "ARS-Tangga" (kategori bebas/custom).
  TAG_PREFIX = 'ARS-'

  # 8 kategori standar arsitektur beserta kata kunci (fallback jika elemen
  # belum ditandai memakai Tag ARS-). Urutan array = urutan tombol di panel
  # Seleksi Objek & urutan tampil pada hasil Hitung BOQ.
  CATEGORY_KEYWORDS = {
    'Dinding' => ['dinding', 'wall', 'tembok'],
    'Lantai'  => ['lantai', 'floor', 'slab'],
    'Plafon'  => ['plafon', 'ceiling'],
    'Atap'    => ['atap', 'roof'],
    'Kolom'   => ['kolom', 'column'],
    'Balok'   => ['balok', 'beam', 'girder'],
    'Pintu'   => ['pintu', 'door'],
    'Jendela' => ['jendela', 'window']
  }.freeze

  CATEGORY_LIST = CATEGORY_KEYWORDS.keys.freeze

  # Arah permukaan yang relevan untuk menghitung "Luas" per kategori, supaya
  # hasil akhir cukup SATU kolom Luas (tidak dipisah luas-dinding/luas-lantai).
  VERTICAL_CATS = ['Dinding', 'Kolom', 'Balok', 'Pintu', 'Jendela'].freeze
  TOP_CATS      = ['Lantai', 'Atap'].freeze
  BOTTOM_CATS   = ['Plafon'].freeze

  # entityID (Integer) -> referensi entity Ruby, untuk fitur klik = select+zoom
  @@id_map = {}

  def self.id_map
    @@id_map
  end

  # ===========================================================================
  # KLASIFIKASI
  # Urutan prioritas:
  #   1) Tag bernama "ARS-<Kategori>"  -> otoritatif, mendukung kategori BEBAS
  #   2) Kata kunci pada Tag / nama definisi / nama instance (8 kategori baku)
  #   3) "Lainnya" jika tidak cocok apa pun
  # ===========================================================================
  def self.classify(entity)
    tag_name = entity.layer ? entity.layer.name.to_s : ''

    if tag_name =~ /\A#{TAG_PREFIX}(.+)\z/i
      cat = Regexp.last_match(1).strip
      return cat unless cat.empty?
    end

    def_name  = entity.is_a?(Sketchup::ComponentInstance) ? entity.definition.name.to_s : ''
    inst_name = begin
                  entity.name.to_s
                rescue
                  ''
                end
    haystack = "#{tag_name} #{def_name} #{inst_name}".downcase

    CATEGORY_KEYWORDS.each do |cat, keywords|
      keywords.each { |kw| return cat if haystack.include?(kw) }
    end

    'Lainnya'
  end

  # ===========================================================================
  # PENELUSURAN GEOMETRI
  # Mengumpulkan elemen "terukur" (Group / ComponentInstance berisi Face
  # secara langsung). Group/Component yang murni folder pengelompokan
  # (tanpa Face langsung, hanya berisi sub-group) ditelusuri lebih dalam.
  # ===========================================================================
  def self.gather_elements(entities, ancestor_transform, results)
    entities.each do |e|
      next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      next if e.respond_to?(:hidden?) && e.hidden?
      next if e.layer && !e.layer.visible?

      sub_entities = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
      has_faces  = sub_entities.any? { |x| x.is_a?(Sketchup::Face) }
      has_subgrp = sub_entities.any? { |x| x.is_a?(Sketchup::Group) || x.is_a?(Sketchup::ComponentInstance) }

      if !has_faces && has_subgrp
        gather_elements(sub_entities, ancestor_transform * e.transformation, results)
      else
        results << { entity: e, ancestor_transform: ancestor_transform, sub_entities: sub_entities }
      end
    end
    results
  end

  # Volume solid dihitung manual via teorema divergensi (tetrahedron ke titik
  # asal) sehingga bekerja untuk Group maupun ComponentInstance tanpa
  # bergantung pada Group#volume yang mensyaratkan mesh benar-benar manifold.
  def self.manual_volume(faces, world_transform)
    vol = 0.0
    faces.each do |f|
      mesh = f.mesh(0)
      next unless mesh
      mesh.polygons.each do |poly|
        pts = poly.map { |idx| mesh.point_at(idx.abs).transform(world_transform) }
        next if pts.length < 3
        p0 = pts[0]
        (1..pts.length - 2).each do |i|
          p1 = pts[i]
          p2 = pts[i + 1]
          vol += (p0.x * (p1.y * p2.z - p2.y * p1.z) -
                  p0.y * (p1.x * p2.z - p2.x * p1.z) +
                  p0.z * (p1.x * p2.y - p2.x * p1.y))
        end
      end
    end
    (vol / 6.0).abs
  end

  def self.world_bounds(bounds, ancestor_transform)
    pts = (0..7).map { |i| bounds.corner(i).transform(ancestor_transform) }
    wb = Geom::BoundingBox.new
    wb.add(pts)
    wb
  end

  # ===========================================================================
  # METRIK MENTAH PER ELEMEN (volume + luas per arah + dimensi)
  # ===========================================================================
  def self.raw_metrics(item)
    e  = item[:entity]
    at = item[:ancestor_transform]
    wt = at * e.transformation
    faces = item[:sub_entities].grep(Sketchup::Face)

    vertical_in2 = 0.0
    top_in2      = 0.0
    bottom_in2   = 0.0
    total_in2    = 0.0

    faces.each do |f|
      area = f.area(wt)
      total_in2 += area
      begin
        normal = f.normal.transform(wt)
        normal.normalize!
        if normal.z.abs < 0.15
          vertical_in2 += area
        elsif normal.z > 0.85
          top_in2 += area
        elsif normal.z < -0.85
          bottom_in2 += area
        end
      rescue
        # normal degenerate, lewati klasifikasi arah untuk face ini
      end
    end

    volume_in3 = manual_volume(faces, wt)
    wb = world_bounds(e.bounds, at)

    {
      volume_m3:        volume_in3 * M3_PER_IN3,
      vertical_area_m2: (vertical_in2 / 2.0) * M2_PER_IN2, # 1 sisi (depan=belakang)
      top_area_m2:      top_in2 * M2_PER_IN2,
      bottom_area_m2:   bottom_in2 * M2_PER_IN2,
      total_area_m2:    total_in2 * M2_PER_IN2,
      panjang_m: wb.width  * M_PER_IN,
      lebar_m:   wb.depth  * M_PER_IN,
      tinggi_m:  wb.height * M_PER_IN
    }
  end

  # "Luas" tunggal yang relevan sesuai kategori elemen -> memenuhi permintaan
  # 1 kolom Luas saja (tidak dipisah luas-dinding vs luas-lantai).
  def self.effective_area(category, m)
    if VERTICAL_CATS.include?(category)
      m[:vertical_area_m2]
    elsif TOP_CATS.include?(category)
      m[:top_area_m2]
    elsif BOTTOM_CATS.include?(category)
      m[:bottom_area_m2]
    else
      candidates = [m[:vertical_area_m2], m[:top_area_m2], m[:bottom_area_m2]]
      best = candidates.max
      best.positive? ? best : (m[:total_area_m2] / 2.0)
    end
  end

  # ===========================================================================
  # KUMPULKAN DATA BOQ (mode: :selection atau :model)
  # ===========================================================================
  def self.build_boq(mode)
    model = Sketchup.active_model
    @@id_map = {}

    source = mode == :selection ? model.selection.to_a : model.entities
    raw = gather_elements(source, Geom::Transformation.new, [])

    rows = []
    raw.each do |item|
      e = item[:entity]
      cat = classify(e)
      m = raw_metrics(item)
      luas = effective_area(cat, m)

      name = begin
               n = e.name.to_s
               n = (e.is_a?(Sketchup::ComponentInstance) ? e.definition.name.to_s : 'Group') if n.empty?
               n
             rescue
               'Group'
             end
      tag = e.layer ? e.layer.name.to_s : 'Layer0'

      @@id_map[e.entityID] = e

      rows << {
        id: e.entityID,
        kategori: cat,
        nama: name,
        tag: tag,
        volume: m[:volume_m3].round(3),
        luas: luas.round(3),
        panjang: m[:panjang_m].round(3),
        lebar: m[:lebar_m].round(3),
        tinggi: m[:tinggi_m].round(3)
      }
    end

    rows
  end

  def self.summarize(rows)
    summary = {}
    rows.each do |r|
      s = summary[r[:kategori]] ||= { jumlah: 0, volume: 0.0, luas: 0.0 }
      s[:jumlah] += 1
      s[:volume] += r[:volume]
      s[:luas] += r[:luas]
    end
    # urutkan sesuai CATEGORY_LIST dulu, sisanya (custom / "Lainnya") di akhir
    ordered_keys = CATEGORY_LIST & summary.keys
    other_keys = (summary.keys - CATEGORY_LIST).sort
    other_keys = (other_keys - ['Lainnya']) + (other_keys.include?('Lainnya') ? ['Lainnya'] : [])
    result = {}
    (ordered_keys + other_keys).each { |k| result[k] = summary[k] }
    result
  end

  def self.grand_total(rows)
    {
      jumlah: rows.length,
      volume: rows.sum { |r| r[:volume] }.round(3),
      luas: rows.sum { |r| r[:luas] }.round(3)
    }
  end

  # ===========================================================================
  # INVENTARIS TAG (dipakai panel "Seleksi Objek" untuk menampilkan semua
  # elemen yang sudah ditandai, dikelompokkan per kategori)
  # ===========================================================================
  def self.build_inventory
    model = Sketchup.active_model
    raw = gather_elements(model.entities, Geom::Transformation.new, [])
    inventory = {}
    raw.each do |item|
      e = item[:entity]
      cat = classify(e)
      next if cat == 'Lainnya' # hanya tampilkan elemen yang sudah terklasifikasi

      @@id_map[e.entityID] = e

      (inventory[cat] ||= []) << {
        id: e.entityID,
        nama: begin
                n = e.name.to_s
                n = (e.is_a?(Sketchup::ComponentInstance) ? e.definition.name.to_s : 'Group') if n.empty?
                n
              rescue
                'Group'
              end
      }
    end
    inventory
  end
end
