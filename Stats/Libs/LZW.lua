--[[============================================================================
  Stats - Libs/LZW.lua
  ---------------------------------------------------------------------------
  Compresseur LZW maison + encodage Base64 standard, sans dependance externe.
  Choix deliberement simple plutot qu'une bibliotheque tierce embarquee : un
  LZW a codes 12 bits (dictionnaire fige a 4096 entrees) est un algorithme
  mecanique, facile a retracer a la main des deux cotes (addon Lua ET page
  web JS), donc beaucoup moins risque de desynchronisation qu'une reimplantation
  approximative d'un format de compression plus complexe. Le ratio est moins
  bon qu'un vrai deflate, mais largement suffisant pour des seaux journaliers
  de quelques personnages : ce n'est pas le facteur limitant du format d'export.

  Le decodeur JS miroir (identique bit a bit) vit dans le fichier du site
  Tibiscui.fr : dashboard-shared.js. Toute modification ici DOIT etre reportee
  la-bas, sinon les exports generes en jeu ne se liront plus sur le site.

  API :
    SX.LZW.Compress(str)   -> chaine d'octets compressee
    SX.LZW.Decompress(str) -> chaine d'octets d'origine
    SX.LZW.Base64Encode(str) -> texte imprimable (alphabet standard, avec '=')
    SX.LZW.Base64Decode(str) -> chaine d'octets d'origine
============================================================================]]

local ADDON, SX = ...
SX.LZW = SX.LZW or {}
local M = SX.LZW

local DICT_MAX = 4096  -- codes 12 bits ; dictionnaire fige (pas de reset) au-dela

-- ============================================================================
-- LZW
-- ============================================================================
local function packCodes(codes)
  local n = #codes
  local bytes = {}
  local i = 1
  while i <= n do
    local a = codes[i]
    local b = codes[i + 1]
    if b then
      local byte1 = math.floor(a / 16)
      local byte2 = (a % 16) * 16 + math.floor(b / 256)
      local byte3 = b % 256
      bytes[#bytes + 1] = string.char(byte1, byte2, byte3)
      i = i + 2
    else
      local byte1 = math.floor(a / 16)
      local byte2 = (a % 16) * 16
      bytes[#bytes + 1] = string.char(byte1, byte2)
      i = i + 1
    end
  end
  local header = string.char(
    math.floor(n / 16777216) % 256,
    math.floor(n / 65536) % 256,
    math.floor(n / 256) % 256,
    n % 256
  )
  return header .. table.concat(bytes)
end

local function unpackCodes(data)
  local count = data:byte(1) * 16777216 + data:byte(2) * 65536 + data:byte(3) * 256 + data:byte(4)
  local codes = {}
  local pos = 5
  local i = 1
  while i <= count do
    local b1, b2 = data:byte(pos, pos + 1)
    local a = b1 * 16 + math.floor(b2 / 16)
    codes[#codes + 1] = a
    i = i + 1
    if i <= count then
      local b3 = data:byte(pos + 2)
      codes[#codes + 1] = (b2 % 16) * 256 + b3
      i = i + 1
      pos = pos + 3
    else
      pos = pos + 2
    end
  end
  return codes
end

function M.Compress(input)
  if not input or input == "" then return "" end
  local dict = {}
  for i = 0, 255 do dict[string.char(i)] = i end
  local dictSize = 256
  local w = ""
  local codes = {}
  for i = 1, #input do
    local c = input:sub(i, i)
    local wc = w .. c
    if dict[wc] then
      w = wc
    else
      codes[#codes + 1] = dict[w]
      if dictSize < DICT_MAX then
        dict[wc] = dictSize
        dictSize = dictSize + 1
      end
      w = c
    end
  end
  if w ~= "" then codes[#codes + 1] = dict[w] end
  return packCodes(codes)
end

function M.Decompress(data)
  if not data or data == "" then return "" end
  local codes = unpackCodes(data)
  if #codes == 0 then return "" end
  local dict = {}
  for i = 0, 255 do dict[i] = string.char(i) end
  local dictSize = 256
  local out = {}
  local prev = dict[codes[1]]
  out[1] = prev
  for i = 2, #codes do
    local code = codes[i]
    local entry
    if dict[code] then
      entry = dict[code]
    elseif code == dictSize then
      entry = prev .. prev:sub(1, 1)
    else
      error("Stats.LZW: code de decompression invalide")
    end
    out[#out + 1] = entry
    if dictSize < DICT_MAX then
      dict[dictSize] = prev .. entry:sub(1, 1)
      dictSize = dictSize + 1
    end
    prev = entry
  end
  return table.concat(out)
end

-- ============================================================================
-- BASE64 (alphabet standard RFC 4648, avec padding '=') - lisible partout,
-- decodable en JS cote site avec l'API native atob() sans code supplementaire.
-- ============================================================================
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_REV = {}
for i = 1, #B64 do B64_REV[B64:sub(i, i)] = i - 1 end

function M.Base64Encode(data)
  if not data or data == "" then return "" end
  local out = {}
  local len = #data
  local i = 1
  while i <= len do
    local b1, b2, b3 = data:byte(i, i + 2)
    b2 = b2 or 0
    b3 = b3 or 0
    local n = b1 * 65536 + b2 * 256 + b3
    local c1 = math.floor(n / 262144) % 64
    local c2 = math.floor(n / 4096) % 64
    local c3 = math.floor(n / 64) % 64
    local c4 = n % 64
    out[#out + 1] = B64:sub(c1 + 1, c1 + 1)
    out[#out + 1] = B64:sub(c2 + 1, c2 + 1)
    out[#out + 1] = (i + 1 <= len) and B64:sub(c3 + 1, c3 + 1) or "="
    out[#out + 1] = (i + 2 <= len) and B64:sub(c4 + 1, c4 + 1) or "="
    i = i + 3
  end
  return table.concat(out)
end

function M.Base64Decode(text)
  if not text or text == "" then return "" end
  text = text:gsub("[^%w%+%/%=]", "")
  local out = {}
  local i = 1
  local len = #text
  while i <= len do
    local c1 = B64_REV[text:sub(i, i)] or 0
    local c2 = B64_REV[text:sub(i + 1, i + 1)] or 0
    local e3 = text:sub(i + 2, i + 2)
    local e4 = text:sub(i + 3, i + 3)
    local c3 = B64_REV[e3]
    local c4 = B64_REV[e4]
    local n = c1 * 262144 + c2 * 4096 + (c3 or 0) * 64 + (c4 or 0)
    local b1 = math.floor(n / 65536) % 256
    local b2 = math.floor(n / 256) % 256
    local b3 = n % 256
    out[#out + 1] = string.char(b1)
    if e3 ~= "" and e3 ~= "=" then out[#out + 1] = string.char(b2) end
    if e4 ~= "" and e4 ~= "=" then out[#out + 1] = string.char(b3) end
    i = i + 4
  end
  return table.concat(out)
end
