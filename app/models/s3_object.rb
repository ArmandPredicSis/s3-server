class S3Object < ActiveRecord::Base
  include ActiveModel::Serializers::Xml
  include S3ObjectManager

  belongs_to :bucket
  mount_uploader :file, FileUploader
end
