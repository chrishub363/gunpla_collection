class ChangeScalematesIdIndexToNonUnique < ActiveRecord::Migration[8.1]
  def change
    remove_index :kits, :scalemates_id
    add_index :kits, :scalemates_id
  end
end
