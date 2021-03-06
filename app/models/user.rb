# == Schema Information
#
# Table name: users
#
#  id                       :bigint(8)        not null, primary key
#  confirm_token            :string(22)       default("")
#  confirm_token_created_at :datetime
#  email                    :string
#  eos_account              :string
#  ip_address               :string           default(""), not null
#  state                    :integer          default("email_saved")
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_users_on_confirm_token  (confirm_token)
#  index_users_on_email          (email)
#  index_users_on_eos_account    (eos_account) UNIQUE
#

class User < ApplicationRecord
  include AASM

  has_many :orders

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  before_create :generate_confirm_token

  enum state: {
    email_saved: 0,
    email_confirmed: 1,
    eos_account_created: 2
  }

  aasm column: :state, enum: true do
    state :email_saved, initial: true
    state :email_confirmed, :eos_account_created

    event :email_confirmed do
      transitions from: [:email_saved, :email_confirmed], to: :email_confirmed
    end

    event :eos_account_created, before_transaction: :reset_confirm_token do
      transitions from: :email_confirmed, to: :eos_account_created
    end

    event :reset do
      after do
        UserMailer.email_confirmation(self).deliver
      end
      transitions from: [:email_confirmed, :eos_account_created], to: :email_saved
    end
  end

  class << self
    def has_valid_confirm_token(confirm_token)
      return nil if confirm_token.blank?

      where(confirm_token: confirm_token).where(confirm_token_created_at: (Time.now - 10.minutes)..Time.now).take
    end

    def qualify_for_event(ip_address)
      max = if Rails.env.alpha?
        9999999
      else
        3
      end
      User.eos_account_created.where(ip_address: ip_address).count < max
    end
  end

  def name
    email.split('@').dig(0)
  end

  def regenerate_confirm_token!
    generate_confirm_token
    save!
  end

  private

  def generate_confirm_token
    self.confirm_token = SecureRandom.urlsafe_base64.to_s
    self.confirm_token_created_at = Time.now
  end

  def reset_confirm_token
    self.confirm_token = nil
  end
end
