require "rails_helper"

RSpec.describe "Tasks", type: :request do
  let(:user) { create(:user) }
  let(:token) do
    JWT.encode({ user_id: user.id, exp: 24.hours.from_now.to_i }, ENV['JWT_SECRET_KEY'] || 'fallback-secret')
  end
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "POST /tasks" do
    it "creates a task" do
      post "/tasks", params: { title: "Test task", description: "A description", priority: 2 }, headers: headers
      expect(response).to have_http_status(:created)

      json = JSON.parse(response.body)
      expect(json["title"]).to eq("Test task")
      expect(json["user_id"]).to eq(user.id)
    end
  end

  describe "GET /tasks" do
    it "returns tasks for current user" do
      create_list(:task, 3, user: user)
      create(:task) # other user's task

      get "/tasks", headers: headers
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json.length).to eq(3)
    end
  end

  describe "GET /tasks/:id" do
    it "returns the task" do
      task = create(:task, user: user)

      get "/tasks/#{task.id}", headers: headers
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["id"]).to eq(task.id)
    end
  end

  describe "PATCH /tasks/:id" do
    it "updates the task" do
      task = create(:task, user: user)

      patch "/tasks/#{task.id}", params: { title: "Updated title" }, headers: headers
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["title"]).to eq("Updated title")
    end
  end

  describe "DELETE /tasks/:id" do
    it "soft deletes the task" do
      task = create(:task, user: user)

      delete "/tasks/#{task.id}", headers: headers
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["deleted_at"]).to be_present

      task.reload
      expect(task.deleted_at).not_to be_nil
    end
  end
end
