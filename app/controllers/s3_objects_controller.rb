class S3ObjectsController < ApplicationController
  before_action :find_bucket

  def index
    @s3_objects = @bucket.s3_objects
  end

  def create
    @s3_object = S3Object.find_by(uri: uri) || S3Object.new(bucket: @bucket)
    @s3_object.update_attributes(
      uri: uri, bucket: @bucket,
      key: key, content_type: params[:content_type])
  end

  def show
    binding.pry
    @s3_object = S3Object.find_by(uri: uri)

    if @s3_object && File.exist?(@s3_object.file.path)
      case params[:request_method]
      when 'HEAD'
        response.headers.tap do |hs|
          hs['Content-Type'] = @s3_object.content_type
          hs['Content-Length'] = @s3_object.size.to_s
        end
        head :ok
      when 'GET'
        send_file(@s3_object.file.path,
                  type: @s3_object.content_type, disposition: 'attachment',
                  stream: true, buffer_size: 4096, url_based_filename: false)
      end
    else
      render Error.create(code: 'NoSuchKey', message: 'Thespecified key does not exist',
                          resource: 's3_object'), status: :not_found
    end
  end

  def multipart_completion
    @s3_object = S3Object.find(@params['uploadId'].to_s)
    MultipartCompletion.call(@s3_object, request)
    @s3_object.file.filename = filename

    render @s3_object, status: :ok
  end

  # patch upload
  def part_upload
    @s3_object = S3Object.find(params['uploadId'].to_s)
    PartUpload.call(@s3_object, params[:partNumber])
    @s3_object.save!

    response.headers.tap do |hs|
      hs['ETag'] = @s3_object.md5
    end
    head :ok
  end

  # curl multipart upload
  def multipart_upload
    @s3_object = S3Object.find(params['uploadId'].to_s) || S3Object.new(bucket: @bucket)

    if filename.eql? '${filename}'
      [@uri, @key].each do |v|
        v.sub!('${filename}', file.original_filename)
      end
    else
      file.original_filename = filename
    end

    @s3_object.assign_attributes(
      uri: uri, file: file, bucket: @bucket,
      key: key, content_type: file.content_type,
      size: File.size(file.path), md5: Digest::MD5.file(file.path).hexdigest)

    render @s3_object, status: :created
  end

  def singlepart_upload
    binding.pry
    @s3_object = S3Object.find_by(id: params['uploadId'].to_s) || S3Object.create(
      bucket: @bucket, uri: uri, file: file, key: key, content_type: file.content_type,
      size: File.size(file.path), md5: Digest::MD5.file(file.path).hexdigest)

    response.headers.tap do |hs|
      hs['ETag'] = @s3_object.md5
    end
    head :ok
  end

  def copy
    if @source.blank?
      render :no_content
    else
      src_elts = @source.split('/')
      root_offset = src_elts.first.empty? ? 1 : 0

      src_bucket = src_elts[root_offset]
      src_key = src_elts[(1 + root_offset)..-1].join('/')
      uri = src_bucket + '/' + src_key
      @src_s3_object = S3Object.find_by(uri: uri)
      @s3_object = CopyObject.call(@src_s3_object, filename, @bucket, key)

      render @s3_object, status: :ok
    end
  end

  def multipart_abortion
    @s3_object = S3Object.find_by(uri: @uri)

    @s3_object.destroy if @s3_object
    if Dir.exist?((dir = File.join('tmp', 'multiparts', "s3o_#{params['uploadId']}")))
      FileUtils.rm_r(dir)
    end

    head :no_content
  end

  def destroy
    @s3_object = S3Object.find_by(uri: @uri)
    @s3_object.destroy
    head :no_content
  end

  private

  def find_bucket
    @bucket ||= Bucket.find_by(name: params[:bucket]) || Bucket.create!(name: params[:bucket])
  end

  def source
    @source ||= request.headers['x-amz-copy-source']
  end

  def uri
    path = request.url.gsub!("http://#{request.host}:#{request.port}/", '')
    @uri ||= case
             when params[:format]
               "#{path}.#{params[:format]}"
             when params[:key]
               "#{path}/#{params[:key]}"
             else
               path
             end
  end

  def key
    @key ||= params[:key] || uri.split('/')[1..-1].join('/')
  end

  def filename
    @filename ||= key.split('/').last
  end

  def file
    @file ||= params[:file] || ActionDispatch::Http::UploadedFile.new(
      tempfile: tmpfile,
      filename: filename,
      type: request.content_type || 'application/octet-stream',
      headers: "Content-Disposition: form-data; name=\"file\"; filename=\"noname.txt\"\r\n" \
      "Content-Type: #{request.content_type || 'application/octet-stream'}\r\n"
    )
  end

  def tmpfile
    tmpfile = Tempfile.new(filename)
    tmpfile.binmode
    tmpfile.write(request.body.read)
    tmpfile
  end
end
