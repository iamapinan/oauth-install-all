<?php
    require_once('{INSTALL_DIR}/ssp/lib/_autoload.php');
    $as = new SimpleSAML_Auth_Simple('default-sp');
    $as->requireAuth();
    echo "<h1>NameID</h1>";
    echo "<pre>";
    print_r($as->getAuthData("saml:sp:NameID"));
    echo "</pre>";
    echo "<h1>IdP</h1>";
    echo "<pre>";
    print_r($as->getAuthData("saml:sp:IdP"));
    echo "</pre>";
    echo "<h1>SessionIndex</h1>";
    echo "<pre>";
    print_r($as->getAuthData("saml:sp:SessionIndex"));
    echo "</pre>";
    echo "<h1>Attributes</h1>";
    echo "<pre>";
    print_r($as->getAttributes());
    echo "</pre>";
?>
