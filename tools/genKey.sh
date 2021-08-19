#!/bin/bash
SECRET=secretPassword


genCA() {
    echo generate a certificate authority
    openssl genrsa -des3 -out rootCa.key -passout pass:$SECRET 4096
    openssl req -x509 -new -nodes -key rootCa.key -sha256 -days 3650 -subj '/CN=kubeedge' -out rootCa.pem -passin pass:$SECRET
}

genCert() {
    echo generate a cert
    openssl x509 -req -extfile <(printf "subjectAltName=IP:$2") -days 365 -in $1.csr -CA rootCa.pem -CAkey rootCa.key -CAcreateserial -out $1.pem -passin pass:$SECRET
    #openssl x509 -req -in $1.csr -CA rootCa.pem -CAkey rootCa.key -out $1.pem -days 365 -sha256 -passin pass:$SECRET
}

genCSR() {
    echo generate a csr
    openssl genrsa -out $2.key 4096
    openssl req -new -key $2.key -subj $1 -out $2.csr \
	-reqexts SAN \
    	-config <(cat /etc/ssl/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=IP:192.168.122.154"))
}

#
#if ! command openssl &> /dev/null
#then
#    echo opennssl could not be found
#    exit 1
#fi

case $1 in
    genCA)
        genCA
        ;;
    genCert)
        if [ -z $2 ]; then 
            echo You have to add a name to this functionality
            exit 1
        fi
        if [ -z $3 ]; then 
            echo missing ip address
            exit 1
        fi
        genCert $2 $3
        ;;
    genCSR)
        if [ -z $2 ]; then 
            echo You have to add a name to this functionality
            exit 1
        fi
        if [ -z $3 ]; then 
            echo You have to add a name to this functionality
            exit 1
        fi
        genCSR $2 $3
        ;;
    *)
        echo unknown
        ;;
esac

exit 0
