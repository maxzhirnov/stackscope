class ServersController < ApplicationController
  before_action :set_server, only: [:edit, :update, :check_now, :destroy]

  def index
    @servers = Server.order(:name)
  end

  def new
    @server = Server.new
  end

  def create
    @server = Server.new(server_params)
    if @server.save
      redirect_to servers_path, notice: "Server added."
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

  def check_now
    PingServerJob.perform_now(@server.id)
    FetchMetricsJob.perform_now(@server.id)
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

  def server_params
    params.require(:server).permit(:name, :host, :port, :agent_url, :agent_token, :ping_interval_seconds)
  end
end
