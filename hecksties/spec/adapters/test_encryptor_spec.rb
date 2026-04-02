require "spec_helper"
require "hecks/adapters/test_encryptor"

RSpec.describe Hecks::Adapters::TestEncryptor do
  subject(:enc) { described_class.new }

  it "round-trips a string" do
    cipher = enc.encrypt("hello")
    expect(enc.decrypt(cipher)).to eq("hello")
  end

  it "produces visibly different ciphertext" do
    expect(enc.encrypt("secret")).not_to eq("secret")
  end

  it "handles empty strings" do
    cipher = enc.encrypt("")
    expect(enc.decrypt(cipher)).to eq("")
  end
end
