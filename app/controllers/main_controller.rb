class MainController < ApplicationController
  protect_from_forgery with: :null_session, only: [:properties]
  def index
    reset_session
  end

  def callback
    # Running in Authorization Code mode.  
    # Start the code flow using the provider's token_endpoint
    if cookies['issuer'] && params[:code]
      discover_provider(cookies['issuer'])

      # swap code for access/refresh/id token
      authorization_code_flow

      # Use the access token to get claims from userinfo endpoint
      userinfo_call

      # Use the access token to get some properties
      @properties = spark_properties_call

      # Exchange our ID Token for Amazon Cognito Credentials
      credentials = amazon_exchange(session[:encoded_id_token], @provider_info.issuer)

      @dynamo_properties = dynamo_data(credentials)
    end
  end

  def properties
    render :json => spark_properties_call 
  end

  # Display a partial diagram for AJAX calls
  def diagram
  end

  private

  def discover_provider(issuer)
    @provider_info = OpenIDConnect::Discovery::Provider::Config.discover!(issuer)
    logger.debug "issuer discovery #{issuer} => #{@provider_info.inspect}"
  end

  # Perform the authorization code token exchange with the
  # OIDC Provider's token endpoint
  def authorization_code_flow
    key_info = KEY_CONFIG[ @provider_info.issuer ]
    logger.debug "key info: #{key_info.inspect}"
    # Hit the token endpoint and save the returned access/refresh/id tokens
    tokens = token_call(
      token_endpoint: @provider_info.token_endpoint,
      client_id: key_info['client_id'],
      client_secret: key_info['client_secret'],
      code: params[:code],
      redirect_uri: key_info['redirect_uri']
    )
    logger.debug "tokens: #{tokens.inspect}"
    return nil if ! tokens
    session[:encoded_id_token] = tokens[:id_token]
    session[:id_token] = decode_id_token(tokens[:id_token])
    session[:access_token] = tokens[:access_token]
    session[:refresh_token] = tokens[:refresh_token]
    session[:expires_in] = tokens[:expires_in].to_i

  end

  # Make a call to the specified userinfo endpoint and
  # return a nested hash of claims
  def userinfo_call
    c = Curl::Easy.new(@provider_info.userinfo_endpoint)
    c.resolve_mode = :ipv4
    c.headers = { authorization: "Bearer #{session[:access_token]}" }
    c.perform
    if c.body_str
      body_pretty = JSON.pretty_generate( JSON.parse( c.body_str ) )
      if c.response_code != 200
        session[:userinfo] = "Error #{c.response_code}:\n#{body_pretty}"
      else
        session[:userinfo] = body_pretty
      end
      logger.debug "userinfo: #{session[:userinfo].inspect}"
    end
  end

  # Make a call to the specified token endpoint
  # return hash with access/refresh/id tokens
  def token_call(options={})
    c = Curl::Easy.new(options[:token_endpoint])
    c.resolve_mode = :ipv4
    qs = URI.decode({
      grant_type: "authorization_code",
      client_id: options[:client_id],
      client_secret: options[:client_secret],
      code: options[:code],
      redirect_uri: options[:redirect_uri]
    }.to_query)
    logger.debug "token call query string: #{qs}"
    c.http_post(qs)
    if c.response_code != 200
      logger.error "token call Response code from #{options[:token_endpoint]} is #{c.response_code}"
      logger.error "body: #{c.body_str}"
      return nil
    end
    if c.body_str
      obj = JSON.parse(c.body_str)
      obj.symbolize_keys!
      return obj
    end
  end

  # Take an encoded ID Token, decode & verify it, and return
  # JSON text of the claims
  def decode_id_token(id_token)
    e = nil
    # Iterate all of the provider's public keys and try them until success
    @provider_info.public_keys.each do |key|
      begin
        id_obj = OpenIDConnect::ResponseObject::IdToken.decode id_token, key
        if id_obj.valid?
          return JSON.pretty_generate(JSON.parse(id_obj.to_json))
        end
      rescue => e
        logger.info "Invalid ID Token: #{e.message}"
      end
    end
    raise e if e
  end

  # Using the Spark API gem, grab some properties
  def spark_properties_call
    begin
      access_token = params[:access_token] || session[:access_token]
      if access_token
        expires = (session[:expires_in] || params[:expires_in] || 3600).to_i
        logger.debug "spark_properties_call using access token #{access_token} and expiration #{expires}"
        SparkApi.client.session = SparkApi::Authentication::OAuthSession.new(
          "access_token"=> access_token, 
          "expires_in" => expires)
      # An authorization code flow was given
      elsif params[:code]
        logger.debug "spark_properties_call using code #{params[:code]}"
        SparkApi.client.oauth2_provider.code = params[:code]
        SparkApi.client.authenticate
      else
        SparkApi.client.session = nil
        return '{error: "Spark API unauthenticated"}'
      end
      listings = SparkApi.client.get("/listings", _limit: 2).results
      compacted = listings.compact_recursive
      return JSON.pretty_generate(JSON.parse(compacted.to_json))
    rescue => e
      logger.error "Spark Properties: #{e.message} #{e.backtrace.join("\n")}"
      if e.message == "To be implemented by client application"
        return "{error: \"The token you provided is invalid.  A new authorization is required.\"}"
      else
        return "{error: \"#{e.message}\"}"
      end
    end
  end


  # Given an ID Token for an issuer URL, exchange it for
  # an Amazon Cognito  Aws::Credentials object
  def amazon_exchange(id_token, issuer)
    # Fix up the issuer to what Amazon requires for its Logins map
    logins = { issuer.sub(/^https?:\/\//, '') => id_token }

    # Init the Cognito client using our account's client/secret pair
    client = Aws::CognitoIdentity::Client.new( access_key_id: AWS_KEYS['access_key_id'],
                                              secret_access_key: AWS_KEYS['secret_access_key'],
                                              region: AWS_KEYS['region'])

    # Exchange our ID Token for a transient identity ID
    transient_id = client.get_id(identity_pool_id: AWS_KEYS['identity_pool_id'],
                                 logins: logins)

    logger.debug "AWS transient_id: #{transient_id.inspect}"

    # NOTE:  We can also get an Amazon OpenID Token by saying:
    # client.get_open_id_token(identity_id: transient_id.identity_id, logins: logins)

    # Since we don't require an ID Token to hit AWS services, we'll instead
    # exchange the transient identity for Aws::Credentials
    id_creds = client.get_credentials_for_identity(identity_id: transient_id.identity_id,
                                                   logins: logins)

    logger.debug "AWS id_creds: #{id_creds.inspect}"

    creds = Aws::Credentials.new( id_creds.credentials.access_key_id, 
                                 id_creds.credentials.secret_key,
                                 id_creds.credentials.session_token)

    logger.debug "AWS creds: #{creds.inspect}"
    return creds
  end

  # Given an Amazon Aws::Credentials object, scan the 
  # Properties table and return some data!
  def dynamo_data(creds)
    dynamo = Aws::DynamoDB::Client.new(region: AWS_KEYS['region'],
                                       credentials: creds)
    data = dynamo.scan(table_name: "Properties")
    items = JSON.pretty_generate( data.items )
    return items
  end
end
