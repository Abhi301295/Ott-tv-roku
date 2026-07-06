# Live TV pixel parity spec

Source of truth: `lg-samsung-tv-player/src/features/livetv/index.tsx`  
Canvas: **1920×1080** (FHD_1080). Netflix header overlays hero (React `h-screen` + fixed header).

## Page split

| Region | React | px @ 1080 |
|--------|-------|-----------|
| Hero | `h-[45vh]` | 486 |
| EPG | `h-[55vh]` | 594 |
| Page bg | `bg-[#0C111A]` | `#0C111A` |

## Hero

| Element | React class | Value |
|---------|-------------|-------|
| Backdrop | `opacity-70`, fade `opacity-30` 150ms, `duration-300` | 0.7 / 0.3 |
| Backdrop position | `objectPosition: center 20%` | scaleToZoom |
| Left gradient | `from-[#0C111A] via-[#0C111A]/85 w-[60%]` | 1152px wide |
| Bottom gradient | `from-[#0C111A] via-[#0C111A]/30` | bottom vignette |
| Meta anchor | `bottom-6 left-10 max-w-[50%]` | y=198, x=40, maxW=960 |
| Spotlight | `text-pink-500 text-sm font-extrabold tracking-wider uppercase mb-1` | `#ec4899`, 14px |
| Title | `text-4xl font-extrabold tracking-tight leading-tight mb-2` | white, 36px |
| Time | `text-gray-300 text-sm font-semibold mb-2` | `#d1d5db`, 14px |
| Description | `text-gray-400 text-sm leading-relaxed mb-5 line-clamp-3` | `#9ca3af`, 14px, maxW=960, 69px |
| Play Now | `px-6 py-3 rounded-full bg-[#E5007A]` focus `scale-105 ring-4 ring-[#E5007A]/50` | h=44, pad 24×12 |
| Play Beginning | `border-white/40 bg-transparent` focus `bg-white/10 border-white` | outline PNG, transparent fill |
| EPG grid lines | `border-white/5` | `#ffffff` @ 5% → `0xffffff0d` |
| Button gap | `gap-4` | 16px |

## EPG grid

| Constant | React | Value |
|----------|-------|-------|
| `PIXELS_PER_MINUTE` | const | 10 |
| `ROW_HEIGHT` | const | 90 |
| `TIMELINE_HEIGHT` | `ht-48` | 48 |
| `VIEWPORT_HEIGHT` | scroll centering | 380 |
| Channel col | `w-[200px]` | 200 |
| EPG top border | `border-t border-white/5` | `#ffffff` @ 5% |
| Grid clip | `calc(55vh - 48px)` | 546 |

## Timeline

| Element | React | Value |
|---------|-------------|-------|
| Corner | `w-[200px] px-6 text-sm font-medium` | "Today", 14px semibold |
| Markers | `text-xs font-semibold text-gray-400`, `-translate-x-1/2` | 12px, centered |
| Interval | 30 min | |
| Live dot | `w-2.5 h-2.5 bg-[#E5007A] ring-4 ring-[#E5007A]/30` | 10px |
| Live line | `w-[1.5px] bg-[#E5007A]` at `left + 200` | 2px (device) |

## Channel cell

| Element | React | Value |
|---------|-------------|-------|
| Padding | `px-4 gap-3` | 16, 12 |
| Logo box | `h-12 w-[70px] bg-white/5 border-white/10 rounded` | 70×48 |
| Name | `text-sm font-semibold` focused `text-white` else `text-gray-300` | 14px |
| Number | `text-sm text-zinc-400 font-medium` | 14px, `#a1a1aa` |
| Focused | `bg-[#151D2A] border-[#E5007A] scale-[1.01] shadow-lg shadow-[#E5007A]/25` | |

## Program card

| Element | React | Value |
|---------|-------------|-------|
| Padding | `p-3` | 12px |
| Time | `text-[11px]` focused `text-[#E5007A]` else `text-gray-400` | 11px |
| Title | `text-[14px] font-semibold text-white` | 14px |
| Duration | `text-[11px] text-gray-500` | 11px, `#6b7280` |
| Unfocused bg | `bg-[#0B0F17]/30` | `#0B0F17` @ 30% |
| Focused | `bg-[#151D2A] border-[#E5007A] scale-[1.01] shadow-[0_0_15px_rgba(229,0,122,0.35)]` | |
| Borders | `border-r border-b border-white/5` | 1px `#ffffff` @ 5% |

## Navigation (React focus keys)

| Key | Behavior |
|-----|----------|
| Initial | `PROGRAM_0_{liveIndex}` after 100ms |
| Program UP row 0 | `HERO_PLAY_NOW_BTN` |
| Program UP/DOWN | overlap + center-distance algorithm |
| Program LEFT first visible | `CHANNEL_ROW_{n}` |
| Channel RIGHT | `PROGRAM_{n}_{focusedProgramIndex}` |
| Channel UP row 0 | `HERO_PLAY_NOW_BTN` |
| Play Now UP | `FocusKey.HEADER` |
| Play Now DOWN | `PROGRAM_0_{focusedProgramIndex}` |
| Horizontal scroll | margin 150px, viewport − channel col |

## Roku mapping

All coordinates live in `source/lib/livetv/LiveTvLayout.brs`.  
Colors in `source/lib/livetv/LiveTvConstants.brs`.
