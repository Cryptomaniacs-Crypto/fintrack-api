# frozen_string_literal: true

# Per-user home-banner cover photo: stored encrypted (like payment proofs),
# served only via the owner-scoped banner endpoint. Nullable -> no banner.
Sequel.migration do
  change do
    alter_table(:accounts) do
      add_column :banner_image_secure, String, text: true
      add_column :banner_content_type, String
    end
  end
end
