# frozen_string_literal: true

class ClientRegistrationCompletionMethod < AppZenithRecord
  IDS = { "email" => 1, "telephone" => 2, "google" => 3, "apple" => 4 }.freeze

  has_many :completions, class_name: "ClientRegistrationCompletion", foreign_key: :method_id,
                         inverse_of: :completion_method, dependent: :restrict_with_exception
  validates :key, inclusion: { in: IDS.keys }
  validates :key, length: { maximum: 16 }

  public

  def readonly?
    persisted?
  end
end
