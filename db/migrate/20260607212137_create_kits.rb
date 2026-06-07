class CreateKits < ActiveRecord::Migration[8.1]
  def change
    create_table :kits do |t|
      t.string :title, null: false
      t.string :full_title
      t.string :grade
      t.string :grade_abbr
      t.string :series
      t.string :scale
      t.string :brand
      t.string :topic
      t.string :image_url
      t.integer :scalemates_id
      t.string :scalemates_url
      t.string :status, null: false, default: "unbuilt"

      t.timestamps
    end

    add_index :kits, :status
    add_index :kits, :grade_abbr
    add_index :kits, :series
    add_index :kits, :scalemates_id, unique: true
  end
end
