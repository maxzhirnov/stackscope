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
end
