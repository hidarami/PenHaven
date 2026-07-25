# Plan: App Lock Delay, Username Updates, Profile Fixes, Share Cards, and Bookmarks

This plan addresses multiple issues: implementing a 1-minute delay before app lock when backgrounded, fixing static username display in feed cards and entry viewer, resolving profile change errors, ensuring share cards use user profiles, adding text selection for Quote/Paper cards within the share sheet, and creating a bookmarks viewing interface in the Mine section.

## Issues to Fix

### 1. App Lock Delay (High Priority)
**Current behavior**: App locks immediately when backgrounded (AppLifecycleState.paused)
**Desired behavior**: Only lock after 1 minute of being backgrounded

**Implementation**:
- Modify `home_screen.dart` to track when app goes to background
- Add a timer that checks if app returns within 1 minute
- Only call `lockApp()` if timer completes without app returning
- Store background timestamp in SharedPreferences to handle app termination

**Files to modify**:
- `lib/screens/home_screen.dart` - Add timer logic in `didChangeAppLifecycleState`
- `lib/providers/app_state.dart` - May need to add background timestamp tracking

### 2. Username Update in Feed Cards and Entry Viewer (High Priority)
**Current behavior**: Old username shown in feed cards and entry viewer doesn't update when user changes their profile
**Root cause**: The `PublishedEntry` object stores the author label at publish time, and both feed cards and entry viewer display this static value. For the current user's own entries, they should display the current profile name.

**Implementation**:
- In `community_panel.dart`, update feed card widgets to check if entry is owned by current user
- If owned, use `CommunityState.profileDisplayName` instead of `entry.authorLabel`
- In `community_entry_viewer.dart`, update author row to use current profile for own entries
- Listen to CommunityState changes to update when profile changes
- This applies to: _FeaturedCard, _CompactEntryCard, and entry viewer author row

**Files to modify**:
- `lib/screens/community/community_panel.dart` - Update feed card widgets to use current profile
- `lib/screens/community/community_entry_viewer.dart` - Update author row to use current profile

### 3. Profile Change Unmounted Widget Error (High Priority)
**Current behavior**: Screen turns red with "widget has been unmounted" error when changing profile
**Root cause**: In `_ProfileSheetState._save()`, the code calls `setState` after async operations without checking `mounted`

**Implementation**:
- Add `mounted` checks before all `setState` calls in `_ProfileSheetState`
- Ensure async operations are cancelled if widget is disposed

**Files to modify**:
- `lib/screens/community/community_panel.dart` - Fix `_ProfileSheetState._save()` method

### 4. Avatar Placeholders in Share Cards (Medium Priority)
**Current behavior**: Share cards use placeholder avatars instead of user's profile image
**Root cause**: Share card widgets don't access the user's profile image from CommunityState

**Implementation**:
- Pass profile image path to share card widgets
- Update all share card types (Editorial, Magazine, Quote, Paper) to use actual profile image when available
- Fall back to placeholder if no image set

**Files to modify**:
- `lib/screens/community/community_entry_viewer.dart` - Update share card widgets to accept and use profile image

### 5. Text Selection for Quote and Paper Cards (Medium Priority)
**Current behavior**: Quote and Paper cards default to first sentences of entry
**Desired behavior**: User can choose which parts of the entry to include within the share sheet itself

**Implementation**:
- Add a text editing field in the share sheet that appears when Quote or Paper format is selected
- Pre-fill with entry preview but allow user to edit the text
- Update card rendering to use the edited text from the field
- Keep Editorial and Magazine formats as-is (they show full preview)

**Files to modify**:
- `lib/screens/community/community_entry_viewer.dart` - Add text editing field to `_SanctuaryShareSheet` for Quote/Paper formats

### 6. Bookmarks Viewing Interface (Medium Priority)
**Current behavior**: No way to view bookmarked entries
**Desired behavior**: Glassmorphic pill in Mine section that opens bookmarks view

**Implementation**:
- Add a glassmorphic "Bookmarks" pill at the top of the Mine tab (before user's entries)
- When tapped, show a filtered view of bookmarked entries
- Load bookmarked entry IDs from SharedPreferences
- Filter feed entries to show only bookmarked ones in the bookmarks view
- Add bookmark management (remove from bookmarks) in the view
- Return to normal Mine view when back/closed

**Files to modify**:
- `lib/screens/community/community_panel.dart` - Add bookmarks pill and view logic in _MyPostsTab
- `lib/providers/community_state.dart` - Add bookmark loading/filtering methods

## Implementation Order

1. Fix profile change error (critical - prevents feature use)
2. Fix username update in feed cards and entry viewer (high visibility issue)
3. Implement app lock delay when backgrounded (security feature)
4. Fix avatar placeholders in share cards (consistency)
5. Add text selection for Quote/Paper cards within share sheet (feature enhancement)
6. Add bookmarks viewing interface in Mine section (new feature)

## Testing Notes

- Test app lock delay by backgrounding app and returning before/after 1 minute
- Test username update by changing profile and viewing own entries
- Test profile change error by changing both name and image
- Test share cards with and without profile image set
- Test text selection in Quote/Paper formats
- Test bookmarks tab with multiple bookmarked entries
