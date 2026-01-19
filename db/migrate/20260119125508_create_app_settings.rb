class CreateAppSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :app_settings, if_not_exists: true do |t|
      t.string :key
      t.string :value

      t.timestamps
    end

    add_index :app_settings, :key, unique: true, if_not_exists: true
  end
end
