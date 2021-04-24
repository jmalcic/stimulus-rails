module Stimulus
  class InstallGenerator < ::Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    class_option :webpacker, type: :boolean, desc: "Install Stimulus for Webpacker",
                             default: const_defined?(:Webpacker)

    def install_stimulus
      return unless webpacker?

      say "Installing Stimulus"
      run "yarn add stimulus"
    end

    def copy_javascripts
      say "Copying Stimulus JavaScript"
      directory "app/assets/javascripts", javascripts_path
      if sprockets?
        remove_file File.join(javascripts_path, "/controllers/index.js")
      else
        remove_file File.join(javascripts_path, "/importmap.json.erb")
        remove_dir File.join(javascripts_path, "/libraries")
      end
    end

    def add_javascripts_to_pipeline
      if sprockets?
        say "Add `app/assets/javascripts` to asset pipeline manifest"
        append_to_file asset_manifest_path, <<~JS
          //= link_tree ../javascripts
        JS
      else
        say "Add Stimulus controllers import to Webpacker entry"
        append_to_file entry_path, <<~JS
          import "controllers"
        JS
      end
    end

    def add_stimulus_include_tags
      return unless sprockets?

      if File.exist?(application_layout_path)
        say "Add Stimulus include tags in application layout"
        insert_into_file application_layout_path, '\1\2<%= stimulus_include_tags %>',
                         before: /(?<=\S)(?<!<%= stimulus_include_tags %>)(\n( {2,3}|\t)*)?<\/head>/
      else
        say "Default application.html.erb is missing!", :red
        print_wrapped "Add <%= stimulus_include_tags %> within the <head> tag in your custom layout.", indent: 8
      end
    end

    def disable_development_debug_mode
      return unless sprockets?

      say "Turn off development debug mode"
      comment_lines development_config_path, /config.assets.debug = true/
    end

    def disable_rack_mini_profiler
      return unless sprockets?

      say "Turn off rack-mini-profiler"
      comment_lines "Gemfile", /rack-mini-profiler/ if File.exist?("Gemfile")
      comment_lines gemspec_path, /rack-mini-profiler/ if File.exist?(gemspec_path)

      say_status :run, "bundle install"
      Gem.bin_path("bundler", "bundle").then do |bin_path|
        require "bundler"
        Bundler.with_original_env { system %Q["#{Gem.ruby}" "#{bin_path}" install] }
      end
    end

    private

    def sprockets?
      !webpacker?
    end

    def webpacker?
      options[:webpacker]
    end

    def engine?
      defined? ENGINE_ROOT
    end

    def javascripts_path
      sprockets? ? "app/assets/javascripts" : Webpacker.config.source_entry_path
    end

    def asset_manifest_path
      File.join("app/assets/config", engine? ? "#{underscored_name}_manifest.js" : "manifest.js")
    end

    def entry_path
      File.join(Webpacker.config.source_entry_path, "application.js")
    end

    def gemspec_path
      "#{engine_name}.gemspec"
    end

    def application_layout_path
      if engine?
        File.join("app/views/layouts", namespaced_name, "application.html.erb")
      else
        "app/views/layouts/application.html.erb"
      end
    end

    def development_config_path
      engine? ? "test/dummy/config/environments/development.rb" : "config/environments/development.rb"
    end

    def engine_name
      File.basename(destination_root)
    end

    def underscored_name
      engine_name.underscore
    end

    def namespaced_name
      engine_name.tr("-", "/")
    end
  end
end
