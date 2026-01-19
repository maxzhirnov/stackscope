class ServersController < ApplicationController
  before_action :set_server, only: [:edit, :update, :check_now, :destroy]

  def index
    @servers = Server.order(:position, :name)
  end

  def new
    @server = Server.new
  end

  def create
    @server = Server.new(server_params)
    if @server.save
      redirect_to post_create_path, notice: "Server added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @server.update(server_params)
      redirect_to servers_path, notice: "Server updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @server.destroy
    redirect_to servers_path, notice: "Server deleted."
  end

  def reorder
    order = Array(params[:order])
    ActiveRecord::Base.transaction do
      order.each_with_index do |id, index|
        Server.where(id: id).update_all(position: index)
      end
    end
    head :ok
  end

  def check_now
    PingServerJob.perform_now(@server.id)
    FetchMetricsJob.perform_now(@server.id)
    @server.reload
    respond_to do |format|
      format.turbo_stream do
        partial = params[:source] == "dashboard" ? "dashboard/server_card" : "servers/server_card"
        render turbo_stream: [
          turbo_stream.replace(
            helpers.dom_id(@server, :card),
            partial: partial,
            locals: { server: @server }
          ),
          turbo_stream.append(
            "toast-container",
            partial: "shared/toast",
            locals: { message: "Checks triggered.", type: "notice" }
          )
        ]
      end
      format.html { redirect_back fallback_location: root_path, notice: "Checks triggered." }
    end
  end

  private

  def set_server
    @server = Server.find(params[:id])
  end

  def post_create_path
    params[:return_to] == "dashboard" ? root_path : servers_path
  end

  def server_params
    params.require(:server).permit(:name, :host, :port, :agent_url, :agent_token, :ping_interval_seconds, :position)
  end
end
