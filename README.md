# Polly Voice Target for Internal Audio Readings

> [!WARNING]
> **AI-authored:** This change was autonomously planned and implemented by an AI software factory from a human-authored specification, with possible subsequent human review or modification.

Tests whether small, target-guided EQ moves can push Amazon Polly narration toward the tonal balance of a human reference recording. Every clip in `audio/source/` is rendered against every recording in `audio/target/` with FFmpeg only, using the `target` audio as a directional vector.

```sh
./voicetune/analyze.sh
./voicetune/generate.sh
./voicetune/demo.sh
```

`generate.sh [attempts] [seed]` defaults to 4 attempts per pair. Each attempt moves every band a random 15–50% of the way toward the target (`PULL_MIN`, `PULL_MAX`), capped at ±5 dB (`MAX_GAIN_DB`). Bands are centred at 125, 400, 1400, 3500 and 8000 Hz.

## Notes

- Results do not yield desired direction. Need to identify other approaches.
