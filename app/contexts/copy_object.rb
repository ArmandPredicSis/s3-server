class CopyObject
  def self.call(source, filename, bucket, key)
    CopyObject.new(source, filename, bucket, key).call
  end

  def initialize(source, filename, bucket, key)
    @source, @filename, @bucket, @key = source, filename, @bucket, @key
  end

  def call
    file = File.open(@source.file.path)
    file.filename = @filename
    @s3_object = S3Object.find_by(uri: @params[:s3_object_uri]) || S3Object.new(
        uri: @uri, file: file, bucket: @bucket, key: @key, content_type: @source.content_type,
        size: File.size(file.path), md5: Digest::MD5.file(file.path).hexdigest)
  end
end
