# == Schema Information
#
# Table name: orders
#
#  id                                                                 :bigint(8)        not null, primary key
#  account_name(the name of the payer who issued the virtual account) :string
#  account_no(virtual account number)                                 :string           default("")
#  amount                                                             :integer          not null
#  bank_code(Virtual account bank code)                               :string
#  bank_name(Virtual account bank name)                               :string
#  eos_account                                                        :string           default(""), not null
#  expire_date(expiration date of the virtual account)                :date
#  order_no                                                           :string           not null
#  pgcode                                                             :integer          default(NULL), not null
#  product_name                                                       :string           default("")
#  public_key                                                         :string           default(""), not null
#  return_code                                                        :string           default("")
#  return_message                                                     :string           default("")
#  state                                                              :integer          default("created"), not null
#  tid                                                                :string           default("")
#  created_at                                                         :datetime         not null
#  updated_at                                                         :datetime         not null
#
# Indexes
#
#  index_orders_on_eos_account  (eos_account)
#  index_orders_on_order_no     (order_no)
#

require 'test_helper'

class OrderTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
