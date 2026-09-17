#include <metal_stdlib>
using namespace metal;

static inline float rumi_hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
}

static inline float rumi_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);

    float a = rumi_hash(i);
    float b = rumi_hash(i + float2(1.0, 0.0));
    float c = rumi_hash(i + float2(0.0, 1.0));
    float d = rumi_hash(i + float2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static inline float rumi_wave(float angle, float time) {
    float a = sin(angle * 3.0 + time * 1.45);
    float b = sin(angle * 5.0 - time * 0.82 + 1.7);
    float c = sin(angle * 9.0 + time * 0.38 + 3.1);
    return (a * 0.52 + b * 0.32 + c * 0.16);
}

static inline float rumi_listening_wave(float angle, float time, float frequency) {
    float f = mix(1.0, 7.0, clamp(frequency, 0.0, 1.0));
    float a = sin(angle * 4.0 + time * (2.0 * f));
    float b = sin(angle * 7.0 - time * (3.1 * f) + 1.7);
    float c = sin(angle * 13.0 + time * (4.4 * f) + 3.1);
    return (a * 0.45 + b * 0.35 + c * 0.20);
}

static inline half4 rumi_orb(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float pixelScale,
    half4 baseColor,
    half4 edgeColor,
    float listeningFrequency
) {
    float side = max(min(size.x, size.y), 1.0);
    float2 center = size * 0.5;
    float2 uv = (position - center) / side;

    float radius = length(uv);
    float angle = atan2(uv.y, uv.x);
    float px = 1.0 / (side * max(pixelScale, 1.0));

    float frequency = clamp(listeningFrequency, 0.0, 1.0);
    float wave = frequency > 0.0 ? rumi_listening_wave(angle, time, frequency) : rumi_wave(angle, time);
    float grainSpeed = mix(0.18, 2.2, frequency);
    float grain = rumi_noise(float2(cos(angle), sin(angle)) * 3.4 + time * grainSpeed);
    float edgeOffset = (wave * 0.030 + (grain - 0.5) * 0.012);
    float orbRadius = 0.315 + edgeOffset;

    float body = 1.0 - smoothstep(orbRadius, orbRadius + px * 2.0, radius);
    float rim = 1.0 - smoothstep(0.0, px * 7.0, abs(radius - orbRadius));
    float innerShade = smoothstep(0.03, orbRadius, radius);

    float3 background = float3(currentColor.rgb);
    float3 base = float3(baseColor.rgb);
    float3 edge = float3(edgeColor.rgb);
    float3 color = mix(base * 0.55, base, 1.0 - innerShade * 0.35);
    color += edge * rim * 0.85;
    color += edge * body * max(wave, 0.0) * 0.06;

    float alpha = max(body * 0.92, rim);
    return half4(half3(saturate(mix(background, color, alpha))), 1.0h);
}

[[ stitchable ]] half4 rumi_idle(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float pixelScale,
    half4 baseColor,
    half4 edgeColor
) {
    return rumi_orb(position, currentColor, size, time, pixelScale, baseColor, edgeColor, 0.0);
}

[[ stitchable ]] half4 rumi_listening(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float pixelScale,
    half4 baseColor,
    half4 edgeColor,
    float listeningFrequency
) {
    return rumi_orb(position, currentColor, size, time, pixelScale, baseColor, edgeColor, listeningFrequency);
}
