class DashboardController < ApplicationController
  def index
    @servers = Server.includes(:metric_samples).order(:name)
    @shortcuts = Shortcut.order(:category, :position, :name)
  end
end
