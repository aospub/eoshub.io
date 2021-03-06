class AppStateController < ApplicationController
  include EosAccount

  def index
    announcement = Announcement.where('active = true AND published_at <= NOW() AND ended_at >= NOW()').order("published_at DESC").take
    setting = Setting.order("created_at DESC").take
    event_activation = Product.eos_account.event_activation
    
    render json: {status: 'SUCCESS', data:{announcement:announcement, setting:setting, event_activation:event_activation}}, status: :ok
  end
end
