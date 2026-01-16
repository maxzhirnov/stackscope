class ShortcutsController < ApplicationController
  before_action :set_shortcut, only: [:edit, :update, :destroy]

  def index
    @shortcuts = Shortcut.order(:category, :position, :name)
  end

  def new
    @shortcut = Shortcut.new
  end

  def create
    @shortcut = Shortcut.new(shortcut_params)
    if @shortcut.save
      redirect_to shortcuts_path, notice: "Shortcut added."
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

  private

  def set_shortcut
    @shortcut = Shortcut.find(params[:id])
  end

  def shortcut_params
    params.require(:shortcut).permit(:name, :url, :icon_url, :category, :position, :icon_image)
  end
end
