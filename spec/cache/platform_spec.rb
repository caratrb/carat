# frozen_string_literal: true

RSpec.describe "carat cache with multiple platforms" do
  before :each do
    gemfile <<-G
      source "file://#{gem_repo1}"

      platforms :mri, :rbx do
        gem "rack", "1.0.0"
      end

      platforms :jruby do
        gem "activesupport", "2.3.5"
      end
    G

    lockfile <<-G
      GEM
        remote: file:#{gem_repo1}/
        specs:
          rack (1.0.0)
          activesupport (2.3.5)

      PLATFORMS
        ruby
        java

      DEPENDENCIES
        rack (1.0.0)
        activesupport (2.3.5)
    G

    cache_gems "rack-1.0.0", "activesupport-2.3.5"
  end

  it "ensures that a successful carat install does not delete gems for other platforms" do
    carat! "install"

    expect(carated_app("vendor/cache/rack-1.0.0.gem")).to exist
    expect(carated_app("vendor/cache/activesupport-2.3.5.gem")).to exist
  end

  it "ensures that a successful carat update does not delete gems for other platforms" do
    carat! "update", :all => carat_update_requires_all?

    expect(carated_app("vendor/cache/rack-1.0.0.gem")).to exist
    expect(carated_app("vendor/cache/activesupport-2.3.5.gem")).to exist
  end
end
