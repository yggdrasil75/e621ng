require 'securerandom'

class ExceptionLog < ApplicationRecord
  serialize :extra_params, JSON

  def self.add(exception, user_id, request)
    extra_params = {
      host: Socket.gethostname,
      params: request.filtered_parameters,
      user_id: user_id,
      referrer: request.referrer,
      user_agent: request.user_agent
    }

    # Required to unwrap exceptions that occur inside template rendering.
    unwrapped_exception = exception
    if exception.is_a?(ActionView::Template::Error)
      unwrapped_exception = exception.cause
    end

    if unwrapped_exception.is_a?(ActiveRecord::QueryCanceled)
      extra_params[:sql] = {}
      extra_params[:sql][:query] = unwrapped_exception&.sql || "[NOT FOUND?]"
      extra_params[:sql][:binds] = unwrapped_exception&.binds
    end

    create!(
      ip_addr: request.remote_ip || "0.0.0.0",
      class_name: unwrapped_exception.class.name,
      message: unwrapped_exception.message,
      trace: unwrapped_exception.backtrace.join("\n"),
      code: SecureRandom.uuid,
      version: Rails.application.config.x.git_hash,
      extra_params: extra_params,
    )
  end

  def user
    User.find_by(id: extra_params["user_id"])
  end
end
