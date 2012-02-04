# encoding: utf-8

require 'github_api/configuration'
require 'github_api/connection'
require 'github_api/validation'
require 'github_api/request'
require 'github_api/mime_type'
require 'github_api/core_ext/hash'
require 'github_api/core_ext/array'
require 'github_api/compatibility'
require 'github_api/api/actions'
require 'github_api/api_factory'

module Github

  # @private
  class API
    include Authorization
    include MimeType
    include Connection
    include Request
    include Validation

    attr_reader *Configuration::VALID_OPTIONS_KEYS
    attr_accessor *VALID_API_KEYS

    # Callback to update global configuration options
    class_eval do
      Configuration::VALID_OPTIONS_KEYS.each do |key|
        define_method "#{key}=" do |arg|
          self.instance_variable_set("@#{key}", arg)
          Github.send("#{key}=", arg)
        end
      end
    end

    # Creates new API
    def initialize(options = {}, &block)
      options = Github.options.merge(options)
      Configuration::VALID_OPTIONS_KEYS.each do |key|
        send("#{key}=", options[key])
      end
      _process_basic_auth(options[:basic_auth])
      _set_api_client
      client if client_id? && client_secret?

      self.instance_eval(&block) if block_given?
    end

  private

    # Extract login and password from basic_auth parameter
    def _process_basic_auth(auth)
      case auth
      when String
        self.login    = auth.split(':').first
        self.password = auth.split(':').last
      when Hash
        self.login    = auth[:login]
        self.password = auth[:password]
      end
    end

    # Assigns current api class
    def _set_api_client
      Github.api_client = self
    end

    # Responds to attribute query or attribute clear
    def method_missing(method, *args, &block) # :nodoc:
      case method.to_s
      when /^(.*)\?$/
        return !self.send($1.to_s).nil?
      when /^clear_(.*)$/
        self.send("#{$1.to_s}=", nil)
      else
        super
      end
    end

    def _update_user_repo_params(user_name, repo_name=nil) # :nodoc:
      self.user = user_name || self.user
      self.repo = repo_name || self.repo
    end

    def _merge_user_into_params!(params)  #  :nodoc:
      params.merge!({ 'user' => self.user }) if user?
    end

    def _merge_user_repo_into_params!(params)   #  :nodoc:
      { 'user' => self.user, 'repo' => self.repo }.merge!(params)
    end

    # Turns any keys from nested hashes including nested arrays into strings
    def _normalize_params_keys(params)  #  :nodoc:
      case params
      when Hash
        params.keys.each do |k|
          params[k.to_s] = params.delete(k)
          _normalize_params_keys(params[k.to_s])
        end
      when Array
        params.map! do |el|
          _normalize_params_keys(el)
        end
      else
        params.to_s
      end
      return params
    end

    # Removes any keys from nested hashes that don't match predefiend keys
    def _filter_params_keys(keys, params)  # :nodoc:
      case params
      when Hash
        params.keys.each do |k, v|
          unless (keys.include?(k) or VALID_API_KEYS.include?(k))
            params.delete(k)
          else
            _filter_params_keys(keys, params[k])
          end
        end
      when Array
        params.map! do |el|
          _filter_params_keys(keys, el)
        end
      else
        params
      end
      return params
    end

    def _hash_traverse(hash, &block)
      hash.each do |key, val|
        block.call(key)
        case val
        when Hash
          val.keys.each do |k|
            _hash_traverse(val, &block)
          end
        when Array
          val.each do |item|
            _hash_traverse(item, &block)
          end
        end
      end
      return hash
    end

    def _merge_mime_type(resource, params) # :nodoc:
#       params['resource'] = resource
#       params['mime_type'] = params['mime_type'] || :raw
    end

    # TODO add to core extensions
    def _extract_parameters(array)
      if array.last.is_a?(Hash) && array.last.instance_of?(Hash)
        pop
      else
        {}
      end
    end

    def _token_required
    end

  end # API
end # Github
