class BucketsController < ApplicationController
  before_action :find_user

  def index
    @buckets = Bucket.all
  end

  def create
    @bucket = Bucket.create!(name: params[:bucket_name], user: @user)
  end

  def show
    @bucket = Bucket.find_by(name: params[:bucket_name])

    unless @bucket
      @error = Error.create(code: 'NoSuchBucket', resource: params[:bucket_name],
                            message: 'The resource you requested does not exist')
      render @error
    end
  end

  def destroy
    @bucket = Bucket.find_by(name: params[:bucket_name])

    if @bucket && @bucket.s3_objects.blank?
      @bucket.destroy

      head :no_content
    elsif @bucket
      render Error.create(code: 'BucketNotEmpty',
                          message: 'The bucket you tried to delete is not empty.',
                          resource: 'bucket'), status: :unprocessable_entity
    else
      @error = Error.create(code: 'NoSuchBucket', resource: params[:bucket_name],
                            message: 'The resource you requested does not exist')
      render @error
    end
  end

  private

  def find_user
    @user = User.create!
  end
end
