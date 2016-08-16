require 'helper'

class GoogleCloudStorageOutputTest < Test::Unit::TestCase
    
    def setup
      Fluent::Test.setup
    end
    
  CONFIG = %[
hostname localhost
path log-${tag}/%Y/%m/%d/%H/${hostname}-${chunk_id}.log.gz
bucket_id test_bucket
buffer_path /hdfs/path/aaa.log
private_key_path /hdfs/path/aaa.key
email aaa@aaa.com
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::OutputTestDriver.new(Fluent::GoogleCloudStorageOutput, "test").configure(conf)
  end

  def test_configure
    d = create_driver
    p d.instance.hostname
    p d.instance.path
    assert_equal 'log-${tag}/%Y/%m/%d/%H/localhost-${chunk_id}.log.gz', d.instance.path
    assert_equal '%Y%m%d%H', d.instance.time_slice_format
    
    assert_equal true, d.instance.output_include_time
    assert_equal true, d.instance.output_include_tag
    assert_equal 'json', d.instance.output_data_type
    assert_nil d.instance.remove_prefix
    assert_equal 'TAB', d.instance.field_separator
    assert_equal true, d.instance.add_newline
  end

  def test_configure_placeholders
    d = create_driver %[
hostname test.localhost
path log-${tag}/%Y/%m/%d/%H/${hostname}-${chunk_id}.log.gz
bucket_id test_bucket
buffer_path /hdfs/path/aaa.log
private_key_path /hdfs/path/aaa.key
email aaa@aaa.com
]
    assert_equal 'log-${tag}/%Y/%m/%d/%H/test.localhost-${chunk_id}.log.gz', d.instance.path
  end
  

  def test_path_format
    d = create_driver
    assert_equal 'log-${tag}/%Y/%m/%d/%H/localhost-${chunk_id}.log.gz', d.instance.path
    assert_equal '%Y%m%d%H', d.instance.time_slice_format
    assert_equal 'log-${tag}/2012/07/18/01/localhost-${chunk_id}.log.gz', d.instance.path_format('2012071801')

    d = create_driver %[
hostname test.localhost
path log-${tag}/%Y%m%d%H%M/${hostname}-${chunk_id}.log.gz
bucket_id test_bucket
buffer_path /hdfs/path/aaa.log
private_key_path /hdfs/path/aaa.key
time_slice_format %Y%m%d%H%M
email aaa@aaa.com
]
    assert_equal 'log-${tag}/%Y%m%d%H%M/test.localhost-${chunk_id}.log.gz', d.instance.path
    assert_equal '%Y%m%d%H%M', d.instance.time_slice_format
    assert_equal 'log-${tag}/201207180103/test.localhost-${chunk_id}.log.gz', d.instance.path_format('201207180103')

    assert_raise Fluent::ConfigError do
      d = create_driver %[
            namenode server.local:14000
            path /hdfs/path/file.%Y%m%d.%H%M.log
            append false
          ]
    end
  end
end
