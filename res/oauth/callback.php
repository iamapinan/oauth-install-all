<?php

use fkooman\OAuth\Client\ClientConfig;
use fkooman\OAuth\Client\Callback;
use fkooman\OAuth\Client\AuthorizeException;
use fkooman\OAuth\Client\SessionStorage;
use Guzzle\Http\Client;

require_once 'vendor/autoload.php';

/* OAuth client configuration */
$clientConfig = new ClientConfig(
    array(
        "authorize_endpoint" => "{BASE_URL}/php-oauth/authorize.php",
        "client_id" => "demo-oauth-app",
        "client_secret" => "foobar",
        "token_endpoint" => "{BASE_URL}/php-oauth/token.php",
    )
);

try {
    $cb = new Callback("demo-oauth-app", $clientConfig, new SessionStorage(), new Client());
    $cb->handleCallback($_GET);

    header("HTTP/1.1 302 Found");
    header("Location: {BASE_URL}/demo-oauth-app/index.php");
} catch (AuthorizeException $e) {
    // this exception is thrown by Callback when the OAuth server returns a 
    // specific error message for the client, e.g.: the user did not authorize 
    // the request
    echo sprintf("ERROR: %s, DESCRIPTION: %s", $e->getMessage(), $e->getDescription());
} catch (Exception $e) {
    // other error, these should never occur in the normal flow
    echo sprintf("ERROR: %s", $e->getMessage());
}
