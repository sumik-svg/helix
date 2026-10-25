Engine_Helix : CroneEngine {
    var <synthGroup;
    var <droneSynth;
    var <cutoff = 3000;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        synthGroup = Group.new(context.xg);

        // 1. Percussive pluck sound for base pairs
        SynthDef(\helix_voice, {
            arg out = 0, hz = 440, amp = 0.4, release = 0.8, pan = 0, filterCutoff = 3000;
            var env = EnvGen.kr(Env.perc(0.005, release, 1, -4), doneAction: 2);
            var sub = SinOsc.ar(hz);
            var tone = LFTri.ar(hz * 2) * 0.15;
            var snd = (sub + tone) * env * amp;
            snd = LPF.ar(snd, filterCutoff.clip(100, 18000));
            Out.ar(out, Pan2.ar(snd, pan));
        }).add;

        // 2. Swelling detuned drone sound (LFO filter modulation)
        SynthDef(\helix_drone, {
            arg out = 0, hz = 65.41, amp = 0.0, baseCutoff = 350, lfoRate = 0.07, lfoDepth = 550, detune = 0.012;
            var smoothedHz = Lag.kr(hz, 2.5); // Smooth portamento
            var smoothedAmp = Lag.kr(amp, 2.0); // Smooth fade in/out
            
            // LFO-driven cutoff breathing and swelling
            var lfo = SinOsc.kr(lfoRate).range(0, 1);
            var dynCutoff = (baseCutoff + (lfo * lfoDepth)).clip(60, 12000);

            // 4 detuned saw/triangle oscillators + sub-oscillator
            var detuneOffsets = [-1, 1, -0.4, 0.4] * detune;
            var oscs = detuneOffsets.collect { arg d;
                var freq = smoothedHz * (1 + d);
                VarSaw.ar(freq, 0, LFTri.kr(0.04 + (d * 0.05)).range(0.2, 0.8))
                + (Pulse.ar(freq * 0.5, 0.5) * 0.35); // Sub-bass 1 octave down
            };

            var sig = Splay.ar(oscs, 0.8); // Spread widely across stereo field
            sig = MoogFF.ar(sig, dynCutoff, 1.8); // Analog-style filter
            sig = sig * smoothedAmp * 0.32;
            Out.ar(out, sig);
        }).add;

        context.server.sync;

        // Spawn persistent drone synth (initial amplitude is 0)
        droneSynth = Synth(\helix_drone, [
            \out, context.out_b,
            \hz, 65.41,
            \amp, 0.0
        ], context.xg);

        this.addCommand("play", "ffff", { arg msg;
            var hz = msg[1];
            var amp = msg[2];
            var release = msg[3];
            var pan = msg[4];
            Synth(\helix_voice, [
                \out, context.out_b,
                \hz, hz,
                \amp, amp,
                \release, release,
                \pan, pan,
                \filterCutoff, cutoff
            ], synthGroup);
        });

        this.addCommand("cutoff", "f", { arg msg;
            cutoff = msg[1];
        });

        this.addCommand("drone_amp", "f", { arg msg;
            droneSynth.set(\amp, msg[1]);
        });

        this.addCommand("drone_hz", "f", { arg msg;
            droneSynth.set(\hz, msg[1]);
        });

        this.addCommand("drone_cutoff", "f", { arg msg;
            droneSynth.set(\baseCutoff, msg[1]);
        });
    }

    free {
        droneSynth.free;
        synthGroup.free;
    }
}