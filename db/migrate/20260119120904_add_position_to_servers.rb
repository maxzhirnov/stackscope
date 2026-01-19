class AddPositionToServers < ActiveRecord::Migration[8.0]
  def change
    return if column_exists?(:servers, :position)

    add_column :servers, :position, :integer, default: 0, null: false
  end
end
