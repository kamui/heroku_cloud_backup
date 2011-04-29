require 'heroku_cloud_backup'

namespace :heroku do
  desc "Example showing PostgreSQL database backups from Heroku to Amazon S3"
  task :backup => :environment do
    HerokuCloudBackup.run
  end
end