#!/bin/bash

main () {
    # Checks wether zip is installed or in PATH
    if ! [[ $(which zip) ]]
    then
        echo "ERROR: 'zip' not installed or not in PATH. Avorting..."
        exit 1
    fi

    # Does not let 'name' be empty
    while true
    do
        read -rp "Name: " name
        if ! [[ $name == "" ]]
        then
            break
        fi
    done

    read -rp "Expiration (days) [1825]: " expiration
    echo "${expiration:="1825"}" > /dev/null

    easyrsa="/etc/openvpn/easy-rsa/easyrsa"
    cacert="/etc/openvpn/ca.crt"
    takey="/etc/openvpn/ta.key"
    key="/etc/openvpn/easy-rsa/pki/private/$name.key"
    cert="/etc/openvpn/easy-rsa/pki/issued/$name.crt"
    ovpn="/root/$name.ovpn"

    $easyrsa gen-req "$name" nopass
    $easyrsa --days=$expiration sign-req client "$name"

    cp /root/template.ovpn "$ovpn"
    # Yes/No menu
    while true
    do
        echo
        read -rp "Inject keys and certificates (needed for OpenVPN Connect)? (y/n) " opt
        case $opt in
            "y"|"Y"|"yes"|"YES")
            inject
            break
            ;;
            "n"|"N"|"no"|"NO")
            notInject
            break
            ;;
            *)
            echo "ERROR: Invalid option"
            ;;
        esac
    done

    rm "$key" "$cert"
    echo
    echo "WARNING: CERTS and KEYS have been REMOVED from the server"
}

# Creates ovpn file with absolute paths to certs and keys
notInject () {
    keypath="/etc/ssl/private/"
    certpath="/etc/ssl/certs/"
    { 
        echo "ca $keypath$cacert"
        echo "cert $certpath$cert"
        echo "key $keypath$key"
        echo "tls-auth $keypath$takey 1"
    } >> "$ovpn"

    echo
    echo "Store keys in $keypath"
    echo "Store certs in $certpath"

    compress
}

# Injects certs and keys into ovpn file
inject () {
    {
        echo "<ca>"
        cat "$cacert"
        echo "</ca>"
        echo "<cert>"
        cat "$cert"
        echo "</cert>"
        echo "<key>"
        cat "$key"
        echo "</key>"
        echo "<tls-auth>"
        cat "$takey"
        echo "</tls-auth>"
        echo "key-direction 1"
    } >> "$ovpn"

    compress
}

compress () {
    echo -n "Compressing files..."
    zip -q -j "/root/$name.zip" "$cacert" "$cert" "$key" "$takey" "$ovpn"
    echo "Done."
}

main
