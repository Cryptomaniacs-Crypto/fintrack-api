# frozen_string_literal: true

require 'base64'

module FinanceTracker
  # Validates an uploaded payment-proof image before it is encrypted and stored.
  # Defence in depth: we check the declared content-type against an allowlist,
  # cap the decoded size, and verify the real magic bytes so a renamed/forged
  # file (e.g. an HTML or script payload claiming to be a PNG) is rejected.
  module ImageProof
    class InvalidImage < StandardError; end

    MAX_BYTES = 2 * 1024 * 1024 # 2 MB

    # content-type => required leading magic bytes
    SIGNATURES = {
      'image/png'  => "\x89PNG\r\n\x1A\n".b,
      'image/jpeg' => "\xFF\xD8\xFF".b
    }.freeze

    module_function

    # Returns the validated content-type, or raises InvalidImage.
    def validate!(base64, content_type)
      type = content_type.to_s
      raise InvalidImage, 'Unsupported image type (use PNG or JPEG)' unless SIGNATURES.key?(type)

      bytes =
        begin
          Base64.strict_decode64(base64.to_s)
        rescue ArgumentError
          raise InvalidImage, 'Image is not valid base64'
        end

      raise InvalidImage, 'Image is empty' if bytes.empty?
      raise InvalidImage, 'Image exceeds the 2MB limit' if bytes.bytesize > MAX_BYTES
      raise InvalidImage, 'Image content does not match its declared type' unless bytes.b.start_with?(SIGNATURES[type])

      type
    end
  end
end
