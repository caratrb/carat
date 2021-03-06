require "spec_helper"

describe "carat init" do
  it "generates a Gemfile" do
    carat :init
    expect(bundled_app("Gemfile")).to exist
  end

  it "does not change existing Gemfiles" do
    gemfile <<-G
      gem "rails"
    G

    expect {
      carat :init
    }.not_to change { File.read(bundled_app("Gemfile")) }
  end

  it "should generate from an existing gemspec" do
    spec_file = tmp.join('test.gemspec')
    File.open(spec_file, 'w') do |file|
      file << <<-S
        Gem::Specification.new do |s|
        s.name = 'test'
        s.add_dependency 'rack', '= 1.0.1'
        s.add_development_dependency 'rspec', '1.2'
        end
      S
    end

    carat :init, :gemspec => spec_file

    gemfile = bundled_app("Gemfile").read
    expect(gemfile).to match(/source 'https:\/\/rubygems.org'/)
    expect(gemfile.scan(/gem "rack", "= 1.0.1"/).size).to eq(1)
    expect(gemfile.scan(/gem "rspec", "= 1.2"/).size).to eq(1)
    expect(gemfile.scan(/group :development/).size).to eq(1)
  end
end
