module S3ObjectManager
  extend ActiveSupport::Concern

  included do
    before_destroy { self.file.delete }
  end
end
