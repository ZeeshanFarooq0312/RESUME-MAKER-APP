# Privacy Policy — Resume Builder

_Effective July 30, 2026_

Resume Builder (listed on Play Store as "Resume Builder - CV, Cover Letter &
Proposal") is a resume, cover letter, and proposal builder that stores
everything locally by default. This document explains what happens to your
information when you use it.

## Overview

The app itself has no backend server of its own for your resume, cover
letter, or proposal content — there is no "cloud" run by us for that data to
go to, because none exists. The one part of the app that isn't purely local
is your account: signing up, logging in, and password reset are handled by
**Firebase Authentication** (a Google service), described below. Everything
else you type, import, or generate — your Profile, resumes, cover letters,
and proposals — is stored only in the app's local storage on your own
device. The developer never receives a copy of any of it. The other
exceptions are the app's optional AI features and optional subscription,
both described below.

## Your account

On first use, the app asks you to sign up with a name, email, and password,
then complete a profile (work history, education, skills). Account creation,
login, and password reset are handled by **Firebase Authentication**, a
Google service — your email address and a securely-hashed credential are
stored on Firebase's servers, not only on your device. This app's developer
does not directly see your password (Firebase never exposes it to us in any
form), but does have access, through the Firebase console, to the account's
email address and sign-up date, the same way any app using a login system
would.

- Forgot your password? Use **Forgot password?** on the login screen — this
  sends a real password-reset email via Firebase, the same as most apps
  with accounts.
- Logging out (Settings → Log Out) just returns you to the login screen; your
  account and documents are untouched and you can log back in.
- **Settings → Clear All Data** deletes your saved Profile and every
  document on this device and signs you out, but does **not** delete the
  underlying Firebase account itself — to remove that entirely, contact us
  (see Contact below).
- Your Profile (work history, education, skills) stays local exactly as
  before — it is not stored by Firebase, and is only sent anywhere at all
  if you explicitly use the job-description resume-tailoring feature (see
  AI features below).

## What the app does

- Asks you to create an account and complete a profile before first use.
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
  description from your saved profile.
- Offers an optional Pro subscription (see below) that unlocks premium
  templates and unlimited AI features.

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
same way every other document in this app is — separately from your account
credentials, which Firebase handles as described above — and it's only sent
to Groq when you explicitly generate a tailored resume.

## Subscriptions (optional)

The app offers an optional Pro subscription (monthly, yearly, or a one-time
lifetime purchase) that unlocks premium templates and unlimited AI
features. The free Basic plan remains fully usable without subscribing.

Purchases are handled entirely by **Google Play Billing**, and subscription
status is managed for us by **RevenueCat**, a third-party subscription
platform. Neither we nor RevenueCat ever see your payment details (card
number, etc.) — that's handled directly by Google Play. RevenueCat receives
purchase and entitlement data (which plan you're on, renewal dates) tied to
an anonymous identifier, not your resume content, account, or profile. You
can review or cancel a subscription any time from the Google Play Store's
own subscriptions page, and restore a prior purchase from Settings →
Manage Subscription.

## Data we collect

**Beyond your account, nothing leaves your device except what's described in
AI features and Subscriptions above.** Specifically:

- Your account email and a securely-hashed credential are stored by Firebase
  Authentication (Google) to make sign-up/login/password-reset work — this
  app's developer does not directly store or see your password. Your
  Profile (name, work history, education, skills, etc.) is separate from
  your account and stored locally only.
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

We don't sell, rent, or share your information with anyone. We do rely on a
few third-party services to run parts of the app: **Firebase Authentication**
(Google), which stores your account email and hashed credential and handles
sign-up/login/password-reset, as described above; Google's ML Kit
translation library, which runs translation on-device after its language
model is downloaded (your resume text is not sent to Google to be
translated); Groq's AI API, used only when you tap an AI feature, as
described above; and, only if you subscribe, Google Play Billing and
RevenueCat, as described in Subscriptions above.

## Storage, control & deletion

- **Edit or delete** any single document from the Home or Favorites tab.
- **Wipe your local data and sign out** from Settings → Clear All Data —
  this removes your Profile and every document on this device, and signs
  you out, but does not delete the Firebase account itself.
- **Delete your account entirely**, including the email/credential stored by
  Firebase: email us (see Contact below) and we'll remove it.
- **Uninstalling the app** removes all local data, the same way uninstalling
  any app clears its local storage, but does not delete the Firebase
  account — use the option above for that.

Your document content never reaches us, so for everything except your
account there's no separate "request my data" process needed — those
controls already live in the app itself.

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
