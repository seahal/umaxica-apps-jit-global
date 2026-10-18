# typed: false
# frozen_string_literal: true

module SignComRouteAliasHelper
  def self.included(base)
    define_route_aliases(base)
  end

  def self.extended(base)
    if base.is_a?(Module)
      define_route_aliases(base)
    else
      base.singleton_class.class_eval { SignComRouteAliasHelper.define_route_aliases(self) }
    end
  end

  def self.define_route_aliases(base)
    {
      "sign_app_" => "sign_com_",
      "acme_app_" => "acme_com_",
    }.each do |source_prefix, target_prefix|
      Rails.application.routes.url_helpers.public_instance_methods.grep(/^#{source_prefix}/).each do |helper_name|
        target_helper_name = helper_name.to_s.sub(source_prefix, target_prefix)
        next unless Rails.application.routes.url_helpers.public_method_defined?(target_helper_name.to_sym)

        # FIXME: do not use define_method!
        base.define_method(helper_name) do |*args, **kwargs, &block|
          public_send(target_helper_name, *args, **kwargs, &block)
        end
      end
    end
  end

  define_route_aliases(self)
end
