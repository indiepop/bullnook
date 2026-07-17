from PIL import Image, ImageDraw, ImageFilter
import math

SIZE = 1024
img = Image.new('RGB', (SIZE, SIZE), (255, 200, 50))
draw = ImageDraw.Draw(img)

def draw_gradient_background(draw, size):
    for y in range(size):
        # Warm orange to yellow gradient
        r = int(255)
        g = int(160 + (y / size) * 60)
        b = int(40 + (y / size) * 40)
        draw.line([(0, y), (size, y)], fill=(r, g, b))

draw_gradient_background(draw, SIZE)

# Add subtle radial glow
glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
glow_draw = ImageDraw.Draw(glow)
center = SIZE // 2
for r in range(center, 0, -4):
    alpha = int(30 * (1 - r / center))
    glow_draw.ellipse([center-r, center-r-100, center+r, center+r-100], fill=(255, 255, 200, alpha))
img = Image.alpha_composite(img.convert('RGBA'), glow)
draw = ImageDraw.Draw(img)

# Bull head - large, round, cartoonish
head_color = (220, 80, 40)  # bright reddish-orange
head_center = (SIZE // 2, SIZE // 2 + 60)
head_radius = 260

# Shadow under head
shadow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
shadow_draw = ImageDraw.Draw(shadow)
shadow_draw.ellipse([head_center[0]-220, head_center[1]+180, head_center[0]+220, head_center[1]+260], fill=(0, 0, 0, 60))
img = Image.alpha_composite(img, shadow)
draw = ImageDraw.Draw(img)

# Ears (behind head)
ear_color = (200, 70, 35)
left_ear = [(head_center[0]-220, head_center[1]-80), (head_center[0]-300, head_center[1]-160), (head_center[0]-180, head_center[1]-200)]
right_ear = [(head_center[0]+220, head_center[1]-80), (head_center[0]+300, head_center[1]-160), (head_center[0]+180, head_center[1]-200)]
draw.polygon(left_ear, fill=ear_color)
draw.polygon(right_ear, fill=ear_color)

# Horns - big, exaggerated, curved
horn_color = (255, 230, 150)
horn_outline = (200, 170, 100)
# Left horn
left_horn_points = []
for t in range(0, 101):
    angle = math.radians(180 - t * 1.5)  # from 180 to 30 degrees
    r = 180 + t * 1.2
    x = head_center[0] - 120 + r * math.cos(angle)
    y = head_center[1] - 140 + r * math.sin(angle) * 0.6
    left_horn_points.append((x, y))
# Thicken the horn
for i in range(len(left_horn_points) - 1):
    width = 50 - i * 0.3
    draw.line([left_horn_points[i], left_horn_points[i+1]], fill=horn_color, width=int(width))
    draw.line([left_horn_points[i], left_horn_points[i+1]], fill=horn_outline, width=int(width+8))
    draw.line([left_horn_points[i], left_horn_points[i+1]], fill=horn_color, width=int(width))

# Right horn
right_horn_points = []
for t in range(0, 101):
    angle = math.radians(0 + t * 1.5)  # from 0 to 150 degrees
    r = 180 + t * 1.2
    x = head_center[0] + 120 + r * math.cos(angle)
    y = head_center[1] - 140 + r * math.sin(angle) * 0.6
    right_horn_points.append((x, y))
for i in range(len(right_horn_points) - 1):
    width = 50 - i * 0.3
    draw.line([right_horn_points[i], right_horn_points[i+1]], fill=horn_outline, width=int(width+8))
    draw.line([right_horn_points[i], right_horn_points[i+1]], fill=horn_color, width=int(width))

# Head shape
# Main head circle with highlight
draw.ellipse([head_center[0]-head_radius, head_center[1]-head_radius,
              head_center[0]+head_radius, head_center[1]+head_radius],
             fill=head_color, outline=(180, 60, 30), width=8)

# Highlight on forehead
highlight = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
highlight_draw = ImageDraw.Draw(highlight)
highlight_draw.ellipse([head_center[0]-120, head_center[1]-220, head_center[0]+80, head_center[1]-80], fill=(255, 150, 120, 120))
img = Image.alpha_composite(img, highlight)
draw = ImageDraw.Draw(img)

# Snout / muzzle
snout_color = (255, 180, 150)
snout_center = (head_center[0], head_center[1] + 80)
snout_radius = 140
draw.ellipse([snout_center[0]-snout_radius, snout_center[1]-snout_radius,
              snout_center[0]+snout_radius, snout_center[1]+snout_radius],
             fill=snout_color, outline=(230, 140, 110), width=4)

# Nostrils
draw.ellipse([snout_center[0]-50, snout_center[1]-20, snout_center[0]-20, snout_center[1]+20], fill=(80, 40, 30))
draw.ellipse([snout_center[0]+20, snout_center[1]-20, snout_center[0]+50, snout_center[1]+20], fill=(80, 40, 30))

# Big cartoon eyes
eye_white_left = (head_center[0] - 90, head_center[1] - 60)
eye_white_right = (head_center[0] + 90, head_center[1] - 60)
eye_radius = 55
# Eye whites
draw.ellipse([eye_white_left[0]-eye_radius, eye_white_left[1]-eye_radius,
              eye_white_left[0]+eye_radius, eye_white_left[1]+eye_radius], fill=(255, 255, 255), outline=(60, 60, 60), width=4)
draw.ellipse([eye_white_right[0]-eye_radius, eye_white_right[1]-eye_radius,
              eye_white_right[0]+eye_radius, eye_white_right[1]+eye_radius], fill=(255, 255, 255), outline=(60, 60, 60), width=4)

# Pupils - looking up and to the side for lively expression
pupil_radius = 25
draw.ellipse([eye_white_left[0]-10-pupil_radius, eye_white_left[1]-15-pupil_radius,
              eye_white_left[0]-10+pupil_radius, eye_white_left[1]-15+pupil_radius], fill=(40, 30, 20))
draw.ellipse([eye_white_right[0]+10-pupil_radius, eye_white_right[1]-15-pupil_radius,
              eye_white_right[0]+10+pupil_radius, eye_white_right[1]-15+pupil_radius], fill=(40, 30, 20))

# Eye shine
shine_radius = 8
draw.ellipse([eye_white_left[0]-20-shine_radius, eye_white_left[1]-30-shine_radius,
              eye_white_left[0]-20+shine_radius, eye_white_left[1]-30+shine_radius], fill=(255, 255, 255))
draw.ellipse([eye_white_right[0]+0-shine_radius, eye_white_right[1]-30-shine_radius,
              eye_white_right[0]+0+shine_radius, eye_white_right[1]-30+shine_radius], fill=(255, 255, 255))

# Eyebrows - expressive, raised
brow_color = (120, 50, 30)
draw.polygon([(head_center[0]-130, head_center[1]-130), (head_center[0]-60, head_center[1]-150), (head_center[0]-50, head_center[1]-135)], fill=brow_color)
draw.polygon([(head_center[0]+130, head_center[1]-130), (head_center[0]+60, head_center[1]-150), (head_center[0]+50, head_center[1]-135)], fill=brow_color)

# Big smile
smile_y = snout_center[1] + 60
mouth_points = []
for t in range(0, 101):
    x = head_center[0] - 80 + t * 1.6
    y = smile_y + 20 * math.sin(math.radians(t * 1.8))
    mouth_points.append((x, y))
for i in range(len(mouth_points) - 1):
    draw.line([mouth_points[i], mouth_points[i+1]], fill=(120, 40, 30), width=10)

# Nose ring (gold) - playful touch
ring_center = (snout_center[0], snout_center[1] + 50)
ring_radius = 18
draw.ellipse([ring_center[0]-ring_radius, ring_center[1]-ring_radius,
              ring_center[0]+ring_radius, ring_center[1]+ring_radius],
             outline=(255, 215, 0), width=8)

# Add some sparkles for fun
sparkle_positions = [(180, 180), (840, 220), (220, 800), (800, 780)]
for sx, sy in sparkle_positions:
    draw.polygon([(sx, sy-20), (sx+8, sy-8), (sx+20, sy), (sx+8, sy+8), (sx, sy+20), (sx-8, sy+8), (sx-20, sy), (sx-8, sy-8)], fill=(255, 255, 220))

# Apply slight blur for softness
img = img.filter(ImageFilter.GaussianBlur(radius=0.5))

# Convert to RGB and save
img_rgb = img.convert('RGB')
img_rgb.save('/Users/yangzhuo/BullNook/app_icon_cartoon_bull.png', 'PNG')
print("Icon saved to /Users/yangzhuo/BullNook/app_icon_cartoon_bull.png")
