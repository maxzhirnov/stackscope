class ShortcutsController < ApplicationController
  before_action :set_shortcut, only: [:edit, :update, :destroy]

  def index
    @shortcuts = Shortcut.order(:position, :name)
  end

  def new
    @shortcut = Shortcut.new
  end

  def create
    @shortcut = Shortcut.new(shortcut_params)
    if @shortcut.save
      redirect_to post_create_path, notice: "Shortcut added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @shortcut.update(shortcut_params)
      redirect_to shortcuts_path, notice: "Shortcut updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shortcut.destroy
    redirect_to shortcuts_path, notice: "Shortcut deleted."
  end

  def reorder
    order = Array(params[:order])
    ActiveRecord::Base.transaction do
      order.each_with_index do |id, index|
        Shortcut.where(id: id).update_all(position: index)
      end
    end
    head :ok
  end

  private

  def set_shortcut
    @shortcut = Shortcut.find(params[:id])
  end

  def post_create_path
    params[:return_to] == "dashboard" ? root_path : shortcuts_path
  end

  def shortcut_params
    params.require(:shortcut).permit(:name, :url, :icon_url, :category, :position, :icon_image, :monitor_enabled, :check_interval_seconds)
  end
end
