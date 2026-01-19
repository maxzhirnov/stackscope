# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_01_19_131852) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_credentials", force: :cascade do |t|
    t.string "username"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "app_settings", force: :cascade do |t|
    t.string "key"
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "metric_samples", force: :cascade do |t|
    t.integer "server_id", null: false
    t.decimal "cpu_usage"
    t.decimal "memory_usage"
    t.decimal "disk_usage"
    t.decimal "load_avg"
    t.datetime "collected_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "uptime_seconds"
    t.decimal "swap_usage"
    t.integer "disk_read_bps"
    t.integer "disk_write_bps"
    t.integer "net_rx_bps"
    t.integer "net_tx_bps"
    t.text "fs_usage_json"
    t.index ["server_id"], name: "index_metric_samples_on_server_id"
  end

  create_table "servers", force: :cascade do |t|
    t.string "name"
    t.string "host"
    t.string "agent_url"
    t.string "status"
    t.datetime "last_ping_at"
    t.datetime "last_metrics_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "port"
    t.string "agent_token"
    t.integer "ping_interval_seconds", default: 60, null: false
    t.integer "ping_latency_ms"
    t.integer "position", default: 0, null: false
  end

  create_table "shortcuts", force: :cascade do |t|
    t.string "name"
    t.string "url"
    t.string "icon"
    t.string "category"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "icon_url"
    t.boolean "monitor_enabled", default: true, null: false
    t.integer "check_interval_seconds", default: 60, null: false
    t.datetime "last_checked_at"
    t.string "last_status"
    t.integer "last_status_code"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "metric_samples", "servers"
end
