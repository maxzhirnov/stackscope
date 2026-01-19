module ApplicationHelper
  def metric_value(value, suffix, precision: 1)
    return "—" if value.nil?

    formatted = number_with_precision(value, precision: precision, strip_insignificant_zeros: true)
    suffix.present? ? "#{formatted}#{suffix}" : formatted
  end

  def metric_class(value, bad_threshold, warn_threshold)
    return "" if value.nil?

    if value >= bad_threshold
      "metric-bad"
    elsif value >= warn_threshold
      "metric-warn"
    else
      "metric-ok"
    end
  end

  def human_bytes_per_sec(value)
    return "—" if value.nil?

    units = %w[B/s KB/s MB/s GB/s]
    size = value.to_f
    idx = 0
    while size >= 1024 && idx < units.length - 1
      size /= 1024.0
      idx += 1
    end
    "#{number_with_precision(size, precision: 1, strip_insignificant_zeros: true)} #{units[idx]}"
  end

  def human_seconds(value)
    return "—" if value.nil?

    seconds = value.to_i
    days = seconds / 86_400
    hours = (seconds % 86_400) / 3600
    minutes = (seconds % 3600) / 60
    if days.positive?
      "#{days}d #{hours}h"
    elsif hours.positive?
      "#{hours}h #{minutes}m"
    else
      "#{minutes}m"
    end
  end

  def sparkline(values, width: 160, height: 40, stroke: "#1c7c73")
    points = values.compact
    return "" if points.empty?

    min = points.min
    max = points.max
    range = (max - min).nonzero? || 1
    step = width.to_f / (points.size - 1).clamp(1, points.size)

    coords = points.each_with_index.map do |v, i|
      x = (i * step).round(2)
      y = (height - ((v - min) / range) * height).round(2)
      "#{x},#{y}"
    end.join(" ")

    <<~SVG.html_safe
      <svg class=\"sparkline\" viewBox=\"0 0 #{width} #{height}\" aria-hidden=\"true\">
        <polyline points=\"#{coords}\" fill=\"none\" stroke=\"#{stroke}\" stroke-width=\"2\" stroke-linecap=\"round\" />
      </svg>
    SVG
  end
end
