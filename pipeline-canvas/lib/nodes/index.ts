import type { EdgeSpec, NodeSpec, RegionId } from '../types';
import { captureNodes } from './capture';
import { apiNodes } from './api';
import { integrationNodes } from './integrations';
import { ingestNodes } from './ingest';
import { brainNodes } from './brain';
import { podcastNodes } from './podcast';
import { sinkNodes } from './sinks';

export const ALL_NODES: NodeSpec[] = [
  ...captureNodes,
  ...apiNodes,
  ...integrationNodes,
  ...ingestNodes,
  ...brainNodes,
  ...podcastNodes,
  ...sinkNodes,
];

export const REGIONS: { id: RegionId; title: string; blurb: string }[] = [
  { id: 'capture', title: 'Capture', blurb: 'the iPhone app' },
  { id: 'api', title: 'API', blurb: 'the backend on Render' },
  { id: 'integrations', title: 'Integrations', blurb: 'connected accounts' },
  { id: 'ingest', title: 'Ingest', blurb: 'material becomes verified fact' },
  { id: 'brain', title: 'Brain', blurb: 'facts become patterns' },
  { id: 'podcast', title: 'Podcast', blurb: 'understanding becomes audio' },
  { id: 'sinks', title: 'Where things stop', blurb: 'loss, by design and by damage' },
];

const flow = (from: string, to: string, label?: string): EdgeSpec => ({ from, to, kind: 'flow', label });
const branch = (from: string, to: string, label?: string): EdgeSpec => ({ from, to, kind: 'branch', label });
const inferred = (from: string, to: string, label?: string): EdgeSpec => ({ from, to, kind: 'inferred', label });

export const ALL_EDGES: EdgeSpec[] = [
  // capture -> api. Inferred throughout: no upload is ever recorded, so these
  // arrows are true by construction but unprovable from data.
  inferred('cap.text_entry', 'cap.upload'),
  inferred('cap.journal_entry', 'cap.upload'),
  inferred('cap.voice_recording', 'cap.transcription'),
  inferred('cap.transcription', 'cap.upload'),
  branch('cap.voice_recording', 'cap.voice_journal', 'duplicate projection'),
  inferred('cap.voice_journal', 'cap.upload'),
  inferred('cap.video_entry', 'cap.upload'),
  inferred('cap.onboarding_profile', 'cap.upload'),
  inferred('cap.healthkit', 'cap.background'),
  inferred('cap.screen_time', 'cap.background'),
  inferred('cap.calendar', 'cap.background'),
  inferred('cap.apple_music', 'cap.background'),
  inferred('cap.photos', 'cap.background'),
  inferred('cap.contacts', 'cap.background'),
  inferred('cap.upload', 'api.content'),
  inferred('cap.background', 'api.device_batches'),

  // api -> downstream
  flow('api.content', 'ing.raw'),
  flow('api.device_batches', 'ing.raw'),
  inferred('api.imports', 'ing.raw'),
  flow('api.oauth_start', 'api.oauth_callback'),
  flow('api.oauth_callback', 'int.connection'),
  inferred('api.podcast', 'pod.run'),
  inferred('api.goals', 'brn.promoter'),
  inferred('api.content', 'api.agent_client'),
  inferred('api.agent_client', 'ing.run'),

  // integrations
  flow('int.connection', 'int.vault'),
  flow('int.scheduler', 'int.jobs'),
  inferred('int.jobs', 'int.worker'),
  inferred('int.worker', 'int.sync_run', 'job_id never set'),
  flow('int.sync_run', 'int.payloads'),
  flow('int.payloads', 'int.items'),
  flow('int.items', 'int.analysis_units'),
  flow('int.analysis_units', 'ing.raw'),
  branch('int.jobs', 'sink.dead_letter', 'gave up'),
  inferred('int.sync_run', 'int.tests'),

  // ingest
  flow('ing.raw', 'ing.lease'),
  flow('ing.lease', 'ing.run'),
  flow('ing.run', 'ing.extract'),
  flow('ing.extract', 'ing.verify'),
  branch('ing.verify', 'sink.dropped_spans', 'no quote, no fact'),
  flow('ing.verify', 'ing.entity'),
  branch('ing.entity', 'sink.entity_pending', 'which person?'),
  flow('ing.entity', 'ing.fact'),
  flow('ing.fact', 'ing.evidence'),
  flow('ing.fact', 'ing.supersede'),
  branch('ing.supersede', 'sink.retired_facts', 'replaced'),
  flow('ing.fact', 'ing.shim'),
  branch('ing.raw', 'sink.failed_raw', 'never processed'),

  // brain
  flow('ing.fact', 'brn.promoter'),
  flow('brn.promoter', 'brn.candidate'),
  flow('brn.candidate', 'brn.live', 'met the bar'),
  flow('brn.live', 'brn.decay'),
  branch('brn.decay', 'sink.retired_patterns', 'stopped recurring'),
  flow('brn.live', 'brn.why'),
  branch('brn.why', 'sink.why_refused', 'not justified'),
  flow('brn.why', 'brn.portrait'),
  flow('brn.live', 'brn.portrait'),
  flow('ing.shim', 'brn.insights'),
  inferred('ing.fact', 'brn.lint'),
  inferred('brn.lint', 'brn.remediation'),

  // podcast
  flow('brn.portrait', 'pod.context'),
  flow('brn.live', 'pod.context'),
  flow('pod.context', 'pod.evidence'),
  flow('pod.evidence', 'pod.cookA'),
  flow('pod.cookA', 'pod.cookB'),
  flow('pod.cookB', 'pod.cookC'),
  flow('pod.cookC', 'pod.guard'),
  flow('pod.guard', 'pod.tts'),
  flow('pod.tts', 'pod.episode'),
  inferred('pod.run', 'pod.cookA'),
];
