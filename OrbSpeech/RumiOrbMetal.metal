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

[[ stitchable ]] half4 rumi_idle(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float pixelScale,
    half4 baseColor,
    half4 edgeColor
) {
    float side = max(min(size.x, size.y), 1.0);
    float2 center = size * 0.5;
    float2 uv = (position - center) / side;

    float radius = length(uv);
    float angle = atan2(uv.y, uv.x);
    float px = 1.0 / (side * max(pixelScale, 1.0));

    float wave = rumi_wave(angle, time);
    float grain = rumi_noise(float2(cos(angle), sin(angle)) * 3.4 + time * 0.18);
    float edgeOffset = (wave * 0.020 + (grain - 0.5) * 0.010);
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
