class AddDescription < ActiveRecord::Migration[5.2]
  def change
    add_column :requests, :description, :string
  end
end
