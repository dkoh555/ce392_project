import math

THETAS = 180
# floating‐point version
sinvals = [math.sin(math.pi * i / THETAS) for i in range(THETAS)]
cosvals = [math.cos(math.pi * i / THETAS) for i in range(THETAS)]

# print C array literal
print("static const float sinvals[{}] = {{".format(THETAS))
print(", ".join(f"{v:.15f}" for v in sinvals))
print("};\n")

print("static const float cosvals[{}] = {{".format(THETAS))
print(", ".join(f"{v:.15f}" for v in cosvals))
print("};")