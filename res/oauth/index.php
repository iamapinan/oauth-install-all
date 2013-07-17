<?php

use fkooman\OAuth\Client\Api;
use fkooman\OAuth\Client\ClientConfig;
use fkooman\OAuth\Client\SessionStorage;
use Guzzle\Http\Client;
use fkooman\Guzzle\Plugin\BearerAuth\BearerAuth;
use fkooman\Guzzle\Plugin\BearerAuth\Exception\BearerErrorResponseException;

require_once '{INSTALL_DIR}/php-simple-auth/lib/SimpleAuth.php';
require_once 'vendor/autoload.php';

try {
    // first we login to this app...
    $auth = new SimpleAuth();
    $userId = $auth->authenticate();

    /* OAuth client configuration */
    $clientConfig = ClientConfig::fromArray(array(
        "authorize_endpoint" => "{BASE_URL}/php-oauth/authorize.php",
        "client_id" => "demo-oauth-app",
        "client_secret" => "foobar",
        "token_endpoint" => "{BASE_URL}/php-oauth/token.php",
    ));

    /* the OAuth 2.0 protected URI */
    $apiUri = "{BASE_URL}/php-oauth/api.php/authorizations/";

    /* initialize the API */
    $api = new Api();
    $api->setClientConfig("demo-oauth-app", $clientConfig);
    $api->setStorage(new SessionStorage());
    $api->setHttpClient(new Client());

    /* the user to bind the tokens to */
    $api->setUserId($userId);

    /* the scope you want to request */
    $api->setScope(array("authorizations"));

    $output = fetchTokenAndData($api, $apiUri);

    header("Content-Type: application/json");
    echo $output;

} catch (\Exception $e) {
    echo sprintf("ERROR: %s", $e->getMessage());
}

function fetchTokenAndData(Api $api, $apiUri)
{
    /* check if an access token is available */
    $accessToken = $api->getAccessToken();
    if (false === $accessToken) {
        /* no valid access token available, go to authorization server */
        header("HTTP/1.1 302 Found");
        header("Location: " . $api->getAuthorizeUri());
        exit;
    }

    /* we have an access token that appears valid */
    try {
        $client = new Client();
        $bearerAuth = new BearerAuth($accessToken->getAccessToken());
        $client->addSubscriber($bearerAuth);
        $response = $client->get($apiUri)->send();

        return $response->getBody();
    } catch (BearerErrorResponseException $e) {
        if ("invalid_token" === $e->getBearerReason()) {
            // the token we used was invalid, possibly revoked, we throw it away
            $api->deleteAccessToken();
            // and try again...
            return fetchTokenAndData($api, $apiUri);
        }
        throw $e;
    }

}
