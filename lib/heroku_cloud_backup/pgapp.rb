require 'rest-client'
require 'open-uri'

module HerokuCloudBackup
  class PGApp
    def initialize(app_name)
      @app_name = app_name
    end

    def transfers
      http_get "#{@app_name}/transfers"
    end

    def transfers_public_url(id)
      http_post "#{@app_name}/transfers/#{URI.encode(id.to_s)}/actions/public-url"
    end

    private

    def http_get(path)
      checking_client_version do
        retry_on_exception(RestClient::Exception) do
          response = heroku_postgresql_resource[path].get
          display_heroku_warning response
          sym_keys(json_decode(response.to_s))
        end
      end
    end

    def http_post(path, payload = {})
      checking_client_version do
        response = heroku_postgresql_resource[path].post(json_encode(payload))
        display_heroku_warning response
        sym_keys(json_decode(response.to_s))
      end
    end

    def checking_client_version
      begin
        yield
      rescue RestClient::BadRequest => e
        if message = json_decode(e.response.to_s)["upgrade_message"]
          abort(message)
        else
          raise e
        end
      end
    end

    def retry_on_exception(*exceptions)
      retry_count = 0
      begin
        yield
      rescue *exceptions => ex
        raise ex if retry_count >= 3
        sleep 3
        retry_count += 1
        retry
      end
    end

    @headers = { x_heroku_gem_version: "3.43.9" }

    def self.headers
      if ENV['HEROKU_HEADERS']
        @headers.merge! json_decode(ENV['HEROKU_HEADERS'])
      end
      @headers
    end

    def heroku_postgresql_resource
      RestClient::Resource.new(
        "https://#{heroku_postgresql_host}/client/v11/apps",
        user: HerokuCloudBackup::Auth.user,
        password: HerokuCloudBackup::Auth.password,
        headers: self.class.headers
      )
    end

    def json_encode(object)
      JSON.generate(object)
    end

    def json_decode(json)
      JSON.parse(json)
    rescue JSON::ParserError
      nil
    end

    def display_heroku_warning(response)
      warning = response.headers[:x_heroku_warning]
      display warning if warning
      response
    end

    def sym_keys(c)
      if c.is_a?(Array)
        c.map { |e| sym_keys(e) }
      else
        c.inject({}) do |h, (k, v)|
          h[k.to_sym] = v; h
        end
      end
    end

    def heroku_postgresql_host
      if ENV['SHOGUN']
        "shogun-#{ENV['SHOGUN']}.herokuapp.com"
      else
        determine_host(ENV["HEROKU_POSTGRESQL_HOST"], "postgres-api.heroku.com")
      end
    end

    def determine_host(value, default)
      if value.nil?
        default
      else
        "#{value}.herokuapp.com"
      end
    end

    def display(msg="", new_line=true)
      if new_line
        puts(msg)
      else
        print(msg)
      end
      $stdout.flush
    end
  end
end
