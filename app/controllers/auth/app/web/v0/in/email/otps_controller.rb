# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Web
      module V0
        module In
          module Email
            class OtpsController < ::Auth::App::ApplicationController
              AUTHENTICATION_MODE = :guest

              def create
                result = SignInOtpResender.new(
                  kind: :email, state: otp_params[:state], surface: :app,
                ).call
                render_result(result)
              end

              private

              def otp_params
                # `slice` first: this reads a fixed set of keys and ignores everything else the
                # request carries (`ri`, the Turnstile token). Permitting without narrowing would
                # report those as unpermitted, which they are not - they are simply not ours.
                params.slice(:state).permit(:state)
              end

              def render_result(result)
                response.headers["Retry-After"] =
                  result.retry_after.to_s if result.status == :too_many_requests
                render json: {
                  resendable: result.resendable,
                  retry_after: result.retry_after,
                }, status: result.status
              end
            end
          end
        end
      end
    end
  end
end
