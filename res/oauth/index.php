<?php

use fkooman\OAuth\Client\Api;
use fkooman\OAuth\Client\Context;
use fkooman\OAuth\Client\ClientConfig;
use fkooman\OAuth\Client\SessionStorage;
use fkooman\OAuth\Client\PdoStorage;
use fkooman\OAuth\Client\Scope;

use Guzzle\Http\Client;
use Guzzle\Plugin\Log\LogPlugin;
use Guzzle\Log\MessageFormatter;
use Guzzle\Log\MonologLogAdapter;

use fkooman\Guzzle\Plugin\BearerAuth\BearerAuth;
use fkooman\Guzzle\Plugin\BearerAuth\Exception\BearerErrorResponseException;

use Monolog\Logger;
use Monolog\Handler\StreamHandler;

require_once '{INSTALL_DIR}/php-simple-auth/lib/SimpleAuth.php';
require_once 'vendor/autoload.php';

/* if the SSL certificate check should not be performed, set this to false */
$guzzleConfig = array("ssl.certificate_authority" => {ENABLE_CERTIFICATE_CHECK});

try {
    /* first we login to this app... */
    $auth = new SimpleAuth();
    $userId = $auth->authenticate();

    $db = new PDO(sprintf("sqlite:%s/data/client.sqlite", __DIR__));
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $tokenStorage = new PdoStorage($db);
    //$tokenStorage = new SessionStorage();

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

    /* create the log channel */
    $log = new Logger('client-api');
    $log->pushHandler(new StreamHandler(sprintf("%s/data/client.log", __DIR__), Logger::DEBUG));
    $logPlugin = new LogPlugin(new MonologLogAdapter($log), MessageFormatter::DEBUG_FORMAT);

    $httpClient = new Client();
    $httpClient->setConfig($guzzleConfig);
    $httpClient->addSubscriber($logPlugin);

    /* initialize the API */
    $api = new Api("demo-oauth-app", $clientConfig, $tokenStorage, $httpClient);
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
            /* the token we used was invalid, possibly revoked, we throw it
               away */
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
