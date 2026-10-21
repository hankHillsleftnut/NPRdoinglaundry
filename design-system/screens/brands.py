# Source logos as brand marks (kept in their own colours; exempt from the token check via data-brand).
def tile(inner, bg='#FFFFFF', stroke=True):
    s = '<rect x="0.25" y="0.25" width="31.5" height="31.5" rx="7.25" fill="none" stroke="#000" stroke-opacity="0.08" stroke-width="0.5"/>' if stroke else ''
    return f'<svg data-brand width="32" height="32" viewBox="0 0 32 32" style="flex-shrink:0"><rect width="32" height="32" rx="7.5" fill="{bg}"/>{inner}{s}</svg>'
G = ('<g transform="translate(7 7) scale(0.375)"><path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>'
     '<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>'
     '<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>'
     '<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/></g>')
petals = ''.join(f'<ellipse cx="16" cy="10.5" rx="3.2" ry="5.5" fill="{c}" fill-opacity="0.85" transform="rotate({i*45} 16 16)"/>' for i, c in enumerate(['#F6B23A','#F4D03F','#9BCB4C','#4FB0A5','#3E8EDE','#8E6CD8','#D65DB1','#EE6A4C']))
LOGO = {
  'apple health': tile('<path d="M16 24.5s-7.5-4.6-7.5-10.1c0-2.4 1.8-4.2 4-4.2 1.5 0 2.8.8 3.5 2 .7-1.2 2-2 3.5-2 2.2 0 4 1.8 4 4.2 0 5.5-7.5 10.1-7.5 10.1z" fill="#FF2D55"/>'),
  'calendar': tile('<text x="16" y="10.5" text-anchor="middle" font-family="SF Pro Text, Helvetica" font-size="5.5" font-weight="600" fill="#FF3B30">MON</text><text x="16" y="24.5" text-anchor="middle" font-family="SF Pro Text, Helvetica" font-size="13" fill="#1C1C1E">20</text>'),
  'google': tile(G),
  'contacts': tile('<circle cx="16" cy="13" r="4.5" fill="#FFFFFF"/><path d="M7.5 25c1.2-4 4.6-6 8.5-6s7.3 2 8.5 6z" fill="#FFFFFF"/>', '#A2A7AF', False),
  'screen time': tile('<path d="M11 8h10M11 24h10M12 8c0 4 4 5.5 4 8s-4 4-4 8M20 8c0 4-4 5.5-4 8s4 4 4 8" fill="none" stroke="#FFFFFF" stroke-width="1.8" stroke-linecap="round"/>', '#5E5CE6', False),
  'photos': tile(petals),
  'spotify': '<svg data-brand width="32" height="32" viewBox="0 0 32 32" style="flex-shrink:0"><circle cx="16" cy="16" r="16" fill="#1ED760"/><path d="M8.5 12.5c5-1.6 10.8-1.1 15 1.2M9.3 16.6c4.2-1.2 8.8-.8 12.4 1.1M10 20.4c3.4-.9 6.8-.6 9.6.9" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round"/></svg>',
  'apple music': tile('<path d="M13 21.5V11l8-2v10" fill="none" stroke="#FFFFFF" stroke-width="1.8" stroke-linejoin="round"/><circle cx="11.3" cy="21.5" r="2.2" fill="#FFFFFF"/><circle cx="19.3" cy="19.5" r="2.2" fill="#FFFFFF"/>', '#FA2D48', False),
  'reddit': '<svg data-brand width="32" height="32" viewBox="0 0 32 32" style="flex-shrink:0"><circle cx="16" cy="16" r="16" fill="#FF4500"/><ellipse cx="16" cy="18.5" rx="7.5" ry="5" fill="#FFFFFF"/><circle cx="22.5" cy="13.5" r="1.8" fill="#FFFFFF"/><circle cx="9.5" cy="13.5" r="1.8" fill="#FFFFFF"/><circle cx="13.2" cy="18" r="1.2" fill="#FF4500"/><circle cx="18.8" cy="18" r="1.2" fill="#FF4500"/><circle cx="20.5" cy="7.5" r="1.5" fill="#FFFFFF"/><path d="M16 13.5l1.2-5.2 3.3.8" fill="none" stroke="#FFFFFF" stroke-width="1"/></svg>',
}
LOGO.update({
  'youtube': tile('<rect x="5" y="9" width="22" height="14" rx="4" fill="#FF0000"/><path d="M14 12.5v7l6-3.5z" fill="#FFFFFF"/>'),
  'tiktok': tile('<path d="M17.5 8v11a3.5 3.5 0 1 1-3-3.46" fill="none" stroke="#25F4EE" stroke-width="2.2" transform="translate(-0.8 -0.6)"/><path d="M17.5 8v11a3.5 3.5 0 1 1-3-3.46" fill="none" stroke="#FE2C55" stroke-width="2.2" transform="translate(0.8 0.6)"/><path d="M17.5 8v11a3.5 3.5 0 1 1-3-3.46M17.5 8c.6 2.4 2.2 3.8 4.5 4" fill="none" stroke="#FFFFFF" stroke-width="2.2"/>', '#000000', False),
  'x': tile('<path d="M9 9l14 14M23 9L9 23" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round"/>', '#000000', False),
  'linkedin': tile('<rect x="9" y="13.5" width="3" height="9" fill="#FFFFFF"/><circle cx="10.5" cy="10" r="1.8" fill="#FFFFFF"/><path d="M15 13.5h2.8v1.4c.6-1 1.7-1.6 3-1.6 2.3 0 3.2 1.5 3.2 4v5.2h-3v-4.7c0-1.2-.4-2-1.5-2s-1.6.8-1.6 2v4.7H15z" fill="#FFFFFF"/>', '#0A66C2', False),
  'chatgpt': tile('<circle cx="16" cy="16" r="6.5" fill="none" stroke="#FFFFFF" stroke-width="1.8"/><path d="M16 9.5v13M10.4 12.75l11.2 6.5M10.4 19.25l11.2-6.5" stroke="#FFFFFF" stroke-width="1.4"/>', '#000000', False),
  'claude': tile('<g stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round">' + ''.join(f'<path d="M16 16L16 8" transform="rotate({a} 16 16)"/>' for a in range(0, 360, 45)) + '</g>', '#D97757', False),
  'grok': tile('<path d="M10 22L22 10M14 10h8v8" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round"/>', '#000000', False),
  'netflix': tile('<path d="M11 8h3l4 11V8h3v16h-3l-4-11v11h-3z" fill="#E50914"/>', '#000000', False),
  'instagram': tile('<rect x="8" y="8" width="16" height="16" rx="5" fill="none" stroke="#FFFFFF" stroke-width="1.8"/><circle cx="16" cy="16" r="3.8" fill="none" stroke="#FFFFFF" stroke-width="1.8"/><circle cx="20.8" cy="11.2" r="1" fill="#FFFFFF"/>', '#D6249F', False),
  'substack': tile('<path d="M10 9h12v2H10zM10 12.5h12v2H10zM10 16h12v8l-6-3.2-6 3.2z" fill="#FFFFFF"/>', '#FF6719', False),
})
