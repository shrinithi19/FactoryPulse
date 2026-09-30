# ADR-001: Anomaly Detection Ensemble

## Status
Accepted

## Decision
Use an ensemble of an LSTM Autoencoder and an Isolation Forest for
per-machine anomaly detection, with adaptive (per-machine) thresholds
rather than fixed global thresholds.

## Why LSTM Autoencoder
Trained to reconstruct healthy sensor windows; high reconstruction
error means the current window no longer looks like the machine's own
healthy baseline. Because it's trained on sequences, it's specifically
good at catching **gradual degradation** — a slow drift that no single
reading looks anomalous enough to flag on its own, but the temporal
pattern does.

## Why Isolation Forest
Isolation Forest scores individual points by how easy they are to
isolate via random splits — outliers isolate in fewer splits. It has no
notion of sequence, which is precisely its complementary value here: it
catches **sudden point anomalies** (a spike, a dropout) that an
autoencoder trained on smooth reconstruction can actually average away
rather than flag, since a single-timestep spike may not move a
window-level reconstruction error much.

Running both and combining their outputs catches both failure
signatures instead of picking one and blind-spotting the other.

## Why adaptive (per-machine) thresholds
A single global threshold either fires constantly on machines that run
naturally "noisier" (more vibration variance by design) or misses
genuine anomalies on quieter machines. Calibrating the threshold per
machine class — using that machine's own healthy-period reconstruction
error distribution (e.g. mean + kσ) — is what keeps the alert engine
from becoming background noise (alarm fatigue), which was one of the
core problems in the original problem statement.

## Trade-off
Two models to train, tune, and keep in sync per machine class instead
of one. Accepted because the two failure modes they catch (gradual vs.
sudden) are genuinely different signals, and losing either one means
missing a real class of faults.
