class ApplicationController < ActionController::Base
  include Rescuable

  protect_from_forgery with: :exception

  # PATCH admin/products as JSON
  skip_before_action :verify_authenticity_token, if: -> { admin_update? }

  before_action :set_locale

  rescue_from StandardError, with: :unexpected_error

  rescue_from ActiveRecord::RecordNotFound, with: :object_not_found

  rescue_from ActionController::ParameterMissing, with: :parameter_missing

  rescue_from ArgumentError, with: :parameter_missing

  rescue_from Exceptions::DefaultError, with: :render_default_error

  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity

  def access_denied(exception)
    flash[:warning] = exception.message
    return redirect_to new_admin_user_session_path if current_admin_user.nil?
    return redirect_to new_admin_user_confirmation_path unless current_admin_user.confirmed?
    redirect_back(fallback_location: admin_root_path)
  end

  def after_sign_out_path_for(resource_or_scope)
    if resource_or_scope == :admin_user
      new_admin_user_session_path
    else
      root_path
    end
  end

  private

  def admin_update?
    v = controller_path.split(/\//)&.dig(0) == 'admin' 
    v &&= (controller_name == 'products' || controller_name == 'announcements')
    v &&= action_name == 'update' 
    v &&= request.format.json?
    v
  end
end
