#!/usr/bin/env bash

pushd ..
luarocks remove kong-oidc --force
luarocks remove lua-resty-openidc --force
luarocks make
luarocks pack kong-oidc
luarocks pack lua-resty-openidc
popd

rm -rf ./rocksdir
mkdir ./rocksdir
mv ../*.rock ./rocksdir/
