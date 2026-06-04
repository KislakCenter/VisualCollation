# 🤖 AI Usage Disclosure: Designed and implemented by Claude (Anthropic).
require 'rails_helper'

RSpec.describe User, type: :model do
  it { is_expected.to be_mongoid_document }

  it { is_expected.to have_field(:name).of_type(String) }

  it { is_expected.to have_many(:images) }
  it { is_expected.to have_many(:projects) }

  describe "email downcasing" do
    it "saves email as lowercase" do
      user = FactoryGirl.create(:user, email: "User@Example.COM")
      expect(user.email).to eq "user@example.com"
    end

    it "downcases email on update" do
      user = FactoryGirl.create(:user, email: "original@example.com")
      user.update(email: "UPDATED@EXAMPLE.COM")
      expect(user.reload.email).to eq "updated@example.com"
    end
  end
end
