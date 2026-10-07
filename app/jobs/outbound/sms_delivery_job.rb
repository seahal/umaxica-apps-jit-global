# typed: false
# frozen_string_literal: true

require "aws-sdk-sns"

module Outbound
  class SmsDeliveryJob < ApplicationJob
    queue_as :default

    retry_on Aws::SNS::Errors::ServiceError, wait: :polynomially_longer, attempts: 5
    retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 3
    retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 3

    # A malformed or mixed payload is a permanent producer/configuration
    # failure. It must not be silently discarded because doing so hides a
    # delivery gap while preserving the no-plaintext-delivery boundary.
    discard_on ArgumentError, report: true

    def perform(encrypted_payload: nil, to: nil, title: nil, encrypted_body: nil, body: nil)
      payload = delivery_payload(encrypted_payload:, to:, title:, encrypted_body:, body:)
      if payload.key?(:otp_binding)
        if payload.fetch(:otp_binding)[1] == "credential_registration"
          return deliver_current_registration_otp(payload)
        end

        binding = SignUpOtpDeliveryBindingValue.for_sms(otp_binding: payload.fetch(:otp_binding))
        flow_class = (binding.surface == "app") ? ClientSignUpFlow : VisitorSignUpFlow
        flow = flow_class.find_by(public_id: binding.flow_ref)
        return unless flow

        return SignUpOtpDeliveryGuard.call(
          flow: flow, channel: :telephone, contact_ref: binding.contact_ref,
          counter: binding.counter, destination: payload.fetch(:to),
        ) { OutboundSms.deliver_now(**payload.slice(:to, :title, :body)) }
      end
      OutboundSms.deliver_now(**payload.slice(:to, :title, :body))
    end

    private

    def deliver_current_registration_otp(payload)
      binding = ContactRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: payload.fetch(:otp_binding))
      transaction_class =
        (binding.surface == "app") ? ClientTelephoneCeremonyTransaction : VisitorTelephoneCeremonyTransaction
      transaction = transaction_class.find_by(transaction_id: binding.flow_ref)
      return unless transaction

      ContactRegistrationOtpDeliveryIssuer.call(
        transaction: transaction, contact_ref: binding.contact_ref, counter: binding.counter,
        destination: payload.fetch(:to), message_body: payload.fetch(:body),
      ) { OutboundSms.deliver_now(**payload.slice(:to, :title, :body)) }
    end

    # Existing encrypted-body jobs may remain in a deployed queue during rollout.
    # New producers only enqueue the versioned full-payload envelope.
    def delivery_payload(encrypted_payload:, to:, title:, encrypted_body:, body:)
      if encrypted_payload.present?
        if [to, title, encrypted_body, body].any?(&:present?)
          raise ArgumentError, "Mixed SMS job payload formats are not accepted"
        end

        return OutboundSensitivePayload.decrypt_sms_delivery(encrypted_payload)
      end

      raise ArgumentError, "Plaintext SMS job payload is no longer accepted" if body.present?
      raise ArgumentError, "Incomplete legacy SMS job payload" if to.blank? || title.blank? || encrypted_body.blank?

      { to:, title:, body: OutboundSensitivePayload.decrypt_sms_body(encrypted_body) }
    end
  end
end
