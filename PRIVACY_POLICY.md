# Privacy Policy — Resume Builder

_Effective July 30, 2026_

Resume Builder (listed on Play Store as "Resume Builder - CV, Cover Letter &
Proposal") is a resume, cover letter, and proposal builder that stores
everything locally by default. This document explains what happens to your
information when you use it.

## Overview

The app has no account system and no backend server of its own — there is no
"cloud" run by us for your data to go to, because none exists. Everything you
type, import, or generate is stored in the app's local storage **on your own
device**. The developer never receives a copy of it. The one exception is the
app's optional AI features, described below: if you choose to use one, the
relevant text is sent to a third-party AI provider (Groq) to generate a
suggestion, and only then.

## What the app does

- Creates and edits resumes, cover letters, and proposals using built-in templates.
- Imports an existing resume from a PDF you choose, to prefill the form.
- Lets you add a photo to templates that support one.
- Exports your finished document as a PDF and hands it to your phone's own
  share sheet (email, messaging apps, cloud drives — whichever you pick).
- Translates a resume's text into another language, using an on-device
  translation model.
- Blocks screenshots while a document is open for preview, as a safeguard for
  your own sensitive information.
- Offers optional AI features (see below) to rewrite or draft resume, cover
  letter, and proposal content, and to generate a resume tailored to a job
  description you paste in.

## AI features (optional, requires internet)

The app includes optional AI-assisted writing features: rewriting a resume
bullet point, drafting a summary/cover letter body/proposal section, and
generating a full resume tailored to a job description from your saved
Profile. These are **entirely opt-in** — nothing is sent anywhere unless you
tap an AI button — and require an internet connection to work.

When you use one, the relevant text (for example, a single bullet point, or
your saved Profile's job title/skills/experience plus a pasted job
description) is sent to **Groq**, a third-party AI provider, to generate a
suggestion. Your contact details — email, phone, and address — are not
included in AI prompts. This app doesn't control Groq's own retention
practices; see Groq's privacy policy for how they handle requests on their
end.

The "Profile" used to power job-description tailoring is stored locally the
same way every other document in this app is — there's no account or login
involved, and it's only sent to Groq when you explicitly generate a tailored
resume.

## Data we collect

**None, beyond what's described in AI features above.** Specifically:

- No account, name, email, or password is collected — there's nothing to sign up for.
- No analytics, tracking, or advertising software is included in this app.
- No crash-reporting or usage-monitoring service is integrated.
- The resume, cover letter, and proposal content you write, any PDF you
  import, and any photo you pick are processed and stored entirely on your
  device, except for the text you explicitly send via an AI feature.

If you delete the app, or use **Settings → Clear All Data** inside it, that
information is gone — including from our side, since we never had it to begin
with.

## Permissions explained

| Permission | What it's for | Leaves your device? |
| --- | --- | --- |
| Internet | A one-time download of a Google ML Kit translation model, the first time you pick a given language on the translate screen (no personal data). Also used, only if you use an AI feature, to send your prompt text to Groq's chat API and receive a generated suggestion. | Only for AI features you explicitly use |
| Files / storage | Lets you choose an existing resume PDF from your device so the app can read and prefill your details from it. | Stays local |
| Photos | Lets you pick a profile photo for templates that include one. The photo is stored only inside that document's data on your device. | Stays local |
| Screenshot blocking | Actively prevents the operating system from letting other apps capture a screenshot while a document is open for preview. | Nothing collected |

## Third parties

We don't sell, rent, or share your information with anyone, and there's no
server of ours storing it. Two pieces of third-party code are involved:
Google's ML Kit translation library, which runs translation on-device after
its language model is downloaded (your resume text is not sent to Google to
be translated); and Groq's AI API, used only when you tap an AI feature, as
described above.

## Storage, control & deletion

- **Edit or delete** any single document from the Home or Favorites tab.
- **Wipe everything at once** from Settings → Clear All Data.
- **Uninstalling the app** removes all of it, the same way uninstalling any
  app clears its local storage.

Because none of this data is transmitted to us, there's no separate
"request my data" or "delete my account" process — the controls already live
in the app itself.

## Children's privacy

This app is not directed at children under 13. Since it doesn't collect
personal information from any user, it doesn't knowingly collect personal
information from children either.

## Changes to this policy

If this policy changes in a way that affects what the app does with your
information, the effective date above will be updated to reflect it.

## Contact

Questions about this policy or how the app handles information can be sent to
zeeshanfarooq4656@gmail.com.
