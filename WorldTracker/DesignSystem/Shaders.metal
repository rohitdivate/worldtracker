#include <metal_stdlib>
using namespace metal;

// Been There's shader library. Everything here is applied transiently from
// ShaderEffects.swift — a compile failure means "no effect", never broken UI.

/// Radial water ripple radiating from a touch point.
/// distortionEffect: returns where each destination pixel samples from.
[[ stitchable ]]
float2 ripple(float2 position, float2 origin, float time,
              float amplitude, float frequency, float decay, float speed) {
    float dist = length(position - origin);
    float delay = dist / speed;
    float t = max(0.0, time - delay);
    float rippleAmount = amplitude * sin(frequency * t) * exp(-decay * t);
    float2 direction = dist > 0.001 ? normalize(position - origin) : float2(0.0, 0.0);
    return position + rippleAmount * direction;
}

/// Diagonal shine sweep — a soft highlight band crossing the view.
/// colorEffect: returns the tinted color for each pixel.
[[ stitchable ]]
half4 shine(float2 position, half4 color, float2 size, float progress) {
    if (color.a < 0.001) {
        return color;
    }
    // 0…1 along the ↘ diagonal; the band is centered on `progress`
    // (driven past both edges so the sweep enters and exits cleanly).
    float band = (position.x + position.y) / max(1.0, size.x + size.y);
    float distanceToBand = abs(band - progress);
    float glow = smoothstep(0.10, 0.0, distanceToBand) * 0.30;
    half3 lifted = min(half3(1.0), color.rgb + half3(glow) * color.a);
    return half4(lifted, color.a);
}
