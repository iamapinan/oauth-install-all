<?php
    require_once('/Library/WebServer/Documents/oauth/ssp/lib/_autoload.php');
    $as = new SimpleSAML_Auth_Simple('default-sp');
    $as->requireAuth();
    $nameid = $as->getAuthData("saml:sp:NameID");
    $idp = $as->getAuthData("saml:sp:IdP");
    $sessionIndex = $as->getAuthData("saml:sp:SessionIndex");
    $attributes = $as->getAttributes();
    echo "<h1>NameID</h1>";
    echo "<pre>";
    print_r($nameid);
    echo "</pre>";
    echo "<h1>IdP</h1>";
    echo "<pre>";
    print_r($idp);
    echo "</pre>";
    echo "<h1>SessionIndex</h1>";
    echo "<pre>";
    print_r($sessionIndex);
    echo "</pre>";
    echo "<h1>Attributes</h1>";
    echo "<pre>";
    print_r($attributes);
    echo "</pre>";
?>
