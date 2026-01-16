class CreateShortcuts < ActiveRecord::Migration[8.0]
  def change
    create_table :shortcuts do |t|
      t.string :name
      t.string :url
      t.string :icon
      t.string :category
      t.integer :position

      t.timestamps
    end
  end
end
