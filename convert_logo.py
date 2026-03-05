from PIL import Image
import os

# 打开logo.png文件
img = Image.open('logo.png')

# 调整图像大小为适合的图标尺寸
icon_sizes = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)]

# 保存为logo.ico
img.save('logo.ico', format='ICO', sizes=icon_sizes)

print('Logo converted successfully!')
