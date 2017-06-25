require 'securerandom'
require 'json'
require 'redis'

# === usage
#
# Create an initializer (like +config/initializers/session_store.rb+) with
# content
#
#   require 'cookieless_redis_store'
#   Rails.application.config.middleware.use CookielessRedisStore,
#     redis: {database: 0}, expire_after: 1.month
#
# See {#initialize} for possible parameters.
class CookielessRedisStore < ActionDispatch::Session::AbstractStore
  REDIS_OPTION_KEYS = %i(
    url host port path timeout connect_timeout password db driver tcp_keepalive
    reconnect_attempts
  ).freeze
  FORCE_OPTIONS = {
    defer: true,
    skip: false,
    renew: false,
    cookie_only: false
  }.freeze

  # @param extractor [SessionIdExtractor]
  #   called to extract the session idenfifier from a request
  # @param redis [Hash]
  #   Redis options filtered by {REDIS_OPTION_KEYS}. See
  #   {http://www.rubydoc.info/gems/redis/Redis:initialize documentation for Redis}.
  # @param on_error [ErrorResolver]
  # @param options [Hash]
  #   other options shared among session stores, overriden by {FORCE_OPTIONS}
  def initialize(app, extractor: SessionIdExtractor::DEFAULT, redis: {},
                 on_error: proc {}, **options)
    @redis = Redis.new(redis.slice(*REDIS_OPTION_KEYS))

    if extractor.respond_to?(:call)
      @extractor = extractor
    else
      raise ArgumentError, 'extractor is not callable'
    end
    if on_error.respond_to?(:call)
      @on_error = on_error
    else
      raise ArgumentError, 'on_error is not callable'
    end

    super(app, options.merge(FORCE_OPTIONS))
  end

  private def find_session(request, session_id)
    session_id = @extractor.call(request)
    if session_id.nil?
      [new_session_id, {}]
    else
      begin
        session = JSON.parse(@redis.get(session_id) || 'null')
        if session.nil?
          [new_session_id, {}]
        else
          [session_id, session]
        end
      rescue Redis::BaseError, JSON::JSONError => e
        @on_error.call(e, request, session_id)
        [new_session_id, {}]
      end
    end
  end

  private def write_session(request, session_id, session, options)
    @redis.set(session_id, JSON.generate(session), ex: options[:expire_after])
    session_id
  rescue Redis::BaseError => e
    @on_error.call(e, request, session_id, session)
    false
  end

  private def delete_session(request, session_id, options)
    @redis.del(session_id)
    if options[:drop]
      nil
    else
      new_session_id
    end
  rescue Redis::BaseError => e
    @on_error.call(e, request, session_id, session)
    new_session_id
  end

  private def new_session_id
    SecureRandom.base64
  end

  # This module is only used to document some requirements for an object; this
  # is not an actual module for mix-in. See {DEFAULT} for an example that meets
  # the requirements.
  module SessionIdExtractor
    DEFAULT = proc do |request|
      match = request.headers[:authorization]&.match(/Token\s+(\S+)/)&.[](1)
    end

    # Extracts the session identifier from the +request+.
    #
    # @param request [ActionDispatch::Request]
    # @return [String, nil] nil if the session identifier is not found
    def call(request)
      raise NotImplementedError
    end
  end

  # This module is only used to document some requirements for an object; this
  # is not an actual module for mix-in. {Proc} is an example that meets the
  # requirements; it can also be a lambda whose last argument is optional.
  module ErrorResolver
    # Deal with the +exception+.
    #
    # @param exception [JSON::JSONError, Redis::BaseError]
    # @param request [ActionDispatch::Request]
    # @param session_id [String]
    # @param session [Hash, nil]
    def call(exception, request, session_id, session = nil)
      raise NotImplementedError
    end
  end
end
