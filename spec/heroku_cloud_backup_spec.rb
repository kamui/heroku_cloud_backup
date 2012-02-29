# encoding: utf-8

require 'minitest/autorun'
require "heroku_cloud_backup"

class MiniTest::Spec
  class << self
    alias :context :describe
  end
end

describe HerokuCloudBackup do
  before(:each) do
    Fog.mock!
  end

  context ".client" do
    it "should return an instance of PGBackups::Client" do
      ENV['PGBACKUPS_URL'] = "http://example.com"
      HerokuCloudBackup.client.must_be_instance_of PGBackups::Client
    end
  end

  context ".connection" do
    before(:each) do
      ENV['HCB_KEY1'] = ENV['HCB_KEY2'] = 'testcredentials'
    end

    after(:each) do
      HerokuCloudBackup.connection = nil
    end

    %w(aws rackspace google).each do |provider|
      context "with HCB_PROVIDER=#{provider}" do
        let(:connection) do
          ENV['HCB_PROVIDER'] = provider
          HerokuCloudBackup.connection
        end

        it "should return a valid storage object if provider is #{provider}" do
          connection.wont_be_nil
        end

        it "should return a storage object matching the provider" do
          connection.class.name.must_match(/^Fog::Storage::#{provider}::/i)
        end
      end
    end

    it "should raise HerokuCloudBackup::Errors::ConnectionError exception if provider is invalid" do
      ENV['HCB_PROVIDER'] = "notsupported"
      lambda { HerokuCloudBackup.connection }.must_raise HerokuCloudBackup::Errors::ConnectionError
    end
  end
end
