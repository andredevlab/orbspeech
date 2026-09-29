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

static inline float rumi_listening_wave(float angle, float time) {
    float a = sin(angle * 4.0 + time * 3.2);
    float b = sin(angle * 7.0 - time * 4.1 + 1.7);
    float c = sin(angle * 13.0 + time * 5.2 + 3.1);
    return (a * 0.45 + b * 0.35 + c * 0.20);
}

static inline float rumi_ease(float value) {
    float t = clamp(value, 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

static inline float rumi_transition_progress(float elapsed, float duration) {
    if (duration <= 0.0) {
        return 1.0;
    }
    return rumi_ease(elapsed / duration);
}

static inline half4 rumi_mix_color(half4 start, half4 target, float progress) {
    return half4(mix(float4(start), float4(target), progress));
}

static inline half4 rumi_orb(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float pixelScale,
    half4 baseColor,
    half4 edgeColor,
    float2 centerOffset,
    float bounce,
    float listeningLevel
) {
    float side = 190.0;
    float bounceScale = 1.0 + clamp(bounce, 0.0, 1.0) * 0.16;
    float2 center = size * 0.5 + centerOffset;
    float2 uv = (position - center) / (side * bounceScale);

    float radius = length(uv);
    float angle = atan2(uv.y, uv.x);
    float px = 1.0 / (side * max(pixelScale, 1.0));

    bool isIdle = listeningLevel < 0.0;
    float level = clamp(listeningLevel, 0.0, 1.0);
    float wave = isIdle ? rumi_wave(angle, time) : rumi_listening_wave(angle, time);
    float grainSpeed = isIdle ? 0.18 : mix(0.18, 1.1, level);
    float grain = rumi_noise(float2(cos(angle), sin(angle)) * 3.4 + time * grainSpeed);
    float edgeAmplitude = isIdle ? 0.030 : 0.105 * level;
    float grainAmplitude = isIdle ? 0.012 : 0.024 * level;
    float edgeOffset = (wave * edgeAmplitude + (grain - 0.5) * grainAmplitude);
    float orbRadius = 0.315 + edgeOffset;

    float body = 1.0 - smoothstep(orbRadius, orbRadius + px * 2.0, radius);
    float rim = 1.0 - smoothstep(0.0, px * 7.0, abs(radius - orbRadius));
    float innerShade = smoothstep(0.03, orbRadius, radius);

    float3 background = float3(currentColor.rgb);
    float3 base = float3(baseColor.rgb);
    float3 edge = float3(edgeColor.rgb);
    float3 color = mix(base * 0.55, base, 1.0 - innerShade * 0.35);
    color += edge * rim * 0.85;
    color += edge * body * max(wave, 0.0) * 0.06 * (isIdle ? 1.0 : level);

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
    half4 edgeColor,
    float2 centerOffset,
    float bounce,
    half4 targetBaseColor,
    half4 targetEdgeColor,
    float2 targetCenterOffset,
    float targetBounce,
    float transitionElapsed,
    float transitionDuration,
    float transientBounceAmplitude
) {
    float progress = rumi_transition_progress(transitionElapsed, transitionDuration);
    half4 resolvedBaseColor = rumi_mix_color(baseColor, targetBaseColor, progress);
    half4 resolvedEdgeColor = rumi_mix_color(edgeColor, targetEdgeColor, progress);
    float2 resolvedCenterOffset = mix(centerOffset, targetCenterOffset, progress);
    float resolvedBounce = mix(bounce, targetBounce, progress) + sin(progress * M_PI_F) * transientBounceAmplitude;
    return rumi_orb(position, currentColor, size, time, pixelScale, resolvedBaseColor, resolvedEdgeColor, resolvedCenterOffset, resolvedBounce, -1.0);
}

[[ stitchable ]] half4 rumi_listening(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float pixelScale,
    half4 baseColor,
    half4 edgeColor,
    float2 centerOffset,
    float bounce,
    half4 targetBaseColor,
    half4 targetEdgeColor,
    float2 targetCenterOffset,
    float targetBounce,
    float transitionElapsed,
    float transitionDuration,
    float transientBounceAmplitude,
    float listeningFrequency
) {
    float progress = rumi_transition_progress(transitionElapsed, transitionDuration);
    half4 resolvedBaseColor = rumi_mix_color(baseColor, targetBaseColor, progress);
    half4 resolvedEdgeColor = rumi_mix_color(edgeColor, targetEdgeColor, progress);
    float2 resolvedCenterOffset = mix(centerOffset, targetCenterOffset, progress);
    float resolvedBounce = mix(bounce, targetBounce, progress) + sin(progress * M_PI_F) * transientBounceAmplitude;
    return rumi_orb(position, currentColor, size, time, pixelScale, resolvedBaseColor, resolvedEdgeColor, resolvedCenterOffset, resolvedBounce, listeningFrequency);
}

[[ stitchable ]] half4 rumi_thinking(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float pixelScale,
    half4 baseColor,
    half4 edgeColor,
    float2 centerOffset,
    float bounce,
    half4 targetBaseColor,
    half4 targetEdgeColor,
    float2 targetCenterOffset,
    float targetBounce,
    float transitionElapsed,
    float transitionDuration,
    float transientBounceAmplitude
) {
    float commandProgress = rumi_transition_progress(transitionElapsed, transitionDuration);
    baseColor = rumi_mix_color(baseColor, targetBaseColor, commandProgress);
    edgeColor = rumi_mix_color(edgeColor, targetEdgeColor, commandProgress);
    centerOffset = mix(centerOffset, targetCenterOffset, commandProgress);
    bounce = mix(bounce, targetBounce, commandProgress) + sin(commandProgress * M_PI_F) * transientBounceAmplitude;
    
    float side = 190.0;
    float bounceScale = 1.0 + clamp(bounce, 0.0, 1.0) * 0.16;
    float2 startCenter = size * 0.5 + centerOffset;
    float2 cornerCenter = float2(side * 0.5 + 18.0, size.y * 0.5);
    float2 plankCenter = float2(-10.0, size.y * 0.5);
    float px = 1.0 / (side * max(pixelScale, 1.0));

    float progress = rumi_ease(time / 1.5);
    float morph = progress;
    float2 shapeCenter = mix(startCenter, cornerCenter, progress);
    shapeCenter = mix(shapeCenter, plankCenter, morph);

    float2 circleScale = float2(side, side) * bounceScale;
    float2 plankScale = float2(34.0, size.y * 0.30);
    float2 shapeScale = mix(circleScale, plankScale, morph);
    float2 uv = (position - shapeCenter) / shapeScale;

    float radius = length(uv);
    float angle = atan2(uv.y, uv.x);
    float wave = mix(
        rumi_wave(angle, time),
        sin(uv.y * 19.0 + time * 3.4) * 1.1 + sin(uv.y * 31.0 - time * 2.1) * 0.55,
        morph
    );
    float grain = rumi_noise(float2(cos(angle), sin(angle)) * 3.4 + time * 0.18);
    float shapeRadius = mix(0.315, 1.0, morph) + wave * mix(0.030, 0.035, morph) + (grain - 0.5) * 0.012;
    float body = 1.0 - smoothstep(shapeRadius, shapeRadius + px * mix(2.0, 18.0, morph), radius);
    float rim = 1.0 - smoothstep(0.0, px * mix(7.0, 24.0, morph), abs(radius - shapeRadius));
    float innerShade = smoothstep(0.03, shapeRadius, radius);

    float3 background = float3(currentColor.rgb);
    float3 base = float3(baseColor.rgb);
    float3 edge = float3(edgeColor.rgb);
    float3 color = mix(base * 0.55, base, 1.0 - innerShade * 0.35);
    color += edge * rim * mix(0.85, 0.72, morph);
    color += edge * body * max(wave, 0.0) * 0.06;
    float alpha = max(body * 0.92, rim);

    return half4(half3(saturate(mix(background, color, alpha))), 1.0h);
}

[[ stitchable ]] half4 rumi_settling(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float pixelScale,
    half4 baseColor,
    half4 edgeColor,
    float2 centerOffset,
    float bounce,
    half4 targetBaseColor,
    half4 targetEdgeColor,
    float2 targetCenterOffset,
    float targetBounce,
    float transitionElapsed,
    float transitionDuration,
    float transientBounceAmplitude
) {
    float commandProgress = rumi_transition_progress(transitionElapsed, transitionDuration);
    baseColor = rumi_mix_color(baseColor, targetBaseColor, commandProgress);
    edgeColor = rumi_mix_color(edgeColor, targetEdgeColor, commandProgress);
    centerOffset = mix(centerOffset, targetCenterOffset, commandProgress);
    bounce = mix(bounce, targetBounce, commandProgress) + sin(commandProgress * M_PI_F) * transientBounceAmplitude;
    
    float side = 190.0;
    float bounceScale = 1.0 + clamp(bounce, 0.0, 1.0) * 0.16;
    float2 startCenter = size * 0.5 + centerOffset;
    float2 cornerCenter = float2(side * 0.5 + 18.0, size.y * 0.5);
    float2 plankCenter = float2(-10.0, size.y * 0.5);
    float px = 1.0 / (side * max(pixelScale, 1.0));

    float progress = rumi_ease(time / 1.5);
    float reverseProgress = 1.0 - progress;
    float morph = reverseProgress;
    float2 shapeCenter = mix(startCenter, cornerCenter, reverseProgress);
    shapeCenter = mix(shapeCenter, plankCenter, morph);

    float2 circleScale = float2(side, side) * bounceScale;
    float2 plankScale = float2(34.0, size.y * 0.30);
    float2 shapeScale = mix(circleScale, plankScale, morph);
    float2 uv = (position - shapeCenter) / shapeScale;

    float radius = length(uv);
    float angle = atan2(uv.y, uv.x);
    float wave = mix(
        rumi_wave(angle, time),
        sin(uv.y * 19.0 + time * 3.4) * 1.1 + sin(uv.y * 31.0 - time * 2.1) * 0.55,
        morph
    );
    float grain = rumi_noise(float2(cos(angle), sin(angle)) * 3.4 + time * 0.18);
    float shapeRadius = mix(0.315, 1.0, morph) + wave * mix(0.030, 0.035, morph) + (grain - 0.5) * 0.012;
    float body = 1.0 - smoothstep(shapeRadius, shapeRadius + px * mix(2.0, 18.0, morph), radius);
    float rim = 1.0 - smoothstep(0.0, px * mix(7.0, 24.0, morph), abs(radius - shapeRadius));
    float innerShade = smoothstep(0.03, shapeRadius, radius);

    float3 background = float3(currentColor.rgb);
    float3 base = float3(baseColor.rgb);
    float3 edge = float3(edgeColor.rgb);
    float3 color = mix(base * 0.55, base, 1.0 - innerShade * 0.35);
    color += edge * rim * mix(0.85, 0.72, morph);
    color += edge * body * max(wave, 0.0) * 0.06;
    float alpha = max(body * 0.92, rim);

    return half4(half3(saturate(mix(background, color, alpha))), 1.0h);
}
