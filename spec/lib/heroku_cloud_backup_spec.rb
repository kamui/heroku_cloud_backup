require "heroku_cloud_backup"

describe HerokuCloudBackup do
  before(:each) { Fog.mock! }
  
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
        
        it "should return a valid storage connection object" do
          connection.should be
        end

        it "should return a connection object matching the provider" do
          connection.class.to_s.should match(/::#{provider}::/i)
        end
      end
    end
  end
end
