# SPOM shared relief profile design tree

## Notes

The user invoked grill-with-docs after rejecting SDK30's loss of shaped hard
edges. The implementation must preserve relief silhouettes and join their
displaced profiles. SDK29/30 mask coverage tests did not test that requirement.

## Decisions-so-far

1. Exposed hard edges retain their relief silhouette. Explicit user correction.
2. Neighboring edge heights blend locally to one shared relief profile; each
   surface away from the join retains its detail. Q1 answered yes.
3. Corners retain a sharp angle along the shaped profile. Q2 answered yes.
4. Height5, authored input assets and native collision remain as previously
   requested. The user's `+` confirms the full contract and implementation may proceed.

Design branches:

- Boundary appearance: exposed silhouette / shared profile at a neighbor.
  - Mismatched heights: local adjustment on both sides (settled Q1).
  - Sharp corner: sharp shared contour (settled Q2).
- Proof: compare displaced boundary positions and varying outlines, including
  differing materials/scales, partial joins and convex/concave corners.
- Implementation: derived shared boundary geometry with residual SPOM, delivered
  in SDK31. The binary adjacency mask is removed. Physical/profile regressions
  now cover the confirmed contract; changing height/layout requires rebaking.
- SDK32 correction: collapsed UV return strips use bounded physical depth and
  inherit relief direction/scale from a nearby well-mapped face on the same
  connected surface. Container057/060 renders pass; accepted wall065 geometry
  is exactly unchanged. See M4.05m and the container evidence receipt.

## Fog

- Contract confirmed; no user decision is pending.
- The wall example is accepted as good enough. Container retest, broader human
  appearance, moving-camera and1440p performance acceptance remain pending.
- No unfinished implementation or owned process remains. Await the user's retest
  or new feedback; do not repeat the rejected gap-only approach.
