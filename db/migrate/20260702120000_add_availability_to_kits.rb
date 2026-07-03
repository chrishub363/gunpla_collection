class AddAvailabilityToKits < ActiveRecord::Migration[8.1]
  def change
    # Retail vs. limited-distribution (P-Bandai, Gundam Base, event/web-shop
    # exclusives). Derived at seed time from the scraped subtitle; indexed
    # because it backs a sidebar filter facet like status/grade_abbr.
    add_column :kits, :availability, :string, default: "retail", null: false
    add_index :kits, :availability
  end
end
