class DashboardController < ApplicationController
  def index
    @servers = Server.includes(:metric_samples).order(:position, :name)
    @shortcuts = Shortcut.order(:position, :name)
  end
end
