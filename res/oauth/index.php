<?php

use fkooman\OAuth\Client\Api;
use fkooman\OAuth\Client\Context;
use fkooman\OAuth\Client\ClientConfig;
use fkooman\OAuth\Client\SessionStorage;
use fkooman\OAuth\Client\Scope;

use Guzzle\Http\Client;
use fkooman\Guzzle\Plugin\BearerAuth\BearerAuth;
use fkooman\Guzzle\Plugin\BearerAuth\Exception\BearerErrorResponseException;

require_once '{INSTALL_DIR}/php-simple-auth/lib/SimpleAuth.php';
require_once 'vendor/autoload.php';

$guzzleConfig = array("ssl.certificate_authority" => {ENABLE_CERTIFICATE_CHECK});

try {
    // first we login to this app...
    $auth = new SimpleAuth();
    $userId = $auth->authenticate();

    /* OAuth client configuration */
    $clientConfig = new ClientConfig(
        array(
            "authorize_endpoint" => "{BASE_URL}/php-oauth/authorize.php",
            "client_id" => "demo-oauth-app",
            "client_secret" => "foobar",
            "token_endpoint" => "{BASE_URL}/php-oauth/token.php",
        )
    );

    /* the OAuth 2.0 protected URI */
    $apiUri = "{BASE_URL}/php-oauth/api.php/authorizations/";

    /* initialize the API */
    $api = new Api("demo-oauth-app", $clientConfig, new SessionStorage(), new Client('', $guzzleConfig));
    $context = new Context($userId, new Scope("authorizations"));

    /* check if an access token is available */
    $accessToken = $api->getAccessToken($context);
    if (false === $accessToken) {
        /* no valid access token available, go to authorization server */
        header("HTTP/1.1 302 Found");
        header("Location: " . $api->getAuthorizeUri($context));
        exit;
    }

    try {
        $client = new Client('', $guzzleConfig);
        $bearerAuth = new BearerAuth($accessToken->getAccessToken());
        $client->addSubscriber($bearerAuth);
        $response = $client->get($apiUri)->send();

        header("Content-Type: application/json");
        echo $response->getBody();
    } catch (BearerErrorResponseException $e) {
        if ("invalid_token" === $e->getBearerReason()) {
            // the token we used was invalid, possibly revoked, we throw it away
            $api->deleteAccessToken($context);
            $api->deleteRefreshToken($context);

            /* no valid access token available, go to authorization server */
            header("HTTP/1.1 302 Found");
            header("Location: " . $api->getAuthorizeUri($context));
            exit;
        }
        throw $e;
    }

} catch (\Exception $e) {
    echo sprintf("ERROR: %s", $e->getMessage());
}
