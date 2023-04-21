-- Real Estate Valuation Extension for MoneyMoney
-- Fetches the valuation from "pricehubble"
--
-- Username: Dossier Share URL
-- Password: Initial Price

-- MIT License

-- Copyright (c) 2023 Markus Harmsen

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.


WebBanking{
  version = 0.1,
  description = "Add your real estate valuation into MoneyMoney",
  services = { "RealEstateValuation" }
}

local shareId = nil
local accessToken = nil
local purchasePrice = nil
local connection = Connection()

function SupportsBank (protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == "RealEstateValuation"
end

function InitializeSession (protocol, bankCode, username, reserved, password)
  -- Username should include JWT token (last part of the URL)
  local jwt = string.match(username, '/?([^/%.]+%.[^/%.]+%.[^/%.]+)$')
  -- Password can be set to be the inital buying price
  purchasePrice = tonumber(password)

  -- 1: Trade in JWT token to access token
  accessToken = getAccessToken(jwt)
  if accessToken == nil
  then
    MM.printStatus("Error: could not get access token")
    return LoginFailed
  end

  -- 2: Extract shareId
  local payload = parseJWT(jwt)
  if not jwtValid(payload)
  then
    MM.printStatus("Error: invalid JWT token")
    return LoginFailed
  end

  shareId = payload["shareId"]
end

function ListAccounts (knownAccounts)
  local account = {
    name = "Valuation",
    accountNumber = "Real Estate",
    currency = "EUR",
    portfolio = true,
    type = "AccountTypePortfolio"
  }

  return {account}
end

function RefreshAccount (account, since)
  local dossier = getDossier(shareId)

  local security = {
    name = extractAddress(dossier),
    currency = nil,
    market = "pricehubble",
    quantity = 1,
    price = dossier["valuationSale"]["value"],
    purchasePrice = purchasePrice
  }

  return {securities = {security}}
end

function EndSession ()
end

-- Helpers

function parseJWT (jwt)
  -- JWT is "header.payload.signature", we are just interested in the payload
  local encodedPayload = string.match(jwt, '%.(.+)%.')
  local payload = MM.base64decode(encodedPayload)

  return JSON(payload):dictionary()
end

function jwtValid (payload)
  -- Ensure type is correct and token is still usable
  return ( payload["shareType"] == "valuation" ) and ( payload["exp"] > os.time() )
end

function getAccessToken(jwt)
  local json = connection:request("POST", "https://api.pricehubble.com/auth/login/jwt", "{\"token\":\"" .. jwt .. "\"}", "application/json")

  return JSON(json):dictionary()['access_token']
end

function getDossier(id)
  local json = connection:request("GET", "https://api.pricehubble.com/api/v1/dossiers/links/" .. id, nil, nil, { authorization = "Bearer " .. accessToken })

  return JSON(json):dictionary()["dossier"]
end

function extractAddress(dossier)
  local address = dossier["property"]["location"]["address"]

  return address["street"] .. " " .. address["houseNumber"] .. ", " .. address["postCode"] .. " " .. address["city"]
end
