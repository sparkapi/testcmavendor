class DeployController < ApplicationController
  protect_from_forgery with: :null_session, only: [:webhook]
  def webhook
    # Super cheesy deployment system... for now
    if params[:ref] == "refs/heads/master" && params[:repository]["name"] == "testcmavendor"
      logger.info `git pull origin master`
      logger.info `bundle install`
      logger.info `touch #{Rails.root}/tmp/restart.txt`
    end
    render json: {}
  end
end
