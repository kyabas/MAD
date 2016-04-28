local Object = require 'object'

local Point = Object 'Point' {}

local p1 = Point 'p1' { x=3, y=2, z=1  }
local p2 = p1    'p2' { x=2, y=1 }
local p3 = p2    'p3' { x=1  }
local p4 = p3    'p4' { }

print(p1.name, p1.x, p1.y, p1.z)
print(p2.name, p2.x, p2.y, p2.z)
print(p3.name, p3.x, p3.y, p3.z)
print(p4.name, p4.x, p4.y, p4.z)

p1:set_method('getz', \s s.z)

local s = 0
for i=1,5e8 do
--  print("+++ sum")
  s = s + (p1:getz() + p2:getz() + p3:getz() + p4:getz())
end

print('s=',s)

--[=[
+++ sum
index: z 'p1'
getv : z 'p1'
index: getz 'p2'
getv : getz 'p2'
getv : getz 'p1'
getv : getz 'Point'
getv : getz 'Object'
getv : getz 'nil'
get  : getz 'p1'
index: z 'p2'
getv : z 'p2'
getv : z 'p1'
index: getz 'p3'
getv : getz 'p3'
getv : getz 'p2'
getv : getz 'p1'
getv : getz 'Point'
getv : getz 'Object'
getv : getz 'nil'
get  : getz 'p2'
get  : getz 'p1'
index: z 'p3'
getv : z 'p3'
getv : z 'p2'
getv : z 'p1'
index: getz 'p4'
getv : getz 'p4'
getv : getz 'p3'
getv : getz 'p2'
getv : getz 'p1'
getv : getz 'Point'
getv : getz 'Object'
getv : getz 'nil'
get  : getz 'p3'
get  : getz 'p2'
get  : getz 'p1'
index: z 'p4'
getv : z 'p4'
getv : z 'p3'
getv : z 'p2'
getv : z 'p1'
s=  4
--]=]
