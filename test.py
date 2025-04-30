import numpy as np

# Создаем градиент 170x320 RGB565
width, height = 320, 170
image = np.zeros((height, width), dtype=np.uint16)

for y in range(height):
    for x in range(width):
        r = int((x / width) * 31) & 0x1F
        g = int((y / height) * 63) & 0x3F
        b = int(((x+y)/(width+height)) * 31) & 0x1F
        image[y,x] = (r << 11) | (g << 5) | b

# Сохраняем в .mem файл
with open('test_image.mem', 'w') as f:
    for y in range(height):
        for x in range(width):
            f.write(f"{image[y,x]:04X}\n")