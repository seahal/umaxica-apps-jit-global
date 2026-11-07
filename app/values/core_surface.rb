# typed: false
# frozen_string_literal: true

module CoreSurface
  DEFAULT = :unknown
  SURFACES = %i(app com org net dev).freeze

  module_function

  def detect(request)
    host = normalized_host(extract_host(request))
    return DEFAULT if host.blank?

    labels = host.split(".")
    labels.each do |label|
      surface = label.to_sym
      return surface if SURFACES.include?(surface)
    end

    DEFAULT
  end

  def current(request)
    detect(request)
  end

  def matches?(request, surface)
    current(request) == surface.to_sym
  end

  def normalized_host(value)
    CoreHostNormalization.normalize(value)
  end
  private_class_method :normalized_host

  def extract_host(request)
    return request.host if request.respond_to?(:host)

    request.to_s
  end
  private_class_method :extract_host
end
