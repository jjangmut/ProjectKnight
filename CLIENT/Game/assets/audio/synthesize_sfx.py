import os
import math
import random
import struct
import wave

AUDIO_DIR = r"D:\JUNYPAPA_STUDIO\Projects\ProjectKnight\CLIENT\Game\assets\audio"
SAMPLE_RATE = 22050

def write_wav(filename, samples, sample_rate=SAMPLE_RATE):
    filepath = os.path.join(AUDIO_DIR, filename)
    # Peak normalization to -1.5 dB (approx 0.84) to avoid any clipping
    max_val = max(abs(s) for s in samples) if samples else 1.0
    if max_val < 1e-6:
        max_val = 1.0
    target_peak = 0.84
    scale = target_peak / max_val if max_val > target_peak else 0.84

    with wave.open(filepath, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        packed = bytearray()
        for s in samples:
            val = int(max(-32767, min(32767, s * scale * 32767)))
            packed.extend(struct.pack('<h', val))
        wf.writeframes(packed)
    print(f"Generated {filename}: {len(samples)} frames ({len(samples)/sample_rate:.2f}s), peak={max_val:.2f}")

def gen_noise(count):
    return [random.uniform(-1.0, 1.0) for _ in range(count)]

def synthesize_all():
    random.seed(42)
    os.makedirs(AUDIO_DIR, exist_ok=True)

    # 1. player_slash_1.wav (Fast crisp blade whoosh)
    dur = 0.10
    n = int(dur * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.pow(1.0 - (i / n), 1.8)
        # Pitch sweep 350 -> 650 -> 250
        freq = 350.0 + 300.0 * math.sin(math.pi * (i / n))
        tone = math.sin(2.0 * math.pi * freq * t) * 0.4
        noise = random.uniform(-1.0, 1.0) * math.pow(1.0 - (i / n), 1.4) * 0.6
        samples.append((tone + noise) * env)
    write_wav("player_slash_1.wav", samples)

    # 2. player_slash_2.wav (Medium blade whoosh)
    dur = 0.12
    n = int(dur * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.pow(1.0 - (i / n), 1.7)
        freq = 280.0 + 400.0 * math.sin(math.pi * (i / n))
        tone = math.sin(2.0 * math.pi * freq * t) * 0.45
        noise = random.uniform(-1.0, 1.0) * math.pow(1.0 - (i / n), 1.3) * 0.55
        samples.append((tone + noise) * env)
    write_wav("player_slash_2.wav", samples)

    # 3. player_slash_3.wav (Heavy finisher blade slash)
    dur = 0.16
    n = int(dur * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.pow(1.0 - (i / n), 1.6)
        freq = 220.0 + 550.0 * math.sin(math.pi * (i / n))
        tone = math.sin(2.0 * math.pi * freq * t) * 0.45 + math.sin(2.0 * math.pi * (freq * 1.5) * t) * 0.15
        noise = random.uniform(-1.0, 1.0) * math.pow(1.0 - (i / n), 1.2) * 0.60
        samples.append((tone + noise) * env)
    write_wav("player_slash_3.wav", samples)

    # 4. enemy_hit_impact.wav (Crisp blade hit impact)
    dur = 0.13
    n = int(dur * SAMPLE_RATE)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / n
        env = math.pow(1.0 - t, 1.6)
        freq = 520.0 - 420.0 * math.pow(t, 0.4)
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        tonal = math.sin(phase) * 0.45
        thump = math.sin(2.0 * math.pi * 85.0 * (i / SAMPLE_RATE)) * max(0.0, 1.0 - t * 4.0) * 0.45
        noise = random.uniform(-1.0, 1.0) * math.pow(1.0 - t, 2.5) * 0.50
        samples.append((tonal + thump + noise) * env)
    write_wav("enemy_hit_impact.wav", samples)

    # 5. enemy_hit_counter.wav (Heavy counter / critical strike impact)
    dur = 0.24
    n = int(dur * SAMPLE_RATE)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / n
        env = math.pow(1.0 - t, 1.4)
        freq = 680.0 - 550.0 * math.pow(t, 0.35)
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        tonal = math.sin(phase) * 0.40
        ring = (math.sin(2.0 * math.pi * 880.0 * (i / SAMPLE_RATE)) + math.sin(2.0 * math.pi * 1320.0 * (i / SAMPLE_RATE))) * 0.20 * math.pow(1.0 - t, 1.2)
        thump = math.sin(2.0 * math.pi * 55.0 * (i / SAMPLE_RATE)) * max(0.0, 1.0 - t * 3.5) * 0.60
        noise = random.uniform(-1.0, 1.0) * math.pow(1.0 - t, 2.2) * 0.55
        samples.append((tonal + ring + thump + noise) * env)
    write_wav("enemy_hit_counter.wav", samples)

    # 6. guard_block.wav (Shield guard block)
    dur = 0.20
    n = int(dur * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.pow(1.0 - (i / n), 2.0)
        thump = math.sin(2.0 * math.pi * 110.0 * t) * 0.45
        clang = (math.sin(2.0 * math.pi * 680.0 * t) * 0.35 + math.sin(2.0 * math.pi * 1420.0 * t) * 0.25) * math.pow(1.0 - (i / n), 1.5)
        noise = random.uniform(-1.0, 1.0) * math.pow(1.0 - (i / n), 2.8) * 0.30
        samples.append((thump + clang + noise) * env)
    write_wav("guard_block.wav", samples)

    # 7. parry_clash.wav (High crystalline ringing clash)
    dur = 0.42
    n = int(dur * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.pow(1.0 - (i / n), 1.2)
        # Dual bell chime 1760 Hz (A6) and 3520 Hz (A7) + harmonic 5280 Hz
        chime = (math.sin(2.0 * math.pi * 1760.0 * t) * 0.40 +
                 math.sin(2.0 * math.pi * 3520.0 * t) * 0.25 +
                 math.sin(2.0 * math.pi * 5280.0 * t) * 0.12)
        # Metallic transient attack in first 0.06s
        trans = random.uniform(-1.0, 1.0) * max(0.0, 1.0 - (i / (0.06 * SAMPLE_RATE))) * 0.55
        # Low punch
        punch = math.sin(2.0 * math.pi * 140.0 * t) * max(0.0, 1.0 - (i / (0.08 * SAMPLE_RATE))) * 0.35
        samples.append((chime + trans + punch) * env)
    write_wav("parry_clash.wav", samples)

    # 8. player_dash.wav (Air dash whoosh)
    dur = 0.15
    n = int(dur * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * (i / n)) * math.pow(1.0 - (i / n), 0.8)
        freq = 300.0 + 800.0 * (i / n)
        noise = random.uniform(-1.0, 1.0) * 0.70
        tone = math.sin(2.0 * math.pi * freq * t) * 0.30
        samples.append((tone + noise) * env)
    write_wav("player_dash.wav", samples)

    # 9. player_hurt.wav (Blunt impact grunt)
    dur = 0.18
    n = int(dur * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.pow(1.0 - (i / n), 1.8)
        thump = math.sin(2.0 * math.pi * (110.0 - 50.0 * (i / n)) * t) * 0.65
        noise = random.uniform(-1.0, 1.0) * math.pow(1.0 - (i / n), 2.5) * 0.40
        samples.append((thump + noise) * env)
    write_wav("player_hurt.wav", samples)

    # 10. dive_slam_impact.wav (Heavy ground slam explosion)
    dur = 0.28
    n = int(dur * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.pow(1.0 - (i / n), 1.5)
        sub = math.sin(2.0 * math.pi * 55.0 * t) * 0.60
        thump = math.sin(2.0 * math.pi * 95.0 * t) * max(0.0, 1.0 - (i / (0.10 * SAMPLE_RATE))) * 0.40
        noise = random.uniform(-1.0, 1.0) * math.pow(1.0 - (i / n), 2.0) * 0.50
        samples.append((sub + thump + noise) * env)
    write_wav("dive_slam_impact.wav", samples)

    # 11. boss_tell_beast.wav (Stage 2 Beast roar telegraph)
    dur = 0.38
    n = int(dur * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * (i / n) * 0.5) * math.pow(1.0 - (i / n), 0.7)
        # FM growl: 120 Hz modulated by 28 Hz
        growl = math.sin(2.0 * math.pi * 120.0 * t + 1.8 * math.sin(2.0 * math.pi * 28.0 * t)) * 0.55
        noise = random.uniform(-1.0, 1.0) * 0.45 * math.pow(1.0 - (i / n), 1.2)
        samples.append((growl + noise) * env)
    write_wav("boss_tell_beast.wav", samples)

    # 12. boss_tell_crossbow.wav (Stage 3 Crossbow mechanical lock/tell)
    dur = 0.22
    n = int(dur * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Three clicks at t=0.02, t=0.08, t=0.14
        click = 0.0
        for ct in [0.02, 0.08, 0.14]:
            dt = t - ct
            if 0.0 <= dt <= 0.025:
                click += math.sin(2.0 * math.pi * 1800.0 * dt) * math.exp(-dt * 300.0) * 0.50
                click += random.uniform(-1.0, 1.0) * math.exp(-dt * 400.0) * 0.40
        samples.append(click)
    write_wav("boss_tell_crossbow.wav", samples)

    # 13. boss_crossbow_fire.wav (Stage 3 Bolt fire release)
    dur = 0.16
    n = int(dur * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.pow(1.0 - (i / n), 1.8)
        twang = math.sin(2.0 * math.pi * (420.0 - 150.0 * (i / n)) * t) * 0.55
        snap = random.uniform(-1.0, 1.0) * max(0.0, 1.0 - (i / (0.04 * SAMPLE_RATE))) * 0.65
        samples.append((twang + snap) * env)
    write_wav("boss_crossbow_fire.wav", samples)

    # 14. boss_tell_golem.wav (Stage 4 Golem seismic rumble telegraph)
    dur = 0.40
    n = int(dur * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.pow(i / n, 0.6) * math.pow(1.0 - (i / n), 0.5) * 1.5
        # Deep tectonic pulse 45 Hz with 15 Hz trembling amplitude modulation
        tremble = 0.6 + 0.4 * math.sin(2.0 * math.pi * 14.0 * t)
        sub = math.sin(2.0 * math.pi * 48.0 * t) * tremble * 0.65
        crackle = random.uniform(-1.0, 1.0) * 0.25 * math.pow(i / n, 1.2)
        samples.append((sub + crackle) * env)
    write_wav("boss_tell_golem.wav", samples)

    # 15. boss_golem_fissure.wav (Stage 4 Fissure rock eruption blast)
    dur = 0.32
    n = int(dur * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.pow(1.0 - (i / n), 1.5)
        boom = math.sin(2.0 * math.pi * 50.0 * t) * 0.55
        crack = random.uniform(-1.0, 1.0) * math.pow(1.0 - (i / n), 1.8) * 0.55
        samples.append((boom + crack) * env)
    write_wav("boss_golem_fissure.wav", samples)

    # 16. boss_tell_abyssal.wav (Stage 5 Abyssal void shimmer telegraph)
    dur = 0.36
    n = int(dur * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * (i / n)) * 0.8
        # Binaural detuned void drone 440 Hz + 445 Hz + sub 110 Hz
        v1 = math.sin(2.0 * math.pi * 440.0 * t) * 0.35
        v2 = math.sin(2.0 * math.pi * 445.0 * t) * 0.35
        sub = math.sin(2.0 * math.pi * 110.0 * t) * 0.30
        samples.append((v1 + v2 + sub) * env)
    write_wav("boss_tell_abyssal.wav", samples)

    # 17. boss_abyssal_strike.wav (Stage 5 Dark void strike burst)
    dur = 0.25
    n = int(dur * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.pow(1.0 - (i / n), 1.6)
        slice_tone = math.sin(2.0 * math.pi * (820.0 - 500.0 * (i / n)) * t) * 0.45
        dark_sub = math.sin(2.0 * math.pi * 65.0 * t) * max(0.0, 1.0 - (i / (0.10 * SAMPLE_RATE))) * 0.45
        noise = random.uniform(-1.0, 1.0) * math.pow(1.0 - (i / n), 2.2) * 0.40
        samples.append((slice_tone + dark_sub + noise) * env)
    write_wav("boss_abyssal_strike.wav", samples)

    # 18. stage_clear_stinger.wav (Triumphant ascending arpeggio fanfare)
    # C5 (523.25), E5 (659.25), G5 (783.99), C6 (1046.50)
    dur = 1.30
    n = int(dur * SAMPLE_RATE)
    samples = [0.0] * n
    notes = [(0.0, 523.25, 0.4), (0.18, 659.25, 0.4), (0.36, 783.99, 0.45), (0.54, 1046.50, 0.60)]
    for start_t, freq, weight in notes:
        start_idx = int(start_t * SAMPLE_RATE)
        note_dur = dur - start_t
        note_n = int(note_dur * SAMPLE_RATE)
        for j in range(note_n):
            idx = start_idx + j
            if idx >= n:
                break
            t = j / SAMPLE_RATE
            env = math.exp(-t * 3.2)
            # Glockenspiel bell harmonics (fundamental + 2nd + 3rd harmonic)
            tone = (math.sin(2.0 * math.pi * freq * t) * 0.60 +
                    math.sin(2.0 * math.pi * (freq * 2.0) * t) * 0.25 +
                    math.sin(2.0 * math.pi * (freq * 3.0) * t) * 0.12)
            samples[idx] += tone * env * weight
    write_wav("stage_clear_stinger.wav", samples)

    # 19. campaign_victory_fanfare.wav (Majestic orchestral chord progression)
    # Chords: F major (F4, A4, C5) -> G major (G4, B4, D5) -> C major triumphant (C4, E4, G4, C5, E5, G5)
    dur = 2.80
    n = int(dur * SAMPLE_RATE)
    samples = [0.0] * n
    chords = [
        # (start_t, dur_c, freqs, weight)
        (0.0, 0.65, [349.23, 440.0, 523.25], 0.40),       # F major
        (0.60, 0.65, [392.00, 493.88, 587.33], 0.45),      # G major
        (1.20, 1.60, [261.63, 329.63, 392.00, 523.25, 659.25, 1046.50], 0.65) # Grand C major
    ]
    for start_t, dur_c, freqs, weight in chords:
        start_idx = int(start_t * SAMPLE_RATE)
        chord_n = int((dur - start_t) * SAMPLE_RATE)
        for j in range(chord_n):
            idx = start_idx + j
            if idx >= n:
                break
            t = j / SAMPLE_RATE
            env = math.exp(-t * (1.8 if start_t < 1.0 else 0.95))
            chord_val = 0.0
            for f in freqs:
                chord_val += (math.sin(2.0 * math.pi * f * t) * 0.45 +
                              math.sin(2.0 * math.pi * (f * 2.0) * t) * 0.18 +
                              math.sin(2.0 * math.pi * (f * 3.0) * t) * 0.08)
            chord_val /= len(freqs)
            samples[idx] += chord_val * env * weight
    write_wav("campaign_victory_fanfare.wav", samples)

if __name__ == "__main__":
    synthesize_all()
