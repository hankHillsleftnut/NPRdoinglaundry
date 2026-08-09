export type IntegrationAvailability =
  | 'available'
  | 'in_development'
  | 'approval_required'
  | 'verification_required'
  | 'export_import'
  | 'access_review';

export interface IntegrationCatalogEntry {
  id: string;
  displayName: string;
  collectionMode: 'native_ios' | 'oauth_api' | 'data_export';
  availability: IntegrationAvailability;
  intelligenceDomains: string[];
  statusLabel?: string;
  setupRequirement?: string;
}

export const INTEGRATION_CATALOG: IntegrationCatalogEntry[] = [
  { id: 'healthkit', displayName: 'Apple Health', collectionMode: 'native_ios', availability: 'available', intelligenceDomains: ['health', 'sleep', 'activity', 'routine'], statusLabel: 'Device sync' },
  { id: 'screen_time', displayName: 'Screen Time', collectionMode: 'native_ios', availability: 'in_development', intelligenceDomains: ['attention', 'habits', 'applications'], statusLabel: 'Device sync repair' },
  { id: 'google_docs', displayName: 'Google Docs', collectionMode: 'oauth_api', availability: 'available', intelligenceDomains: ['writing', 'work', 'interests'], statusLabel: 'Continuous sync' },
  { id: 'calendar', displayName: 'Calendar', collectionMode: 'native_ios', availability: 'in_development', intelligenceDomains: ['time', 'commitments', 'relationships', 'routine'], statusLabel: 'Device sync' },
  { id: 'apple_music', displayName: 'Apple Music', collectionMode: 'native_ios', availability: 'in_development', intelligenceDomains: ['music', 'taste', 'mood'], statusLabel: 'Device sync' },
  { id: 'photos', displayName: 'Photos', collectionMode: 'native_ios', availability: 'in_development', intelligenceDomains: ['memories', 'places', 'activity'], statusLabel: 'Device metadata sync' },
  { id: 'contacts', displayName: 'Contacts', collectionMode: 'native_ios', availability: 'in_development', intelligenceDomains: ['relationships', 'organizations'], statusLabel: 'Device sync' },
  { id: 'spotify', displayName: 'Spotify', collectionMode: 'oauth_api', availability: 'in_development', intelligenceDomains: ['music', 'taste', 'mood'], statusLabel: 'Continuous sync' },
  { id: 'youtube', displayName: 'YouTube', collectionMode: 'oauth_api', availability: 'in_development', intelligenceDomains: ['learning', 'interests', 'media'], statusLabel: 'API-visible sync' },
  { id: 'reddit', displayName: 'Reddit', collectionMode: 'oauth_api', availability: 'in_development', intelligenceDomains: ['interests', 'communities', 'opinions'], statusLabel: 'Continuous sync' },
  { id: 'gmail', displayName: 'Gmail', collectionMode: 'oauth_api', availability: 'verification_required', intelligenceDomains: ['relationships', 'commitments', 'work'], statusLabel: 'Verification-gated sync', setupRequirement: 'Google OAuth verification and possible restricted-scope security assessment' },
  { id: 'tiktok', displayName: 'TikTok', collectionMode: 'oauth_api', availability: 'approval_required', intelligenceDomains: ['interests', 'media', 'attention'], statusLabel: 'API-visible sync', setupRequirement: 'TikTok Login Kit, video.list approval, and later Data Portability approval for richer behavior history' },
  { id: 'x', displayName: 'X', collectionMode: 'oauth_api', availability: 'approval_required', intelligenceDomains: ['interests', 'opinions', 'media'], statusLabel: 'API-tier gated sync', setupRequirement: 'Approved X API tier, scopes, and cost ceiling' },
  { id: 'grok', displayName: 'Grok', collectionMode: 'data_export', availability: 'export_import', intelligenceDomains: ['questions', 'projects', 'thinking'], statusLabel: 'Optional file import', setupRequirement: 'Only user-provided files until an official consumer-history API exists' },
  { id: 'netflix', displayName: 'Netflix', collectionMode: 'data_export', availability: 'export_import', intelligenceDomains: ['media', 'taste', 'routine'], statusLabel: 'Optional file import' },
  { id: 'chatgpt', displayName: 'ChatGPT', collectionMode: 'data_export', availability: 'export_import', intelligenceDomains: ['questions', 'projects', 'thinking'], statusLabel: 'Optional file import' },
  { id: 'claude', displayName: 'Claude', collectionMode: 'data_export', availability: 'export_import', intelligenceDomains: ['questions', 'projects', 'thinking'], statusLabel: 'Optional file import' },
];
