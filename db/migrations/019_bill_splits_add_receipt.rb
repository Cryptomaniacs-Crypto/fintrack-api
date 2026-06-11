# frozen_string_literal: true

Sequel.migration do
  up do
    cols = schema(:bill_splits).map(&:first)
    alter_table(:bill_splits) do
      # Encrypted base64 of the source receipt photo the owner optionally uploads,
      # plus its content type. Lets participants verify entered prices vs reality.
      add_column :receipt_image_secure, String, text: true unless cols.include?(:receipt_image_secure)
      add_column :receipt_content_type, String unless cols.include?(:receipt_content_type)
    end
  end

  down do
    cols = schema(:bill_splits).map(&:first)
    alter_table(:bill_splits) do
      drop_column :receipt_image_secure if cols.include?(:receipt_image_secure)
      drop_column :receipt_content_type if cols.include?(:receipt_content_type)
    end
  end
end
