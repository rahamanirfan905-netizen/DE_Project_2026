# Problem understanding

| Problem | Need and stakeholder | Classification |
|---|---|---|
| P1 | Members need quick Continue Watching, Top 10, My List and genre rows; this affects the personalization/UI experience. | Customer-facing / real-time |
| P2 | Members need responsive title pages, title search and next-episode autoplay; playback and search own this. | Customer-facing / real-time |
| P3 | Members need case-insensitive sign-in and fast profile switching; identity owns this. | Customer-facing / real-time |
| P4 | Content strategy needs a trustworthy report of unwatched episodes, rather than an incorrectly empty result. | Reporting / analytics |
| P5 | Payments and billing need prompt retry, on-hold, monthly-run and dunning workflows. | Operational / time-sensitive |
| P6 | Parents and compliance need evidence that kids profiles stay within maturity limits, and trust needs account-sharing detection. | Compliance / reporting |
| P7 | Content and marketing need scalable binge, completion, device, Originals, ratings and My List analytics as viewing grows 20 times. | Reporting / analytics |
| P8 | Finance needs plan revenue and churn reporting; support needs a responsive activity console. | Mixed: reporting plus customer-facing support |

## Assumptions

- Each export is a consistent snapshot and identifiers are stable across files.
- `completed` is a recorded product event, not a value that can always be recomputed from watched seconds: movies and episodes have different runtimes and viewing data may be partial.
- `amount_inr` records the charged historical amount; it must not be derived from the current plan price because prices or plans can change.
- PostgreSQL timestamps retain the source `+05:30` offset by using `timestamptz`.
