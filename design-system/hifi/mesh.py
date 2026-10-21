# Episode artwork as mesh gradients (founder 20 Oct, c-e42cnl / c-scy4k9: "make these gradients much prettier, do research on mesh gradients").
# Research: a mesh reads as rich when it has 4-6 colour points at distinct positions over a base: one light source, one body colour,
# one cool or dark anchor in the opposite corner, one warm accent, and a small bright highlight. The blend is done in oklab so mid-tones stay clean.
# On iOS this maps to SwiftUI MeshGradient (3x3 points, smoothsColors) plus a fine grain overlay; here each point is a radial ellipse.
from review import C


def _e(size, at, colour, amount=100, fade=70):
    c = C(colour) if amount == 100 else f'color-mix(in oklab, {C(colour)} {amount}%, transparent)'
    return f'radial-gradient({size} at {at} in oklab, {c} 0%, transparent {fade}%)'


MESHES = {
    # this week's episode: dusk, a low amber sun over warm night, a rose glow where the light meets the dark
    'weekly': ('night-800', [_e('110% 120%', '92% 0%', 'amber-200', fade=55), _e('90% 90%', '55% 40%', 'amber-600', 70, 100),
                             _e('100% 100%', '0% 100%', 'night-950', fade=90), _e('70% 70%', '20% 20%', 'red-300', 30, 100), _e('40% 34%', '82% 12%', 'amber-50', 60)]),
    # the morning brief: open sky, sun in the top corner, deeper blue pooling at the bottom
    'brief': ('sky-500', [_e('110% 120%', '92% 0%', 'amber-200', fade=55), _e('90% 90%', '10% 10%', 'sky-300', fade=100),
                          _e('100% 100%', '90% 100%', 'sky-700', fade=95), _e('80% 80%', '0% 100%', 'sky-900', 80, 100), _e('40% 34%', '40% 28%', 'sky-100', 55)]),
    # your first episode: green, new growth, morning light
    'first': ('green-500', [_e('110% 120%', '92% 0%', 'amber-200', fade=55), _e('90% 90%', '12% 14%', 'green-300', fade=100),
                            _e('100% 100%', '0% 100%', 'green-900', fade=95), _e('80% 80%', '100% 100%', 'sky-800', 45, 100), _e('40% 34%', '46% 30%', 'green-50', 45)]),
    # older episodes: warm grey, quieter
    'older': ('night-300', [_e('110% 120%', '92% 0%', 'amber-200', fade=55), _e('90% 90%', '14% 12%', 'paper-50', 75, 100),
                            _e('100% 100%', '0% 100%', 'night-600', fade=95), _e('80% 80%', '100% 100%', 'red-300', 30, 100), _e('40% 34%', '52% 36%', 'amber-50', 45)]),
}


def styles(kind):
    base, layers = MESHES[kind]
    return {'backgroundColor': C(base), 'backgroundImage': ', '.join(layers)}


if __name__ == '__main__':
    import json
    print(json.dumps({k: styles(k) for k in MESHES}, indent=1))
