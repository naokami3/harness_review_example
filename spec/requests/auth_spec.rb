require "rails_helper"

RSpec.describe "Auth", type: :request do
  describe "POST /auth/register" do
    it "creates a new user" do
      params = { username: "testuser", email: "test@example.com", password: "password123" }

      post "/auth/register", params: params
      expect(response).to have_http_status(:created)

      json = JSON.parse(response.body)
      expect(json["username"]).to eq("testuser")
      expect(json["email"]).to eq("test@example.com")
      expect(json).not_to have_key("password_digest")
    end
  end

  describe "POST /auth/login" do
    it "returns a token" do
      user = create(:user, username: "loginuser", password: "password123")

      post "/auth/login", params: { username: "loginuser", password: "password123" }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["token"]).to be_present
      expect(json["user"]["id"]).to eq(user.id)
    end
  end
end
