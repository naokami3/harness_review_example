class ApplicationController < ActionController::API
  private

  def authenticate!
    token = request.headers["Authorization"]&.split(" ")&.last
    return render json: { error: "Token missing" }, status: :unauthorized unless token

    decoded = JWT.decode(token, secret_key, false)
    @current_user = User.find(decoded[0]["user_id"])
  rescue JWT::DecodeError, ActiveRecord::RecordNotFound
    render json: { error: "Invalid token" }, status: :unauthorized
  end

  def current_user
    @current_user
  end

  def secret_key
    ENV['JWT_SECRET_KEY'] || 'fallback-secret'
  end
end
