import type { NextConfig } from 'next';

const config: NextConfig = {
  reactStrictMode: true,
  // The canvas reads Supabase with the service key. That key must never be
  // bundled for the browser, so nothing here may be exposed via NEXT_PUBLIC_*.
  serverExternalPackages: ['@supabase/supabase-js'],
};

export default config;
