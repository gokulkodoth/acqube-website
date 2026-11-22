# Acqube blog drafts – writing guide

Files in this folder are uploaded automatically to **acqube.com/admin → Blog** as **Drafts**
(GitHub Action "Upload blog drafts"). Nothing is published until Gokul clicks Publish.
This folder is not part of the public website (folders starting with `_` are not served).

## File format
`_blog-drafts/YYYY-MM-DD-short-slug.json` (date = the day it was written, India time):
```json
{ "title": "…", "category": "GST", "excerpt": "…", "body": "…", "topic_key": "gst-itc-reversal", "sources": ["https://…"] }
```
- `title`: plain, specific, ≤ 80 characters ideally (max 200). Must not repeat an existing title.
- `category`: one of GST, Income Tax, TDS, Company Law, Payroll, IP, Licences, Compliance, Business.
- `excerpt`: 1–2 sentences, ≤ 250 characters, says what the reader will learn.
- `body`: 600–900 words in the site's simple markdown – only `## Heading`, `- bullet`, `**bold**`,
  blank lines between paragraphs. No tables, links, images, numbered lists or HTML.
- `topic_key` / `sources`: for our records only (not shown on the site).

## Audience and voice
Indian small-business owners, start-up founders, salaried professionals. Plain English, short
sentences, practical. Explain what to do, by when, and what happens if you don't. No hype.

## Accuracy rules (most important)
- Research every rule, rate, threshold, form number and due date in **current** official or
  reputable sources (incometaxindia.gov.in, cbic-gst.gov.in, gst.gov.in, mca.gov.in, epfindia.gov.in,
  esic.gov.in, ipindia.gov.in, fssai.gov.in, CBDT/CBIC notifications, major CA/tax publications).
- The Income-tax Act, 2025 applies from 1 April 2026 ("tax year" replaces previous/assessment
  year; many sections and forms are renumbered). Mention old and new references where helpful.
- If sources disagree or something is uncertain, leave it out or say it is subject to notification.
- Never invent case law, circular numbers or statistics.
- End with one short paragraph inviting readers to contact Acqube (phone +91 99955 44890,
  hello@acqube.com) – no hard selling – followed by:
  "*This article is for general information and is not professional advice.*"

## Topic mix
Rotate categories; don't use the same category twice in a row. Prefer:
1. Upcoming deadlines in the next 2–4 weeks (GST, TDS, advance tax, ROC, PF/ESI).
2. Recent changes (new notifications, budget changes, new forms, new limits).
3. Evergreen how-tos small businesses search for (registrations, licences, choosing structures).
Match Acqube services: GST, income tax, TDS (24Q/26Q), accounting, company/LLP, registrations,
payroll PF/ESI, licences (FSSAI, trade licence, IEC, MSME), trademark, business advisory, loans.

## Topics already covered
See `blog/` (published article folders) and the other `.json` files here. Do not repeat a topic
unless there is a genuinely new angle (e.g. a new law or limit) and the title makes that clear.
