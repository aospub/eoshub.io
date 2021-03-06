ActiveAdmin.register Order do
  menu priority: 4
  permit_params :state, :eos_account, :public_key
  actions :all, except: [:new, :create, :destroy]

  preserve_default_filters!
  filter :state, as: :select, collection: Order.states.map { |k, v| [k, v] }
  filter :pgcode, as: :select, collection: Order.pgcodes.map { |k, v| [k, v] }
  remove_filter :user, :amount, :product_name, :account_name, :bank_code, :expire_date, :return_code, :return_message, :tid, :payment_results

  index do
    selectable_column
    id_column
    column :order_no
    column :eos_account
    state_column :state
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :order_no
      row :eos_account
      state_row :state
      tag_row :pgcode
      row :product_name
      row :public_key
      row :tid
      row :return_code
      row :return_message
      row :created_at
      row :updated_at
    end

    panel '가상계좌 정보' do
      table_for order do
        column :account_name
        column :account_no
        column :bank_code
        column :bank_name
        column :expire_date
      end
    end

    panel '결제 내역' do
      paginated_collection(order.payment_results.page(params[:payment_results_page]).per(15), param_name: 'payment_results_page', download_links: false) do
        table_for collection do
          column I18n.t('activerecord.attributes.attribute_commons.id') do |payment_result|
            link_to payment_result.id, admin_payment_result_path(payment_result)
          end
          column :cid
          column :tid
          column :pay_info
          column :transaction_date
          column :code
          column :message
        end
      end
    end

    active_admin_comments
  end

  action_item :create_eos_account_btn, only: :show do
    link_to '계정 생성', create_eos_account_order_path(resource.order_no), method: :post if resource.paid?
  end

  form do |f|
    f.inputs do
      f.input :state
      f.input :eos_account
      f.input :public_key
    end
    f.actions
  end
end
