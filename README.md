# Smart Resume Builder

Fully offline Flutter resume/CV builder. No backend, no API costs.

## Setup

1. Extract this folder, `cd` into it.
2. Run:
   ```
   flutter pub get
   ```
3. Run on a connected device/emulator:
   ```
   flutter run
   ```

## What's included

- **Multi-step form**: Personal Info → Experience → Education → Skills
  (`lib/screens/form_screen.dart`)
- **Local persistence**: data auto-saves to the device via `shared_preferences`
  so users can leave and resume editing (`lib/screens/home_screen.dart`)
- **Two PDF templates**:
  - `Classic` — single column, ATS-friendly, no color (`lib/pdf/templates/classic_template.dart`)
  - `Modern` — color sidebar layout, positioned as the premium template (`lib/pdf/templates/modern_template.dart`)
- **PDF preview + share/print/save** using the `printing` package, which gives
  you native share sheet, print, and save-to-device for free
  (`lib/screens/preview_screen.dart`)
- **Distinctive theme** (deep slate + gold, Playfair Display + Inter fonts)
  instead of default Material blue (`lib/theme/app_theme.dart`)

## Next steps to monetize

1. **Add Google Play Billing** to gate the Modern template behind a one-time
   purchase. Use the `in_app_purchase` package:
   ```
   flutter pub add in_app_purchase
   ```
   Wrap the `_openPreview` call for `ResumeTemplate.modern` in
   `template_screen.dart` with a purchase check — if not purchased, show a
   paywall dialog before navigating to `PreviewScreen`.

2. **Add more templates** once the pipeline works — each new template is just
   a new file in `lib/pdf/templates/` following the same pattern as
   `classic_template.dart` / `modern_template.dart`, plus a new
   `_TemplateCard` entry in `template_screen.dart`.

3. **App icon + Play Store listing**: replace the default Flutter launcher
   icon (use `flutter_launcher_icons` package) and write a keyword-optimized
   title/description before publishing — this is your main free marketing
   channel on a tight budget.

4. **Optional: AdMob banner** on the free/Classic flow for extra revenue from
   users who never buy Modern. Add `google_mobile_ads` package if you want this.

## Notes

- All PDF generation happens on-device via the `pdf` package — zero server
  cost regardless of how many users you get.
- `uuid` package gives stable IDs to experience/education entries so list
  add/remove/edit works cleanly in the UI.
