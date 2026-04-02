# Hecks::Adapters::TestEncryptor
#
# Reversible Base64 encryptor for fast tests. Produces visibly different
# ciphertext without requiring an encryption key, so specs can verify
# that encryption/decryption round-trips without needing OpenSSL.
#
#   enc = Hecks::Adapters::TestEncryptor.new
#   cipher = enc.encrypt("secret")   # => "c2VjcmV0"
#   enc.decrypt(cipher)              # => "secret"
#
require "base64"

module Hecks
  module Adapters
    class TestEncryptor
      def encrypt(value)
        Base64.strict_encode64(value.to_s)
      end

      def decrypt(value)
        Base64.strict_decode64(value.to_s)
      end
    end
  end
end
