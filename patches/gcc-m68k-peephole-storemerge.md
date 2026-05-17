# Fix peephole2 miscompile of paired adjacent zero stores in `gcc/config/m68k/m68k.md`

Companion notes for [`gcc-m68k-peephole-storemerge.patch`](gcc-m68k-peephole-storemerge.patch).
Suitable for use as a PR description against
[AmigaPorts/gcc](https://github.com/AmigaPorts/gcc) branch `amiga6`.

## Summary

The fork-added "combine clr" peephole at
[`gcc/config/m68k/m68k.md` line 9181][peep] silently corrupts the second
store when two adjacent zero-store insns have different memory modes
(e.g. `HI` then `SI`). It merges them into a single clear sized by the
**first** insn's mode only, dropping the bytes past the first store's
end. zlib 1.3.1's `trees.c` `bi_windup` is one real-world canary; the
result is that every `libz.a` built with amiga-gcc at `-O2` produces
deflate streams with a phantom `0x00` byte before the Adler32, which
`inflate` rejects as `Z_DATA_ERROR`.

The fix is a one-line additional condition that requires both matched
insns' modes to be equal before allowing the merge.

[peep]: https://github.com/AmigaPorts/gcc/blob/amiga6/gcc/config/m68k/m68k.md#L9181

## Reproducer (minimal)

```c
typedef unsigned short ush;
struct s { char p[5810]; ush a; int b; };
void f(struct s *s) { s->a = 0; s->b = 0; }
```

Compiled with `m68k-amigaos-gcc -O2 -c`:

| Before patch | After patch |
| --- | --- |
| `clr.l 5810(a0)` (4 bytes — **wrong**, covers only 4 of 6 needed bytes) | `clr.w 5810(a0)`; `clr.l 5812(a0)` (correct) |

## Root cause

The peephole pattern:

```
(define_peephole2
  [(set (mem (plus (match_operand:SI 0 …) (match_operand:SI 2 …))) (match_operand 1 …))
   (set (mem (plus (match_dup 0)            (match_operand:SI 3 …))) (match_dup 1))]
  "(operands[4] = SET_DEST(PATTERN(insn))) && 
   …
   INTVAL (operands[2]) + GET_MODE_SIZE(GET_MODE(operands[4])) == INTVAL (operands[3])"
  [(set (match_dup 5) (match_dup 1))]
{
  operands[5] = gen_rtx_MEM(GET_MODE(operands[4]) == HImode ? SImode : DImode,
                            gen_rtx_PLUS(SImode, operands[0], operands[2]));
})
```

`operands[4]` is the **first** insn's `SET_DEST`. Both the
offset-adjacency check (`INTVAL(2) + size_of_first == INTVAL(3)`) and
the merged-store mode (`HImode ? SImode : DImode`) are derived from the
first insn alone. The second insn's mode is **never inspected**. When
the two modes differ — `HI` then `SI` is the common case — the offset
check still passes (the gap is 2 bytes, which matches the first's
`HImode` size), but the merged `SImode` clear only covers 4 of the 6
needed bytes. The tail of the second store is silently lost.

The trigger is a five-way coincidence:

1. Both source-level values are literal `0`.
2. Smaller-sized field stored first (e.g. `ush` then `int`).
3. The two fields are adjacent in memory (no padding).
4. Accessed via pointer + displacement (e.g. deep inside a heap struct),
   not at offset 0 of a stack local.
5. `-O2` or higher.

So it stays invisible in most code (initializer lists, `memset`,
same-size pairs) but bites compression libraries / hash tables / parser
state structs that pair small-then-larger zero stores at non-trivial
offsets. zlib's `deflate_state` has `ush bi_buf; int bi_valid;` cleared
together in three functions (`bi_flush`, `bi_windup`, `_tr_init`) —
all three are miscompiled.

## Where the bug surfaced

`zlib 1.3.1` compiled with this toolchain produced deflate streams that
`inflate` rejected with `Z_DATA_ERROR`. RTL-dump bisection through the
gcc passes located the corruption at `peephole23` (the third
`peephole2` run), with `Splitting with gen_peephole2_57` deleting the
two original stores and emitting one undersized clear. Mapping that
back through `m68k.md` identified this peephole as the culprit.

`git blame` shows the peephole was added by the fork in
[`472bcfa22`](https://github.com/AmigaPorts/gcc/commit/472bcfa22)
(2024-09-16) — not present in upstream gcc.

## The fix

Reject the merge unless both matched insns have the same mode.
`peep2_next_insn(1)` is the safe peephole2 API for accessing the second
matched insn:

```diff
   "(operands[4] = SET_DEST(PATTERN(insn))) && 
+  /* BUGFIX: only merge SAME-SIZE adjacent zero stores. Without this
+   * the peephole merges e.g. HI + SI into a single SI clear, which
+   * covers 4 of the 6 needed bytes — silently corrupting the second
+   * store's tail. Surfaced via zlib trees.c (bi_buf:ush + bi_valid:int).  */
+  GET_MODE (operands[4]) == GET_MODE (SET_DEST (PATTERN (peep2_next_insn (1)))) && 
   (TARGET_68080 || GET_MODE_SIZE(GET_MODE(operands[4])) == 2) && 
```

When the modes match (`HI+HI`, `SI+SI`) the peephole fires as designed
(`.w + .w → .l`, `.l + .l → .q` on 68080). When they differ, the
peephole falls through and the two original stores are emitted
unchanged.

(`prev_active_insn(insn)` was tried first but segfaults on insns whose
previous neighbour isn't a `SET` — JUMPs, NOTEs, USE/CLOBBER — which
the peephole2 framework legitimately considers as match candidates.
`peep2_next_insn(N)` is the standard API and is guaranteed to return a
SET-pattern insn for the matched slots.)

## Verification

Toolchain rebuilt with patch applied (3 ms patch step, ~30 min for the
full toolchain rebuild). Then:

1. `bi_windup` disasm in the new `libz.a`:
   ```
   clr.w 5812(a0)
   clr.l 5814(a0)
   ```
   (Was: `clr.l 5812(a0)`.)

2. `zlib-roundtrip-c` (six test cases: ASCII, git-tree-shaped, redundant
   2KB, every-byte-0..255, single NUL, etc.) — all six pass, byte counts
   match Linux zlib 1.3 output exactly: 13, 53, 232, 70, 9, 267.

3. Rebuilt the entire amiga-gcc toolchain end-to-end with no other
   regressions; binutils, newlib, gcc itself, sfdc, fd2sfd, vasm/vbcc/
   vlink, libnix, ixemul, clib2, libdebug, libpthread, ndk, zlib all
   build and link clean.

## Audit note

It's worth grep'ing for other places in the amiga-gcc-shipped libraries
that pair small-then-larger zero stores — they're equally affected,
just less noisy than zlib's deflate stream getting a phantom byte. The
patch fixes all of them at once.
