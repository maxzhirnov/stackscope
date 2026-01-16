class CreateAdminCredentials < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_credentials do |t|
      t.string :username
      t.string :password_digest

      t.timestamps
    end
  end
end
