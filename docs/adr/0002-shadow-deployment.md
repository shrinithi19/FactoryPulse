# ADR-002: Shadow Deployment

## Status
Accepted

## Decision
Candidate models promoted to "Staging" in the MLflow registry score live
production traffic silently, alongside the current "Production" model.
Staging's outputs are logged and compared but never drive alerts or
work orders. Promotion to Production only happens after the shadow
period shows the candidate is equivalent to or better than the current
model on live data, not just on the offline test split.

## Why
Offline metrics (RMSE, PR-AUC on a held-out split) don't guarantee
real-world performance — the offline test set is still a fixed,
historical sample, and a model can look strong there while behaving
differently on live, slightly-different-distribution traffic (sensor
drift, a machine class underrepresented in the historical data, etc.).
In a predictive-maintenance system, a false negative from a
regressed model isn't just a bad metric — it's a missed failure that
was the entire point of the system. Shadow deployment moves the
"does this actually work" question from a one-time offline check to a
live, low-risk trial before the new model is trusted with real alerts.

## Promotion criteria
A candidate moves Staging → Production only after its shadow-period
outputs are reviewed against the current Production model on the same
live traffic — not on a fixed schedule, and not automatically on shadow
period end. This is a manual, audited promotion (see `users` /
`audit_log` tables), not an automatic gate, because the comparison
involves judgment calls (e.g. is a small RMSE regression on RUL
acceptable if precision on the anomaly side improved) that a single
scalar threshold doesn't capture well at this stage.

## Trade-off
Running two models in inference doubles compute cost on the inference
path for the duration of the shadow period. Accepted because the
platform is explicitly framed around a safety/cost-critical domain
(unplanned downtime, safety incidents from missed faults) where the
cost of a silently-worse model reaching Production is much higher than
the cost of temporarily doubled inference compute.
