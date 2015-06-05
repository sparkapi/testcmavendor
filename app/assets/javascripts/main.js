var switch_flow = function(response_type) {
    var text = "None";
    switch (response_type) {
      case 'id_token':
      case 'id_token token':
        text = "Implicit";
        break;
      case 'code':
        text = "Authorization Code";
        break;
      case 'id_token code token':
      case 'id_token code':
      case 'code token':
        text = "Hybrid";
        break;
      default:
        text = "Invalid Selection"
        break;
    }
    return text;
};
var check_flow = function() {
    var response_type = $(".response_type:checked").map(function() {
      return this.value;
    }).get().join(' ');
    //console.log("response: '" + response_type + "'");
    var flow = switch_flow(response_type);
    $("#flow_text").text(flow);
};
var cleanArray = function(actual){
  var newArray = new Array();
  for(var i = 0; i<actual.length; i++){
    if (actual[i]){
      newArray.push(actual[i]);
    }
  }
  return newArray;
}

/* given id_token, code, and token, return a parameter-like string
 * for use with the diagram ajax call
 */
var tokens2Flow = function(options) {
  var str = cleanArray([ 
    options['id_token'] ? "id_token" : undefined,
    options['code'] ? "code" : undefined,
    options['token'] ? "token" : undefined,
  ]).join(' ');
  switch( switch_flow( str ) ) {
    case "Implicit":
      return 'implicit';
      break;
    case "Authorization Code":
      return "authorization_code";
      break;
    case "Hybrid":
      return "hybrid";
      break;
  }
}

var getExpiresIn = function() {
  var expires_in = window.location.href.match('expires_in=([^&]*)');
  if ( expires_in )
    return expires_in[1];
  return null;
}

$(document).ready(function() {
  check_flow();
  /* Monitor for check changes and update the Flow text
   * to reflect the OAuth2 flow
   */
  $(".response_type").change(function() {
    check_flow();
  });  
});
