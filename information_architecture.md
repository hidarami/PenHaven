# PenHaven — Information Architecture

## Top-level structure
Root: `SplashScreen` → `OnboardingScreen` (first run only) → `HomeScreen`

`HomeScreen` hosts a horizontal `PageView` of 2–3 panels depending on the
Sanctuary setting:

| Index | Panel            | Sanctuary required? |
|-------|------------------|----------------------|
| 0     | `LibraryPanel`   | No |
| 1     | `StoryPanel`     | No — always the default open panel |
| 2     | `CommunityPanel` | Yes — removed entirely when Sanctuary is off |

Persistent overlay across all panels: `HomePersistentUI` (Sun/Moon indicator
top-left — reserved, never a back button; Search + Menu glass buttons top-right).

## Panel: Library (index 0)
Tabs: **Stories** | **Reflections** (Reflections tab hidden when Sanctuary is off)
- Stories tab → `StoryCard` list → tap → sets `activeStory`, jumps to Story panel
- Reflections tab → `_ReflectionsTab` → received write-backs on your published work

## Panel: Story (index 1, default)
`_HeroCard` (active story) → `EntryCard` list → tap → `EntryReadScreen`
- Floating "+ New Entry" → `AppState.createEntry()` → `EditorScreen`
- Long-press entry → context menu (delete)

## Panel: Community / Sanctuary (index 2, optional)
Tabs: **For You** (featured + category filter) | **Recent** (paginated feed)
- Publish sheet → picks a local entry → `CommunityState.publishEntry`
- Entry card tap → `CommunityEntryViewer`
  - Reflections feed on that entry → `ReflectionViewer`
  - Write Back → `WriteBackSheet` → Private Journal or Publish to Sanctuary → `EditorScreen` with pinned `ReflectionHeaderBlock`

## Entry reading/editing flow
EntryReadScreen (pure reading, no chrome)
├─ swipe right → pop to Story panel
├─ double-tap / long-press → EditorScreen
└─ ActionPill (if published) → clap / respond / share

EditorScreen (block-based WYSIWYG)
├─ back chevron → save → EntryReadScreen (not Story panel)
├─ overflow menu → export (PDF/TXT/image), version history, publish/unpublish
└─ WysiwygToolbar → formatting, block insertion
## Settings tree
`SettingsScreen`
- PRIVACY → App Lock (PIN + biometric) → `PinSetupScreen` / `RecoveryScreen`
- SANCTUARY → on/off toggle (confirmation on disable) — see below
- HELP → replay onboarding
- ABOUT → philosophy card

`AppearanceScreen` (reached from Menu, not Settings)
- DISPLAY → dark mode, dynamic atmosphere
- THEME → `ThemesScreen` (20 manual themes + Dynamic/Auto)
- READING FONT → `FontsScreen`

`MenuPanel` (glass drawer, right-anchored)
- Profile card → `ProfileScreen`
- Journal: Library, Write
- General: Settings, Appearance, Backup & Export, Support link

## Sanctuary toggle — data flow
Off → `AppState.setSanctuaryEnabled(false)`:
1. Persists flag locally (`SharedPreferences`)
2. `SupabaseService.setSanctuaryVisibility(false)` sets `is_hidden = true` on
   all of the user's `published_entries` + `write_backs` rows
3. `HomeScreen` drops the Community panel from the `PageView`
4. `LibraryPanel` hides the Reflections tab (forces index back to Stories)
5. All feed/reflection queries already filter `is_hidden = false`, so content
   disappears from every other user's view without being deleted

On → reverses step 2 (`is_hidden = false`), everything reappears identically.

## Locked state
`AppState.isLocked` short-circuits `HomeScreen.build()` to render `LockScreen`
before any panel is built — locking is a full-screen override, not a route.