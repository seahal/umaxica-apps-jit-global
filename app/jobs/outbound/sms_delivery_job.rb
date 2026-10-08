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

    def perform(encrypted_payload: nil)
      payload = OutboundSensitivePayload.decrypt_sms_delivery(encrypted_payload)
      if payload.key?(:otp_binding)
        case payload.fetch(:otp_binding)[1]
        when "credential_registration" then return deliver_current_registration_otp(payload)
        when "sign_up" then return deliver_current_signup_otp(payload)
        else raise ArgumentError, "unsupported bound SMS purpose"
        end
      end
      OutboundSms.deliver_now(**payload.slice(:to, :title, :body))
    end

    private

    def deliver_current_signup_otp(payload)
      binding = TelephoneSignUpOtpDeliveryBindingValue.for_sms(otp_binding: payload.fetch(:otp_binding))
      flow_model, telephone_model, transaction_model =
        case binding.surface
        when "app" then [ClientSignUpFlow, ClientTelephone, ClientTelephoneCeremonyTransaction]
        when "com" then [VisitorSignUpFlow, VisitorTelephone, VisitorTelephoneCeremonyTransaction]
        else raise ArgumentError, "unsupported Telephone signup delivery realm"
        end
      flow = flow_model.find_by(public_id: binding.flow_ref)
      transaction = transaction_model.find_by(transaction_id: binding.transaction_ref)
      return false unless flow && transaction

      telephone = telephone_model.find_by(public_id: transaction.telephone_candidate_ref)
      return false unless telephone

      TelephoneSignUpOtpDeliveryGuard.call(
        flow: flow, telephone: telephone, transaction: transaction, generation: binding.generation,
        destination: payload.fetch(:to), code: payload.fetch(:otp_code),
      ) { OutboundSms.deliver_now(**payload.slice(:to, :title, :body)) }
    end

    def deliver_current_registration_otp(payload)
      binding = TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: payload.fetch(:otp_binding))
      transaction_model, telephone_model =
        case binding.surface
        when "app" then [ClientTelephoneCeremonyTransaction, ClientTelephone]
        when "com" then [VisitorTelephoneCeremonyTransaction, VisitorTelephone]
        when "org" then [OperatorTelephoneCeremonyTransaction, OperatorTelephone]
        else raise ArgumentError, "unsupported Telephone registration delivery realm"
        end
      transaction = transaction_model.find_by(transaction_id: binding.transaction_ref)
      telephone =
        if binding.surface == "org"
          telephone_model.find_by(id: binding.candidate_ref)
        else
          telephone_model.find_by(public_id: binding.candidate_ref)
        end
      return false unless transaction && telephone

      TelephoneCredentialRegistrationOtpDeliveryGuard.call(
        transaction: transaction, telephone: telephone, generation: binding.generation,
        destination: payload.fetch(:to), code: payload.fetch(:otp_code),
      ) { OutboundSms.deliver_now(**payload.slice(:to, :title, :body)) }
    end
  end
end
