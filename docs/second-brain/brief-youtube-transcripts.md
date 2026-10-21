# Brief: how to read YouTube links you send

20 October 2026. One decision for you.

## TL;DR

**Recommendation: use a paid transcript service** with its own terms (about $0.001–0.01 per video). Read the transcript of each YouTube link you send, and never scrape YouTube directly. **Your call:** service, scraping, or titles only for now.

## The problem

YouTube is your biggest content source, but a video link can't be read like a page. The official YouTube API only gives captions for videos **the account owns**, so it can't read anyone else's.

## Options

| | What it is | Risk | Cost |
|---|---|---|---|
| **A. Transcript service (recommended)** | A third-party API (e.g. Supadata and similar) returns the transcript; they carry the scraping and its terms | Vendor dependency; their compliance | ~$0.001–0.01 per video |
| B. Scrape YouTube ourselves | Fetch YouTube's caption files directly | Against YouTube's terms of service; breaks without warning | Free |
| C. Titles and descriptions only | What the official API gives | Shallow: "understood" from the title alone | Free |

## What changes after

Each YouTube link you send is read from its transcript, in sections like a long page, and summarised. It's still kept apart from what the brain believes about you. **Send me:** "A", "B" or "C". With A I'll pick the vendor by cost and reliability and tell you which.
