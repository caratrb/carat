require "spec_helper"

describe "installing a gem with C extensions" do
  it "installs" do
    build_repo2 do
      build_gem "c_extension" do |s|
        s.extensions = ["ext/extconf.rb"]
        s.write "ext/extconf.rb", <<-E
          require "mkmf"
          name = "c_extension_bundle"
          dir_config(name)
          raise "OMG" unless with_config("c_extension") == "hello"
          create_makefile(name)
        E

        s.write "ext/c_extension.c", <<-C
          #include "ruby.h"

          VALUE c_extension_true(VALUE self) {
            return Qtrue;
          }

          void Init_c_extension_bundle() {
            VALUE c_Extension = rb_define_class("CExtension", rb_cObject);
            rb_define_method(c_Extension, "its_true", c_extension_true, 0);
          }
        C

        s.write "lib/c_extension.rb", <<-C
          require "c_extension_bundle"
        C
      end
    end

    gemfile <<-G
      source "file://#{gem_repo2}"
      gem "c_extension"
    G

    carat "config build.c_extension --with-c_extension=hello"
    carat "install"

    expect(out).not_to include("extconf.rb failed")

    run "Carat.require; puts CExtension.new.its_true"
    expect(out).to eq("true")
  end
end
