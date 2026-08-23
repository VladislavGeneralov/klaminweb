# Klamin

Gridless circular sequencer for mobile browsers — a spinning disc instead of a step grid, in the spirit of Theremin's rhythmicon. Drop minerals anywhere on the disc; each one sounds as it passes a fixed playhead while the disc spins. No quantization by default (a toggle is planned).

Current state: a working single-file spike (`index.html`), no build step, no dependencies. Open it directly in a browser.

## Why it's built this way

The instrument lives or dies on timing precision and on the visual never lying about the audio, so a few decisions were made deliberately rather than by default:

- **Sound is scheduled on the Web Audio clock, never on `requestAnimationFrame`.** A lookahead scheduler ticks every ~40ms and queues `AudioBufferSourceNode.start(time)` ~150ms ahead on `audioContext`'s own clock. rAF drives only what's drawn on screen.
- **Rotation is a sequence of exponential ramp segments**, not a single speed value. Play/pause spins the disc up/down with real (exponential) inertia, like a turntable motor; the speed fader uses the same mechanism with a much shorter time constant so it feels near-instant. Every new ramp reads the *actual live* speed of whatever ramp is currently active as its own starting point — interrupting a ramp mid-flight never produces an audible or visual jump.
- **Geometry is two fixed reference frames**, not one. Each mineral holds a fixed angle offset from the disc's own rotating zero-mark; the playhead is a fixed radial spoke in screen space that never rotates. A mineral's position is purely angular — radius is spacing only, it has no effect on sound.
- **A mineral's visual *spin* is deliberately not derived from its position.** Position (`thetaOffset`) says where the dot sits; a separate `rotBase` (the disc's own angle at the exact moment it was set down) says how it's rotated — drawn as `discAngle - rotBase`. It keeps whatever orientation it had while being carried (upright, same as the palette icon and the drag preview) and only turns by however much the disc spins *after* being placed. The alternative — deriving rotation from position, so it's "glued flat" at a fixed disc-relative angle — was rejected because it makes the image snap to a new orientation the instant it's dropped, with nothing during the drag to telegraph what that'll be.
- **Any state change (speed, add/remove/move a mineral) cancels not-yet-played scheduled audio and recomputes fresh from the live rotation state.** Dragging a mineral mutes it for the duration of the drag and only triggers a recompute on release; the speed fader recomputes continuously, on every input event, since live tempo control is the point of it.
- **Visual feedback for a trigger (the flash) is never driven by the scheduler.** The scheduler only queues audio. The render loop independently re-derives, every frame, from the same closed-form angle formula, whether a mineral just crossed the playhead — otherwise the flash would visibly lead the sound by the whole lookahead window (~150ms), which is the classic bug in this kind of system.
- **Layout is sized once from the smallest guaranteed viewport (`100svh`), not measured ad hoc**, with a sanity-check retry (via `ResizeObserver`) if an early reading comes back implausibly small. Combined with `touch-action`/`overscroll-behavior` locks, the page never needs to scroll. Even on desktop the app renders inside a fixed portrait frame — it's a phone instrument first.
- **Mineral sounds are real recorded samples**, loaded via `fetch` + `decodeAudioData`, decoded before the user ever touches the screen. There are 9 mineral slots (kept to 9, not 10, so the quantize toggle fits in the header), each with 2 sample banks (`samples/N/N_1.wav`, `samples/N/N_2.wav`); a toggle swaps the whole kit's timbre live. `AudioContext` itself is created and unlocked exactly once, on the first play tap, and is never suspended again afterward.
- **Quantization is a toggle, not a mode baked into placement.** Off (default): a mineral's angle is whatever you dropped it at — fully free. On: 16 evenly spaced radial slots (relative to the disc's own rotating zero-mark, not the screen) are always visible as a faint dark grid, turning gold while quantize is active; a dropped mineral's true position is snapped to the nearest slot immediately (so audio timing is correct from the first frame), and only the *visual* dot animates from your drop point to the slot over ~0.2s.
- **Radius never means "slot taken."** Sound only depends on angle, so several minerals can legitimately share one quantize line at different radii — that's not a collision, just a stack on the same spoke. A real collision (same line *and* close radius, or close pixel proximity in freeform) resolves by nudging — freeform slides the angle to whichever side is closer to where you dropped; quantize keeps the snapped angle exactly and slides the *radius* along that same line instead. The "fly back" reject is reserved for the dead zone now, nothing else.
- **The quantize "catch" glow is a plain pixel distance, not an angle.** While quantize is on, the drag ring turns gold once you're within one mineral's diameter (in screen pixels, computed as arc length at the drag's own radius) of a line — snapping itself always finds the nearest line regardless, this is purely a "you're about to catch here" cue, deliberately not lit for the whole wedge.

## Mobile performance pass

A real issue found and fixed: `canvas.getBoundingClientRect()` was being called from several hot paths — every rAF frame while any mineral was mid-drag or mid-snap-animation, and on every raw `pointermove` event during a drag (which can fire faster than rAF on some touchscreens). That's a forced synchronous layout read each time. Since the layout here is fixed (no scroll, sized off `svh`), the canvas only actually moves on a real resize — its position is now cached (`canvasRect`) once in `applySize()` and on `resize`/`orientationchange`, and every other call site reads the cache instead.

Smaller fixes in the same pass: `ctx2d.shadowBlur` (a real per-draw cost on some mobile canvas backends) is now only set while a mineral is actually flashing or lifted, not as a constant low-level glow on every idle mineral every frame; the handful of `rgba(...)` strings that never change frame-to-frame (grid color, zero mark, playhead, catch rings) are computed once at load instead of re-parsed from hex every frame; the `disk.some(closure)` flash check became a plain loop to drop the per-frame closure allocation.

Checked and not a concern at the current scale: mineral photos are 410×410, ~150-225KB each (~1.65MB total, fine over LAN or GitHub Pages, only worth revisiting if the palette grows a lot); the scheduler's `setInterval` tick is O(minerals) with a handful of Newton-Raphson iterations, negligible; `ctx2d.save()/rotate()/restore()` per mineral (for the disc-relative spin) is a normal, cheap canvas operation at 9 minerals.

## Open / not yet built

- No cap on mineral count.
- No save/load — sessions are ephemeral by design.

## Visual style

Fixed token set, defined once in `:root` and read into a JS `THEME` object at load (`getComputedStyle`) so canvas drawing can never drift from the CSS values — there is exactly one place that defines what "gold" or "panel" means.

| Token | Value | Used for |
|---|---|---|
| `--bg` | `#000000` | Page background, disc's center hub |
| `--panel` | `#171310` | Header strip and the bar under the fader (same tone, deliberately) |
| `--ink` / `--ink-dim` | `#ece6da` / `#8c8375` | Body text color (mostly unused — see below) / toggle borders and label text, always, regardless of on/off state |
| `--accent` | `#e3a458` | Fader thumb, disc-zero mark, valid-drop ring |
| `--accent-dim` | `#7a5a34` | Play button fill |
| `--edge` | `#0e0b08` | All borders and deep insets (fader track, mineral/button outlines) |
| `--gold` | `#d4af37` | Disc rim, dead-zone ring, quantize grid, playhead marker, toggle knobs — always gold, on or off, on/off is shown by the knob's position alone |
| `--vinyl` | `#241608` | Disc body |
| `--danger` | `#c4503c` | Invalid-drop ring |
| `--ivory` | `#f2ede2` | Fixed playhead spoke |

Rules that go with the tokens, not just the values:

- No gradients anywhere, CSS or canvas — including soft inset-shadow bevels that only *simulate* a gradient (tried once on the buttons, read as dated "2000s glossy" style, removed). Flat fills, hard-edged borders only.
- No visible text labels except the single-letter "B" / "Q" on the two mode toggles — added deliberately once the toggles moved out of the palette and needed to identify themselves on their own.
- The fader and the two mode toggles all share one visual language: a bordered rectangular track with a rectangular knob — nothing round-and-thin like a native slider. The toggles live outside the disc now, top-left ("B", bank) and top-right ("Q", quantize), oriented vertically.
- The disc itself reads as a vinyl record on purpose: dark brown body, gold rim, gold ring at the dead-zone boundary, black center dot.
- Two matching arrow markers, not lines: the zero mark (inside the dead-zone ring, rotates with the disc) and the playhead marker (outside the rim, fixed in screen space, pointing inward) are both filled, both gold — the zero mark long and narrow, the playhead noticeably shorter and squatter, so they read as a pair without being identical.
- A control's border must contrast with its own fill, not just with the panel behind it — `--edge`-on-`--edge` (fader/button borders) is invisible-by-design since those sit on a lighter surface; anything that itself sits on a dark ground (the toggles) borders in `--ink-dim` instead.
- Minerals are real photos (`minerals/N.png`, transparent-background cutouts), not flat color dots — in the palette, on the disc, and in the drag preview. The flat `MINERAL_COLORS` palette still exists as a fallback (a photo that hasn't loaded, or is missing) and as the tint behind each mineral's glow/shadow.
- The dragged-from-palette preview is a real DOM element (`#dragGhost`, `position: fixed`), not drawn on canvas — canvas is clipped to `discWrap`'s box and can't render above the palette panel while a new mineral is still being dragged over it. Everything else (on-disk minerals, the snap-into-place animation) stays canvas-drawn since it never needs to leave the disc's own bounds.

## Running it

Opening `index.html` directly via `file://` breaks sample loading — `fetch()` of local files is blocked by the browser. Double-click `start.lnk` (or `start.bat`): it starts a local static server (`python -m http.server 8080`) and opens `http://localhost:8080`. For testing on an actual phone, open the machine's LAN IP on port 8080 from the phone, same wifi network.
