<?php

use fkooman\OAuth\Client\ClientConfig;
use fkooman\OAuth\Client\Callback;
use fkooman\OAuth\Client\AuthorizeException;
use fkooman\OAuth\Client\SessionStorage;
use fkooman\OAuth\Client\PdoStorage;

use Guzzle\Http\Client;
use Guzzle\Plugin\Log\LogPlugin;
use Guzzle\Log\MessageFormatter;
use Guzzle\Log\MonologLogAdapter;

use Monolog\Logger;
use Monolog\Handler\StreamHandler;

require_once 'vendor/autoload.php';

/* if the SSL certificate check should not be performed, set this to false */
$guzzleConfig = array("ssl.certificate_authority" => {ENABLE_CERTIFICATE_CHECK});

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
    $db = new PDO(sprintf("sqlite:%s/data/client.sqlite", __DIR__));
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $tokenStorage = new PdoStorage($db);
    //$tokenStorage = new SessionStorage();

    /* create the log channel */
    $log = new Logger('client-callback');
    $log->pushHandler(new StreamHandler(sprintf("%s/data/client.log", __DIR__), Logger::DEBUG));
    $logPlugin = new LogPlugin(new MonologLogAdapter($log), MessageFormatter::DEBUG_FORMAT);

    $httpClient = new Client();
    $httpClient->setConfig($guzzleConfig);
    $httpClient->addSubscriber($logPlugin);

    $cb = new Callback("demo-oauth-app", $clientConfig, $tokenStorage, $httpClient);
    $cb->handleCallback($_GET);

    header("HTTP/1.1 302 Found");
    header("Location: {BASE_URL}/demo-oauth-app/index.php");
} catch (AuthorizeException $e) {
    /* this exception is thrown by Callback when the OAuth server returns a
       specific error message for the client, e.g.: the user did not authorize
       the request */
    echo sprintf("ERROR: %s, DESCRIPTION: %s", $e->getMessage(), $e->getDescription());
} catch (Exception $e) {
    /* other error, these should never occur in the normal flow */
    echo sprintf("ERROR: %s", $e->getMessage());
}
