require "spec_helper"
require "openssl"
require "hecks/adapters/aes_encryptor"

RSpec.describe Hecks::Adapters::AesEncryptor do
  let(:key) { OpenSSL::Random.random_bytes(32) }
  subject(:enc) { described_class.new(key) }

  it "round-trips a string" do
    cipher = enc.encrypt("hello")
    expect(enc.decrypt(cipher)).to eq("hello")
  end

  it "produces different ciphertext each time (random IV)" do
    a = enc.encrypt("same")
    b = enc.encrypt("same")
    expect(a).not_to eq(b)
  end

  it "rejects keys that are not 32 bytes" do
    expect { described_class.new("short") }.to raise_error(ArgumentError, /32 bytes/)
  end

  it "handles empty strings" do
    cipher = enc.encrypt("")
    expect(enc.decrypt(cipher)).to eq("")
  end
end
