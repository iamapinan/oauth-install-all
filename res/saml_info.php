<?php
    require_once('{INSTALL_DIR}/ssp/lib/_autoload.php');
    $as = new SimpleSAML_Auth_Simple('default-sp');
    $as->requireAuth();
    $nameid = $as->getAuthData("saml:sp:NameID");
    $attributes = $as->getAttributes();
    echo "<h1>NameID</h1>";
    echo "<pre>";
    print_r($nameid);
    echo "</pre>";
    echo "<h1>Attributes</h1>";
    echo "<pre>";
    print_r($attributes);
    echo "</pre>";
?>
