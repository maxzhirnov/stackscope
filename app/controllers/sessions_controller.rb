class SessionsController < ApplicationController
  skip_before_action :require_login
  skip_before_action :ensure_admin_credentials
  skip_before_action :verify_authenticity_token, only: :create

  def new
    redirect_to root_path if current_admin
  end

  def create
    username = params[:username].to_s.strip
    password = params[:password].to_s.strip
    credential = AdminCredential.where("lower(username) = ?", username.downcase).first
    if credential&.authenticate(password)
      session[:admin_id] = credential.id
      redirect_to root_path, notice: "Signed in."
    else
      flash.now[:alert] = "Invalid username or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to new_session_path, notice: "Signed out."
  end
end
