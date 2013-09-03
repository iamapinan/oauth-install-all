<?php
$authorizeUri = "{BASE_URL}/php-oauth/authorize.php";
$storageUri = "{BASE_URL}/php-remoteStorage/api.php";

$resource = isset($_GET['resource']) ? $_GET['resource'] : null;
if (null === $resource) {
    header("HTTP/1.1 400 Bad Request");
    header("Content-Type: application/json; charset=UTF-8");
    json_encode(array("error" => "resource missing"));
    exit;
}

if (!is_string($resource) || 0 >= strlen($resource)) {
    header("HTTP/1.1 400 Bad Request");
    header("Content-Type: application/json; charset=UTF-8");
    echo json_encode(array("error" => "resource needs to be non empty string"));
    exit;
}

if (0 !== strpos($resource, "acct:")) {
    header("HTTP/1.1 400 Bad Request");
    header("Content-Type: application/json; charset=UTF-8");
    echo json_encode(array("error" => "requested resource is not an account"));
    exit;
}

$subject = substr($resource, 5);
if (0 >= strlen($subject)) {
    header("HTTP/1.1 400 Bad Request");
    header("Content-Type: application/json; charset=UTF-8");
    echo json_encode(array("error" => "empty resource"));
    exit;
}

$output = array (
    'subject' => sprintf('%s', $resource),
    'links' => array(
        array(
            'href' => sprintf('%s/%s', $storageUri, $subject),
            'rel' => 'remotestorage',
            'type' => 'draft-dejong-remotestorage-01',
            'properties' => array(
                'http://tools.ietf.org/html/rfc6749#section-4.2' => sprintf('%s?x_resource_owner_hint=%s', $authorizeUri, $subject)
            )
        )
    ),
);

header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
echo json_encode($output);
exit;
