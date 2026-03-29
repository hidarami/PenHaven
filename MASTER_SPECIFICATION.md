# FLOW APP - COMPLETE MASTER SPECIFICATION
## Definitive Design Document & Implementation Guide

**Version:** 2.0  
**Last Updated:** February 2026  
**Purpose:** This is the SINGLE SOURCE OF TRUTH for Flow app development. Any AI working on this project should read this document FIRST before making any changes.

---

## TABLE OF CONTENTS
1. [App Philosophy & Core Principles](#philosophy)
2. [Complete Navigation Architecture](#navigation)
3. [Panel-by-Panel Specifications](#panels)
4. [Entry System (Read-Only & Editor)](#entries)
5. [Atmosphere & Visual System](#atmosphere)
6. [UI/UX Interaction Rules](#interactions)
7. [Technical Implementation Details](#technical)
8. [Critical Design Requirements](#critical)
9. [Common Mistakes to Avoid](#mistakes)

---

<a name="philosophy"></a>
## 1. APP PHILOSOPHY & CORE PRINCIPLES

### What Flow Is
Flow is a **premium journaling/writing sanctuary** designed for neurodivergent minds. It is NOT a productivity app. It has no streaks, no guilt, no aggressive prompts. The app breathes with the user and the time of day.

### Design Philosophy
- **Atmosphere over decoration**: The app should feel like being in a physical room at different times of day
- **Gesture over buttons**: No back buttons anywhere - all navigation is swipe-based
- **Mercy over judgment**: Tasks fade instead of turning red, nothing is ever "overdue"
- **Editorial quality**: Text rendering should look like a premium magazine (Medium/Pencake aesthetic)
- **Minimalist coherence**: Every element belongs to the same quiet, warm world

### Key Aesthetic References
- **Text style**: Medium's editorial headings, Pencake's body font
- **Atmosphere**: 3PM golden afternoon silence, the feeling of warm light through windows
- **UI**: Neumorphic (soft raised) for interactive elements, liquid glass for floating menu
- **Color palette**: Warm neutrals (cream, warm white, warm dark), with teal accent (#7BA591)

---

<a name="navigation"></a>
## 2. COMPLETE NAVIGATION ARCHITECTURE

### Root Structure: Three Horizontal Panels
The app has **exactly THREE swipeable root panels** arranged horizontally:

```
[Panel 0: Library] ← [Panel 1: Story Panel] → [Panel 2: Work Desk]
    (Add Stories)      (HOME - Entries)         (Tasks/Capsule)
```

### Panel Order & Starting Point
- **App opens to Panel 1** (Story Panel) - this is the HOME screen
- PageController initialPage: 1
- User swipes LEFT to reach Work Desk (Panel 2)
- User swipes RIGHT to reach Library (Panel 0)

### Navigation Rules - ABSOLUTE
1. **NO BACK BUTTONS ANYWHERE** - The top-left corner is RESERVED for the Sun/Moon indicator
2. **Swipe left-to-right** = go back / go left
3. **Swipe right-to-left** = go forward / go right
4. **Double-tap** = enter edit mode (context-dependent)
5. **Long-press** = edit inline (for tasks, story titles)

### Persistent UI Elements
- **Menu button** (hamburger icon): Top-right corner, ALWAYS VISIBLE, liquid glass style
- **Sun/Moon indicator**: Top-left corner, ALWAYS VISIBLE, code-drawn SVG
- Both elements stay fixed across ALL panels and screens

---

<a name="panels"></a>
## 3. PANEL-BY-PANEL SPECIFICATIONS

### PANEL 0: LIBRARY (Add Stories Panel)
**Location:** Leftmost panel  
**Purpose:** Create and browse stories  
**Access:** Swipe right from Story Panel OR via Menu

#### Visual Layout
```
┌─────────────────────────────┐
│ Library                     │
│ 3 stories              [☰] │
│                             │
│  [Large centered + button]  │  ← When empty
│     "Add New Story"         │
│                             │
│  OR                         │
│                             │
│  [+ Add New Story] button   │  ← When has stories
│                             │
│  ┌─────────────────────┐   │
│  │ Story Title         │   │
│  │ Description...      │   │
│  └─────────────────────┘   │
│  ┌─────────────────────┐   │
│  │ Another Story       │   │
│  └─────────────────────┘   │
└─────────────────────────────┘
```

#### Behavior
- **When empty**: Large centered "+" button (80x80 circle) with "Add New Story" label
- **When populated**: Small "+ Add New Story" neumorphic button at top, then scrollable story list
- **Tapping a story**: Does NOT navigate - stories are selected via Menu, this is just a browser
- **Creating a story**: Opens dialog with title (required) and description (optional) fields
- **Story cards**: Neumorphic style, show title + description (2 lines max, ellipsis)
- **NO IMAGES ANYWHERE** on this panel - images live only inside entries

#### First Time User Experience
When user first opens app and has no stories, Panel 1 shows a special state (see Panel 1 section).

---

### PANEL 1: STORY PANEL (Main/Home Panel)
**Location:** Middle panel - **THIS IS THE HOME SCREEN**  
**Purpose:** Display entries of the active story  
**Access:** App opens here by default

#### Visual Layout - With Entries
```
┌─────────────────────────────┐
│ ☀                      [☰] │
│                             │
│ Story Title                 │
│ Story description           │
│ 5 entries                   │
│                             │
│ ─────────────────────────── │
│ Entry 1:                    │
│ Entry Title Here            │
│ [Preview text...]           │
│ ─────────────────────────── │
│ Entry 2:                    │
│ Another Entry               │
│ [Preview text...]           │
│ ─────────────────────────── │
│                             │
│           [+ Add Entry]     │
└─────────────────────────────┘
```

#### Visual Layout - First Time (No Stories)
```
┌─────────────────────────────┐
│ ☀                      [☰] │
│                             │
│ Story                       │  ← EDITABLE
│ Double-tap or long-press    │
│ to edit                     │
│                             │
│         [no entries]        │
│                             │
│      [+ Add Entry]          │
└─────────────────────────────┘
```

#### Header Section
- **Story title**: Large, bold (Crimson Pro 34-38pt), editable via double-tap or long-press
- **Story description**: Smaller, italic, below title
- **Entry count**: Tiny label "5 entries" in very small font with letter-spacing

#### Entry List
- Each entry shows as a card/row:
  - "Entry N:" label (small, uppercase, letter-spaced)
  - Entry title (large, bold italic, Crimson Pro 22pt)
  - Preview text (2 lines max, ellipsis)
  - Thumbnail image **IF entry has images** (120px height, edge-to-edge)
  - Date + time spent
- **Tapping an entry**: Opens Entry Read-Only Panel (full screen overlay)
- **NO IMAGES FROM ENTRIES** are visible on this panel EXCEPT small thumbnails in preview cards

#### Add Entry Button
- Small "+ Add Entry" button at bottom of list
- Neumorphic style
- Creates blank entry and opens Editor

#### First-Time Behavior
When user has no stories yet:
1. Shows editable "Story" text at top
2. Double-tap or long-press activates inline TextField
3. User types story name, presses Enter
4. Creates story with that name
5. Panel now shows that story's (empty) entry list

---

### PANEL 2: WORK DESK
**Location:** Rightmost panel  
**Purpose:** Tasks, thoughts, and time capsule  
**Access:** Swipe left from Story Panel

#### Visual Layout
```
┌─────────────────────────────┐
│ ☀                 [⏳] [☰] │  ← Time Capsule top-right
│                             │
│ Work Desk                   │
│ Tasks fade. It's okay.      │
│                             │
│ ┌─────────────────────────┐ │
│ │ + Add a thought...      │ │  ← Input field
│ └─────────────────────────┘ │
│                             │
│ ○ Task item here            │
│ ○ Another task              │
│ ○ Buy groceries             │
│                             │
└─────────────────────────────┘
```

#### Components

**1. Header**
- Title: "Work Desk" (large, bold)
- Subtitle: "Tasks fade. It's okay to let go." (italic, muted)
- **Time Capsule icon**: Upper-right corner (opposite title), circle with hourglass icon

**2. Add Task Input**
- Neumorphic container
- "+" icon on left
- Text field: "Add a thought..."
- Calendar icon (toggle deadline)
- Submit arrow button on right

**3. Task List**
- Scrollable list of tasks
- Each task: Circle checkbox + title text
- **Single tap on checkbox**: Marks complete, starts 3-second fade, then auto-archives
- **Long press on task**: Opens inline edit mode (TextField replaces text)
- **Visual**: Neumorphic cards with soft shadows
- **Fading**: AnimatedOpacity from 1.0 to 0.0 over 3 seconds when completed
- After fade completes, task is removed from active list and moved to Archive

**4. Task States**
- **Active**: Visible, editable
- **Completed**: Fades out over 3 seconds
- **Archived** (after 24h or 48h): Moved to Archive (accessible via Menu)

**5. Mercy Rule**
- Tasks with deadline: Auto-archive 24h after deadline
- Tasks without deadline: Auto-archive 48h after creation
- **NO red warnings, NO overdue labels** - they just quietly fade away

---

<a name="entries"></a>
## 4. ENTRY SYSTEM (Read-Only & Editor)

### Entry Data Structure
```dart
Entry {
  String id;
  String storyId;
  String title;
  String content;  // Markdown text
  DateTime createdAt;
  DateTime updatedAt;
  int timeSpentSeconds;
  String moodColor;
  String? headerImage;  // Optional banner image
  List<EntryImage> images;  // In-body images with positions
  bool isDeleted;
}

EntryImage {
  String path;  // File path
  int position;  // Character offset in content
}
```

---

### ENTRY READ-ONLY MODE

**Purpose:** Pure reading experience, magazine-quality rendering  
**Access:** Tap entry from Story Panel  
**Exit:** Swipe left-to-right to return to Story Panel  
**Edit:** Double-tap ANYWHERE on screen to enter Editor

#### Visual Layout
```
┌─────────────────────────────┐
│ [Header Image - optional]   │  ← Full-width, 240px height
│                             │
│  Entry Title                │  ← Justified, 36pt bold
│  Sunday, March 2, 2026      │
│                             │
│  Body text starts here      │
│  with full markdown         │
│  rendering...               │
│                             │
│  [Inline Image]             │  ← If user added images
│                             │
│  More text continues...     │
│                             │
│  Session time: 15m          │
│  Updated Mar 2              │
└─────────────────────────────┘
```

#### Critical Requirements

**1. Header Image (Optional)**
- **Position**: FIRST thing, before title
- **Size**: Full-width, 240px height, edge-to-edge (no horizontal padding)
- **Style**: Rounded corners (16px), subtle gradient overlay at bottom
- **Cropping**: Fit: cover, user chose crop position in Editor
- **If missing**: Skip entirely, start with title

**2. Title**
- **Font**: Crimson Pro, 36pt, bold (700)
- **Alignment**: Justified
- **Color**: Matches atmosphere text color
- **Style**: Medium/editorial heading aesthetic
- **Line height**: 1.15

**3. Date**
- **Format**: "EEEE, MMMM d, yyyy • h:mm a"
- **Font**: Inter, 14pt, medium weight
- **Color**: Muted text color

**4. Body Content**
- **Markdown**: FULLY RENDERED using flutter_markdown's MarkdownBody
- **Font**: Crimson Pro, 18pt, line-height 1.8
- **NO RAW SYNTAX**: Must render `**bold**`, `*italic*`, `### headers`, `> quotes`, etc.
- **Blockquotes**: Left border (4px teal), light teal background, padding 16px
- **Code blocks**: Light grey background, rounded corners, JetBrains Mono font
- **Lists**: Proper indentation (24px), styled bullets/numbers

**5. Inline Images**
- **Source**: entry.images list (separate from header)
- **Display**: Full-width, edge-to-edge, rounded corners (12px)
- **Position**: Wherever they were inserted during editing
- **Spacing**: 16px margin above and below each image
- **Count**: Unlimited

**6. Footer Info**
- Session time (if > 0)
- Last updated date
- Small, muted text (11pt, 50% opacity)

#### Interaction Rules
- **Entire screen is tap target**: Double-tap anywhere enters Editor
- **Swipe left-to-right**: Returns to Story Panel (Navigator.pop)
- **NO visible UI chrome**: No "double tap to edit" labels, no buttons, pure content
- **Text selection**: Standard system selection menu (copy/paste)
- **NO editing capabilities**: Everything is read-only, all edits happen in Editor

#### Navigation Flow
```
Story Panel → Tap Entry → Read-Only Mode → Double-tap → Editor
                ↑                                          ↓
                └──────── Swipe left-to-right ─────────────┘
                                                           ↓
                         ← Back chevron ← (returns to Read-Only)
```

---

### ENTRY EDITOR MODE

**Purpose:** Full editing environment with markdown toolbar  
**Access:** Double-tap anywhere in Read-Only mode  
**Exit:** "<" back chevron (top-left) returns to Read-Only mode

#### Visual Layout
```
┌─────────────────────────────┐
│ <          Read      ... [☰]│  ← Back, Preview, Menu
│                             │
│ [Header Image - tap to add] │  ← Optional, tap to add/change/delete
│                             │
│ Entry Title____________     │  ← Editable TextField
│ March 2, 2026 (editable)    │
│                             │
│ Body text editor area       │  ← Main TextField
│ with cursor...              │
│                             │
│ [Image at cursor position]  │  ← Inline images
│                             │
│ Continue writing...         │
│                             │
├─────────────────────────────┤
│ [B] [I] [H1] [≡] ["] [📷]  │  ← Markdown toolbar
└─────────────────────────────┘
```

#### Header Section
- **"<" back chevron**: Top-left, returns to Read-Only (NOT to Story Panel)
- **"Read" button**: Optional preview toggle
- **"..." menu**: Top-right overflow menu

#### Header Image Area
- **If no image**: Dashed border box "Tap to add header image"
- **If has image**: Shows image with small "×" button overlay to delete
- **Tap to add**: Opens image picker → crop window → saves as headerImage
- **Independent**: Completely separate from inline images in body

#### Editable Fields
1. **Title**: TextField, Crimson Pro 32-36pt, bold
2. **Date**: Tappable, opens date picker to customize
3. **Body**: Large multiline TextField, Crimson Pro 18pt, line-height 1.8

#### Markdown Toolbar (Bottom)
Horizontal scrollable row of buttons:
- **B**: Bold (`**text**`)
- **I**: Italic (`*text*`)
- **H1, H2, H3**: Heading levels (`#`, `##`, `###`)
- **≡**: Alignment (left, center, right, justified)
- **"**: Pull quote / Blockquote (`> text`)
- **🎨**: Highlight (custom syntax `==text==`)
- **📷**: Add image (opens picker → crop → inserts at cursor)

#### Image Insertion Flow
1. User places cursor in text
2. Taps 📷 button in toolbar
3. Opens device image picker
4. User selects image
5. **Crop window opens** (ImageCropper):
   - User can crop however they want OR leave uncropped
   - User can reposition crop area
   - Confirms crop
6. Image is inserted at cursor position as EntryImage(path, cursorPosition)
7. **Renders full-width** in editor (edge-to-edge)
8. User can continue writing after the image

#### Image Positioning Rules
- Images insert **at cursor position**, not at end
- If cursor is at start of document, image goes at top (after header image if exists)
- If cursor is in middle of text, image appears between paragraphs
- If cursor is at end, image goes at bottom
- **Multiple images**: Unlimited, each tracked by position in content

#### "..." Overflow Menu
- Word count (live)
- Export entry (TXT, PDF, Image)
- Delete entry (moves to Bin)
- Session log (shows writing session history)
- Delete picture header (if exists)
- Custom date picker

#### Saving Behavior
- **Auto-save**: Debounced 1200ms after last keystroke
- **On exit**: Saves when user taps back chevron
- **Session time**: Tracks time spent with cursor active in editor

---

<a name="atmosphere"></a>
## 5. ATMOSPHERE & VISUAL SYSTEM

### Philosophy
The atmosphere is the emotional heart of the app. It is NOT just a background color change - it is a multi-layered system that makes the user FEEL the time of day.

---

### Three-Layer Atmosphere System

**Layer 1: Light Streak Overlay** (PRIMARY)
- The most important layer
- Simulated window light projection on the background
- Only appears in specific atmospheres (3PM, Golden Hour)
- Uses blend mode: `screen` or `soft-light`
- Never overlaps text (background layer only)

**Layer 2: Background Tint Shift** (SUBTLE)
- Base background color shifts slightly with atmosphere
- Maximum 8-10% shift from neutral base
- User feels it before consciously noticing it

**Layer 3: Sun/Moon Icon** (ANCHOR)
- Top-left corner indicator
- Anchors the atmosphere visually
- Color shifts with time of day

---

### Light Mode vs Dark Mode Variants

**CRITICAL RULE**: Every atmosphere has TWO versions - one for light mode, one for dark mode. They express the same TIME-OF-DAY EMOTION but in different visual languages.

#### Golden 3PM (The Star Atmosphere)
The app's love letter to the beauty of 3PM afternoon silence. This is the most important atmosphere.

**Light Mode:**
- Base color: Warm cream-gold `#FFF3C4`
- **Window light streak**: Full effect
  - Diagonal bands of soft warm light (30-45° angle)
  - Grid of parallelogram-shaped patches (2×3)
  - Divided by thin shadow lines (mullions)
  - Colors: Soft cream-white `rgba(255, 240, 210, 0.18)` to `rgba(255, 235, 195, 0.25)`
  - Blend mode: `screen` (CRITICAL for realistic light)
  - Covers ~60-70% of screen diagonally
  - Edges heavily feathered (Gaussian blur)
- Warm radial glow from upper-right
- Golden dust motes (animated particles)
- Slow imperceptible drift animation (2-4% movement over minutes)

**Dark Mode:**
- Base color: Deep warm dark `#1E1600`
- **NO light streak** (streaks imply brightness)
- Instead: Soft warm amber radial glow from upper corners
- Like afternoon light seeping around curtains in dark room
- Extremely low opacity (12-15%)
- No particles in dark mode

#### Midnight Ink
**Light Mode:**
- Base: Cooler blue-grey white `#E8E3F5`
- No overlay (clean)
- Feels like well-lit indoor space at night

**Dark Mode:**
- Base: Deep cool dark `#0D0D1A`
- Subtle cool-blue radial glow at top (15% opacity)
- Like moonlight through skylight

#### Sunday Morning
**Light Mode:**
- Base: Clean warm white `#F5F1E8`
- Very faint cool-white radial glow from top

**Dark Mode:**
- Base: Warm dark `#1A1912`
- Faint cool-blue glow at top

#### Golden Hour (Sunrise/Sunset)
**Light Mode:**
- Base: Warm golden white `#FFF0CC`
- Faint diagonal streak from upper-left (softer than 3PM)
- More white than gold

**Dark Mode:**
- Base: Warm dark `#1C1400`
- Faint cool-blue top glow
- Like dawn light starting to appear

#### Rainy / Foggy / Snowy (Weather-based)
These activate when weather API returns relevant conditions.
- Light mode: Blue-tinted backgrounds
- Dark mode: Deep cool darks
- Animated particles (rain streaks, fog waves)

---

### Sun/Moon Indicator Specifications

**Location:** Top-left corner, always visible  
**Size:** 32×32px  
**Drawing method:** Code-drawn SVG (CustomPainter), NEVER emoji or icon library  
**Style:** Thin stroke lines (1.2px), no fills, rounded caps

#### Sun (6 AM - 6 PM)
- Central circle (thin stroke, no fill)
- 8 radiating lines at 45° intervals
- Line lengths slightly irregular (organic feel)
- Total size: ~30px diameter

#### Moon (6 PM - 6 AM)
- Two overlapping circles creating crescent
- Main circle + offset mask circle
- Thin strokes, delicate appearance

#### Color Shifts (CRITICAL)
The indicator color changes based on atmosphere:
- **Golden 3PM atmosphere**: Warm gold `#FFD700` @ 85% opacity
- **Morning (6-10 AM)**: Soft warm white `#FFF8DC` @ 75% opacity
- **Daytime (10 AM-6 PM)**: Neutral warm `#FFE4B5` @ 70% opacity
- **Night**: Cool pale white `#F0F8FF` @ 65% opacity

#### Animation
- Gentle morph between sun and moon (3s ease)
- Subtle breathing pulse (repeat reverse)
- Color transitions smoothly with atmosphere changes

---

### Comfort Mode (Mood Detection)

**Purpose:** Detect when user is writing heavy/sad content and shift background subtly to comfort them.

#### Trigger Words (Requires 3+ matches)
lonely, grief, tired, empty, broken, sad, pain, loss, alone, hurt, dark, hopeless, numb, heavy, weary, overwhelmed, desperate, scared, afraid, anxious, worthless, defeated, forgotten

#### Behavior When Triggered
1. **Slow transition**: 45-60 seconds (implemented as 50 steps over 50 seconds)
   - SO slow user can't pinpoint when it started
   - Feels like the room itself is responding
   
2. **Whisper text** (appears for 3 seconds):
   - Random message: "take your time", "you're not alone", "it's okay", "breathe", "one moment at a time"
   - Position: Bottom-center of screen
   - Style: 16pt Crimson Pro italic
   - Opacity: 15% (barely visible, felt more than seen)
   - Fades in, holds 3s, fades out
   
3. **Color shift**:
   - Light mode → Comfort light `#FFF0E8` (warm peachy-cream)
   - Dark mode → Comfort dark `#2A1E18` (warm deep brown-black)

#### Why This Works
- Slow transition = feels organic, not mechanical
- Whisper connects the change to meaning ("the app noticed")
- User understands: "the app feels my sadness" not "something broke"

---

<a name="interactions"></a>
## 6. UI/UX INTERACTION RULES

### Button & UI Element Styles

#### Liquid Glass (Floating Elements Only)
- **Use for**: Menu button, optional sun/moon background
- **Style**: Frosted, translucent, blurred background (20-28px blur)
- **Properties**:
  - White at 12-18% opacity
  - Border: White at 50% opacity, 0.5px width
  - Backdrop filter blur
  - Soft shadow

#### Neumorphic (All Interactive Elements)
- **Use for**: All buttons, inputs, cards, task items
- **Style**: Soft raised appearance
- **Properties**:
  - Light shadow: top-left (-2, -2), light color, blur 4px
  - Dark shadow: bottom-right (2, 2), dark color, blur 4px
  - Background matches surface (3-5% brightness difference)
  - Fully rounded corners
  - No borders
- **Dark mode adaptation**:
  - Light shadow uses lighter version of dark base (NOT white)
  - Dark shadow goes deeper
  - Effect must still be visible in dark mode

---

### Typography System

#### Fonts
- **Headings**: Crimson Pro (serif, editorial)
- **Body**: Crimson Pro (for entry content, UI labels)
- **UI labels**: Inter (sans-serif, for small system text)
- **Code**: JetBrains Mono (monospace)

#### Sizes & Weights
- **Story/Entry titles**: 34-38pt, bold (700)
- **Entry body**: 18pt, regular (400), line-height 1.8
- **Headings in content**: 
  - H1: 32pt bold
  - H2: 26pt semibold
  - H3: 22pt semibold
- **UI labels**: 11-14pt, medium (500)
- **Small labels**: 10-11pt, semibold (600), letter-spacing 1.5-2.0

#### Text Colors
Always derived from atmosphere:
- **Text color**: `readableText(atmosphereBackground)` - high contrast
- **Muted color**: `readableMuted(atmosphereBackground)` - 60-70% opacity

---

### Gesture System

| Gesture | Context | Action |
|---------|---------|--------|
| Swipe left-to-right | Any root panel | Go to previous panel |
| Swipe right-to-left | Any root panel | Go to next panel |
| Swipe left-to-right | Entry Read-Only | Exit to Story Panel |
| Double-tap | Entry Read-Only | Enter Editor |
| Double-tap / Long-press | Story title | Edit title inline |
| Single tap | Entry in list | Open Read-Only |
| Single tap | Task checkbox | Complete task (fade out) |
| Long press | Task text | Edit task inline |
| Long press | Entry in list | Context menu (delete, etc.) |

---

### Animation Principles

#### Timing
- **Fast interactions**: 200-300ms (button taps, panel switches)
- **Content reveals**: 450-800ms (fade-ins, slides)
- **Atmosphere changes**: 2-3 seconds (slow, breathing)
- **Comfort mode**: 45-60 seconds (imperceptible)

#### Curves
- **Ease out back/quart**: For delightful entrances
- **Ease in out**: For smooth transitions
- **Linear/sine**: For breathing/pulsing animations

#### Delays
- Stagger list items: 70ms increments
- Cascade reveals: 100-200ms increments
- Never delay critical UI (buttons, nav)

---

<a name="technical"></a>
## 7. TECHNICAL IMPLEMENTATION DETAILS

### File Structure
```
lib/
├── main.dart
├── models/
│   └── app_models.dart          # Story, Entry, EntryImage, Todo, etc.
├── providers/
│   └── app_state.dart           # Main state management
├── data/
│   └── database_helper.dart     # SQLite operations
├── services/
│   ├── auth_service.dart        # Biometric lock
│   ├── weather_service.dart     # Weather API
│   ├── image_service.dart       # Image picking & cropping
│   ├── export_service.dart      # TXT/PDF/image export
│   └── permission_service.dart  # Android permissions
├── screens/
│   ├── splash_screen.dart
│   ├── onboarding_screen.dart
│   ├── home_screen.dart         # 3-panel root navigation
│   ├── story_page.dart          # Entry list for a story
│   ├── entry_read_screen.dart   # Read-Only mode
│   ├── editor_screen.dart       # Editor mode
│   ├── work_desk_screen.dart    # Tasks panel
│   └── settings_screen.dart
├── widgets/
│   ├── atmosphere_overlay.dart  # Visual atmosphere layers
│   ├── menu_panel.dart          # Side menu drawer
│   ├── sun_moon_indicator.dart  # Code-drawn time indicator
│   ├── neumorphic_button.dart   # Neumorphic UI components
│   └── glass_pane.dart          # Liquid glass components
└── theme/
    └── app_theme.dart           # Colors, constants
```

---

### Database Schema

#### stories
```sql
CREATE TABLE stories (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  isLocked INTEGER NOT NULL DEFAULT 0,
  isDeleted INTEGER NOT NULL DEFAULT 0
)
```

#### entries
```sql
CREATE TABLE entries (
  id TEXT PRIMARY KEY,
  storyId TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  timeSpentSeconds INTEGER NOT NULL DEFAULT 0,
  moodColor TEXT NOT NULL DEFAULT 'default',
  headerImage TEXT,                    -- Optional header banner
  images TEXT,                         -- JSON: [{path, position}, ...]
  isDeleted INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (storyId) REFERENCES stories (id) ON DELETE CASCADE
)
```

#### todos
```sql
CREATE TABLE todos (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  isCompleted INTEGER NOT NULL DEFAULT 0,
  createdAt TEXT NOT NULL,
  deadline TEXT,
  isArchived INTEGER NOT NULL DEFAULT 0,
  completedAt TEXT
)
```

#### time_capsules
```sql
CREATE TABLE time_capsules (
  id TEXT PRIMARY KEY,
  message TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  openAt TEXT NOT NULL,
  isOpened INTEGER NOT NULL DEFAULT 0
)
```

#### period_logs
```sql
CREATE TABLE period_logs (
  id TEXT PRIMARY KEY,
  startDate TEXT NOT NULL,
  endDate TEXT,
  flowLevel INTEGER NOT NULL DEFAULT 2,
  notes TEXT
)
```

#### app_log
```sql
CREATE TABLE app_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  category TEXT NOT NULL,
  detail TEXT NOT NULL
)
```

---

### State Management (Provider)

#### AppState Properties
```dart
// Data
List<Story> stories
List<Entry> currentEntries
List<Todo> activeTodos, completedTodos
List<TimeCapsule> timeCapsules
List<PeriodLog> periodLogs

// Settings
bool isDarkMode
bool isBiometricEnabled
bool isPeriodTrackerOn
bool hasSeenOnboarding

// Atmosphere
String currentAtmosphere  // 'Normal', 'Golden3PM', 'MidnightInk', etc.
WeatherData? weather

// Editor session
bool isComfortMode
bool isHyperfocusActive
int currentWordCount

// Comfort mode
bool showWhisper
String whisperText
```

#### Key Methods
- `computeAtmosphere()` - Returns atmosphere string based on time/weather
- `checkSentiment(String text)` - Detects heavy words, triggers comfort mode
- `getAtmosphereBg(bool dark)` - Returns background color for atmosphere+mode
- `createStory()`, `saveEntry()`, `addTodo()`, etc.

---

### Dependencies (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2              # State management
  sqflite: ^2.3.3+1             # Local database
  path: ^1.9.0
  uuid: ^4.5.1                  # ID generation
  intl: ^0.19.0                 # Date formatting
  shared_preferences: ^2.3.3    # Settings storage
  google_fonts: ^6.2.1          # Crimson Pro, Inter
  flutter_animate: ^4.5.0       # Animations
  path_provider: ^2.1.4         # File paths
  share_plus: ^10.1.4           # Export sharing
  local_auth: ^2.3.0            # Biometric lock
  image_picker: ^1.1.2          # Photo picker
  image_cropper: ^11.0.0        # Crop images
  pdf: ^3.11.1                  # PDF generation
  http: ^1.2.2                  # Weather API
  geolocator: ^13.0.2           # Location for weather
  permission_handler: ^11.3.1   # Android permissions
  flutter_markdown: ^0.7.3      # Markdown rendering
```

---

### Image Handling

#### Image Picker Flow
1. User taps image button (header or toolbar)
2. `ImageService.pickAndSave()` called
3. Opens system image picker (`ImagePicker`)
4. User selects image
5. **Crop window** opens (`ImageCropper`):
   - User can freely crop or leave uncropped
   - User can reposition crop area
   - Confirms crop
6. Image copied to app's permanent storage:
   - Path: `getApplicationDocumentsDirectory()/flow_images/`
   - Filename: `{timestamp}_{original_name}`
7. Returns file path

#### Storage Structure
- **Header image**: Stored as `Entry.headerImage` (String? path)
- **Inline images**: Stored as `Entry.images` (List<EntryImage>)
- **EntryImage**: `{path: String, position: int}`
- **Position**: Character offset in content where image should appear

#### Display Rules
- **Read-Only**: Full-width (edge-to-edge), rounded corners (12px)
- **Editor**: Full-width while editing, movable cursor position
- **Story Panel thumbnails**: 120px height preview in entry cards
- **NO images** on Library panel or Work Desk

---

### Markdown Rendering

#### Editor (Raw)
- TextEditingController with plain text
- User types markdown syntax: `**bold**`, `*italic*`, `### heading`
- Toolbar buttons insert syntax at cursor position

#### Read-Only (Rendered)
```dart
MarkdownBody(
  data: entry.content,
  selectable: true,
  styleSheet: MarkdownStyleSheet(...),
)
```

**Custom Styles:**
- Paragraphs: Crimson Pro 18pt, 1.8 line-height
- Headings: Crimson Pro, various sizes, bold
- Blockquotes: Teal left border (4px), light teal background
- Code: JetBrains Mono, grey background
- Links: Teal underline

---

### Atmosphere Engine

#### Computation (runs every minute)
```dart
String computeAtmosphere() {
  final hour = DateTime.now().hour;
  
  // Weather overrides (if data available)
  if (weather.condition == 'rainy') return 'Rainy';
  if (weather.condition == 'foggy') return 'Foggy';
  
  // Time-based
  if (hour == 15) return 'Golden3PM';  // The star
  if (hour >= 1 && hour <= 4) return 'MidnightInk';
  if (isSunday && hour >= 7 && hour <= 11) return 'SundayMorning';
  
  return 'Normal';
}
```

#### Color Mapping
```dart
Color getAtmosphereBg(bool dark) {
  if (isComfortMode) {
    return dark ? ComfortDark : ComfortLight;
  }
  
  switch (currentAtmosphere) {
    case 'Golden3PM':
      return dark ? Color(0xFF1E1600) : Color(0xFFFFF3C4);
    case 'MidnightInk':
      return dark ? Color(0xFF0D0D1A) : Color(0xFFE8E3F5);
    // ... etc
  }
}
```

#### Overlay Rendering
`AtmosphereOverlay` widget returns different CustomPainter based on:
- `currentAtmosphere` value
- `isDarkMode` value
Key: `'${atmosphere}_${isDarkMode}'` ensures proper rebuilds

---

<a name="critical"></a>
## 8. CRITICAL DESIGN REQUIREMENTS

### ABSOLUTE RULES - NEVER BREAK

1. **NO BACK BUTTONS**
   - Top-left corner is RESERVED for Sun/Moon indicator
   - Navigation is GESTURE-BASED ONLY
   - Users swipe to go back, no exceptions

2. **THREE PANELS ALWAYS**
   - Home screen has PageView with 3 items
   - PageController initialPage: 1 (middle)
   - Order: Library (0), Story (1), Work Desk (2)

3. **IMAGES ONLY IN ENTRIES**
   - NO images on Story Panel (except tiny thumbnails in previews)
   - NO images on Library Panel
   - NO images on Work Desk
   - Images visible ONLY in Entry Read-Only and Editor

4. **MARKDOWN RENDERING**
   - Read-Only MUST fully render markdown
   - NO raw syntax visible (`**text**` must show as **text**)
   - Use flutter_markdown's MarkdownBody widget
   - Custom StyleSheet for proper fonts/colors

5. **ATMOSPHERE HAS LIGHT & DARK VARIANTS**
   - Every atmosphere defined TWICE
   - Light mode version uses light on bright background
   - Dark mode version adapts (glow instead of streak, etc.)
   - NEVER apply same effect to both modes

6. **HEADER IMAGE FIRST**
   - In Read-Only: Header image appears BEFORE title
   - NOT after title, NOT in middle of content
   - Order: [Header Image] → Title → Date → Body

7. **SWIPE TO EXIT READ-ONLY**
   - GestureDetector wraps content
   - onHorizontalDragEnd with velocity check
   - Positive velocity (right swipe) = Navigator.pop()

8. **EDITOR BACK TO READ-ONLY**
   - "<" chevron in Editor goes to Read-Only
   - NOT to Story Panel
   - Flow: Story → Read-Only → Editor → Read-Only → Story

9. **TASK EDITING VIA LONG PRESS**
   - Single tap on checkbox = complete
   - Long press on text = edit
   - NO edit on single tap

10. **SLOW COMFORT MODE**
    - 45-60 second transition (50 steps)
    - Whisper text for 3 seconds at start
    - Requires 3+ trigger words

---

### Common Visual Requirements

#### Spacing
- Panel padding: 24-28px horizontal
- Vertical spacing: 32-48px between major sections
- List item gaps: 12px
- Icon to label: 8px

#### Rounded Corners
- Cards: 12px
- Buttons: 8-12px
- Images: 12-16px
- Input fields: 8px

#### Shadows (Neumorphic)
- Light shadow: Offset(-2, -2), blur 4px
- Dark shadow: Offset(2, 2), blur 4px
- Both with appropriate alpha based on mode

#### Colors
- Base neutral: `#F7F3EE` (warm white) / `#1A1410` (warm dark)
- Accent: `#7BA591` (teal/sage)
- Text: Derive from `readableText(background)`
- Muted: Derive from `readableMuted(background)`

---

<a name="mistakes"></a>
## 9. COMMON MISTAKES TO AVOID

### Navigation Mistakes

❌ **WRONG**: Two panels (Library merged into Menu)
✅ **RIGHT**: Three swipeable panels - Library, Story, Work Desk

❌ **WRONG**: PageController initialPage: 0 (starts at Library)
✅ **RIGHT**: PageController initialPage: 1 (starts at Story Panel - HOME)

❌ **WRONG**: Back button in top-left corner
✅ **RIGHT**: Sun/Moon indicator in top-left, no back button anywhere

❌ **WRONG**: Tapping entry goes to Editor directly
✅ **RIGHT**: Tapping entry opens Read-Only first, double-tap to edit

---

### Entry System Mistakes

❌ **WRONG**: Read-Only shows raw markdown `**text**`
✅ **RIGHT**: Read-Only renders markdown as **text**

❌ **WRONG**: Header image appears after title
✅ **RIGHT**: Header image appears BEFORE title (first element)

❌ **WRONG**: No way to exit Read-Only (trapped)
✅ **RIGHT**: Swipe left-to-right to return to Story Panel

❌ **WRONG**: Double-tap only works on title
✅ **RIGHT**: Double-tap works ANYWHERE on screen

❌ **WRONG**: Editor back button returns to Story Panel
✅ **RIGHT**: Editor back button returns to Read-Only mode

❌ **WRONG**: Images inserted at bottom regardless of cursor
✅ **RIGHT**: Images inserted at cursor position (tracked by character offset)

---

### Atmosphere Mistakes

❌ **WRONG**: Same atmosphere effect in light and dark mode
✅ **RIGHT**: Separate light/dark variants for every atmosphere

❌ **WRONG**: 3PM light streak visible in dark mode
✅ **RIGHT**: 3PM dark mode shows warm glow from edges, NO streak

❌ **WRONG**: Night atmosphere is dark in light mode
✅ **RIGHT**: Night light mode is cooler white (indoor lamp feel)

❌ **WRONG**: Atmosphere changes instantly (jarring)
✅ **RIGHT**: Atmosphere transitions smoothly over 2-3 seconds

---

### UI Component Mistakes

❌ **WRONG**: Menu button uses neumorphic style
✅ **RIGHT**: Menu button uses liquid glass (frosted, translucent)

❌ **WRONG**: Sun/Moon uses emoji or icon pack
✅ **RIGHT**: Sun/Moon drawn in code with CustomPainter (thin strokes)

❌ **WRONG**: Task single-tap to edit
✅ **RIGHT**: Task long-press to edit, single-tap checkbox to complete

❌ **WRONG**: Completed tasks stay visible or disappear instantly
✅ **RIGHT**: Completed tasks fade out slowly over 3 seconds (AnimatedOpacity)

---

### Layout Mistakes

❌ **WRONG**: Expanded widget inside Column without height constraint
✅ **RIGHT**: Proper constraints (parent with defined height or wrap in Expanded properly)

❌ **WRONG**: Images visible on Story Panel or Library
✅ **RIGHT**: Images ONLY in Entry Read-Only/Editor (plus tiny thumbnails in preview cards)

❌ **WRONG**: Time Capsule icon embedded in "Work Desk" text
✅ **RIGHT**: Time Capsule icon in UPPER-RIGHT corner of Work Desk (opposite title)

❌ **WRONG**: Story title not editable
✅ **RIGHT**: Story title editable via double-tap or long-press (inline TextField)

---

### Comfort Mode Mistakes

❌ **WRONG**: Background shifts instantly when trigger words detected
✅ **RIGHT**: Background shifts over 45-60 seconds (imperceptible)

❌ **WRONG**: No indication why background changed
✅ **RIGHT**: Whisper text appears briefly ("take your time") to connect change to meaning

❌ **WRONG**: Triggers on 1 heavy word
✅ **RIGHT**: Requires 3+ heavy words to trigger

---

### First-Time Experience Mistakes

❌ **WRONG**: Blank screen when no stories exist
✅ **RIGHT**: Editable "Story" text with "Double-tap to edit" hint

❌ **WRONG**: No way to create first story from Story Panel
✅ **RIGHT**: Inline edit creates story, then shows "+ Add Entry" button

❌ **WRONG**: Forces user to Library panel to create first story
✅ **RIGHT**: User can create first story right from home panel

---

## 10. TESTING CHECKLIST

When implementing or fixing features, verify:

### Navigation
- [ ] App opens to Story Panel (middle), not Library
- [ ] Can swipe between all 3 panels smoothly
- [ ] Menu button always visible top-right
- [ ] Sun/Moon indicator always visible top-left
- [ ] NO back buttons anywhere

### Entry System
- [ ] Tap entry → opens Read-Only mode
- [ ] Read-Only shows fully rendered markdown (no raw syntax)
- [ ] Header image appears FIRST (before title) if exists
- [ ] Double-tap anywhere enters Editor
- [ ] Swipe left-to-right exits Read-Only to Story Panel
- [ ] Editor back chevron returns to Read-Only (not Story Panel)
- [ ] Images insert at cursor position, not always at bottom

### Work Desk
- [ ] Time Capsule icon in upper-right corner
- [ ] Can add tasks via input field
- [ ] Single tap checkbox completes task
- [ ] Long press task text enables edit mode
- [ ] Completed tasks fade over 3 seconds then disappear
- [ ] No layout crashes

### Atmosphere
- [ ] Changes every minute based on time
- [ ] 3PM shows different effects in light vs dark mode
- [ ] Night atmosphere adapts to light mode properly
- [ ] Transitions are smooth (2-3 seconds)
- [ ] Sun/Moon icon color shifts with atmosphere

### Comfort Mode
- [ ] Requires 3+ trigger words
- [ ] Transition takes 45-60 seconds
- [ ] Whisper text appears for 3 seconds
- [ ] Background shifts to warm comfort color

### Visual Quality
- [ ] Neumorphic buttons visible in both modes
- [ ] Text always readable (proper contrast)
- [ ] Images full-width, edge-to-edge
- [ ] Markdown blockquotes have left border + background
- [ ] No UI chrome in Read-Only (pure content view)

---

## 11. DESIGN PRINCIPLES SUMMARY

**Atmosphere over decoration**: The app breathes with time of day, but never overpowers content

**Gesture over buttons**: No back buttons - all navigation through swipes and taps

**Mercy over judgment**: Tasks fade, nothing turns red, no "overdue" labels

**Editorial over utility**: Text rendering is magazine-quality, not plain text

**Coherence over features**: Every element belongs to the same warm, minimal world

**Slow over instant**: Comfort mode, atmosphere changes - everything breathes slowly

**Felt over explained**: Sun/Moon shifts color, whisper text appears - the app responds emotionally

**Peace over productivity**: This is a sanctuary, not a task manager

---

## FINAL NOTE TO AI DEVELOPERS

This document represents hundreds of hours of design iteration and user feedback. **Every detail here exists for a reason** - usually because the alternative was tried and didn't work.

When implementing features:
1. **Read the relevant section fully** before coding
2. **Check the "Common Mistakes" section** for your feature
3. **Verify against the testing checklist** after implementation
4. **Consult the wireframe sketch** when layout is unclear

The user has explained this vision 20+ times to different AIs. Please honor the specification as written. When in doubt, ask for clarification rather than making assumptions.

The goal is not a feature-complete app. The goal is a **sanctuary** - a quiet, beautiful space that respects the user and their words.

---

*End of Master Specification - Version 2.0*
