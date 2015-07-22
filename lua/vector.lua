local M = { __author = 'ldeniau', __version = '2015.06', __help = {}, __test = {} }

-- MAD -------------------------------------------------------------------------

M.__help.self = [[
NAME
  vector

SYNOPSIS
  local vector = require 'vector'
  local v1 = vector {1,2,3,4,5,6}
  local v2 = vector(6)
  local r1 = v1:dot(v2)
  local v3 = v1:cross(v2) 

DESCRIPTION
  The module vector implements the operators and math functions on vectors:
    (minus) -, +, -, *, /, %, ^, ==, #, ..,
    unm, add, sub, mul, div, mod, pow,
    size, sizes, get, set, get0, set0,
    zeros, ones, unit, fill, copy,
    real, imag, conj, norm, angle,
    dot, inner, cross, mixed, outer, (products)
    abs, arg, exp, log, pow, sqrt, proj,
    sin, cos, tan, sinh, cosh, tanh,
    asin, acos, atan, asinh, acosh, atanh,
    foldl, foldr, foreach, map, map2,
    concat, tostring, totable, fromtable.

REMARK
  check_bounds  =true checks out of bounds indexes in get , set
  check_bounds0 =true checks out of bounds indexes in get0, set0

RELATIONS (3D GEOMETRY)
  inner prod:   u'.v = |u|.|v| cos(u^v)
  cross prod:   uxv = |u|.|v| sin(u^v) \vec{n}
  mixed prod:   (uxv)'.w = u'.(vxw) = det(u,v,w)
  outer prod:   u.v' = matrix
  dble xprod:   ux(vxw) = (u.w) \vec{v} - (u.v) \vec{w}
                (uxv)xw = (u.w) \vec{v} - (v.w) \vec{u}
  norm      :   |u| = sqrt(u'.u)
  angle     :   u^v = acos(u'.v / |u|.|v|)  in [0,pi] (or [-pi,pi] if n)
  unit      :   u / |u|
  projection:   u'.v
  projector :   I -   u.u' / u'.u
  reflector :   I - 2 u.u' / u'.u
  area      :   |uxv|
  volume    :   |(uxv)'.w|
  unitary   :   |u| = 1
  orthogonal:   u'.v = 0
  collinear :   |uxv| = 0
  coplanar  :   |(uxv)'.w| = 0

RETURN VALUES
  The constructor of vectors

SEE ALSO
  math, gmath, complex, cvector, matrix, cmatrix
]]
 
-- DEFS ------------------------------------------------------------------------

local ffi     = require 'ffi'
local linalg  = require 'linalg'
local gm      = require 'gmath'
local tbl_new = require 'table.new'

-- locals
local clib            = linalg.cmad
local vector, cvector = linalg.vector, linalg.cvector
local matrix, cmatrix = linalg.matrix, linalg.cmatrix

local isnum, iscpx, iscalar, isvec, iscvec, ismat, iscmat,
      real, imag, conj, ident, min,
      abs, arg, exp, log, sqrt, proj,
      sin, cos, tan, sinh, cosh, tanh,
      asin, acos, atan, asinh, acosh, atanh,
      unm, mod, pow = 
      gm.is_number, gm.is_complex, gm.is_scalar,
      gm.is_vector, gm.is_cvector, gm.is_matrix, gm.is_cmatrix,
      gm.real, gm.imag, gm.conj, gm.ident, gm.min,
      gm.abs, gm.arg, gm.exp, gm.log, gm.sqrt, gm.proj,
      gm.sin, gm.cos, gm.tan, gm.sinh, gm.cosh, gm.tanh,
      gm.asin, gm.acos, gm.atan, gm.asinh, gm.acosh, gm.atanh,
      gm.unm, gm.mod, gm.pow

local istype, sizeof, fill = ffi.istype, ffi.sizeof, ffi.fill

local cres = ffi.new 'complex[1]'

-- Lua API

local function idx0 (x, i)
  if check_bounds0 then
    assert(0 <= i and i < x.n, "0-index out of bounds")
  end
  return i
end

local function idx1(x, i)
  if check_bounds then
    assert(1 <= i and i <= x.n, "1-index out of bounds")
  end
  return i-1
end

function M.size  (x)       return x.n end
function M.sizes (x)       return x.n, 1 end
function M.get   (x, i)    return x.data[idx1(x,i)] end
function M.get0  (x, i)    return x.data[idx0(x,i)] end
function M.set   (x, i, e) x.data[idx1(x,i)] = e ; return x end
function M.set0  (x, i, e) x.data[idx0(x,i)] = e ; return x end

function M.zeros(x)
  fill(x.data, sizeof(isvec(x) and 'double' or 'complex', x:size()))
  return x
end

function M.ones (x, e_)
  local e = e_ or 1
  for i=0,x:size()-1 do x.data[i] = e end
  return x
end

function M.unit(x)
  local n = x:norm()
  assert(n ~= 0, "null vector")
  if n ~= 1 then x:div(n, x) end
  return x
end

function M.foldl (x, r, f)
  for i=0,x:size()-1 do r = f(r, x.data[i]) end
  return r
end

function M.foldr (x, r, f)
  for i=0,x:size()-1 do r = f(x.data[i], r) end
  return r
end

function M.foreach (x, f)
  for i=0,x:size()-1 do f(x.data[i]) end
  return x
end

function M.map (x, f, r_)
  local n = x:size()
  local r0 = f(x.data[0])
  local r = r_ or isnum(r0) and vector(n) or cvector(n)
  assert(n == r:size(), "incompatible vector sizes")
  r.data[0] = r0
  for i=1,n-1 do r.data[i] = f(x.data[i]) end
  return r
end

function M.map2 (x, y, f, r_)
  assert(isvec(y) or iscvec(y), "vector expected for 2nd argument")
  local n = x:size()
  local r0 = f(x.data[0], y.data[0])
  local r = r_ or isnum(r0) and vector(n) or cvector(n)
  assert(n == y:size() and n == r:size(), "incompatible vector sizes")
  r.data[0] = r0
  for i=1,n-1 do r.data[i] = f(x.data[i], y.data[i]) end
  return r
end

function M.inner (x, y)
  assert(x:size() == y:size(), "incompatible vector sizes")

  if isvec(x) then
    if isvec(y) then
      return clib.mad_vec_dot(x.data, y.data, x:size())
    elseif iscvec(y) then
      clib.mad_vec_dotv(x.data, y.data, cres, x:size())
      return cres[0]
    else goto invalid end    
  end

  if iscvec(x) then
    if isvec(y) then
      clib.mad_cvec_dotv(x.data, y.data, cres, x:size())
    elseif iscvec(y) then
      clib.mad_cvec_dot (x.data, y.data, cres, x:size())
    else goto invalid end
    return cres[0]
  end

::invalid:: error("invalid vector dot operands")
end

M.dot = M.inner -- shortcut

function M.cross (x, y, r_)
  local n = x:size()
  local r = r_ or isvec(x) and isvec(y) and vector(n) or cvector(n)
  assert(n == y:size() and n == r:size(), "incompatible vector sizes")
  assert(n >= 2, "invalid vector size")
  for i=1,n-2 do
    r.data[i-1] = x.data[i] * y.data[i+1] - x.data[i+1] * y.data[i]
  end
  r.data[n-2] = x.data[n-1] * y.data[0] - x.data[0] * y.data[n-1]
  r.data[n-1] = x.data[  0] * y.data[1] - x.data[1] * y.data[  0]
  return r
end

function M.mixed (x, y, z)
  -- x:cross(y):dot(z) without temporary
  local n, r = x:size(), 0
  assert(n == y:size() and n == z:size(), "incompatible vector sizes")
  assert(n >= 2, "invalid vector size")
  for i=1,n-2 do
    r = r + conj(x.data[i] * y.data[i+1] - x.data[i+1] * y.data[i]) * z.data[i-1]
  end
  r = r + conj(x.data[n-1] * y.data[0] - x.data[0] * y.data[n-1]) * z.data[n-2]
  r = r + conj(x.data[  0] * y.data[1] - x.data[1] * y.data[  0]) * z.data[n-1]
  return r
end

function M.outer (x, y, r_)
  local nr, nc = x:size(), y:size()
  local r = r_ or isvec(x) and isvec(y) and matrix(nr,nc) or cmatrix(nr,nc)
  assert(nr == r:rows() and nc == r:cols(), "incompatible vector-matrix sizes")
  for i=0,nr-1 do
    for j=0,nc-1 do r:set0(i,j, x.data[i] * conj(y.data[j])) end
  end
  return r
end

function M.norm (x)
  if isvec(x) then
    return sqrt(clib.mad_vec_dot(x.data, x.data, x:size()))
  else
    clib.mad_cvec_dot(x.data, x.data, cres, x:size())
    return sqrt(cres[0])
  end
end

function M.angle (x, y, n_)
  local w = x:inner(y)
  local v = x:norm() * y:norm()
  assert(v ~= 0, "null vector")
  local a = acos(w / v) -- [0, pi]
  if n_ ~= nil and x:mixed(y, n_) < 0 then a = -a end -- [-pi, pi]
  return a
end

function M.fill  (x, e )  return x:map(function () return e end, x) end
function M.copy  (x, r_)  return x:map (ident, r_) end
function M.real  (x, r_)  return x:map (real , r_) end
function M.imag  (x, r_)  return x:map (imag , r_) end
function M.conj  (x, r_)  return x:map (conj , r_) end
function M.abs   (x, r_)  return x:map (abs  , r_) end
function M.arg   (x, r_)  return x:map (arg  , r_) end
function M.exp   (x, r_)  return x:map (exp  , r_) end
function M.log   (x, r_)  return x:map (log  , r_) end
function M.sqrt  (x, r_)  return x:map (sqrt , r_) end
function M.proj  (x, r_)  return x:map (proj , r_) end
function M.sin   (x, r_)  return x:map (sin  , r_) end
function M.cos   (x, r_)  return x:map (cos  , r_) end
function M.tan   (x, r_)  return x:map (tan  , r_) end
function M.sinh  (x, r_)  return x:map (sinh , r_) end
function M.cosh  (x, r_)  return x:map (cosh , r_) end
function M.tanh  (x, r_)  return x:map (tanh , r_) end
function M.asin  (x, r_)  return x:map (asin , r_) end
function M.acos  (x, r_)  return x:map (acos , r_) end
function M.atan  (x, r_)  return x:map (atan , r_) end
function M.asinh (x, r_)  return x:map (asinh, r_) end
function M.acosh (x, r_)  return x:map (acosh, r_) end
function M.atanh (x, r_)  return x:map (atanh, r_) end
function M.unm   (x, r_)  return x:map (unm  , r_) end
function M.mod   (x, y, r_) return x:map2(y, mod, r_) end -- TODO
function M.pow   (x, y, r_) return x:map2(y, pow, r_) end -- TODO

function M.__eq (x, y)
  if iscalar(y) then
    for i=0,x:size()-1 do
      if x.data[i] ~= y then return false end
    end
    return true
  end

  if x:rows() ~= y:rows() or x:cols() ~= y:cols() then return false end
  for i=0,x:size()-1 do
    if x.data[i] ~= y.data[i] then return false end
  end
  return true
end

function M.add (x, y, r_)
  local r

  if isnum(x) then
    if isvec(y) then -- num + vec => vec + num
      r = r_ or vector(y:size())
      assert(y:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_addn(y.data, x, r.data, r:size())
    elseif iscvec(y) then -- num + cvec => cvec + num
      r = r_ or cvector(y:size())
      assert(y:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_addn(y.data, x, r.data, r:size())
    else goto invalid end
    return r
  end

  if isvec(x) then
    if isnum(y) then -- vec + num
      r = r_ or vector(x:size())
      assert(x:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_addn(x.data, y, r.data, r:size())
    elseif iscpx(y) then -- vec + cpx
      r = r_ or cvector(x:size())
      assert(x:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_addc(x.data, y.re, y.im, r.data, r:size())
    elseif isvec(y) then -- vec + vec
      r = r_ or vector(x:size())
      assert(x:size() == y:size() and x:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_add(x.data, y.data, r.data, r:size())
    elseif iscvec(y) then -- vec + cvec => cvec + vec
      r = r_ or cvector(x:size())
      assert(x:size() == y:size() and x:size() == r:size(), "incompatible vector sizes")
      clib.mad_cvec_addv(y.data, x.data, r.data, r:size())
    else goto invalid end
    return r
  end

  if iscvec(x) then
    if isnum(y) then -- cvec + num
      r = r_ or cvector(x:size())
      assert(x:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_addn(x.data, y, r.data, r:size())
    elseif iscpx(y) then -- cvec + cpx
      r = r_ or cvector(x:size())
      assert(x:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_addc(x.data, y.re, y.im, r.data, r:size())
    elseif isvec(y) then -- cvec + vec
      r = r_ or cvector(x:size())
      assert(x:size() == y:size() and x:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_addv(x.data, y.data, r.data, r:size())
    elseif iscvec(y) then -- cvec + cvec
      r = r_ or cvector(x:size())
      assert(x:size() == y:size() and x:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_add(x.data, y.data, r.data, r:size())
    else goto invalid end
    return r
  end

::invalid:: error("invalid vector (+) operands")
end

function M.sub (x, y, r_)
  local r

  if isnum(x) then
    if isvec(y) then -- num - vec
      r = r_ or vector(y:size())
      assert(y:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_subn(y.data, x, r.data, r:size())
    elseif iscvec(y) then -- num - cvec
      r = r_ or cvector(y:size())
      assert(y:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_subn(y.data, x, r.data, r:size())
    else goto invalid end
    return r
  end

  if isvec(x) then
    if isnum(y) then -- vec - num => vec + -num
      r = r_ or vector(x:size())
      assert(x:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_addn(x.data, -y, r.data, r:size())
    elseif iscpx(y) then -- vec - cpx => vec + -cpx
      r = r_ or cvector(x:size())
      assert(x:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_addc(x.data, -y.re, -y.im, r.data, r:size())
    elseif isvec(y) then -- vec - vec
      r = r_ or vector(x:size())
      assert(x:size() == y:size() and x:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_sub(x.data, y.data, r.data, r:size())
    elseif iscvec(y) then -- vec - cvec
      r = r_ or cvector(x:size())
      assert(x:size() == y:size() and x:size() == r:size(), "incompatible vector sizes")
      clib.mad_cvec_subv(x.data, y.data, r.data, r:size())
    else goto invalid end
    return r
  end

  if iscvec(x) then
    if isnum(y) then -- cvec - num => cvec + -num
      r = r_ or cvector(x:size())
      assert(x:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_addn(x.data, -y, r.data, r:size())
    elseif iscpx(y) then -- cvec - cpx => cvec + -cpx
      r = r_ or cvector(x:size())
      assert(x:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_addc(x.data, -y.re, -y.im, r.data, r:size())
    elseif isvec(y) then -- cvec - vec
      r = r_ or cvector(x:size())
      assert(x:size() == y:size() and x:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_subv(x.data, y.data, r.data, r:size())
    elseif iscvec(y) then -- cvec - cvec
      r = r_ or cvector(x:size())
      assert(x:size() == y:size() and x:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_sub(x.data, y.data, r.data, r:size())
    else goto invalid end
    return r
  end

::invalid:: error("invalid vector (-) operands")
end

function M.mul (x, y, r_)
  local r

  if isnum(x) then 
    if isvec(y) then -- num * vec => vec * num
      r = r_ or vector(y:size())
      assert(y:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_muln(y.data, x, r.data, r:size())
    elseif iscvec(y) then -- num * cvec => cvec * num
      r = r_ or vector(y:size())
      assert(y:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_muln(y.data, x, r.data, r:size())
    else goto invalid end
    return r
  end

  if isvec(x) then
    if isnum(y) then -- vec * num
      r = r_ or vector(x:size())
      assert(x:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_muln(x.data, y, r.data, r:size())
    elseif iscpx(y) then -- vec * cpx
      r = r_ or cvector(x:size())
      assert(x:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_mulc(x.data, y.re, y.im, r.data, r:size())
    elseif isvec(y) then -- vec * vec
      r = r_ or vector(x:size())
      assert(x:size() == y:size() and x:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_mul(x.data, y.data, r.data, r:size())
    elseif iscvec(y) then -- vec * cvec => cvec * vec
      r = r_ or cvector(x:size())
      assert(x:size() == y:size() and x:size() == r:size(), "incompatible vector sizes")
      clib.mad_cvec_mulv(y.data, x.data, r.data, r:size())
    elseif ismat(y) then -- vec * mat
      r = r_ or vector(y:cols())
      assert(x:size() == y:rows() and r:size() == y:cols(), "incompatible vector-matrix sizes")
      clib.mad_mat_nmul(x.data, y.data, r.data, r:rows(), r:cols())
    elseif iscmat(y) then -- vec * cmat
      r = r_ or cvector(y:cols())
      assert(x:size() == y:rows() and r:size() == y:cols(), "incompatible vector-cmatrix sizes")
      clib.mad_cmat_nmul(x.data, y.data, r.data, r:rows(), r:cols())
    else goto invalid end
    return r
  end

  if iscvec(x) then
    if isnum(y) then -- cvec * num
      r = r_ or cvector(x:size())
      assert(x:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_muln(x.data, y, r.data, r:size())
    elseif iscpx(y) then -- cvec * cpx
      r = r_ or cvector(x:size())
      assert(x:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_mulc(x.data, y.re, y.im, r.data, r:size())
    elseif isvec(y) then -- cvec * vec
      r = r_ or cvector(x:size())
      assert(x:size() == y:size() and x:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_mulv(x.data, y.data, r.data, r:size())
    elseif iscvec(y) then -- cvec * cvec
      r = r_ or cvector(x:size())
      assert(x:size() == y:size() and x:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_mul(y.data, x.data, r.data, r:size())
    elseif ismat(y) then -- cvec * mat
      r = r_ or cvector(y:cols())
      assert(x:size() == y:rows() and r:size() == y:cols(), "incompatible cvector-matrix sizes")
      clib.mad_mat_cmul(x.data, y.data, r.data, r:rows(), r:cols())
    elseif iscmat(y) then -- cvec * cmat
      r = r_ or cvector(y:cols())
      assert(x:size() == y:rows() and r:size() == y:cols(), "incompatible cvector-cmatrix sizes")
      clib.mad_cmat_cmul(x.data, y.data, r.data, r:rows(), r:cols())
    else goto invalid end
    return r
  end

::invalid:: error("incompatible vector (*) operands")
end

function M.div (x, y, r_)
  local r

  if isnum(x) then
    if isvec(y) then -- num / vec
      r = r_ or vector(y:size())
      assert(y:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_divn(y.data, x, r.data, r:size())
    elseif iscvec(y) then -- num / cvec
      r = r_ or vector(y:size())
      assert(y:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_divn(y.data, x, r.data, r:size())
    else goto invalid end
    return r
  end

  if isvec(x) then
    if isnum(y) then -- vec / num => vec * (1/num)
      r = r_ or vector(x:size())
      assert(x:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_muln(x.data, 1/y, r.data, r:size())
    elseif iscpx(y) then -- vec / cpx => vec * (1/cpx)
      r, y = r_ or cvector(x:size()), 1/y
      assert(x:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_mulc(x.data, y.re, y.im, r.data, r:size())
    elseif isvec(y) then -- vec / vec
      r = r_ or vector(x:size())
      assert(x:size() == y:size() and x:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_div(x.data, y.data, r.data, r:size())
    elseif iscvec(y) then -- vec / cvec
      r = r_ or cvector(x:size())
      assert(x:size() == y:size() and x:size() == r:size(), "incompatible vector sizes")
      clib.mad_vec_divv(y.data, x.data, r.data, r:size())
    elseif ismat(y) then -- vec / mat => vec * inv(mat)
      error("vec/mat: NYI matrix inverse")
    elseif iscmat(y) then -- vec / cmat => vec * inv(cmat)
      error("vec/cmat: NYI cmatrix inverse")
    else goto invalid end
    return r
  end

  if iscvec(x) then
    if isnum(y) then -- cvec / num => cvec * (1/num)
      r = r_ or cvector(x:size())
      assert(x:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_muln(x.data, 1/y, r.data, r:size())
    elseif iscpx(y) then -- cvec / cpx => cvec * (1/cpx)
      r, y = r_ or cvector(x:size()), 1/y
      assert(x:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_mulc(x.data, y.re, y.im, r.data, r:size())
    elseif isvec(y) then -- cvec / vec
      r = r_ or cvector(x:size())
      assert(x:size() == y:size() and x:size() == r:size(), "incompatible cvector sizes")
      clib.mad_cvec_divv(x.data, y.data, r.data, r:size())
    elseif iscvec(y) then -- cvec / cvec
      r = r_ or cvector(x:size())
      assert(x:size() == y:size() and x:size() == r:size(), "incompatible vector sizes")
      clib.mad_cvec_div(y.data, x.data, r.data, r:size())
    elseif ismat(y) then -- cvec / mat => cvec * inv(mat)
      error("vec/mat: NYI matrix inverse")
    elseif iscmat(y) then -- cvec / cmat => cvec * inv(cmat)
      error("vec/cmat: NYI matrix inverse")
    else goto invalid end
    return r
  end

::invalid:: error("incompatible vector (/) operands")
end

function M.concat (x, y, r_)
  local nx, ny = x:size(), y:size()
  local n = nx + ny
  local r = r_ or isvec(x) and isvec(y) and vector(n) or cvector(n)
  assert(n == r:size(), "incompatible vector sizes")
  for i=0,nx-1 do r.data[i   ] = x.data[i] end
  for i=0,ny-1 do r.data[i+nx] = y.data[i] end
  return r
end

function M.tostring (x, sep)
  local n = x:size()
  local r = tbl_new(n,0)
  for i=0,n-1 do r[i+1] = tostring(x:get0(i)) end
  return table.concat(r, sep or ' ')
end

function M.totable(x, r_)
  local n = x:sizes()
  local r = r_ or tbl_new(n,0)
  assert(type(r) == 'table', "invalid argument, table expected")
  for i=0,n-1 do r[i+1] = x:get0(i) end
  return r
end

function M.tomatrix(x, nr, nc, r_)
  local n = x:size()
  local r = r_ or isvec(x) and matrix(nr,nc) or cmatrix(nr,nc)
  assert(n  == r:size() and nr == r:rows() and nc == r:cols(), "incompatible matrix sizes")
  for i=0,n-1 do r.data[i] = x.data[i] end
  return r
end

function M.fromtable (x, tbl)
  local n = x:size()
  assert(#tbl == n, "incompatible vector-table sizes")
  for i=0,n-1 do x:set0(i, tbl[i+1]) end
  return x
end

M.__unm      = M.unm
M.__add      = M.add
M.__sub      = M.sub
M.__mul      = M.mul
M.__div      = M.div
M.__mod      = M.mod
M.__pow      = M.pow
M.__len      = M.size
M.__concat   = M.concat
M.__tostring = M.tostring
M.__index    = function (self, idx)
  return isnum(idx) and self:get(idx) or M[idx]
end

ffi.metatype( 'vector_t', M)
ffi.metatype('cvector_t', M)

-- END -------------------------------------------------------------------------
return vector
