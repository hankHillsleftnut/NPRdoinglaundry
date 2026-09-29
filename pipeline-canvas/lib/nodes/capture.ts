import type { NodeSpec } from '../types';

// ---------------------------------------------------------------------------
// CAPTURE -- the iPhone app.
//
// Modelled deliberately as *partially* instrumented. Rows arriving in
// raw_content prove that uploads which succeeded, succeeded. They say nothing
// about uploads that failed, because nothing on the device records those. So
// the arrival of each content type gets a real probe, and the mechanisms around
// it (retry, transcription confidence, background runs) get their own honest
// grey cards rather than being folded into one green dot.
// ---------------------------------------------------------------------------

const arrival = (contentType: string) =>
  ({ kind: 'rollup', source: 'raw_content', bucket: contentType }) as const;

export const captureNodes: NodeSpec[] = [
  // --- column 0: things the person types or speaks -------------------------
  {
    id: 'cap.text_entry',
    title: 'Text journal',
    purpose: 'A written entry typed directly into the app.',
    region: 'capture',
    column: 0,
    order: 0,
    source: 'Retrospect/Retrospect/Models/EntryModel.swift:12',
    probe: arrival('text_entry'),
  },
  {
    id: 'cap.journal_entry',
    isLegacy: true,
    title: 'Journal entry',
    purpose: 'The older journal write path, still used by parts of the app.',
    region: 'capture',
    column: 0,
    order: 1,
    source: 'Retrospect/Retrospect/Models/EntryModel.swift:10',
    probe: arrival('journal_entry'),
  },
  {
    id: 'cap.voice_recording',
    title: 'Voice note',
    purpose: 'A spoken entry recorded and transcribed on the phone.',
    region: 'capture',
    column: 0,
    order: 2,
    source: 'Retrospect/Retrospect/Views/VoiceRecordingView.swift:321',
    probe: arrival('voice_recording'),
    caveat: 'Writes a second row as voice_journal — one recording, two rows.',
  },
  {
    id: 'cap.voice_journal',
    isLegacy: true,
    title: 'Voice journal (duplicate)',
    purpose: 'The second row the same voice note creates via an explicit upload.',
    region: 'capture',
    column: 0,
    order: 3,
    source: 'Retrospect/Retrospect/Views/VoiceRecordingView.swift:362',
    probe: arrival('voice_journal'),
    caveat: 'Double-counts every voice note in any per-type volume metric.',
  },
  {
    id: 'cap.video_entry',
    title: 'Video journal',
    purpose: 'A recorded video entry.',
    region: 'capture',
    column: 0,
    order: 4,
    source: 'Retrospect/Retrospect/Views/VideoJournalView.swift',
    probe: arrival('video_entry'),
  },
  {
    id: 'cap.onboarding_profile',
    title: 'Onboarding answers',
    purpose: 'The questionnaire that seeds what the system knows on day one.',
    region: 'capture',
    column: 0,
    order: 5,
    source: 'Retrospect/Retrospect/Views/DarkOnboardingFlow.swift',
    probe: arrival('onboarding_profile'),
  },

  // --- column 1: device + connected sources --------------------------------
  {
    id: 'cap.healthkit',
    title: 'HealthKit',
    purpose: 'Sleep, activity and workout figures read from Apple Health.',
    region: 'capture',
    column: 1,
    order: 0,
    source: 'Retrospect/Retrospect/Services/NativeSourcesManager.swift',
    probe: arrival('healthkit'),
  },
  {
    id: 'cap.screen_time',
    title: 'Screen Time',
    purpose: 'How long the phone was used, and on what.',
    region: 'capture',
    column: 1,
    order: 1,
    source: 'Retrospect/Retrospect/Services/NativeSourcesManager.swift',
    probe: arrival('screen_time'),
  },
  {
    id: 'cap.calendar',
    title: 'Calendar',
    purpose: 'Events, so the day has a shape to compare against.',
    region: 'capture',
    column: 1,
    order: 2,
    source: 'Retrospect/Retrospect/Services/NativeSourcesManager.swift',
    probe: arrival('calendar'),
  },
  {
    id: 'cap.apple_music',
    title: 'Apple Music',
    purpose: 'What was listened to, as a mood signal.',
    region: 'capture',
    column: 1,
    order: 3,
    source: 'Retrospect/Retrospect/Services/NativeSourcesManager.swift',
    probe: arrival('apple_music'),
  },
  {
    id: 'cap.photos',
    title: 'Photos',
    purpose: 'Photo metadata, for where the person was and with whom.',
    region: 'capture',
    column: 1,
    order: 4,
    source: 'Retrospect/Retrospect/Services/NativeSourcesManager.swift',
    probe: arrival('photos'),
  },
  {
    id: 'cap.contacts',
    title: 'Contacts',
    purpose: 'Names, so people mentioned in entries can be resolved.',
    region: 'capture',
    column: 1,
    order: 5,
    source: 'Retrospect/Retrospect/Services/NativeSourcesManager.swift',
    probe: arrival('contacts'),
  },

  // --- column 2: the mechanisms nobody records ------------------------------
  {
    id: 'cap.transcription',
    title: 'On-device transcription',
    purpose: 'Turns speech into the text everything downstream reads.',
    region: 'capture',
    column: 2,
    order: 0,
    source: 'Retrospect/Retrospect/Services/TranscriptionService.swift:88',
    probe: {
      kind: 'notInstrumented',
      reason: 'Confidence is computed for every transcript, printed, then thrown away.',
      wouldNeed: 'Store the confidence on the entry and send it with the upload.',
    },
  },
  {
    id: 'cap.upload',
    title: 'Upload client',
    purpose: 'Sends a finished entry to the backend.',
    region: 'capture',
    column: 2,
    order: 1,
    source: 'Retrospect/Retrospect/Services/RetrospectAPIClient.swift',
    probe: {
      kind: 'notInstrumented',
      reason: 'A failed upload leaves no trace anywhere — on the device or the server.',
      wouldNeed: 'A synced flag per entry, and a failed-upload queue that reports its depth.',
    },
    caveat: 'No retry queue. No idempotency key.',
  },
  {
    id: 'cap.background',
    title: 'Background sync',
    purpose: 'Flushes pending entries when the app is not open.',
    region: 'capture',
    column: 2,
    order: 2,
    source: 'Retrospect/Retrospect/RetrospectApp.swift',
    probe: {
      kind: 'notInstrumented',
      reason: 'Background task runs are never persisted, so nobody knows if they fire.',
      wouldNeed: 'Write a row per background run with its outcome.',
    },
  },
];
