# Hecks::Adapters::AesEncryptor
#
# AES-256-GCM encryption backend for attribute-level encryption at rest.
# Each encrypted value includes a random IV prepended to the ciphertext,
# Base64-encoded for safe storage in any text column.
#
#   key = OpenSSL::Random.random_bytes(32)
#   enc = Hecks::Adapters::AesEncryptor.new(key)
#   cipher = enc.encrypt("secret")
#   enc.decrypt(cipher)  # => "secret"
#
require "openssl"
require "base64"

module Hecks
  module Adapters
    class AesEncryptor
      ALGO = "aes-256-gcm".freeze
      IV_LEN = 12
      TAG_LEN = 16

      # @param key [String] 32-byte encryption key (binary)
      def initialize(key)
        raise ArgumentError, "Key must be 32 bytes" unless key.bytesize == 32
        @key = key
      end

      # Encrypt a plaintext string. Returns a Base64-encoded string containing
      # the IV, auth tag, and ciphertext.
      #
      # @param value [String] the plaintext to encrypt
      # @return [String] Base64-encoded ciphertext with embedded IV and tag
      def encrypt(value)
        cipher = OpenSSL::Cipher.new(ALGO)
        cipher.encrypt
        iv = cipher.random_iv
        cipher.key = @key

        ciphertext = cipher.update(value.to_s) + cipher.final
        tag = cipher.auth_tag(TAG_LEN)

        Base64.strict_encode64(iv + tag + ciphertext)
      end

      # Decrypt a Base64-encoded ciphertext produced by +encrypt+.
      #
      # @param value [String] Base64-encoded ciphertext
      # @return [String] the original plaintext
      def decrypt(value)
        raw = Base64.strict_decode64(value.to_s)
        iv = raw[0, IV_LEN]
        tag = raw[IV_LEN, TAG_LEN]
        ciphertext = raw[(IV_LEN + TAG_LEN)..]

        decipher = OpenSSL::Cipher.new(ALGO)
        decipher.decrypt
        decipher.iv = iv
        decipher.key = @key
        decipher.auth_tag = tag

        decipher.update(ciphertext) + decipher.final
      end
    end
  end
end
