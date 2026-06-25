class RenameImageUrlToImageOnKits < ActiveRecord::Migration[8.1]
  def change
    # image_url used to hold a remote scalemates URL; it now holds the bare
    # filename of a locally-committed, content-addressed image under public/kit_images.
    rename_column :kits, :image_url, :image
  end
end
