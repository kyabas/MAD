--[=[
 o----------------------------------------------------------------------------o
 |
 | Range module
 |
 | Methodical Accelerator Design - Copyright CERN 2015
 | Support: http://cern.ch/mad  - mad at cern.ch
 | Authors: L. Deniau, laurent.deniau at cern.ch
 | Contrib: -
 |
 o----------------------------------------------------------------------------o
 | You can redistribute this file and/or modify it under the terms of the GNU
 | General Public License GPLv3 (or later), as published by the Free Software
 | Foundation. This file is distributed in the hope that it will be useful, but
 | WITHOUT ANY WARRANTY OF ANY KIND. See http://gnu.org/licenses for details.
 o----------------------------------------------------------------------------o
  
  Purpose:
  - provides full set of functions and operations on ranges

  Information:
  - ranges are not tables nor vector. totable and tovector convert a range in
    a table or a vector.

 o----------------------------------------------------------------------------o
]=]

local M = { __help = {}, __test = {} }

-- help ----------------------------------------------------------------------o

M.__help.self = [[
NAME
  range

SYNOPSIS
  local range = require 'xrange'
  TODO

DESCRIPTION
  Ranges describe start, stop (included) and step. Zero step gives empty range
  with get, index (i.e. []) and iterator (i.e. ipairs).

REMARK:
  - Indexing a range outside its bounds return nil.
  - Ranges can be used as (stateless) iterators in for loops 

RETURN VALUES
  The constructor of ranges

SEE ALSO
  matrix
]]
 
-- modules -------------------------------------------------------------------o

local ffi    = require 'ffi'
local vector = require 'vector'
local table  = require 'table.new'

-- ffi -----------------------------------------------------------------------o

-- xrange layout must be compatible with double[3] for num..num[..num] semantic
--ffi.cdef[[
--  struct xrange { double start, stop, step; };
--]]

-- locals --------------------------------------------------------------------o

local istype     in ffi
local max, floor in math

-- FFI type constructors
local range = ffi.typeof 'xrange'

-- implementation ------------------------------------------------------------o

-- helper

function is_range (x)
  return type(x) == 'cdata' and istype('xrange', x)
end

-- constructor

local function size (start, stop, step)
--  if step < -1 or step > 1 then
--    return max(0, floor( (stop-start)/step +step +0.5) )
--  end
  if step > 1 then
    return max(0, floor( (stop-start+1)/step +0.5) )
  elseif step < -1 then
    return max(0, floor( (stop-start-1)/step +0.5) )
  elseif step ~= 0 then
    return max(0, floor( (stop-start  )/step +1.5) )
  else
    return 0
  end
end

local function value (r, x)
  return r.start + x*r.step
end

local function getpos (r, x)
  local v = value(r, x)
  return v <= r.stop and v
end

local function getneg (r, x)
  local v = value(r, x)
  return v >= r.stop and v
end

local function iterpos(r, i)
  local v = value(r, i)
  if v <= r.stop then return i+1, v end
end

local function iterneg(r, i)
  local v = value(r, i)
  if v >= r.stop then return i+1, v end
end

local function get (r, x)
  return r.step > 0 and getpos(r, x) or r.step < 0 and getneg(r, x)
end

function M.__new (ct, start, stop, step)
  assert(start ~= nil, "xrange: invalid #1 argument")
  if stop == nil then stop = start end -- default
  if step == nil then step = 1 end     -- default
  return ffi.new(ct, start, stop, step)
end

function M.__index (r, a)
  if type(a) == "number"
    then return get(r, a) else return M[a]
  end
end

function M.__ipairs (r)
  if r.step > 0 then
    return iterpos, r, 0
  elseif r.step < 0 then
    return iterneg, r, 0
  end
end

-- methods

function M.range (r)
  return r.start, r.stop, r.step
end

function M.size (r) -- size
  return size(r:range())
end

M.get   = get
M.value = value
M.len   = M.size

--[[
function M.first (r)
  return r._size > 0 and r._start or nil
end

function M.last (r)
  return r:value(r._size)
end

function M.index (r, x)
  local i = size(r.start, x, r.step)
  return i >= 1 and i <= r._size and i or nil
end

function M.value (r, i)
  return i >= 1 and i <= r._size and r._start+(i-1)*r._step or nil
end

function M.element (r, x)
  return x == r:value(r:index(x))
end

function M.minmax (r)
  if r._step < 0 then
    return r:last(), r:first()
  else
    return r:first(), r:last()
  end    
end

function M.bounds (r)
  if r._step < 0 then
    return r._stop, r._start
  else
    return r._start, r._stop
  end    
end

function M.overlap (r, s)
  if r._size == 0 or s._size == 0 then
    return false
  end

  local rl, rh = r:bounds()
  local sl, sh = s:bounds()
  return not (rl < sl and rh < sl or rl > sh)
end

-- convertion

local function convert (r, ctor)
  local t = ctor(r._size,0)
  for i=1,r._size do
    t[i] = r._start+(i-1)*r._step
  end
  return t
end

function M.totable (r)
  return convert(r, table)
end

function M.tovector (r)
  return convert(r, vector)
end

function M.tostring (r)
  if r._step == 1 then
    return string.format("%g:%g", r._start, r._stop)
  else
    return string.format("%g:%g:%g", r._start, r._stop, r._step)
  end
end

function M.equal (r1, r2)
  if r1._size == 0 and r2._size == 0 then
    return true
  else
    return r1._start == r2._start and r1._step == r2._step and r1._size == r2._size
  end          
end
]]

-- metamethods
--[[
M.__len      = M.size
M.__tostring = M.tostring
M.__eq       = M.equal

local function iter(r, i)
  if i < r._size then
    return i+1, r._start+i*r._step
  end
end

function M.__ipairs (r) -- iterator: for n in ipairs(r)
  return iter, r, 0
end
]]

ffi.metatype('xrange', M)

------------------------------------------------------------------------------o
return range