class AddFlavourAndMapping < ActiveRecord::Migration[5.2]
  def change
    add_column :requests, :flavor, :string
    add_column :requests, :mapping, :string
  end
end
