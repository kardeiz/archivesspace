require_relative 'factories'

require_relative "../common"
require_relative '../../indexer/app/lib/realtime_indexer'
require_relative '../../indexer/app/lib/periodic_indexer'

$backend_port = TestUtils::free_port_from(3636)
$frontend_port = TestUtils::free_port_from(4545)
$solr_port = TestUtils::free_port_from(2989)
$backend = "http://localhost:#{$backend_port}"
$frontend = "http://localhost:#{$frontend_port}"
$expire = 30000


$backend_start_fn = proc {

  # for the indexers
  AppConfig[:solr_url] = "http://localhost:#{$solr_port}"

  pid = TestUtils::start_backend($backend_port,
                           {
                             :frontend_url => $frontend,
                             :solr_port => $solr_port,
                             :session_expire_after_seconds => $expire,
                             :realtime_index_backlog_ms => 600000
                           })

  AppConfig[:backend_url] = $backend

  pid

}

$frontend_start_fn = proc {
  pid = TestUtils::start_frontend($frontend_port, $backend)

  pid
}

include FactoryGirl::Syntax::Methods

RSpec.configure do |config|

  config.fail_fast = false

  config.expect_with(:rspec) do |c|
    c.syntax = [:should, :expect]
  end

  config.include BackendClientMethods
  config.include JSTreeHelperMethods
  config.include FactoryGirl::Syntax::Methods
  config.extend RSpecClassHelpers
  config.verbose_retry = true

  config.before(:suite) do
    selenium_init($backend_start_fn, $frontend_start_fn)
    $admin = BackendClientMethods::ASpaceUser.new('admin', 'admin')
    SeleniumFactories.init
    # runs indexers in the same thread as the tests if necessary
    if !ENV['ASPACE_INDEXER_URL']
      $indexer = RealtimeIndexer.new($backend, nil)
      $period = PeriodicIndexer.new
    end
  end

  config.after(:suite) do
    report_sleep
    cleanup
  end
  
  config.before(:all) do
    %w{ csv pdf xml }.each do |f|
      file = "*.#{f}"
      cmd = "rm #{ File.join(Dir.tmpdir, file) }"
      %x{ #{cmd} }
    end
  end

  if ENV['ASPACE_TEST_WITH_PRY']
    require 'pry'
    config.around(:each) do |example|
      example.run
      if example.exception
        puts "FAILED: #{example.exception}"
        binding.pry
      end
    end
  end

end
