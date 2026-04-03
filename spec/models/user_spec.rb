require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      user = build(:user)
      expect(user).to be_valid
    end

    it "requires username" do
      user = build(:user, username: nil)
      expect(user).not_to be_valid
    end

    it "requires email" do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
    end

    it "requires unique username" do
      create(:user, username: "taken")
      user = build(:user, username: "taken")
      expect(user).not_to be_valid
    end

    it "requires unique email" do
      create(:user, email: "taken@example.com")
      user = build(:user, email: "taken@example.com")
      expect(user).not_to be_valid
    end
  end

  describe "associations" do
    it "has many tasks" do
      assoc = described_class.reflect_on_association(:tasks)
      expect(assoc.macro).to eq :has_many
    end
  end
end
