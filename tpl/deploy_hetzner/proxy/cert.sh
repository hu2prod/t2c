#!/bin/bash
EMAIL=`cat EMAIL`
DOMAIN=`cat DOMAIN`
certbot certonly --non-interactive \
  --agree-tos --email $EMAIL \
  --webroot --webroot-path=/opt/proxy/static/ \
  -d $DOMAIN \

