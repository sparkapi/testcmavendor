# TestCMAVendor
Rails app that runs the TestCMAVendor.com OpenID Connect federated sample app

## Federated OpenID Connect Relying Party Walkthrough

A few files are noteworthy in checking out for wring your own RP application:

* [Main Controller](https://github.com/sparkapi/testcmavendor/blob/master/app/controllers/main_controller.rb) -- Authorization Code flow happens here
* [Index View](https://github.com/sparkapi/testcmavendor/blob/master/app/views/main/index.html.erb) -- Sets up the log in event for a chosen OIDC Provider
* [Callback View](https://github.com/sparkapi/testcmavendor/blob/master/app/views/main/callback.html.erb) -- The callback for OIDC.  This has two separate views.  One using the javascript lib for Implicit and Hybrid flows, and one displaying server-side controller variables when using Authorization Code
* [aws_keys.yml](https://github.com/sparkapi/testcmavendor/blob/master/config/aws_keys.yml.sample) -- A sample config file to add your AWS API keys.  These are used during the Authorization Code flow to exchange an ID Token for another ID Token+Access Token server side, using Amazon Cognito.  (Note that Implicit/Hybrid flows do not use this, that happens in javascript)





