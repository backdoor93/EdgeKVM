#!/bin/bash
#ping6 ff02::1 -I breno8|sed -E 's/64 bytes from ((?:[a-zA-Z0-9]{0,4}:?){1,8}|(?:[a-zA-Z0-9]{0,4}:?){1,4}(?:[0-9]{1,3}\.){3}[0-9]{1,3})%breno8.*/$1/g;t;d'
#ping6 ff02::1 -I breno8 -c1 |grep -Eo '64 bytes from (.*)%breno8.*'
peer=$(ping6 ff02::1 -I breno8 -c1 |grep '64 bytes' |sed -E 's/64 bytes from (.*)%breno8.*/\1/')
ssh system@$peer%breno8
