local BasePlugin = require "kong.plugins.base_plugin"
local OidcHandler = BasePlugin:extend()
local utils = require("kong.plugins.oidc.utils")
local filter = require("kong.plugins.oidc.filter")
local session = require("kong.plugins.oidc.session")

OidcHandler.PRIORITY = 1000

function OidcHandler:new()
  OidcHandler.super.new(self, "oidc")
end

function OidcHandler:access(config)
  ngx.log(ngx.DEBUG, "OidcHandler begin")
  OidcHandler.super.access(self)
  local oidcConfig = utils.get_options(config, ngx)

  if filter.shouldProcessRequest(oidcConfig) then
    session.configure(config)
    handle(oidcConfig)
  else
    ngx.log(ngx.DEBUG, "OidcHandler ignoring request, path: " .. ngx.var.request_uri)
  end

  ngx.log(ngx.DEBUG, "OidcHandler done")
end

function handle(oidcConfig)
  local response

  if oidcConfig.verify_only == "yes" then
    response = verify(oidcConfig)
    if response then
      utils.injectUser(response)
    end
    return
  end

  if oidcConfig.introspection_endpoint then
    response = introspect(oidcConfig)
    if response then
      utils.injectUser(response)
    end
  end

  if response == nil then
    response = make_oidc(oidcConfig)
    if response then
      if (response.user) then
        utils.injectUser(response.user)
      end
      if (response.access_token) then
        utils.injectAccessToken(response.access_token)
      end
      if (response.id_token) then
        utils.injectIDToken(response.id_token)
      end
    end
  end
end

function make_oidc(oidcConfig)
  ngx.log(ngx.DEBUG, "OidcHandler calling authenticate, requested path: " .. ngx.var.request_uri)
  local res, err = require("resty.openidc").authenticate(oidcConfig)
  if err then
    if oidcConfig.recovery_page_path then
      ngx.log(ngx.DEBUG, "Entering recovery page: " .. oidcConfig.recovery_page_path)
      ngx.redirect(oidcConfig.recovery_page_path)
    end
    utils.exit(500, err, ngx.HTTP_INTERNAL_SERVER_ERROR)
  end
  return res
end

function introspect(oidcConfig)
  if utils.has_bearer_access_token() or oidcConfig.bearer_only == "yes" then
    local res, err = require("resty.openidc").introspect(oidcConfig)
    if err then
      if oidcConfig.bearer_only == "yes" then
        ngx.header["WWW-Authenticate"] = 'Bearer realm="' .. oidcConfig.realm .. '",error="' .. err .. '"'
        utils.exit(ngx.HTTP_UNAUTHORIZED, err, ngx.HTTP_UNAUTHORIZED)
      end
      return nil
    end
    ngx.log(ngx.DEBUG, "OidcHandler introspect succeeded, requested path: " .. ngx.var.request_uri)
    return res
  end
  return nil
end

function verify(oidcConfig)
  ngx.log(ngx.DEBUG, "OidcHandler verify begin, requested path: " .. ngx.var.request_uri)
  if utils.has_bearer_access_token() then
    local res, err = require("resty.openidc").bearer_jwt_verify(oidcConfig)
    if err then
      ngx.log(ngx.DEBUG, "OidcHandler verify error, requested path: " .. ngx.var.request_uri)
      ngx.header["WWW-Authenticate"] = 'Bearer realm="' .. oidcConfig.realm .. '",error="' .. err .. '"'
      utils.exit(ngx.HTTP_UNAUTHORIZED, err, ngx.HTTP_UNAUTHORIZED)
    end
    ngx.log(ngx.DEBUG, "OidcHandler verify succeeded, requested path: " .. ngx.var.request_uri)
    return res
  end
  ngx.log(ngx.DEBUG, "OidcHandler verify no bearer token")
  ngx.header["WWW-Authenticate"] = 'error=no bearer token'
  utils.exit(ngx.HTTP_UNAUTHORIZED, err, ngx.HTTP_UNAUTHORIZED)
end


return OidcHandler
