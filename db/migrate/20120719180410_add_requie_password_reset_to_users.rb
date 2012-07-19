class AddRequiePasswordResetToUsers < ActiveRecord::Migration
  def change
    add_column :users, :require_password_reset, :boolean, :default => false
  end
end
