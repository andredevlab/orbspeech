// The Glass pack. The hero collection, and the answer to the verdict that killed
// the first forty-eight: "they just don't feel high quality yet."
//
// THE LESSON OF THE REFERENCE CLASS. The Siri and ChatGPT voice orbs do not
// differentiate by silhouette. Every one of them is the same soft volumetric
// glass body; what changes between them is what is happening INSIDE. The first
// forty-eight species went the other way -- each one invented its own shape, and
// forty-eight shapes is a grid of experiments rather than a collection. So this
// family has exactly ONE body, written once and carefully below, and twelve
// interiors. The body is the product. The heroes are what it is thinking about.
//
//   mh_aura     two or three wide soft ribbons of coloured light drifting
//               INSIDE the volume, crossing each other at different depths.
//   mh_droplet  the deformation hero: a zero-g liquid sphere wobbling, breathing
//               with voice, nearly clear around a soft luminous core.
//   mh_limn     near-dark glass whose EDGE is alive: a travelling arc of rim
//               light with a soft tail, never a full even ring.
//   mh_comet    one bright point on a tilted three-dimensional orbit inside,
//               trailing light that curves with the volume.
//   mh_nebula   the volumetric showcase: no object at all, just weather. Mist
//               folding slowly, lit from within so near folds silhouette
//               against the deep glow, with a glint buried in it.
//   mh_prism    light entering where the highlight says it does and fanning
//               into three soft diverging shafts, one hue each.
//   mh_duet     two luminous bodies orbiting a common centre, one warm of the
//               anchor and one cool, passing in front of and behind each other.
//   mh_still    the discipline piece: a nearly clear sphere whose rim and
//               catchlight are the figure, crossed by one slow glint.
//   mh_fathom   nested translucent shells, solved rather than marched, each
//               folded and turning at its own rate: depth you can count.
//   mh_arc      one soft bright filament arcing through the volume, anchored
//               near the core and never touching the shell.
//   mh_opal     play-of-colour: four soft flashes born and absorbed slowly, at
//               four points across the widest spread in the collection.
//   mh_flux     an aurora streaming inside the glass: curtains standing on a
//               bright foot, bending as they go.
//
// WHAT THE BODY KIT IS, and why each part of it is there. Seven things separate a
// glass presence from a painted disc, and a species that skips any one of them
// looks like a sticker no matter how good its interior is:
//
//   1. A DEFORMED SDF SPHERE. mh_deform sums three low-order modes -- sines of
//      the dot product with three slowly rotating axes, wavenumbers 1.7, 2.6 and
//      3.4, so roughly one and a half to three lobes across the body. Low order
//      matters: a high-frequency surface is a golf ball, and the eye reads it as
//      texture rather than as a soft body that is slightly out of round. Every
//      hero carries at least a whisper of it (0.022) because a mathematically
//      perfect sphere is the single most obvious tell that something was drawn
//      by a formula. Droplet turns it to 0.064, and gains its SHADING up
//      further still, which is what a body allowed to look liquid needs.
//
//   2. A REAL INTERIOR. Five taps along the view ray between the entry point and
//      the exit, sampling a THREE-DIMENSIONAL field, accumulated front to back
//      with transmittance so near content occludes far. This is the whole
//      argument of the family: interior content that parallaxes as the body
//      turns cannot be faked by painting on a disc, and the eye knows within
//      about a second which one it is looking at.
//
//   3. REFRACTION AT ENTRY. The ray does not go straight in. mh_refract bends it
//      toward the normal by Snell's law at a gentle 1.20 index, which does
//      nothing at the centre (the normal faces the viewer, so there is no angle
//      to bend) and everything at the limb, where it drags the ray across the
//      body and compresses the interior into the edge. That compression is what
//      makes a sphere look like it is FULL of something. Without it the interior
//      reads as a decal even with the depth march intact -- this was the single
//      biggest step up in the whole file.
//
//   4. A FRESNEL RIM THAT IS NOT A RING. Edge light rises as pow(1 - N.z, 3.9),
//      so it lives in the outer eighth of the body, and it is then weighted by
//      direction: brighter on the side away from the key. An even rim is a
//      stroked circle; an uneven one is a body in a room. It rides the DEFORMED
//      normal, so on droplet the rim traces the wobble.
//
//   5. ONE SPECULAR AND A CONTACT GLOW. Two lobes -- a tight one at 96 and a
//      broad sheen at 4 -- from one key up and to the left that drifts a few
//      degrees over half a minute, plus a barely-there bloom outside the
//      silhouette that pools slightly beneath. The specular is what reaches the
//      rail's cream stop; per the value hierarchy, a cell whose brightest pixel
//      is rust has failed, and on a glass body the highlight is the honest place
//      for the brightest pixel to be.
//
//   6. ABSORPTION. MH_EXT gives the glass a base extinction per unit of path, so
//      the far side of the body is genuinely dimmer than the near side. It is
//      one constant and it bought more depth than any other line in the file: it
//      is what makes a ribbon passing behind the middle read as passing BEHIND
//      rather than merely crossing.
//
//   7. THE FRESNEL SPLIT. mh_transmit weights the interior by how square the
//      view is to the surface, so near the limb almost nothing gets through.
//      That is what puts a real boundary between a bright reflective rim and the
//      content behind it, which is the contrast the reference orbs have and
//      which no amount of rim brightness produces on its own. It also kills the
//      inverted ghost a sphere lenses out of its own interior near the limb --
//      on comet that ghost had been reading as a second comet.
//
// THE MOTION LAW. Nothing here ticks. Every travelling phase goes through
// mh_drift, which is a rate plus the integral of a slow sinusoidal modulation of
// that rate: the closed form is theta = w*t + (k*w/w2)*sin(w2*t), whose
// derivative is w*(1 + k*cos(w2*t)) and is therefore strictly positive for
// k < 1 -- it speeds up and slows down and never stops or reverses. Every
// breath goes through mh_breath, which sums two periods (9.4 s and 14.7 s) that
// share no multiple the eye can find, so the body is always mid-breath and never
// at the top or bottom of a cycle you could count. Each hero's phases are given
// different lanes so no two of its motions agree, which is the difference
// between a presence and a mechanism.
//
// THE HUE SPREAD, and why the rail got its one extension. The reference orbs let
// two or three neighbouring hues interplay inside the glass, and that is a large
// part of why they look expensive. The hard rule is one hue family per
// configuration and the rail exists to enforce it, so the extension is made
// where it cannot go wrong: mh_shade walks the copied three-segment rail exactly
// as before and then ROTATES the resulting OKLAB chroma vector by an angle. L
// and C are untouched, so a spread colour is the same lightness and the same
// saturation as the anchor -- it cannot go muddy, because muddy is what happens
// when chroma is traded for hue. The cap is 0.50 radians, about 29 degrees each
// way: amber to gold on one side and amber to ember on the other. At hue = 0 the
// rotation is the identity and the rail is bit-for-bit the copied one. `spread`
// is c3 on every hero and each spends it on the axis that means something in its
// own physics: aura on which ribbon, comet on the age of the trail, limn on the
// distance behind the arc's head, droplet on depth through the body.
//
// SIZE. Three mounts, and the middle one is not the design target: an 18 pt
// inline field, a 46 pt chip, a 120 pt voice stage. mh_small is the dial and
// every hero spends it the same way -- STRUCTURE COUNTS DOWN, STROKES THICKEN,
// FINE FREQUENCIES SWITCH OFF. At 18 pt aura is two thick ribbons, droplet is a
// wobbling body around one big core, limn is a broad comma of rim light, and
// comet is a spark circling on a wider orbit. What survives is one bold gesture.
// At 120 pt the third ribbon, the granulation, the interior hint and the fine
// trail all come back, and they are what makes the large mount worth watching.
//
// THE CLIP IS A HARD BOUNDARY AND THE BODY RESPECTS IT. The view clips to a
// circle at length(uv) = 0.5. The body sits at MH_R = 0.300 with its
// displacement capped at 8.5 per cent and, on droplet, a voice swell capped at
// 5 per cent on top of that, so the worst case silhouette is 0.339 and the
// containment does not begin to fall until 0.36. The contact glow is allowed to
// run into that falloff because it is a soft gradient meeting another soft
// gradient; the BODY never is, because a sliced glass sphere is the one failure
// nobody would forgive. The body's radius is deliberately NOT driven by
// formScale for the same reason: the silhouette is this family's identity and it
// is not a dial. formScale scales the interior forms, which is where it means
// something anyway.
//
// TWO GROUNDS, ONE FAMILY. The shader is handed the ground it will sit on, and
// on a light one nearly every rule above turns over. There is nowhere brighter
// than paper for energy to go, so the rail descends instead of climbing: content
// becomes CHROMA AND SHADOW rather than light, which is what a tinted
// transparent object actually does to what is behind it. The body goes pale
// -- clear glass on a page is almost nothing plus an edge -- the rim becomes the
// fine dark refracted edge rather than a glow, the contact bloom becomes a
// contact shadow pooled beneath, and the specular leaves the energy sum
// altogether to be composited as the one thing in the frame brighter than the
// page. mh_paper reads the ground's OKLAB lightness and everything downstream
// MIXES on it rather than branching, so a mid grey lands somewhere both rails
// agree on and a designer dragging the ink from ink to paper never sees a jump.
// At paper = 0 every one of those terms is algebraically the identity, which is
// how the twelve heroes reviewed on ink are unchanged to the bit.
//
// COPIED HELPERS. Cross-file Metal linkage is not guaranteed, so the kit is
// copied out of FieldLab.metal and FieldPackPour.metal (by way of
// MurmurPresence.metal, this pack's conventions exemplar) VERBATIM under an mh_
// prefix. Copied, unchanged except for the name:
//
//   mh_hash, mh_grad3, mh_noise3,
//   mh_srgb_to_linear, mh_linear_to_srgb, mh_linear_to_oklab,
//   mh_oklab_to_linear, mh_lch, MHPalette, mh_palette,
//   mh_out, mh_knee, mh_tier, mh_lit, mh_spin, mh_small
//
// Their comments come with them: the reasoning is the part worth carrying.
// mh_shade is the copied rail plus the documented hue rotation above, and
// mh_containment is the copied one with a tighter span, because this family's
// silhouette is a hard-edged body rather than a field that dissolves on its own.
// The derivative-carrying noise, the fBm and the settle law are NOT copied:
// this pack's surfaces are closed-form so their slopes are exact and free, its
// interior haze wants one octave rather than four, and nothing here honours
// epoch. Dead code behind a prefix is still dead code.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// MARK: - The copied kit
//
// Everything in this section is FieldLab.metal's, FieldPackPour.metal's or
// MurmurPresence.metal's, verbatim, renamed. The two exceptions say so.

/// An integer avalanche. Lattice coordinates in, well-mixed bits out. A sine
/// hash was the other option and it drifts into visible repeats once the domain
/// gets large, which the long previews here would find.
static inline uint mh_hash(uint3 v) {
    uint h = v.x * 1597334673u ^ v.y * 3812015801u ^ v.z * 2798796415u;
    h ^= h >> 15; h *= 2246822519u;
    h ^= h >> 13; h *= 3266489917u;
    h ^= h >> 16;
    return h;
}

/// A unit vector distributed uniformly on the sphere, from one lattice cell.
/// Uniform matters: gradients bunched near the poles put a grain in the field
/// that reads as a weave once the octaves stack.
static inline float3 mh_grad3(int3 c) {
    uint h = mh_hash(uint3(c + 4096));
    float z = fma(float(h & 0xFFFFu), 2.0 / 65535.0, -1.0);
    float a = float((h >> 16) & 0xFFFFu) * (6.28318530718 / 65536.0);
    float r = sqrt(max(0.0, 1.0 - z * z));
    return float3(r * cos(a), r * sin(a), z);
}

/// The value alone, for the places that never ask what the slope is.
static float mh_noise3(float3 p) {
    float3 i = floor(p);
    float3 f = p - i;
    float3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    int3 c = int3(i);

    float va = dot(mh_grad3(c + int3(0, 0, 0)), f - float3(0.0, 0.0, 0.0));
    float vb = dot(mh_grad3(c + int3(1, 0, 0)), f - float3(1.0, 0.0, 0.0));
    float vc = dot(mh_grad3(c + int3(0, 1, 0)), f - float3(0.0, 1.0, 0.0));
    float vd = dot(mh_grad3(c + int3(1, 1, 0)), f - float3(1.0, 1.0, 0.0));
    float ve = dot(mh_grad3(c + int3(0, 0, 1)), f - float3(0.0, 0.0, 1.0));
    float vf = dot(mh_grad3(c + int3(1, 0, 1)), f - float3(1.0, 0.0, 1.0));
    float vg = dot(mh_grad3(c + int3(0, 1, 1)), f - float3(0.0, 1.0, 1.0));
    float vh = dot(mh_grad3(c + int3(1, 1, 1)), f - float3(1.0, 1.0, 1.0));

    return mix(mix(mix(va, vb, u.x), mix(vc, vd, u.x), u.y),
               mix(mix(ve, vf, u.x), mix(vg, vh, u.x), u.y), u.z);
}

static inline float3 mh_srgb_to_linear(float3 c) {
    c = max(c, 0.0);
    return select(c * (1.0 / 12.92), pow((c + 0.055) * (1.0 / 1.055), 2.4), c > 0.04045);
}

static inline float3 mh_linear_to_srgb(float3 c) {
    c = max(c, 0.0);
    return select(c * 12.92, 1.055 * pow(c, 1.0 / 2.4) - 0.055, c > 0.0031308);
}

static inline float3 mh_linear_to_oklab(float3 c) {
    float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
    float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
    float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;
    float l_ = pow(max(l, 0.0), 1.0 / 3.0);
    float m_ = pow(max(m, 0.0), 1.0 / 3.0);
    float s_ = pow(max(s, 0.0), 1.0 / 3.0);
    return float3(0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
                  1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
                  0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_);
}

static inline float3 mh_oklab_to_linear(float3 lab) {
    float l_ = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z;
    float m_ = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z;
    float s_ = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z;
    float l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_;
    return float3( 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                  -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                  -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s);
}

/// Lightness, chroma, hue back into OKLAB's rectangular form.
static inline float3 mh_lch(float L, float C, float h) {
    return float3(L, C * cos(h), C * sin(h));
}

/// HOW LIGHT THE GROUND IS, in OKLAB lightness rather than an RGB average,
/// because a saturated mid-blue paper and a light grey with the same channel
/// mean are nowhere near the same brightness to the eye and this decision is
/// entirely about what the eye does.
///
/// Returns 0 for the house ink (L about 0.16), 1 for paper (L about 0.97), and
/// a continuous blend between. The band is placed so a true mid grey -- sRGB
/// 0.5, whose OKLAB L is 0.60, not 0.5 -- lands at about four tenths of the way
/// across, which is the honest answer for a ground that is genuinely ambiguous.
/// Nothing in this file ever branches on it; every use is a mix, so a designer
/// dragging the ink colour from ink to paper sees the body change continuously
/// with no frame where it jumps.
static inline float mh_paper(half4 inkColor) {
    float L = mh_linear_to_oklab(mh_srgb_to_linear(float3(inkColor.rgb))).x;
    return smoothstep(0.50, 0.72, L);
}

/// Four OKLAB stops built from one anchor: the tone the indicator wears.
/// Ordered dark to bright on an ink ground, PALE TO DEEP on a paper one, and
/// mixed between the two by how light the ground is. Never more than one hue
/// family wide either way.
struct MHPalette {
    float3 s0, s1, s2, s3;
    float  paper;   // how light the ground is, 0 ink ... 1 paper
    float  duo;     // how far tone2 is from tone, 0 when identical
    float  dHue;    // tone2's hue minus tone's, the short way round
    float  dC;      // tone2's chroma over tone's
    float  dL;      // tone2's lightness over tone's
};

/// s0 is the ink the whole app sits on, so a field at zero dissolves into the
/// screen with no seam. s1 is a deep shadow that KEEPS the tone's hue at half
/// its chroma, which is what stops the dark end going grey. s2 is the tone. s3
/// is a pale specular a few degrees warmer, because light that has passed
/// through anything comes out warmer than the thing it lit.
/// `depth` opens the range from both ends without letting the hue wander.
static MHPalette mh_palette(half4 inkColor, half4 toneColor, half4 tone2Color,
                            float hueShift, float depth) {
    float3 ink = mh_linear_to_oklab(mh_srgb_to_linear(float3(inkColor.rgb)));
    float3 tone = mh_linear_to_oklab(mh_srgb_to_linear(float3(toneColor.rgb)));

    float L = tone.x;
    float C = length(tone.yz);
    float h = atan2(tone.z, tone.y) + hueShift;
    float d = clamp(depth, 0.30, 2.00);

    // The shadow shifts WARM as it darkens, roughly twenty degrees of hue
    // toward ember, and keeps most of its chroma rather than draining to grey.
    // Both of those are the difference between a deep amber and mud: a straight
    // desaturating fall from gold to ink passes through olive, and olive is what
    // the first cut of every one of these fields looked like.
    MHPalette p;
    p.paper = mh_paper(inkColor);

    // THE SECOND ANCHOR. Read as a DIFFERENCE from the first rather than as a
    // palette of its own, which is what keeps duotone inside the family's one
    // law: the rail is still built entirely from `tone`, and tone2 only says
    // where the spread's positive side is allowed to walk to. A configuration
    // with two anchors is still one material lit two ways, not two materials.
    //
    // `duo` is a smoothstep on the OKLAB distance between the anchors and it is
    // EXACTLY ZERO when they are equal, which is the property the whole upgrade
    // rests on: at zero every term below collapses to the identity and the
    // twelve heroes already reviewed render bit for bit as they did.
    //
    // The hue difference is taken the SHORT way round the wheel. Without the
    // wrap, two anchors either side of the origin -- a red and a warm yellow,
    // say -- would walk the long way through green to reach each other, which is
    // both wrong and the one thing the one-hue-family rule exists to prevent.
    float3 tone2 = mh_linear_to_oklab(mh_srgb_to_linear(float3(tone2Color.rgb)));
    float C2 = length(tone2.yz);
    float h2 = atan2(tone2.z, tone2.y) + hueShift;
    float dh = h2 - (atan2(tone.z, tone.y) + hueShift);
    p.dHue = dh - 6.2831853 * floor(dh / 6.2831853 + 0.5);
    p.dC   = C2 / max(length(tone.yz), 1e-4);
    p.dL   = tone2.x / max(tone.x, 1e-4);
    p.duo  = smoothstep(0.004, 0.035, length(tone2 - tone));

    // THE INK RAIL. Dark to bright: energy becomes light.
    float3 d0 = ink;
    float3 d1 = mh_lch(mix(ink.x, L, 0.30 / d), C * (0.52 + 0.10 * d), h - 0.35);
    float3 d2 = mh_lch(L, C, h);
    float3 d3 = mh_lch(min(L * (1.20 + 0.12 * d), 0.93), C * 0.55, h + 0.10);

    // THE PAPER RAIL, and it runs the other way, because on a light ground
    // energy cannot become light -- there is nowhere brighter than the paper to
    // go. Kris's note was that the defaults are hard on light mode, and this is
    // the whole of why: the ink rail's top stop is a pale cream at L 0.93, which
    // against paper at L 0.97 is invisible. A cream rim on white is not a dim
    // rim, it is no rim.
    //
    // So on paper the rail descends and DEEPENS. Energy becomes chroma and
    // shadow, which is what a tinted transparent object actually does to the
    // light behind it: more material, more colour, less transmitted light.
    //
    //   l0  the paper itself, so a field at zero dissolves into the page with no
    //       seam -- the same law s0 obeys, said on the other side.
    //   l1  THE GLASS. Barely off the paper and barely tinted, because that is
    //       what a clear sphere on white looks like: almost nothing, plus an
    //       edge. This stop is most of the body and it is meant to be.
    //   l2  the tone, dropped in lightness and pushed a fifth up in chroma. This
    //       is where interior CONTENT lands, and the chroma is what carries the
    //       read now that lightness cannot.
    //   l3  the deepest, for the rim's refracted edge and the hottest spines:
    //       darker still and shifted a little toward ember, because looking
    //       through more of a warm glass is what makes it go red rather than
    //       what makes it go pale.
    //
    // Chroma above the sRGB gamut clips in mh_out. The multipliers are kept near
    // 1.2 for that reason: the house amber sits around 0.11 OKLAB chroma, so a
    // fifth over is still inside the gamut and no hue twists on the way out.
    float Lp = ink.x;
    float3 l0 = ink;
    float3 l1 = mh_lch(mix(Lp, L, 0.42 / d), C * (0.34 + 0.10 * d), h + 0.05);
    float3 l2 = mh_lch(L * (0.82 - 0.06 * d), C * (1.20 + 0.14 * d), h);
    float3 l3 = mh_lch(max(L * (0.52 - 0.05 * d), 0.18), C * (1.05 + 0.10 * d), h - 0.08);

    // MIXING THE STOPS RATHER THAN THE COLOURS, and it is exact rather than an
    // approximation: mh_shade's walk is linear in the stops for any fixed t, so
    // blending the stops first and walking once gives the identical answer to
    // walking both rails and blending the results -- at half the cost, and with
    // the guarantee that a mid-grey ground can never land somewhere neither rail
    // would have gone.
    p.s0 = mix(d0, l0, p.paper);
    p.s1 = mix(d1, l1, p.paper);
    p.s2 = mix(d2, l2, p.paper);
    p.s3 = mix(d3, l3, p.paper);
    return p;
}

/// The spread cap. 0.50 radians is about 29 degrees of OKLAB hue either side of
/// the anchor: amber to gold one way, amber to ember the other. Two or three
/// hues in conversation, which is the reference-orb look, and nowhere near a
/// second hue family, which is the rule.
constant float MH_SPREAD = 0.50;

/// Walk the family. Three segments, each eased so its ends are flat, which
/// makes the joins C1: no kink shows up as a contour line in a smooth field.
/// Returns LINEAR light; mh_out does the encoding.
///
/// THE ONE EXTENSION, and the header argues for it at length: `hue` rotates the
/// walked colour's OKLAB chroma vector before it is converted, which moves the
/// hue while holding lightness and chroma exactly. That is the safe axis. The
/// unsafe one is trading chroma for hue, which is how a warm palette turns to
/// mud, and this cannot do it. At hue = 0 the rotation is the identity and this
/// is the copied function unchanged, which is the property that lets every
/// non-spread pixel in the pack stay on the house rail.
static float3 mh_shade(MHPalette p, float t, float hue) {
    t = clamp(t, 0.0, 1.0);
    float3 lab;
    if (t < 0.40) {
        lab = mix(p.s0, p.s1, smoothstep(0.0, 1.0, t * 2.5));
    } else if (t < 0.78) {
        lab = mix(p.s1, p.s2, smoothstep(0.0, 1.0, (t - 0.40) * (1.0 / 0.38)));
    } else {
        lab = mix(p.s2, p.s3, smoothstep(0.0, 1.0, (t - 0.78) * (1.0 / 0.22)));
    }
    // THE SPREAD AXIS, AND DUOTONE RIDES IT. `hue` is a signed offset along the
    // spread: negative is one neighbour of the anchor, positive the other. With
    // one anchor both sides are the same rotation mirrored, which is what the
    // twelve heroes were built on. With two, the POSITIVE side stops being a
    // rotation of the anchor and becomes a walk toward tone2 -- its hue, its
    // chroma and its lightness -- while the negative side is left exactly as it
    // was. That is what "replaces the spread-derived neighbour on that side"
    // means, and it is why spread still matters under duotone: spread is the
    // axis, and it is what widens the palette around EACH anchor.
    //
    // Decomposed into pos and neg rather than clamped to the cap, because opal
    // deliberately runs its spread a third past MH_SPREAD and a clamp here would
    // silently take that back.
    //
    // At duo = 0 the positive side's mix returns MH_SPREAD, the two halves
    // recombine to exactly `hue`, and both scales are exactly 1: the identity,
    // for any magnitude, with no epsilon anywhere in it.
    float a = hue * (1.0 / MH_SPREAD);
    float pos = max(a, 0.0), neg = max(-a, 0.0);
    float rot = -neg * MH_SPREAD + pos * mix(MH_SPREAD, p.dHue, p.duo);
    float w = min(pos, 1.0) * p.duo;
    float cS = 1.0 + w * (p.dC - 1.0);
    float lS = 1.0 + w * (p.dL - 1.0);

    float ch = cos(rot), sh = sin(rot);
    lab.yz = float2(lab.y * ch - lab.z * sh, lab.y * sh + lab.z * ch) * cS;
    lab.x *= lS;
    return mh_oklab_to_linear(lab);
}

/// The last thing every field does. One code value of triangular-PDF
/// interleaved-gradient dither, in the encoded space where the quantization
/// actually happens. Triangular rather than uniform because uniform dither
/// leaves a faint texture of its own in flat areas; triangular does not.
static inline half4 mh_out(float3 linearRGB, float2 pixel) {
    float3 c = mh_linear_to_srgb(linearRGB);
    float n = fract(52.9829189 * fract(dot(pixel, float2(0.06711056, 0.00583715))));
    float tri = n < 0.5 ? (sqrt(2.0 * n) - 1.0) : (1.0 - sqrt(max(0.0, 2.0 - 2.0 * n)));
    c += tri * (1.0 / 255.0);
    return half4(half3(saturate(c)), 1.0h);
}

/// A soft knee, the same one the route curtain uses. Below the knee nothing
/// changes; above it the tail compresses asymptotically instead of clipping,
/// which is what stops a bright field turning into flat white paper.
static inline float mh_knee(float x, float knee) {
    return x < knee ? x : knee + (1.0 - knee) * (1.0 - exp(-(x - knee) / max(1.0 - knee, 1e-3)));
}

/// THE VALUE HIERARCHY, as one curve.
///
/// Three tiers or it fails: ink ground, amber body, CREAM PEAKS. A cell whose
/// brightest pixel is rust is a cell nobody can parse, and these are small
/// objects in a chat UI rather than surfaces someone lives beside.
///
/// One number gets all three by spending the rail unevenly. The bottom
/// seventy-eight per cent of the energy is compressed into the rail's first
/// seventy-two, which is the whole amber body from shadow to tone, so most of
/// the picture is warm and readable and none of it is near white. The last
/// twenty-two per cent of the energy is spent on the rail's last twenty-eight,
/// where the specular lives, so only the figure's key structure goes cream --
/// and when it goes it goes decisively rather than creeping.
///
/// The join is smoothed over a fifth of the range, because a slope kink in a
/// map this shallow shows up as a contour line in a smooth field.
///
/// What this asks of every species: normalise so the figure's SPINE reaches
/// about 1.0 while its body sits between 0.35 and 0.7. In this family the spine
/// is the specular highlight and the hottest interior core, and nothing else is
/// allowed near the top.
static inline float mh_tier(float e) {
    float x = clamp(e, 0.0, 1.0);
    const float K = 0.78;
    float body = (x / K) * 0.72;
    float peak = 0.72 + ((x - K) / (1.0 - K)) * 0.28;
    return mix(body, peak, smoothstep(K - 0.10, K + 0.10, x));
}

/// THE ONE PLACE ENERGY BECOMES LIGHT. All twelve species compute a density in
/// 0...1 and hand it here, which is most of what keeps the family reading as one
/// family: there is exactly one relationship between how much material is at a
/// pixel and how bright and how warm that pixel is, and no species invents its
/// own.
///
/// `glow` is the presence dial and it enters twice, both times where it cannot
/// lie: it scales the energy BEFORE the rail walk, so a lower setting walks less
/// far and therefore reads cooler and deeper rather than merely faded, and it
/// scales the emission on top. At glow = 1 the first term is the identity. At
/// glow = 0 a third of the energy survives, because an indicator that can be
/// switched off by a dial is a bug and not a dial.
///
/// The knee before the rail walk, and not a clamp, because a clamp is where
/// these species would go wrong in the same way: several of them build an energy
/// that can pass 1 in their bright places, and clamping turns those places into
/// FLAT plateaus of identical colour with a visible contour around them. The
/// knee compresses the same overshoot asymptotically, so a specular or the core
/// of a comet keeps its shape instead of becoming a patch.
static inline float3 mh_lit(MHPalette pal, float e, float glow,
                            float base, float span, float emis, float hue) {
    float G = max(glow, 0.0);
    float en = clamp(mh_knee(max(e, 0.0) * (0.35 + 0.65 * G), 0.92), 0.0, 1.0);
    float tRail = clamp(base + span * mh_tier(en), 0.0, 1.0);
    float3 col = mh_shade(pal, tRail, hue);
    // Emission is gated to the specular, not to the tone: the rail reaches the
    // top routinely, and emission from the whole amber body would put the ground
    // back up and flatten the very hierarchy mh_tier just built.
    //
    // And it is switched off as the ground goes light, because on paper the top
    // of the rail is the DEEPEST colour rather than the brightest: multiplying
    // it up would walk the darkest part of the picture back toward the page and
    // undo the one mechanism the light rail has.
    return col * (1.0 + emis * G * (1.0 - pal.paper) * smoothstep(0.72, 1.0, tRail));
}

/// THE CONTAINMENT. fl_edge's job, done for a circle instead of a screen.
///
/// The view clips these indicators to a Circle at length(uv) = 0.5, and a clip
/// is a hard edge: any form still carrying light when it arrives is sliced. In
/// this family the body has its own silhouette well inside that boundary, so
/// this is a safety net for the contact glow rather than the design of the
/// edge -- which is why the span is 0.26 here rather than the 0.31 the other
/// packs use. Called at 0.72, the fall runs from a uv radius of 0.36 to 0.49,
/// and the body's worst case is 0.339.
static inline float mh_containment(float2 uv, float reach) {
    float r = length(uv) * 2.0;
    return 1.0 - smoothstep(reach, reach + 0.26, r);
}

/// Turn the ball. One rotation about the vertical, which is the presence turning
/// to face you, and a tilt, so the pole never sits still long enough to become a
/// landmark the eye can lock onto.
static inline float3 mh_spin(float3 p, float ay, float ax) {
    float ca = cos(ay), sa = sin(ay);
    float3 q = float3(ca * p.x + sa * p.z, p.y, -sa * p.x + ca * p.z);
    float cb = cos(ax), sb = sin(ax);
    return float3(q.x, cb * q.y - sb * q.z, sb * q.y + cb * q.z);
}

/// THE SIZE DIAL. One number, 1 at 18 pt and 0 at 120 pt and above, and every
/// species spends it the same way: structure counts down, strokes thicken.
///
/// The midpoint sits at about 46 pt, the chip mount, so the chip lands two
/// thirds of the way toward the small treatment -- which is right, because a 46
/// pt chip is a small object that happens to be bigger than the smallest one.
static inline float mh_small(float2 size) {
    return 1.0 - smoothstep(16.0, 88.0, max(min(size.x, size.y), 1.0));
}

// MARK: - The motion law
//
// Two functions, and between them they are the reason this family reads as
// premium rather than as animation. Neither has any state between frames: any
// `time` renders the correct picture, which the screenshot rig and the scrub
// slider both depend on.

/// A PHASE THAT NEVER TICKS.
///
/// Anything that travels -- a ribbon around its axis, an arc around the rim, a
/// comet around its orbit -- goes through here instead of through `rate * t`. A
/// constant angular rate is the single most recognisable tell of a shader: the
/// eye locks onto the period within two laps and the presence becomes a loading
/// spinner.
///
/// The closed form is theta = w*t + (k*w/w2) * sin(w2*t + phi), which is the
/// exact integral of a rate w * (1 + k*cos(w2*t + phi)). Two consequences, both
/// of them the point: the rate is strictly positive for k < 1, so the motion
/// eases without ever stalling or reversing, and the modulation period (w2 is
/// about seven seconds and lane-dependent, so no two phases in a species agree)
/// is long enough that what the eye reads is a body that hurries and then
/// relaxes rather than a wobble.
///
/// k is capped at 0.72: past about 0.8 the slow part gets slow enough to look
/// like a stall, and a stall reads as a dropped frame.
static inline float mh_drift(float t, float rate, float wobble, float lane) {
    float k = clamp(wobble, 0.0, 0.72);
    float w2 = 0.137 + 0.0413 * lane;
    return rate * t + (k * rate / w2) * sin(w2 * t + lane * 1.71);
}

/// One lane of the hash, for the gesture clock. Copied.


/// THE FLOURISH CLOCK, and it is the pack's play mechanism.
///
/// Every hero from the second batch on performs ONE gesture: a thing the
/// presence does now and then and then lets go of. Nebula buries a glint in the
/// mist; prism's shafts fan wide and pulse; duet's pair draws close and hurries
/// round each other; still's single glint crossing the glass IS its entire
/// species. The clock says when, and the three rules it exists to keep are all
/// in its arithmetic.
///
/// APERIODIC, NEVER A METRONOME. Time is cut into slots and each slot holds
/// exactly one gesture, but WHERE in its slot the gesture falls is hashed per
/// slot. The interval between two onsets is therefore the slot length plus the
/// difference of two independent jitters, so no two gaps are the same and there
/// is nothing for the eye to lock onto. The slot length is a parameter here
/// rather than the exemplar's constant, because these four want very different
/// tempos: still is briefed at one glint every ten seconds or so, and nebula's
/// buried glint wants to come round rather more often than that.
///
/// DETERMINISTIC. The slot index is floor(t / slot) and everything else is a
/// hash of it, so any t at all renders the correct frame: a screenshot rig, a
/// scrubbed slider and a resumed app all agree. There is no state between frames
/// anywhere in this pack and play does not get to be the exception.
///
/// NOTHING SNAPS. The envelope is sin^2(pi u), which is zero with zero slope at
/// both ends. It does not begin, it arrives; it does not stop, it finishes.
///
/// Returns (envelope, progress, a per-gesture random, the gesture's duration).
/// The random is what each hero spends on WHERE the gesture happens, so no two
/// occurrences are in the same place, and it is stable for the whole gesture
/// because it is hashed from the slot rather than from the time.


/// THE BREATH, and the rule is that the body is never at the top or the bottom
/// of it. Two periods, 9.4 s and 14.7 s, whose ratio is irrational enough that
/// their sum does not repeat inside any session anybody will sit through, so
/// there is no moment the eye can identify as "the start of the cycle". The
/// weights are 0.62 and 0.38 rather than equal because an even sum has a
/// symmetric envelope and reads as a sine again; uneven ones give the breath a
/// slow lean. Returns 0...1.
static inline float mh_breath(float t, float lane) {
    float a = sin(t * 0.668 + lane);
    float b = sin(t * 0.427 + lane * 2.3 + 1.1);
    return 0.5 + 0.5 * (0.62 * a + 0.38 * b);
}

// MARK: - THE GLASS BODY
//
// The shared kit. Every hero calls mh_body, marches its own interior between
// mh_body's entry point and mh_exit's length, shades the surface with
// mh_surface, and finishes on mh_present. The heroes differ ONLY in what they
// put inside.

/// The body's radius in uv. Not a dial: see the header on the clip. Everything
/// in this family is expressed in BODY UNITS, where 1.0 is this radius, so a
/// number like "the ribbon sits at 0.55" means something without arithmetic.
constant float MH_R = 0.300;

/// The refractive index of the glass. 1.18 rather than a physical 1.45: at 1.45
/// the limb swallows so much of the interior that the content the hero worked
/// for disappears into a two-pixel band, and the body reads as a marble rather
/// than as a presence with something happening inside it. 1.18 keeps the
/// magnifying edge and leaves the middle two thirds readable.
///
/// It came down from 1.22 for a second reason worth recording: a real glass
/// sphere shows an inverted GHOST of its own interior near the limb, and with
/// one small bright object inside -- comet's head -- the ghost was bright enough
/// and separate enough to read as a second comet. The species is one point of
/// light. MH_EXT below does most of the work of putting the ghost back in its
/// place; this took the last of it.
constant float MH_ETA = 1.0 / 1.20;

/// THE GLASS IS NOT PERFECTLY CLEAR, and this one number bought more depth than
/// anything else in the file. Every hero's transmittance carries a base
/// extinction per unit of path in addition to whatever its content absorbs, so
/// the far side of the body is genuinely dimmer than the near side: over a
/// two-unit chord a third of the light survives. That is what makes a ribbon
/// passing behind the middle read as passing BEHIND rather than merely crossing,
/// and it is what a body with no absorption at all can never look like, no
/// matter how many samples it takes.
constant float MH_EXT = 0.55;

/// How the surface is displaced. Heroes fill this and hand it to mh_body.
struct MHShape {
    float  amp;        // silhouette displacement, as a fraction of MH_R
    float  hi;         // the fine tremor mode, on top of the three slow ones
    float  gain;       // how much more the SHADING wobbles than the silhouette
    float3 flowDir;    // a travelling wave's axis: responding's directional lean
    float  flowAmp;
    float  flowPhase;
};

/// The still shape: three slow modes, no travelling wave.
static inline MHShape mh_shape(float amp, float hi, float gain) {
    MHShape s;
    s.amp = amp; s.hi = hi; s.gain = gain;
    s.flowDir = float3(0.0, 0.0, 1.0); s.flowAmp = 0.0; s.flowPhase = 0.0;
    return s;
}

/// THE DEFORMATION, and its exact gradient.
///
/// Three modes, each a sine of the dot product with a slowly rotating axis. On
/// the sphere that is a smooth low-order lobe pattern -- close enough to a low
/// band of spherical harmonics for the eye, and about a tenth of the cost. The
/// wavenumbers 1.7, 2.6 and 3.4 give roughly one and a half, two and three lobes
/// across the body: low enough that the result reads as "slightly out of round"
/// rather than as texture, which is the entire difference between a water
/// droplet and a golf ball.
///
/// The three axes rotate at 0.083, 0.061 and 0.047 rad/s -- periods of 76, 103
/// and 134 seconds, mutually incommensurate, so the body's shape never repeats
/// and never sits still. That slowness is deliberate: the deformation is the
/// thing the eye is least supposed to catch happening.
///
/// THE GRADIENT IS FREE AND EXACT. d/dn of sin(k * dot(n, a)) is k*cos(...)*a,
/// so the gradient falls out of the same trig the value needs. That matters more
/// than it sounds: it means the surface NORMAL is exact rather than
/// finite-differenced, which is what lets the specular highlight and the fresnel
/// rim ride the wobble cleanly instead of crawling with sampling noise.
///
/// `hi` is a fourth mode at wavenumber 6.9, which is texture rather than shape
/// and is only ever given amplitude by droplet's activity response. It gets its
/// own faster axis drift because a tremor that drifts as slowly as the body does
/// is not a tremor.
///
/// `flow` is a travelling planar wave -- sin(3.2 * dot(n, dir) + phase) -- and
/// it is how RESPONDING gets into the silhouette: a wave running around the body
/// in one direction, which is the only deformation on offer here that has an
/// unambiguous heading.
struct MHDeform { float d; float3 g; };

static MHDeform mh_deform(float3 n, float t, MHShape sh) {
    float a1 = t * 0.083, a2 = t * 0.061 + 2.10, a3 = t * 0.047 + 4.37;
    float3 ax1 = normalize(float3(cos(a1), 0.62, sin(a1)));
    float3 ax2 = normalize(float3(0.55, cos(a2), sin(a2)));
    float3 ax3 = normalize(float3(sin(a3), -0.44, cos(a3)));

    const float k1 = 1.70, k2 = 2.60, k3 = 3.40;
    const float w1 = 0.55, w2 = 0.30, w3 = 0.18;
    const float NORM = 1.0 / (w1 + w2 + w3);

    float u1 = dot(n, ax1), u2 = dot(n, ax2), u3 = dot(n, ax3);
    float d = (w1 * sin(k1 * u1) + w2 * sin(k2 * u2 + 1.9) + w3 * sin(k3 * u3 + 4.1)) * NORM;
    float3 g = (w1 * k1 * cos(k1 * u1) * ax1
              + w2 * k2 * cos(k2 * u2 + 1.9) * ax2
              + w3 * k3 * cos(k3 * u3 + 4.1) * ax3) * NORM;

    // The tremor. Its axis turns eight times faster than the body's modes do.
    if (sh.hi > 1e-4) {
        float a4 = t * 0.63;
        float3 ax4 = normalize(float3(cos(a4) * 0.8, sin(a4 * 0.77), sin(a4)));
        const float k4 = 6.90;
        float u4 = dot(n, ax4);
        d += sh.hi * sin(k4 * u4);
        g += sh.hi * k4 * cos(k4 * u4) * ax4;
    }

    // The travelling wave: responding, with a heading.
    if (sh.flowAmp > 1e-4) {
        const float kf = 3.20;
        float uf = dot(n, sh.flowDir);
        d += sh.flowAmp * sin(kf * uf + sh.flowPhase);
        g += sh.flowAmp * kf * cos(kf * uf + sh.flowPhase) * sh.flowDir;
    }

    MHDeform o; o.d = d; o.g = g;
    return o;
}

/// THE BODY, solved.
struct MHBody {
    float  m;      // membership: 1 inside, 0 outside, soft over the silhouette
    float3 P;      // the entry point on the deformed surface, in body units
    float3 N;      // the exact outward normal there
    float  Rd;     // the deformed radius along this pixel's direction
    float  rho;    // the pixel's in-plane radius, body units
    float  fres;   // 0 face-on, 1 at grazing
};

/// SOLVING A STAR-SHAPED SDF WITHOUT MARCHING IT.
///
/// The surface is r = Rd(n), which is star-shaped about the origin, so for an
/// orthographic view ray at in-plane radius rho the entry height z satisfies
/// z = sqrt(Rd(n)^2 - rho^2) with n itself depending on z. Two fixed-point
/// iterations solve it to well under a pixel for displacements this small, and
/// two evaluations of mh_deform is a tenth of what a sphere-trace would cost for
/// the same answer. The first pass uses the undeformed sphere's height as its
/// guess, which is never more than 8.5 per cent wrong by construction.
///
/// The projection is orthographic on purpose. A perspective camera on a body
/// this small buys nothing the eye can see and costs a divide per tap, and the
/// parallax that actually sells the volume comes from the REFRACTED interior
/// ray, not from the camera.
///
/// THE SILHOUETTE IS SOFT, and by two numbers added rather than multiplied: a
/// fixed 1.8 per cent of organic feather, because nothing in this house has a
/// hard edge, plus 1.3 pixels of anti-aliasing, because at 18 pt the fixed
/// feather is a fifth of a pixel and would alias to a staircase. The larger of
/// the two wins at each mount, which is what makes the edge look identical at
/// both.
///
/// THE NORMAL. For F(p) = |p| - Rd(p/|p|) the gradient is n minus the tangential
/// part of Rd's gradient over Rd -- exact, because mh_deform hands back the
/// gradient. `gain` then scales the perturbation past physical: the silhouette
/// is capped by the clip but the SHADING is not, so a droplet can look far more
/// liquid than its outline is allowed to be. That is a cheat and it is the right
/// one; the alternative is a body whose highlight barely moves.
static MHBody mh_body(float2 uv, float t, float px, MHShape sh) {
    MHBody o;
    // The clip is the law. Everything downstream trusts this cap.
    sh.amp = clamp(sh.amp, 0.0, 0.085);

    float2 s = uv / MH_R;
    o.rho = length(s);

    float z0 = sqrt(max(1.0 - min(o.rho * o.rho, 1.0), 0.0));
    float3 n0 = normalize(float3(s, z0) + float3(0.0, 0.0, 1e-6));
    float R0 = 1.0 + mh_deform(n0, t, sh).d * sh.amp;

    float z1 = sqrt(max(R0 * R0 - o.rho * o.rho, 0.0));
    float3 n1 = normalize(float3(s, z1) + float3(0.0, 0.0, 1e-6));
    MHDeform d1 = mh_deform(n1, t, sh);
    o.Rd = 1.0 + d1.d * sh.amp;

    float z2 = sqrt(max(o.Rd * o.Rd - o.rho * o.rho, 0.0));
    o.P = float3(s, z2);

    float3 gt = d1.g * sh.amp;
    gt = gt - dot(gt, n1) * n1;                       // the tangential part
    o.N = normalize(n1 - (gt * sh.gain) / max(o.Rd, 1e-3));

    float feather = max(0.018, 1.3 * px);
    o.m = 1.0 - smoothstep(o.Rd - feather, o.Rd + feather, o.rho);
    o.fres = 1.0 - clamp(o.N.z, 0.0, 1.0);
    return o;
}

/// THE BEND AT ENTRY. Snell, written out rather than borrowed from `refract`
/// so the total-internal guard is visible: with eta below 1 the discriminant
/// cannot go negative, but this function is also the obvious place a future
/// hero would raise the index, and a silent NaN at the limb is a black ring
/// around a glass ball.
static inline float3 mh_refract(float3 V, float3 N, float eta) {
    float ci = clamp(-dot(V, N), 0.0, 1.0);
    float k = 1.0 - eta * eta * (1.0 - ci * ci);
    if (k <= 0.0) return V;
    return normalize(eta * V + (eta * ci - sqrt(k)) * N);
}

/// HOW FAR THE INTERIOR SWIMS WHEN THE DEVICE TURNS.
///
/// 0.13 of a radian-ish lean per unit of tilt, which over a two-unit chord
/// moves the far side of the interior about a quarter of the body's radius
/// while the near side barely stirs. That difference IS the parallax and it is
/// the whole point: a picture that slid rigidly with the phone would read as a
/// texture being panned, where content at different depths moving at different
/// rates is the one cue the eye accepts as "there is really something in there".
///
/// Deliberately small. The reference for this is a spirit level or a compass
/// under glass, not a marble in a bowl; at twice this it stops being a material
/// property and becomes a toy.
constant float MH_TILT = 0.13;

/// THE INTERIOR'S LOOK DIRECTION, and the single place tilt enters the family.
///
/// Bending the RAY rather than moving the content is what makes one line serve
/// all eighteen heroes: every interior in this file is expressed against this
/// direction, whether it is marched (aura's sheets, nebula's weather) or solved
/// in closed form (droplet's heart, comet's head, duet's pair, arc's filament,
/// fathom's shells), so all of them parallax correctly and none of them needed a
/// word changed. And because the offset accumulates along the ray, deep content
/// moves further than shallow content for free -- which is the behaviour the
/// brief asks for and would have been fiddly to arrange any other way.
///
/// The body, the rim and the silhouette are built from the surface normal and
/// the entry point, neither of which this touches, so the glass itself holds
/// perfectly still while its contents swim. That contrast is what sells it.
///
/// The zero test is exact rather than an epsilon: at tilt (0,0) this returns
/// mh_refract's own vector untouched, so there is not even a renormalise
/// between today's render and today's render.
static inline float3 mh_look(float3 V, float3 N, float2 tilt) {
    float3 rd = mh_refract(V, N, MH_ETA);
    if (tilt.x == 0.0 && tilt.y == 0.0) return rd;
    return normalize(rd + float3(tilt.x, tilt.y, 0.0) * MH_TILT);
}

/// How far the interior ray travels before it leaves. Solved against the
/// UNDEFORMED unit sphere: the interior march does not need the surface to a
/// fraction of a per cent, and a second deformation solve per pixel would double
/// the body's cost to move the last tap by a pixel. Capped at 2.2 so a grazing
/// pixel outside the silhouette, where the membership is zero anyway, cannot
/// send the loop off into space.
static inline float mh_exit(float3 P, float3 rd) {
    float b = dot(P, rd);
    float c = dot(P, P) - 1.0;
    float disc = b * b - c;
    if (disc <= 0.0) return 0.0;
    return clamp(-b + sqrt(disc), 0.0, 2.2);
}

/// THE INTERIOR HAZE. A faint volumetric air every hero adds to its own content,
/// advecting slowly in all three axes so it is never a still texture. One octave,
/// not four: this is the medium the content hangs in, and an fBm here would give
/// the glass a cloudiness that competes with whatever the hero is actually about.
/// The five taps that already exist do the averaging that would otherwise need
/// the extra octaves.
static inline float mh_haze(float3 p, float t, float scale) {
    float3 q = p * scale + float3(t * 0.051, -t * 0.033, t * 0.089);
    return clamp(0.5 + 0.85 * mh_noise3(q), 0.0, 1.0);
}

/// WHAT GETS IN. The Fresnel split, and it is the piece the first two cuts of
/// this file were missing.
///
/// Light arriving at glass near head-on mostly goes through; light arriving near
/// grazing mostly bounces off. So the interior a pixel can see is weighted by
/// how square that pixel's view is to the surface, and near the limb almost
/// nothing gets through at all. Three things fall out of one line, and each of
/// them was a separate problem before it:
///
///   THE SHELL READS. The rim goes bright and reflective exactly where the
///   interior goes dark, so there is a real boundary between the two rather than
///   content bleeding out to the silhouette. That contrast IS the look of the
///   reference orbs and no amount of rim brightness produces it on its own.
///   DEPTH GETS AN EDGE FALLOFF for free -- content near the limb is seen
///   through more glass at a worse angle, and now it dims accordingly.
///   THE GHOST DIES. A sphere lenses a second, inverted image of its own
///   interior into the region near the limb, and with one small bright object
///   inside -- comet's head -- that ghost was bright enough to read as a second
///   comet. It lives at high fresnel by construction, which is precisely where
///   this takes it down to a tenth.
///
/// The exponent is 2.2 and the floor is 0.12: a real dielectric's curve is
/// steeper than that, and a steeper one here empties the outer third of the body
/// and makes the presence read as a small object inside a large lens.
static inline float mh_transmit(float fres) {
    return 1.0 - 0.88 * pow(clamp(fres, 0.0, 1.0), 2.2);
}

/// THE SCATTER, and it is the difference between light in glass and stickers on
/// black.
///
/// Round one built every hero as emissive content read at a point: a ribbon was
/// bright exactly where the ribbon was and the medium a millimetre away was
/// ink. That is not what a luminous body inside a translucent solid looks like.
/// Real glass is never optically empty -- it scatters, so every bright thing
/// inside it throws a wide soft glow into the material AROUND it, and what you
/// actually see is the object plus its own light living in the fog. Without that
/// term the interiors read as black voids with objects pasted in, which is
/// exactly the verdict round one got.
///
/// The law is one line and every hero spends it the same way. Content here is
/// built from gaussians, so the narrow term is exp(-arg) for some squared
/// normalised distance `arg`; scaling that same argument by 1/k^2 gives the
/// identical shape k times wider, for the cost of one more exp and no new
/// geometry. k is 3.2 -- ten times the area -- which is wide enough to fill the
/// space between two ribbons and tight enough that the object inside it is still
/// an object. Amplitude stays low, a sixth or so, because scatter is a haze
/// around a light and not a second light.
///
/// It dims with depth for free: the scatter is accumulated inside the march, so
/// MH_EXT and the running transmittance attenuate it exactly as they attenuate
/// everything else, and a glow thrown from the far side of the body arrives
/// dimmer than the same glow thrown from the near side.
constant float MH_SCATTER_K = 0.098;   // 1 / 3.2^2

static inline float mh_scatter(float arg, float amp) {
    return amp * exp(-arg * MH_SCATTER_K);
}

/// THE MEDIUM. What the glass is made of when nothing is happening in it.
///
/// The companion to the scatter and the other half of the same verdict: a body
/// whose ambient interior is zero reads HOLLOW, a shell with a hole in it, and
/// no amount of scatter off the content fixes the parts of the volume the
/// content is nowhere near. So there is a floor. It is a soft radial fog --
/// thickest through the middle, gone by the shell so it never fights the rim --
/// modulated by the same slowly advecting noise the haze used, at 0.55 plus 0.45
/// of it so the noise gives the fog structure without ever punching a hole in
/// it.
///
/// Kept deliberately faint. At the amplitudes the heroes give it this lands
/// around a fifth of the way up the rail: a dark warm interior you can see the
/// far wall through, not a glowing ball. The test is that the sphere reads as
/// FULL at a glance and you still cannot say what colour the empty part is.
static inline float mh_medium(float3 p, float t, float scale) {
    float fog = 1.0 - smoothstep(0.05, 0.98, length(p));
    return fog * (0.55 + 0.45 * mh_haze(p, t, scale));
}

/// CONTENT FLOATS, IT DOES NOT TOUCH THE WALL. Interior structure that reaches
/// the shell reads as painted ON the shell, which is the exact failure this
/// family exists to avoid, and it also fights the rim for the same pixels. So
/// every hero fades its content out from 0.72 of the radius and it is gone by
/// 0.99. What is left in that outer shell is haze, rim and specular: the glass
/// itself.
static inline float mh_inside(float3 p) {
    return 1.0 - smoothstep(0.76, 0.99, length(p));
}

/// THE SURFACE, shared by every hero.
struct MHSurface {
    float rim;    // fresnel edge light
    float spec;   // the highlight, both lobes
    float glow;   // the contact bloom outside the silhouette
};

/// THE KEY, and it is a shared function rather than a local because one hero
/// needs to know where it is. The light sits up and to the left and drifts about
/// four degrees over half a minute, which is enough that the highlight is never
/// in the same place twice and not enough that anybody watches it move. Screen y
/// runs DOWN in a colorEffect, so up-left is negative in both.
///
/// It is further out than a beauty light would be: at (-0.52, -0.60) the
/// highlight lands at about 0.45 of the radius, clear of whatever the hero has
/// put in the middle. Pulled in toward the axis it sat directly on top of
/// droplet's heart and comet's orbit and stopped being a separate event.
///
/// mh_prism reads this to place the entry point of the light it splits, so its
/// shafts enter the glass at the same spot the specular says the light is coming
/// from. Two independent copies of the same direction would drift apart the
/// first time either was tuned, and a prism whose beams enter somewhere other
/// than its own highlight is a prism nobody believes.
static inline float3 mh_key(float t) {
    float dr = t * 0.21;
    return normalize(float3(-0.52 + 0.055 * sin(dr),
                            -0.60 + 0.045 * cos(dr * 0.83),
                             0.61));
}
///
/// TWO SPECULAR LOBES. A tight one at 34 is the glint that reaches the rail's
/// cream stop and gives the body its brightest pixel; a broad one at 5 at a
/// sixth of the amplitude is the sheen that tells you the whole upper half of
/// the body is turned toward a light. One lobe alone gives either a plastic dot
/// or a foggy wash; the pair is what reads as glass.
///
/// THE RIM IS NOT A RING. pow(fresnel, 3) puts the edge light in the outer sixth
/// of the body, and it is then weighted by which way that edge faces: 55 per
/// cent everywhere plus 45 per cent on the side AWAY from the key, which is the
/// wrap light every product photograph of a glass object has and which an even
/// ring never looks like. It rides the deformed normal, so on droplet the rim
/// traces the wobble around the body.
///
/// THE CONTACT GLOW pools beneath. It is capped low -- a tenth of the body's
/// energy -- because the brief for it is "barely there": its job is to stop the
/// silhouette meeting the ink as a cut line, not to be a halo anybody notices.
static MHSurface mh_surface(MHBody b, float t, float small, half4 inkColor,
                            float2 tilt, float rimK, float specK, float glowK) {
    MHSurface o;
    float paper = mh_paper(inkColor);
    // The edge does more work on paper than it ever does on ink: it is the whole
    // silhouette of an object that is otherwise nearly the colour of the page,
    // and at small mounts it is very close to the only thing there is. A third
    // more of it, and no other term changes.
    rimK *= mix(1.0, 1.32, paper);

    // THE BARELY COUNTER-MOVE. Tilting the phone turns the ORB relative to the
    // room, so the room's light arrives from a slightly different angle and the
    // catchlight shifts -- against the tilt, because the world stays put while
    // the object turns. It is a fifth of what the interior does and it is meant
    // to be subliminal: what the eye should notice is the contents swimming
    // while the glass holds, and a highlight that moved as much as the interior
    // would say the whole object was sliding instead.
    float3 H = normalize(mh_key(t) - float3(tilt.x, tilt.y, 0.0) * (MH_TILT * 0.20)
                         + float3(0.0, 0.0, 1.0));
    float nh = clamp(dot(b.N, H), 0.0, 1.0);
    // THE TIGHT LOBE IS SIZE-ADAPTIVE, and it has to be: a 96-exponent highlight
    // covers about four pixels at 120 pt and a third of one at 18 pt, where it
    // would flicker in and out as the body wobbled underneath it. At 18 pt the
    // exponent drops to 16, which spreads the same light over two or three
    // pixels -- still unmistakably a glint, and stable.
    //
    // 96 rather than the 58 the first cut used, and the reason is the value
    // hierarchy rather than realism. At 58 the glint's saturated core was a
    // tenth of the frame across: a second bright object competing with whatever
    // the hero had put inside, and on comet it read as a second comet. A
    // specular is meant to be the brightest thing in the picture and one of the
    // smallest. Amplitude is left to the caller, because how much sheen a body
    // wears is a species decision -- droplet's whole surface is the point, and
    // limn's is a dark bead with one catchlight on it.
    float tight = mix(96.0, 16.0, small);
    o.spec = (pow(nh, tight) + 0.09 * pow(nh, 4.0)) * b.m * specK
           * mix(0.92, 1.08, 0.5 - 0.5 * clamp(b.N.y, -1.0, 1.0));

    // The wrap is a LIGHTING cue -- brighter on the side away from the key --
    // and on paper the rim is not lighting at all: it is the refracted edge of a
    // clear sphere, which is a property of the geometry and goes all the way
    // round. So the asymmetry flattens as the ground goes light. Left in, the
    // dark edge faded out along its top and the sphere read as a crescent with a
    // shadow rather than as a closed object on a page.
    float wrap = 0.55 + 0.45 * clamp(dot(normalize(b.N.xy + float2(1e-4)),
                                         normalize(float2(0.42, 0.50))), 0.0, 1.0);
    wrap = mix(wrap, 0.88, paper);
    // Exponent 3.9, and it was fitted against a capture rather than chosen: at 3
    // the rim is a broad wash that reads as the body being lit from behind, and
    // the shell's boundary disappears into it. At 3.9 the light lives in the
    // outer eighth and the eye gets a CRISP EDGE with soft content behind it,
    // which is the single strongest cue that there is a shell at all.
    //
    // It tightens to 5.4 on paper, where the rim is no longer a glow but the
    // dark refracted edge of a clear sphere -- and a dark edge has to be FINE to
    // read as an edge rather than as a dirty ring. Same term, opposite polarity,
    // because the rail underneath it has turned over.
    // THE ENVIRONMENT, and the rule for it is that if you can see it, it is
    // wrong. A real glass body reflects a room: brighter off whatever is above
    // it, darker off whatever is below. So the rim and the catchlight carry a
    // soft vertical gradient read straight off the surface normal -- fourteen
    // per cent on the rim, eight on the specular -- and that is the entire
    // feature. It is not a light and it does not move; it is the reason the
    // glass looks like it is somewhere.
    //
    // IT IS A VALUE GRADIENT AND NOT A COLOUR ONE, on purpose. A cool sky and a
    // warm ground is what an environment really does and it is exactly what this
    // family may not have: a second hue in the picture, arriving through a term
    // nobody dialled, would break the one-hue-family law from underneath.
    //
    // AND IT INVERTS ON PAPER. There, rim energy walks a descending rail, so
    // more of it is DARKER -- and a sky-lit top edge on a light ground has to be
    // paler, not deeper. Same gradient, mirrored, so the top of the sphere is
    // the lighter half of its edge on both grounds.
    //
    // Screen y runs down, so a normal pointing up has negative y.
    float sky = 0.5 - 0.5 * clamp(b.N.y, -1.0, 1.0);
    float envRim = mix(mix(0.86, 1.14, sky), mix(1.14, 0.86, sky), paper);

    o.rim = pow(b.fres, mix(3.9, 5.4, paper)) * b.m * wrap * rimK * envRim;

    // Outside only: (1 - m) is zero under the silhouette and rises through it.
    // 0.13 body units of width, down from 0.20: at 0.20 the bloom was wide
    // enough to read as a second disc around the body, and its outer edge met
    // the containment's falloff as a visible dark ring. At 0.13 it is what it
    // was briefed as -- the silhouette not meeting the ink as a cut line.
    float outr = (b.rho - b.Rd) / 0.13;
    float pool = 0.55 + 0.55 * smoothstep(-0.25, 0.85, b.P.y);
    o.glow = exp(-outr * outr) * (1.0 - b.m) * pool * glowK;
    return o;
}

/// THE FINISH, and the one place the two grounds are told apart.
///
/// Ink underneath, the body composited into it by the containment, a knee, and
/// the dither last. Every hero ends on this line, which is most of why they read
/// as one material with twelve things happening inside it.
///
/// THE ARGUMENTS SPLIT because the light ground needs them to. On ink, the
/// interior, the rim, the specular and the contact bloom are all light and all
/// belong in one energy: sum them, walk the rail, done -- which is exactly what
/// happens below when `paper` is zero, bit for bit as the first eight heroes
/// were reviewed. On paper two of the four stop being light:
///
///   THE SPECULAR IS THE ONLY THING BRIGHTER THAN THE PAGE. Everything else in
///   the picture is the page minus something. So it leaves the energy sum -- if
///   it stayed, the descending rail would render the brightest thing in the
///   frame as the darkest -- and comes back as a small mix toward a warm white
///   pushed a little past 1, so it clips crisply against the pale body it sits
///   on. That body being pale is what makes it visible; a catchlight needs a
///   surround, not a brightness.
///
///   THE CONTACT BLOOM BECOMES A CONTACT SHADOW. Light spilling into ink is a
///   glow; the same term on paper is what an object occludes, so it turns into a
///   soft neutral darkening of the page and is weighted further downward, the
///   way a shadow pools under a thing rather than around it. `below` is read
///   from uv rather than from the body, because a shadow belongs to the ground
///   and not to the sphere.
///
/// THE KNEE MOVES with the ground too. At 0.90 it exists to stop a bright field
/// becoming flat white paper -- but when the ground already IS paper, sitting at
/// about 0.91 in linear light, that same knee spends all its headroom on the
/// page and leaves the catchlight nowhere to go. At 0.96 the page passes through
/// almost untouched and the highlight still compresses rather than clipping
/// hard.
///
/// `hue` is the spread offset the hero accumulated, already weighted by which
/// part of the picture is carrying colour: a pixel that is mostly specular gets
/// almost none of it, because a highlight is the colour of the light rather than
/// the colour of the thing it landed on.
static inline half4 mh_present(float body, float spec, float contact, float hue,
                               float2 uv, MHPalette pal, float glow,
                               half4 inkColor, float2 position, float pixelScale) {
    float paper = pal.paper;
    float dark = 1.0 - paper;

    // What walks the rail. On ink that is everything; on paper the specular and
    // the contact term have both left to be composited instead.
    float railE = body + (spec + contact) * dark;
    float3 field = mh_lit(pal, railE, glow, 0.0, 1.0, 0.34, hue);

    float3 inkLin = mh_srgb_to_linear(float3(inkColor.rgb));
    float3 rgb = mix(inkLin, field, mh_containment(uv, 0.72));

    if (paper > 0.002) {
        // THE CATCHLIGHT. A warm white a whisper past the page, so the knee
        // below turns it into a crisp small highlight rather than a soft one.
        float3 lit = mh_oklab_to_linear(mh_lch(min(pal.s0.x * 1.06 + 0.05, 1.02), 0.012, 0.9));
        // A SMOOTHSTEP RATHER THAN A CLAMP, so only the tight lobe's core takes
        // the white. On ink the specular's broad sheen is welcome light; on
        // paper the same sheen mixed toward white spread the catchlight into a
        // grey smudge half the width of the body, because a soft white on a
        // white page has no edge to be soft against. The threshold sits above
        // the broad lobe's ceiling, so what reaches the page is the glint alone.
        rgb = mix(rgb, lit, smoothstep(0.34, 0.92, spec) * paper);

        // THE CONTACT SHADOW, pooled beneath and neutral: an occlusion belongs
        // to the page, so it takes the page's own colour darkened rather than
        // the tone's.
        // A shadow POOLS, it does not ring. The first cut kept three tenths of
        // the term all the way round the body and the sphere came out sitting in
        // a soft grey halo, which is the one thing a contact shadow must never
        // look like. At 0.06 above the centre line and full below it, the page
        // is clean over the top of the object and darkens under it.
        float below = smoothstep(-0.10, 0.66, uv.y / MH_R);
        float3 shade = inkLin * 0.55;
        rgb = mix(rgb, shade, clamp(contact * 2.60, 0.0, 1.0) * (0.06 + 1.05 * below) * paper);
    }

    float knee = mix(0.90, 0.96, paper);
    rgb = float3(mh_knee(rgb.r, knee), mh_knee(rgb.g, knee), mh_knee(rgb.b, knee));
    return mh_out(rgb, position * pixelScale);
}


/// The number of taps down the interior ray. Five, and the argument for exactly
/// five: four leaves a visible banding when a bright core passes between two
/// sample planes, and six costs twenty per cent more for a difference nobody
/// found in a side-by-side. The taps are placed at the segment midpoints, which
/// is a midpoint Riemann rule and is second-order accurate -- the same five
/// samples placed at the segment edges band noticeably worse.
#define MH_TAPS 5

// MARK: - 7. Duet

// DUET. Two lights orbiting a common centre inside the glass: the conversation.
//
// TWO THINGS IN ONE VOLUME IS A DEPTH PROBLEM, and solving it properly is the
// whole species. Two bright blobs going round each other on a flat disc is a
// loading spinner; two bodies passing in front of and behind one another with
// the far one visibly dimmer and partly eaten by the near one is a conversation
// happening in a space. Three separate mechanisms produce that and each is one
// line:
//
//   THE ORBIT IS TILTED and precesses, so the pair's plane is never edge-on for
//   long and never face-on at all. Face-on is the spinner; edge-on is a line.
//   THE FAR ONE IS DIMMER. Both bodies are solved at the view ray's closest
//   approach, so each knows how deep into the glass it is, and exp(-MH_EXT * s)
//   does the rest -- the one at the back is seen through more material and comes
//   out at a third of the light.
//   THE NEAR ONE OCCLUDES THE FAR ONE. Whichever body the ray reaches first
//   attenuates the other by its own density at this pixel. That is the cue that
//   turns "dimmer" into "behind", and without it the pair reads as two lamps at
//   different brightnesses rather than as two objects at two depths.
//
// SOLVED, NOT SAMPLED, for the same reason droplet's heart is: bodies this
// compact marched at five steps come out as the shape of the sampling. Two dot
// products each, exact at every distance, and perfectly round from any angle.
//
// SPREAD IS THE TWO VOICES. One body sits a little warm of the anchor and the
// other a little cool of it, which is why this species carries the collection's
// joint-highest default: the difference between the two lights IS the content,
// and at spread 0 it degrades to two identical lamps, which is a duet with both
// parts written in unison.
//
// THINKING DEFAULT. This copy intentionally removes the other gallery states,
// live signals and gesture clock. The glow balance only sways slowly between
// the two lights, which is the default "conversation ticking over" read.
//
// SIZE: at 18 pt the orbit opens from 0.41 to 0.56 of the body (a tight orbit in
// a small bead is a wobble, not two objects), both bodies grow by half, and the
// size ratio is pushed toward one so the smaller companion cannot vanish. What
// survives is two clean sparks turning around each other, which is the least the
// species can be and still be itself.
[[ stitchable ]] half4 mh_duet(
    float2 position, half4 currentColor, float2 size, float time, float pixelScale,
    half4 inkColor, half4 toneColor,
    float hueShift, float formScale, float speed, float depth, float glow,
    float2 tilt, half4 tone2
) {
    float2 uv = (position - 0.5 * size) / max(min(size.x, size.y), 1.0);
    float S = max(formScale, 0.10);
    float t = time * max(speed, 0.0);

    float sepK    = 0.5;   // how far apart they hold
    float orbitK  = 0.5;   // how fast they go round
    float ratioK  = 0.5;   // how alike in size they are
    float spreadK = 0.6;   // the two voices

    float small = mh_small(size);
    float px = 1.0 / (max(min(size.x, size.y), 1.0) * max(pixelScale, 1.0) * MH_R);

    MHShape sh = mh_shape(0.023 + 0.007 * mh_breath(t, 3.1), 0.0, 1.25);
    MHBody b = mh_body(uv, t, px, sh);

    float3 V = float3(0.0, 0.0, -1.0);
    float3 rd = mh_look(V, b.N, tilt);
    float L = mh_exit(b.P, rd);

    // THE PLANE. Tilt bounded away from face-on and edge-on, wobbling slowly, and
    // precessing so the pair's geometry never repeats.
    float lean = 0.62 + 0.20 * sin(t * 0.037);
    float prec = mh_drift(t, 0.064, 0.45, 2.0);
    float3 e1 = mh_spin(float3(1.0, 0.0, 0.0), prec, 0.0);
    float3 e2 = mh_spin(float3(0.0, sin(lean), cos(lean)), prec, 0.0);
    float3 nrm = cross(e1, e2);

    // Separation at the default thinking values.
    float r = mix(0.30, 0.50, sepK) * mix(1.0, 1.36, small) * S;

    float rate = 0.40 + 0.55 * orbitK;
    float psi = mh_drift(t, rate, 0.40, 3.0);

    // THE BRAID: a weave along the orbit's normal, opposite in sign for the two,
    // running at three times the orbital rate. Off at rest, on under drive.
    float braid = 0.0;

    float3 spoke = cos(psi) * e1 + sin(psi) * e2;
    float3 A =  r * spoke + nrm * braid;
    float3 B = -r * spoke - nrm * braid;

    // Sizes. The ratio closes toward one at small mounts so the companion cannot
    // disappear into a pixel.
    float wA = (0.145 + 0.030 * sepK) * S * mix(1.0, 1.50, small);
    float wB = wA * mix(0.52, 1.0, mix(ratioK, 1.0, small * 0.65));

    // THE BALANCE. A slow sway at rest, pushed decisively by voice.
    float sway = 0.5 + 0.15 * sin(mh_drift(t, 0.21, 0.50, 7.0));
    float bal = clamp(sway, 0.06, 0.94);
    float brA = 2.0 * bal;
    float brB = 2.0 * (1.0 - bal);

    // Both bodies, at the ray's closest approach.
    float3 toA = A - b.P;
    float sA = dot(toA, rd);
    float argA = max(dot(toA, toA) - sA * sA, 0.0) / max(wA * wA, 1e-6);
    float visA = (sA > 0.0 && sA < L) ? mh_inside(b.P + rd * sA) * exp(-MH_EXT * sA) : 0.0;
    float coreA = exp(-argA) * visA;

    float3 toB = B - b.P;
    float sB = dot(toB, rd);
    float argB = max(dot(toB, toB) - sB * sB, 0.0) / max(wB * wB, 1e-6);
    float visB = (sB > 0.0 && sB < L) ? mh_inside(b.P + rd * sB) * exp(-MH_EXT * sB) : 0.0;
    float coreB = exp(-argB) * visB;

    // THE OCCLUSION, and it is the line that turns "dimmer" into "behind".
    // Whichever the ray reaches first eats the other by its own density here.
    float occA = 1.0, occB = 1.0;
    if (sA < sB) { occB = exp(-2.40 * coreA); } else { occA = exp(-2.40 * coreB); }

    float flare = 1.0;
    float eA = (coreA * 1.05 + mh_scatter(argA, 0.30) * visA) * brA * occA * flare;
    float eB = (coreB * 1.05 + mh_scatter(argB, 0.30) * visB) * brB * occB * flare;

    // The medium.
    float medAmt = mix(0.085, 0.044, small);
    float2 acc = float2(0.0);
    float trans = 1.0;
    float ds = L / float(MH_TAPS);

    for (int i = 0; i < MH_TAPS; i++) {
        float3 p = b.P + rd * ((float(i) + 0.5) * ds);
        float fade = mh_inside(p);
        if (fade <= 0.001) continue;

        float med = mh_medium(p, t, 2.2 / S) * medAmt;
        acc.x += med * trans * ds;
        trans *= exp(-(2.20 * med + MH_EXT) * ds);
    }

    float interior = (acc.x * 3.60 + eA + eB) * b.m * mh_transmit(b.fres);

    // THE TWO VOICES: A warm of the anchor, B cool of it, weighted by which body
    // this pixel is actually seeing.
    float hueW = (eA * 0.85 - eB * 1.0);
    float hue = (interior > 1e-4 ? hueW / max(eA + eB, 1e-4) : 0.0) * spreadK * MH_SPREAD;

    MHSurface sf = mh_surface(b, t, small, inkColor, tilt, 0.80, 0.42, 0.15);

    float e = interior + sf.rim + sf.spec + sf.glow;
    float hueMix = hue * (eA + eB) / max(e, 1e-4);

    MHPalette pal = mh_palette(inkColor, toneColor, tone2, hueShift, depth);
    return mh_present(e - sf.spec - sf.glow, sf.spec, sf.glow, hueMix,
                       uv, pal, glow, inkColor, position, pixelScale);
}
