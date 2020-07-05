local lu = require("luaunit")

TestVerify = require("test.unit.mockable_case"):extend()


function TestVerify:setUp()
  TestVerify.super:setUp()
  self.handler = require("kong.plugins.oidc.handler")()
end

function TestVerify:tearDown()
  TestVerify.super:tearDown()
end

function TestVerify:test_access_token_exists()
  ngx.req.get_headers = function() return {Authorization = "Bearer xxx"} end
  local dict = {}
  function dict:get(key) return key end
  _G.ngx.shared = {introspection = dict }

  ngx.encode_base64 = function(x)
    return "eyJzdWIiOiJzdWIifQ=="
  end

  local headers = {}
  ngx.req.set_header = function(h, v)
    headers[h] = v
  end

  self.handler:access({verify_only = "yes"})
  lu.assertTrue(self:log_contains("verify succeeded"))
  lu.assertEquals(headers['X-Userinfo'], "eyJzdWIiOiJzdWIifQ==")
end

-- function TestVerify:test_verify_success()
--   package.loaded["resty.openidc"].bearer_jwt_verify = function(opts)
--     return "{'test':'test'}", nil, "ACCESSTOKEN"
--   end
--   ngx.req.get_headers = function() return {Authorization = "Bearer xxx"} end
--   local dict = {}
--   function dict:get(key) return key end
--   _G.ngx.shared = {introspection = dict }

--   ngx.encode_base64 = function(x)
--     return "ACCESSTOKEN"
--   end

--   local headers = {}
--   ngx.req.set_header = function(h, v)
--     headers[h] = v
--   end

--   self.handler:access({verify_only = "yes"})
--   lu.assertTrue(self:log_contains("verify succeeded"))
--   lu.assertEquals(headers['X-Userinfo'], "ACCESSTOKEN")
-- end

function TestVerify:test_no_authorization_header()
  -- package.loaded["resty.openidc"].verify = function(...) return {}, nil end
  ngx.req.get_headers = function() return {} end

  local headers = {}
  ngx.req.set_header = function(h, v)
    headers[h] = v
  end

  self.handler:access({verify_only = "yes"})
  lu.assertFalse(self:log_contains(self.mocked_ngx.ERR))
  lu.assertEquals(headers['X-Userinfo'], nil)
  lu.assertTrue(self:log_contains("verify no bearer token"))
  lu.assertEquals(ngx.status, ngx.HTTP_UNAUTHORIZED)
end


lu.run()
