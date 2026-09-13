# Performance Checklist

## Contents

- Core Web Vitals thresholds
- Performance budget
- Enforcing the budget in CI
- Pre-merge checklist
- Anti-pattern reference

## Core Web Vitals thresholds

| Metric                              | Good    | Needs improvement | Poor    |
| ----------------------------------- | ------- | ----------------- | ------- |
| **LCP** (Largest Contentful Paint)  | ≤ 2.5s  | ≤ 4.0s            | > 4.0s  |
| **INP** (Interaction to Next Paint) | ≤ 200ms | ≤ 500ms           | > 500ms |
| **CLS** (Cumulative Layout Shift)   | ≤ 0.1   | ≤ 0.25            | > 0.25  |

Measure on representative hardware and network conditions, not on the development machine.

## Performance budget

```
JavaScript bundle: < 200KB gzipped (initial load)
CSS:               < 50KB gzipped
Images:            < 200KB per image (above the fold)
Fonts:             < 100KB total
API response time: < 200ms (p95)
Time to Interactive: < 3.5s on 4G
Lighthouse Performance score: ≥ 90
```

These are starting values. Replace them with numbers derived from the product's own requirements
where those exist, and record where each number came from.

## Enforcing the budget in CI

```bash
# Bundle size against the configured budget
npx bundlesize --config bundlesize.config.json

# Lighthouse, including Core Web Vitals
npx lhci autorun
```

A budget that is not enforced is a comment. Wire at least one of these into the pipeline before
treating the numbers above as real.

## Pre-merge checklist

- [ ] Before and after measurements exist, as specific numbers rather than impressions
- [ ] The specific bottleneck was identified from profiling data, not guessed
- [ ] Core Web Vitals are within the "Good" thresholds
- [ ] Bundle size has not increased without review
- [ ] No N+1 query patterns in new data-fetching code
- [ ] List endpoints paginate
- [ ] Images carry explicit dimensions, lazy loading, and responsive sizes
- [ ] The performance budget passes in CI, where one is configured
- [ ] Existing tests still pass — the optimization did not change behavior

## Anti-pattern reference

| Anti-pattern                         | Cost                                         | Fix                                                   |
| ------------------------------------ | -------------------------------------------- | ----------------------------------------------------- |
| Optimizing without profiling         | Complexity with no measured gain             | Profile first; optimize only what the data implicates |
| N+1 queries                          | Latency grows linearly with result count     | Eager-load or batch the related records               |
| Unpaginated list endpoints           | Response size unbounded by user data growth  | Paginate from the start                               |
| Images without dimensions            | Layout shift, poor CLS                       | Set width and height, use responsive `srcset`         |
| Unreviewed bundle growth             | Load time degrades a little at a time        | Budget in CI so growth is visible in the diff         |
| Memoizing everything                 | Overhead and stale-closure bugs with no gain | Memoize measured hot paths only                       |
| No production performance monitoring | Regressions are found by users               | Report field metrics from real sessions               |
