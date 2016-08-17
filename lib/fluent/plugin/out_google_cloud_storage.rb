# -*- coding: utf-8 -*-

require 'fluent/mixin/config_placeholders'
require 'fluent/mixin/plaintextformatter'
require 'fluent/log'
require 'uri'

class Fluent::GoogleCloudStorageOutput < Fluent::TimeSlicedOutput

  Fluent::Plugin.register_output('google_cloud_storage', self)

  include Fluent::Mixin::ConfigPlaceholders

  include Fluent::Mixin::PlainTextFormatter

  config_set_default :buffer_type, 'file'
  config_set_default :time_slice_format, '%Y%m%d%H'
  
  config_param :ignore_start_check_error, :bool, :default => false

  # Available methods are:
  # * private_key -- Use service account credential from pkcs12 private key file
  # * compute_engine -- Use access token available in instances of ComputeEngine
  # * private_json_key -- Use service account credential from JSON key
  # * application_default -- Use application default credential
  config_param :auth_method, :string, default: 'private_key'

  ### Service Account credential
  config_param :email, :string, default: nil
  config_param :private_key_path, :string, default: nil
  config_param :private_key_passphrase, :string, default: 'notasecret', secret: true
  config_param :json_key, default: nil

  ### Save File Params
  config_param :bucket_id, :string
  config_param :path, :string

  config_param :compress, :default => nil do |val|
    unless ["gz", "gzip"].include?(val)
      raise ConfigError, "Unsupported compression algorithm '#{val}'"
    end
    val
  end

  config_param :default_tag, :string, :default => 'tag_missing'

  CHUNK_ID_PLACE_HOLDER = '${chunk_id}'

  def initialize
    super
    require 'zlib'
    require 'net/http'
    require 'time'
    require 'mime-types'
    require 'googleauth'
    require 'google/apis/storage_v1'
    @cached_client_expiration = 0
  end

  # Define `log` method for v0.10.42 or earlier
  unless method_defined?(:log)
    define_method("log") { $log }
  end

  def configure(conf)

    if conf['path']
      if conf['path'].index('%S')
        conf['time_slice_format'] = '%Y%m%d%H%M%S'
      elsif conf['path'].index('%M')
        conf['time_slice_format'] = '%Y%m%d%H%M'
      elsif conf['path'].index('%H')
        conf['time_slice_format'] = '%Y%m%d%H'
      end
    end

    super

    case @auth_method
      when 'private_key'
        unless @email && @private_key_path
          raise Fluent::ConfigError, "'email' and 'private_key_path' must be specified if auth_method == 'private_key'"
        end
      when 'compute_engine'
        # Do nothing
      when 'json_key'
        unless @json_key
          raise Fluent::ConfigError, "'json_key' must be specified if auth_method == 'json_key'"
        end
      when 'application_default'
        # Do nothing
      else
        raise Fluent::ConfigError, "unrecognized 'auth_method': #{@auth_method}"
    end

    if @path.index(CHUNK_ID_PLACE_HOLDER).nil?
      raise Fluent::ConfigError, "path must contain ${chunk_id}, which is the placeholder for chunk_id, when append is set to false."
    end
  end

  def client

    return @client if @client && @cached_client_expiration > Time.now

    @auth_options = {
        private_key_path: @private_key_path,
        private_key_passphrase: @private_key_passphrase,
        email: @email,
        json_key: @json_key,
    }

    @scope = [
        Google::Apis::StorageV1::AUTH_CLOUD_PLATFORM,
        Google::Apis::StorageV1::AUTH_DEVSTORAGE_FULL_CONTROL
    ]
    
    client = Google::Apis::StorageV1::StorageService.new.tap do |c|
      c.authorization = get_auth
      c.authorization.fetch_access_token!
    end

    @cached_client_expiration = Time.now + 1800

    @client = client

  end

  #
  # auth for api client
  # @see https://github.com/kaizenplatform/fluent-plugin-bigquery/blob/master/lib/fluent/plugin/bigquery/writer.rb
  #
  def get_auth
    case @auth_method
      when 'private_key'
        get_auth_from_private_key
      when 'compute_engine'
        get_auth_from_compute_engine
      when 'json_key'
        get_auth_from_json_key
      when 'application_default'
        get_auth_from_application_default
      else
        raise ConfigError, "Unknown auth method: #{@auth_method}"
    end
  end

  def get_auth_from_private_key
    require 'google/api_client/auth/key_utils'
    private_key_path = @auth_options[:private_key_path]
    private_key_passphrase = @auth_options[:private_key_passphrase]
    email = @auth_options[:email]

    key = Google::APIClient::KeyUtils.load_from_pkcs12(private_key_path, private_key_passphrase)
    Signet::OAuth2::Client.new(
        token_credential_uri: "https://accounts.google.com/o/oauth2/token",
        audience: "https://accounts.google.com/o/oauth2/token",
        scope: @scope,
        issuer: email,
        signing_key: key
    )
  end

  def get_auth_from_compute_engine
    Google::Auth::GCECredentials.new
  end

  def get_auth_from_json_key
    json_key = @auth_options[:json_key]

    if File.exist?(json_key)
      File.open(json_key) do |f|
        Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: f, scope: @scope)
      end
    else
      key = StringIO.new(json_key)
      Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: key, scope: @scope)
    end
  end

  def get_auth_from_application_default
    Google::Auth.get_application_default([@scope])
  end

  def start
    super
  end

  def shutdown
    super
  end

  def path_format(chunk_key)
    path = Time.strptime(chunk_key, @time_slice_format).strftime(@path)
    path
  end

  def chunk_unique_id_to_str(unique_id)
    unique_id.unpack('C*').map { |x| x.to_s(16).rjust(2, '0') }.join('')
  end
  
  def _write(path, io, encoding)
    
    begin
      
      client.insert_object(@bucket_id, Google::Apis::StorageV1::Object.new, 
        name: URI.escape(path), 
        content_encoding: encoding, 
        upload_source: io, 
        content_type: "application/json") do |res, err|
        if err
          log.warn err
          @client = nil
        end
      end

    rescue Google::Apis::ServerError, Google::Apis::ClientError, Google::Apis::AuthorizationError => e
      @client = nil
      message = e.message
      log.warn "storage.get API", code: e.status_code, message: message, path: path
    end
    
  end

  def write(chunk)
    
    data = chunk.read
    
    path = path_format(chunk.key).gsub(CHUNK_ID_PLACE_HOLDER, chunk_unique_id_to_str(chunk.unique_id))

    io = nil
    encoding = nil
    if ["gz", "gzip"].include?(@compress)
      io = StringIO.new("")
      writer = Zlib::GzipWriter.new(io)
      writer.write(data)
      writer.finish
      io.rewind
      encoding = "gzip"
    else
      io = StringIO.new(data)
    end
    
    _write(path, io, encoding)
    
  end
end
