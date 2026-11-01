import os
import wave
import struct
import math
import random
from PIL import Image, ImageDraw

ASSETS_DIR = r"q:\GODOT WORKS\echo-thief\assets"
AUDIO_DIR = os.path.join(ASSETS_DIR, "audio")
os.makedirs(ASSETS_DIR, exist_ok=True)
os.makedirs(AUDIO_DIR, exist_ok=True)

# ==========================================
# 1. TEXTURES
# ==========================================

# 1A. Security Camera (32x32)
def make_security_camera():
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Wall bracket / base mount (dark charcoal metal)
    draw.rounded_rectangle([4, 10, 12, 22], radius=3, fill=(45, 52, 65, 255), outline=(75, 88, 110, 255), width=1)
    
    # Swivel arm
    draw.rectangle([11, 14, 16, 18], fill=(60, 70, 85, 255))
    
    # Camera body (cylindrical housing pointing rightwards)
    draw.polygon([(15, 8), (28, 11), (28, 21), (15, 24)], fill=(32, 38, 48, 255), outline=(90, 115, 145, 255))
    
    # Front lens bezel
    draw.ellipse([25, 11, 29, 21], fill=(20, 25, 35, 255), outline=(130, 165, 200, 255), width=1)
    
    # Glass lens core (deep cyan reflections)
    draw.ellipse([26, 13, 28, 19], fill=(60, 190, 240, 255))
    
    # Status LED indicator (glowing amber/yellow by default)
    draw.ellipse([18, 10, 21, 13], fill=(255, 200, 50, 255))
    
    img.save(os.path.join(ASSETS_DIR, "camera.png"))
    print("Created camera.png")

# 1B. Laser Emitter (24x24)
def make_laser_emitter():
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Outer metallic mount base
    draw.rounded_rectangle([2, 2, 22, 22], radius=4, fill=(35, 40, 52, 255), outline=(80, 95, 120, 255), width=2)
    
    # Inner emitter socket
    draw.ellipse([5, 5, 19, 19], fill=(20, 24, 32, 255), outline=(110, 130, 160, 255), width=1)
    
    # High-intensity laser diode lens (glowing ruby red)
    draw.ellipse([8, 8, 16, 16], fill=(255, 45, 65, 255))
    draw.ellipse([10, 10, 14, 14], fill=(255, 180, 190, 255))
    
    img.save(os.path.join(ASSETS_DIR, "laser_emitter.png"))
    print("Created laser_emitter.png")

# ==========================================
# 2. AUDIO SYNTHESIS
# ==========================================
SAMPLE_RATE = 22050

def write_wav(filename, samples):
    filepath = os.path.join(AUDIO_DIR, filename)
    with wave.open(filepath, 'w') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        data = bytearray()
        for s in samples:
            val = max(-1.0, min(1.0, s))
            data.extend(struct.pack('<h', int(val * 32767.0)))
        wav.writeframes(data)
    print(f"Created {filename}")

# 2A. Camera Detection Ping / Warning
def gen_camera_detect():
    duration = 0.22
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * (t / duration)) ** 1.2
        # Rising dual-tone high frequency ping
        freq1 = 1200.0 + 800.0 * (t / duration)
        freq2 = 1800.0 + 1200.0 * (t / duration)
        s = (math.sin(2 * math.pi * freq1 * t) * 0.6 + math.sin(2 * math.pi * freq2 * t) * 0.4) * env * 0.35
        samples.append(s)
    write_wav("camera_detect.wav", samples)

# 2B. High-Security Alarm Siren (2-tone oscillating)
def gen_alarm_siren():
    duration = 1.2
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        # Envelope with fast attack and sustained pulse
        env = min(1.0, t * 10.0) * min(1.0, (duration - t) * 4.0)
        # Oscillate between 900 Hz and 1400 Hz at 4 Hz modulation
        freq = 1150.0 + 350.0 * math.sin(2 * math.pi * 4.0 * t)
        # Add slight square-ish harmonics for industrial siren edge
        s = (math.sin(2 * math.pi * freq * t) * 0.7 + math.sin(2 * math.pi * freq * 2.0 * t) * 0.25) * env * 0.45
        samples.append(s)
    write_wav("alarm_siren.wav", samples)

# 2C. Electrical Spark / Disable
def gen_spark_disable():
    duration = 0.35
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = (1.0 - t / duration) ** 2.5
        # Noisy crackle with decaying buzz
        noise = (random.random() * 2.0 - 1.0) * 0.7
        buzz = math.sin(2 * math.pi * 180.0 * t) * 0.4 + math.sin(2 * math.pi * 360.0 * t) * 0.3
        s = (noise + buzz) * env * 0.5
        samples.append(s)
    write_wav("spark_disable.wav", samples)

if __name__ == "__main__":
    make_security_camera()
    make_laser_emitter()
    gen_camera_detect()
    gen_alarm_siren()
    gen_spark_disable()
