class AddIconUrlToShortcuts < ActiveRecord::Migration[8.0]
  def change
    add_column :shortcuts, :icon_url, :string
  end
end
