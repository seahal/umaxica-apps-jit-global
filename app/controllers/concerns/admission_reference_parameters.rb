# frozen_string_literal: true

# Validate raw pairs before Rails' merged parameter hash can hide a duplicate reference.
module AdmissionReferenceParameters
  extend ActiveSupport::Concern

  private

  def duplicate_admission_reference?(name)
    query_pairs = ActionDispatch::QueryParser.each_pair(request.query_string)
    body_pairs = request.request_parameters_list
    raise ArgumentError, "raw admission form parameters unavailable" if request.form_data? && body_pairs.nil?

    count = request.path_parameters.key?(name.to_sym) ? 1 : 0
    query_pairs.each { |key, _value| count += 1 if key == name }
    body_pairs&.each { |key, _value| count += 1 if key == name }
    count > 1
  end
end
