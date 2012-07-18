class AddDefaultUserToUsers < ActiveRecord::Migration
  def change
    add_column :users, :default_user, :boolean, :default => false
  end
end
