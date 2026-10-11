# Assets

Everything here is bundled into the app and can be extracted from it.
**Never put config, `.env` files, keys or real personal data in this folder.**

Use exactly the file names below: the code will reference them.

## `images/branding/`

| File | What |
|---|---|
| `logo_full.png` | Mark + "VITALREG", 1200px wide, transparent (login, splash) |
| `logo_mark.png` | Mark only, 600px wide, transparent (splash) |

Both were cropped from the raster image embedded in the Figma SVG exports.
White versions for the green
splash are made in code with a colour filter, so no separate files are needed.
Replace these with true vector exports if the designer can provide them.

## `images/auth/`

| File | What |
|---|---|
| `login_header.jpg` | Photo behind the top of the login card. Export the image layer only, at 3x (about 1125px wide), JPG quality about 80% |

## `images/onboarding/`

Export the **original photos without the white wash**. The fade is applied in
code so it can be tuned. Use JPG (quality ~80%) at 1080px wide or larger, and
keep each file under ~300 KB.

| File | Screen |
|---|---|
| `onboarding_1.jpg` | 1 · "Pick what you need" (laptop and dashboard) |
| `onboarding_2.jpg` | 2 · "Fill in your information" (two people with phones) |
| `onboarding_3.jpg` | 3 · "Know where things stand" (same photo unless the design changes) |
| `onboarding_4.jpg` | 4 · "Receive your official record" |

Screens 2–4 share `onboarding_2.jpg` (see `OnboardingSlide`). Screen 1's logo
band, green wave and tagline are part of `onboarding_1.jpg`.

## `fonts/`

**Poppins** (the app-wide default) and **Open Sans** (registered, not yet used),
weights 400/500/600/700 and 400/600/700, from Google's official repositories
under the SIL Open Font License. The `OFL-*.txt` licences are bundled and shown
on the app's licences page. Registered in `pubspec.yaml`; family names live in
`lib/design_system/tokens/app_fonts.dart`.

Fonts are bundled rather than downloaded at runtime so the app works offline.

## `reference/`

Snapshots of the backend's place lists, used by offline mode until the app
has downloaded its own: `countries.json` (`/option/country`), `states.json`
(`/option/states/63`) and `lgas.json` (every `/option/lga/:stateId`, with
`State_ID`). Registration centres have no snapshot; they must be downloaded
once online.
