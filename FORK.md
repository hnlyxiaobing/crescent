# Fork Notice

This repository is a fork of [hnlyxiaobing/crescent](https://github.com/hnlyxiaobing/crescent).

## Why this fork exists

Upstream `hnlyxiaobing/crescent@0.10.0` fails to compile its own white-box tests
under the current MoonBit toolchain. Specifically:

- **File**: `core/request.mbt`
- **Test**: `"try_json returns Ok on valid json"` (line ~293)
- **Problem**: The test calls `assert_eq(result, Ok({ name: "Alice", age: 30 }))`.
  `assert_eq` requires its arguments to implement the `Debug` trait so it can
  format failure messages, but the struct `TryJsonTestUser` only derives
  `FromJson, ToJson, Eq` — not `Debug`.

This breaks any downstream package that depends on `hnlyxiaobing/crescent` when
`moon publish` re-downloads dependencies and re-runs their tests in a clean
environment. Our project [MBOpenClacky](https://github.com/hnlyxiaobing/MBOpenClacky)
was blocked from publishing to mooncakes.io by this exact failure.

## What we changed

Two minimal, non-functional edits in `core/request.mbt`:

1. Added `Debug` to the `derive(...)` list on `TryJsonTestUser`:
   ```moonbit
   } derive(FromJson, ToJson, Eq, Debug)
   ```

2. Bound the expected value to a local variable before `assert_eq`
   (avoids relying on anonymous struct literal trait resolution):
   ```moonbit
   let expected = TryJsonTestUser::{ name: "Alice", age: 30 }
   assert_eq(result, Ok(expected))
   ```

No public API was changed. No behavioral change.

## Version mapping

| This fork | Upstream base | Notes |
|---|---|---|
| `hnlyxiaobing/crescent@0.10.1` | `hnlyxiaobing/crescent@0.10.0` | Debug trait fix only |

## Plan to retire this fork

We will submit this fix as a pull request to `hnlyxiaobing/crescent`. As soon as
upstream merges the fix and publishes a new release, we will:

1. Switch our downstream dependencies back to `hnlyxiaobing/crescent`.
2. Mark this fork as **deprecated** on mooncakes.io and GitHub.

## License

Same as upstream: Apache-2.0. All copyright for the original code belongs to
the upstream authors.
