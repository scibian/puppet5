require 'spec_helper'

# Note that this should run after agent.example.com's certificate has been generated
curl_cmd = 'curl --cert /var/lib/puppet/ssl/certs/agent.example.com.pem --key /var/lib/puppet/ssl/private_keys/agent.example.com.pem --cacert /var/lib/puppet/ssl/certs/ca.pem'

describe command("#{curl_cmd} https://puppet:8140/production/status/test") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /is_alive/ }
end

describe command("#{curl_cmd} https://puppet:8140/production/node/agent.example.com") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /"environment":\s*"production"/ }
end

describe command("#{curl_cmd} https://puppet:8140/production/catalog/agent.example.com") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /catalog_uuid/ }
end

describe command("#{curl_cmd} https://puppet:8140/production/certificate/agent.example.com") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /END CERTIFICATE/ }
end
