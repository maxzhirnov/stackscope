class SetupController < ApplicationController
  skip_before_action :require_login
  skip_before_action :ensure_admin_credentials

  def new
    redirect_to new_session_path if AdminCredential.exists?
  end

  def create
    credential = AdminCredential.new(
      username: params[:username].to_s.strip,
      password: params[:password].to_s,
      password_confirmation: params[:password_confirmation].to_s
    )

    if credential.save
      session[:admin_id] = credential.id
      redirect_to root_path, notice: "Admin account created."
    else
      flash.now[:alert] = credential.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end
end
