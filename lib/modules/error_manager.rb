module ErrorManager
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError do |e|
      render_custom_error(e)
    end
  end

  def render_custom_error(error)
    e = case error
        when ActiveRecord::RecordNotFound
          { error: Error.create(code: 'NoSuchKey', message: 'The specified key does not exist',
                                resource: error.message),
            status: 404 }
        when ActionController::RoutingError
          { error: Error.create(code: 'NotImplemented', message: '', resource: error.message),
            status: 404 }
        else
          { error: Error.create(code: 'Unexpected', message: 'Unexpected error occurred',
                                resource: error.message),
            status: 500 }
        end
    render @error = e[:error], template: 'errors/show', status: e[:status]
  end
end
