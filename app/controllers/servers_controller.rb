require "json"
require "net/http"
require "uri"

class ServersController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :check_now
  before_action :set_server, only: [:show, :edit, :update, :check_now, :destroy, :extended_metrics]

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

  def show
    @latest = @server.metric_samples.order(collected_at: :desc).first
    @samples = @server.metric_samples.order(collected_at: :desc).limit(120).reverse
    @extended = @server.extended_metrics_payload
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

  def extended_metrics
    @extended = fetch_extended_metrics(@server)
    if @extended.present?
      @server.update(
        extended_metrics_json: JSON.dump(@extended),
        extended_metrics_fetched_at: Time.current
      )
    end
    @extended = @server.extended_metrics_payload
    render partial: "servers/extended_metrics_frame", locals: { extended: @extended, server: @server }
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

  def fetch_extended_metrics(server)
    return nil if server.agent_url.blank?

    uri = URI.parse(server.agent_url)
    if uri.path.to_s.end_with?("/metrics")
      uri.path = uri.path.sub(%r{/metrics\z}, "/metrics/extended")
    else
      uri.path = uri.path.to_s.sub(/\/$/, "")
      uri.path = "#{uri.path}/metrics/extended"
    end

    request = Net::HTTP::Get.new(uri)
    request["X-Stackscope-Token"] = server.agent_token if server.agent_token.present?

    response = Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: 4,
      read_timeout: 4
    ) do |http|
      http.request(request)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.info("Extended metrics unavailable for server #{server.id}: #{e.class} #{e.message}")
    nil
  end
end
