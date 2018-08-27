class AddInstanceNameAndError < ActiveRecord::Migration[5.2]
  def change
    add_column :requests, :name, :string
    add_column :requests, :error, :string
  end
end
