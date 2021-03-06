# frozen_string_literal: true

require "carat/ssl_certs/certificate_manager"

RSpec.describe "SSL Certificates", :rubygems_master do
  hosts = %w[
    rubygems.org
    index.rubygems.org
    rubygems.global.ssl.fastly.net
    staging.rubygems.org
  ]

  hosts.each do |host|
    it "can securely connect to #{host}", :realworld do
      Carat::SSLCerts::CertificateManager.new.connect_to(host)
    end
  end
end
