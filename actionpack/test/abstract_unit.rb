$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../../activesupport/lib')
$:.unshift(File.dirname(__FILE__) + '/fixtures/helpers')
$:.unshift(File.dirname(__FILE__) + '/fixtures/alternate_helpers')

require 'rubygems'
require 'yaml'
require 'stringio'
require 'test/unit'

gem 'mocha', '>= 0.9.7'
require 'mocha'

begin
  require 'ruby-debug'
  Debugger.settings[:autoeval] = true
  Debugger.start
rescue LoadError
  # Debugging disabled. `gem install ruby-debug` to enable.
end

require 'action_controller'
require 'action_controller/cgi_ext'
require 'action_controller/test_process'
require 'action_view/test_case'

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

ActionController::Base.logger = nil
ActionController::Routing::Routes.reload rescue nil

ActionController::Base.session_store = nil

# Register danish language for testing
I18n.backend.store_translations 'da', {}
I18n.backend.store_translations 'pt-BR', {}
ORIGINAL_LOCALES = I18n.available_locales.map(&:to_s).sort

FIXTURE_LOAD_PATH = File.join(File.dirname(__FILE__), 'fixtures')
ActionView::Base.cache_template_loading = true
ActionController::Base.view_paths = FIXTURE_LOAD_PATH
CACHED_VIEW_PATHS = ActionView::Base.cache_template_loading? ?
                      ActionController::Base.view_paths :
                      ActionController::Base.view_paths.map {|path| ActionView::Template::EagerPath.new(path.to_s)}

class DummyMutex
  def lock
    @locked = true
  end

  def unlock
    @locked = false
  end

  def locked?
    @locked
  end
end

class ActionController::IntegrationTest < ActiveSupport::TestCase
  def with_autoload_path(path)
    path = File.join(File.dirname(__FILE__), "fixtures", path)  
    if ActiveSupport::Dependencies.autoload_paths.include?(path)
      yield
    else
      begin
        ActiveSupport::Dependencies.autoload_paths << path
        yield
      ensure
        ActiveSupport::Dependencies.autoload_paths.reject! {|p| p == path}
        ActiveSupport::Dependencies.clear
      end              
    end
  end
end

module RailsXssEmulation
  module ContentTag
    def self.included(by)
      by.alias_method_chain :content_tag_string, :escaping
    end

    private

    def content_tag_string_with_escaping(name, content, options, escape = true)
      content_tag_string_without_escaping(name, escape ? ERB::Util.h(content) : content, options, escape)
    end

  end

  class InstanceTagWithRailsXss < ActionView::Helpers::InstanceTag
    include RailsXssEmulation::ContentTag
  end

end

ActionController::Reloader.default_lock = DummyMutex.new
