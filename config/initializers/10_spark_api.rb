SparkApi.configure do |config|
  config.authentication_mode = SparkApi::Authentication::OAuth2
  config.api_key      = KEY_CONFIG["https://openidp.fbsdata.com"]["client_id"]
  config.api_secret   = KEY_CONFIG["https://openidp.fbsdata.com"]["client_secret"]
  config.callback     = KEY_CONFIG["https://openidp.fbsdata.com"]["redirect_uri"]
  config.auth_endpoint = "https://dev.sparkplatform.com/oauth2"
  config.endpoint   = 'https://api.dev.fbsdata.com'
  config.ssl_verify = false
end
