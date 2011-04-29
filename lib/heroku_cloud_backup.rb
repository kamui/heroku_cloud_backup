require 'fog'

require 'heroku_cloud_backup/errors'
require 'heroku_cloud_backup/railtie'
require 'heroku_cloud_backup/version'

module HerokuCloudBackup
  class << self
    def create_backup
      @name = "#{ENV['APP_NAME']}-#{Time.now.strftime('%Y-%m-%d-%H%M%S')}.sql"

      db = ENV['DATABASE_URL'].match(/postgres:\/\/([^:]+):([^@]+)@([^\/]+)\/(.+)/)
      if db[3] =~ /amazonaws.com$/
        system "mysqldump --username=#{db[1]} --password=#{db[2]} --host=#{db[3]} --single-transaction #{db[4]} > tmp/#{@name}"
      else
        system "PGPASSWORD=#{db[2]} pg_dump -Fc -i --username=#{db[1]} --host=#{db[3]} #{db[4]} > tmp/#{@name}"
      end

      puts "gzipping sql file..."
      `gzip tmp/#{@name}`
      @backup_filename = "#{@name}.gz"
      @backup_file = "tmp/#{@backup_filename}"
    end

    def run
      puts "[#{Time.now}] heroku:backup started"
      create_backup

      @bucket_name = ENV['hcb_bucket'] || "#{ENV['APP_NAME']}-heroku-backups"
      @backup_path = ENV['hcb_prefix'] || "db"
      @providers = ENV['hcb_providers'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'hcb_providers' config variable."))

      @providers.split(',').each do |provider|
        case provider
          when 'aws'
            @hcb_aws_access_key_id = ENV['hcb_aws_access_key_id'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'hcb_aws_access_key_id' config variable."))
            @hcb_aws_secret_access_key = ENV['hcb_aws_secret_access_key'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'hcb_aws_secret_access_key' config variable."))
            begin
              @connection = Fog::Storage.new(
                :provider => 'AWS',
                :aws_access_key_id => @hcb_aws_access_key_id,
                :aws_secret_access_key => @hcb_aws_secret_access_key
              )
            rescue
              raise HerokuCloudBackup::Errors::ConnectionError.new("There was an error connecting to your provider.")
            end
        else
          raise HerokuCloudBackup::Errors::InvalidProvider.new("One or more of your providers were invalid. Valid values are 'aws', 'rackspace', or 'google'")
        end

        directory = @connection.directories.get(@bucket_name)

        if !directory
          directory = @connection.directories.create(:key => @bucket_name)
        end

        directory.files.create(:key => "#{@backup_path}/#{@backup_filename}", :body => open(@backup_file))
      end

      system "rm #{@backup_file}" if @backup_file

      prune

      puts "[#{Time.now}] heroku:backup complete"
    end

    private

    def prune
      number_of_files = ENV['hcb_max_backups']
      if number_of_files && number_of_files.to_i > 0
        directory = @connection.directories.get(@bucket_name)
        files = directory.files.all(:prefix => @backup_path)
        file_count = 0
        files.reverse.each do |file|
          if file.key =~ Regexp.new("/#{@backup_path}\/#{ENV['APP_NAME']}-\d{4}-\d{2}-\d{2}-\d{6}\.sql\.gz$/i")
            file_count += 1
          else
            next
          end
          if file_count > number_of_files
            file.destroy
          end
        end
      end
    end
  end
end