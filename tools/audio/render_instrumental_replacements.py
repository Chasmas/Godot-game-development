#!/usr/bin/env python3
"""Guaranteed-instrumental fallbacks for vocal-risk soundtrack cues.

Every signal is procedurally synthesized from oscillators, filters and noise.
There are no voice samples, vocal models or speech-like synthesis paths.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from gen_audio import Seq, acid_note, bass_note, clap, delay, env_exp, hat, hp, kick, lead, lp, master, noise, pad_chord, pluck, reverb, render_ogg, sat, sine


def motel_combat():
    s = Seq(115, 48); beat = s.beat; bar = beat * 4; roots = (40, 40, 43, 38)
    for i in range(s.bars):
        root = roots[(i // 4) % 4]; t = i * bar
        if i % 4 == 0: s.add(pad_chord([root + 12, root + 15, root + 19], bar * 4, 1550), t, .28)
        for b in range(4): s.add(kick(.32, 1.2), t + b * beat, .8)
        s.add(clap(.18), t + beat, .34); s.add(clap(.18), t + 3 * beat, .34)
        for step in range(16):
            time = t + step * s.step
            if step % 2 == 0: s.add(bass_note(root + (12 if step in (6, 14) else 0), s.step * .9, 950, 2.6), time, .38)
            if step % 4 in (1, 3): s.add(hat(.035), time, .075)
            if i >= 8 and step in (3, 7, 10, 14): s.add(acid_note(root + 19 + (step % 3) * 3, s.step * .9, 500, 2400, step == 14), time, .18)
    render_ogg("st_motel_combat", master(reverb(s.buf, .17) + delay(s.buf * .16, .19, .27, .18), .76))


def motel_stealth():
    s = Seq(80, 32); bar = s.beat * 4; roots = (33, 33, 31, 35)
    for i in range(s.bars):
        root = roots[(i // 8) % 4]; t = i * bar
        if i % 4 == 0: s.add(pad_chord([root + 12, root + 15, root + 19], bar * 4, 720, .012), t, .5)
        s.add(bass_note(root, bar * .95, 240, 1.3), t, .23)
        for step in (3, 11): s.add(pluck(root + 24 + (i % 3), .65, 1200), t + step * s.step, .10)
        s.add(hp(noise(bar), 4200) * env_exp(bar, 1.6), t, .018)
    render_ogg("st_motel_stealth", master(reverb(s.buf, .48, 1.4), .55))


def story_firewatch():
    s = Seq(68, 34); bar = s.beat * 4; roots = (38, 41, 36, 43)
    for i in range(s.bars):
        root = roots[(i // 8) % 4]; t = i * bar
        if i % 4 == 0: s.add(pad_chord([root + 12, root + 15, root + 19, root + 22], bar * 4, 900, .011), t, .55)
        s.add(bass_note(root - 12, bar * .88, 230, 1.1), t, .13)
        if i % 2 == 1:
            for j, note in enumerate((root + 24, root + 27, root + 31, root + 27, root + 24)):
                s.add(pluck(note, .9, 1550, .28), t + (j + 1) * s.beat * .54, .14)
        s.add(lp(noise(bar), 2400) * env_exp(bar, .65), t, .008)
    render_ogg("st_story_firewatch", master(reverb(s.buf, .62, 1.8), .55))


def arcade_one():
    s = Seq(145, 56); beat = s.beat; bar = beat * 4; roots = (40, 43, 38, 45)
    for i in range(s.bars):
        root = roots[(i // 4) % 4]; t = i * bar
        if i % 4 == 0: s.add(pad_chord([root + 12, root + 16, root + 19], bar * 4, 2400, .008), t, .22)
        for b in range(4): s.add(kick(.24, 1.05), t + b * beat, .72)
        s.add(clap(.16), t + beat, .27); s.add(clap(.16), t + 3 * beat, .27)
        for step in range(16):
            time = t + step * s.step
            s.add(hat(.025), time + s.step * .5, .06)
            if step % 2 == 0: s.add(bass_note(root + (12 if step in (6, 14) else 0), s.step * .8, 1150, 2.0), time, .32)
            if step in (1, 5, 9, 13): s.add(lead(root + 24 + (step % 3) * 3, s.step * 1.3, .002), time, .11)
    render_ogg("st_arcade1", master(reverb(s.buf, .18), .74))


if __name__ == "__main__":
    motel_combat(); motel_stealth(); story_firewatch(); arcade_one()
    print("Rendered four guaranteed-instrumental fallback masters.")
