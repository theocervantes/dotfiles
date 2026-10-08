# Coding standards

## Rails

- Vanilla Rails first. Reach for what the framework already gives you before
  adding a gem, a layer, or a pattern.
- Logic lives in models, concerns, controllers, and jobs. No service objects
  or interactors by default; propose one only when there is a concrete reason.
- Callbacks are fine for an object's own invariants. Don't use them to reach
  into other objects or trigger distant side effects.
- Name methods after the domain: `post.publish!`, not `post.update!(status: "published")`
  scattered across callers.
- Test behavior, not implementation. Use real database interactions and keep
  mocking to a minimum.
- Boring and explicit over clever. If a reader has to stop and decode it,
  rewrite it.
