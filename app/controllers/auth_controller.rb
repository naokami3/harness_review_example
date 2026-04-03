class AuthController < ApplicationController
  def register
    user = User.new(register_params)
    if user.save
      render json: user.as_json(except: :password_digest), status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def login
    user = User.find_by(username: params[:username])
    if user&.authenticate(params[:password])
      token = JWT.encode({ user_id: user.id, exp: 24.hours.from_now.to_i }, secret_key)
      render json: { token: token, user: user.as_json(except: :password_digest) }
    else
      render json: { error: "Invalid credentials" }, status: :unauthorized
    end
  end

  private

  def register_params
    params.permit(:username, :email, :password)
  end
end
