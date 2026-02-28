#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float itemWidth;
    float itemHeight;
    vec4 primaryColor;
    vec4 secondaryColor;
    float sensitivity;
    float rotationSpeed;
    float barWidth;
    float ringOpacity;
    float cornerRadius;
    float bloomIntensity;
    float visualizationMode; // 0=bars, 1=wave, 2=rings, 3=bars+rings, 4=wave+rings, 5=all
    float waveThickness;
    float innerDiameter;
} ubuf;

// Mode helper functions
bool hasRings() { return ubuf.visualizationMode >= 2.0; }
bool hasBars() { return ubuf.visualizationMode == 0.0 || ubuf.visualizationMode == 3.0 || ubuf.visualizationMode >= 5.0; }
bool hasWave() { return ubuf.visualizationMode == 1.0 || ubuf.visualizationMode == 4.0 || ubuf.visualizationMode >= 5.0; }

layout(binding = 1) uniform sampler2D source;

#define TWOPI 6.28318530718
#define PI 3.14159265359
#define NBARS 32

// Sample audio amplitude at normalized position (0.0-1.0)
float getAudio(float pos) {
    return texture(source, vec2(clamp(pos, 0.0, 1.0), 0.5)).r;
}

// Smoothed audio sampling with interpolation
float smoothAudio(float pos) {
    float idx = pos * float(NBARS - 1);
    float frac = fract(idx);
    float i0 = floor(idx) / float(NBARS - 1);
    float i1 = ceil(idx) / float(NBARS - 1);
    return mix(getAudio(i0), getAudio(i1), frac) * ubuf.sensitivity;
}

// Frequency band helpers
float getBass() { return smoothAudio(0.05); }
float getMid() { return smoothAudio(0.3); }
float getHighMid() { return smoothAudio(0.6); }
float getTreble() { return smoothAudio(0.9); }

// SDF for rounded rectangle
float roundedBoxSDF(vec2 center, vec2 size, float radius) {
    vec2 q = abs(center) - size + radius;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

// Compute polar wave visualization
vec4 computePolarWave(vec2 uv, float iTime, float bass, float mid, float highMid, float treble) {
    float aspect = ubuf.itemWidth / ubuf.itemHeight;
    vec2 centered = (uv - 0.5) * 2.0;
    centered.x *= aspect;

    float theta = atan(centered.y, centered.x);
    float d = length(centered);
    float innerRadius = ubuf.innerDiameter / 2.0;
    float baseRadius = 0.35; // Fixed reference for outer extent

    vec4 color = vec4(0.0);

    // RING SYSTEM
    if (hasRings()) {
        // Center Waves
        if (d < innerRadius * 0.6) {
            float wave = mid * 0.8;
            float ripple = sin(d * 25.0 + wave * 15.0 - iTime * 2.0);
            if (ripple > 0.7) {
                float intensity = clamp(mid * 0.6, 0.0, 0.4);
                vec4 waveColor = ubuf.secondaryColor * intensity * ubuf.ringOpacity;
                color = max(color, waveColor);
            }
        }

        // Energy Ring
        float energyRad = innerRadius * 0.65;
        float energyThickness = 0.015 + clamp(highMid * 0.02, 0.0, 0.03);
        if (d > energyRad - energyThickness && d < energyRad + energyThickness) {
            float segmentAngle = theta * 8.0 + highMid * 3.0 + iTime;
            if (mod(segmentAngle, 1.0) < 0.6) {
                float alpha = clamp(highMid * 2.0, 0.3, 1.0) * ubuf.ringOpacity;
                vec4 energyColor = mix(ubuf.primaryColor, ubuf.secondaryColor, 0.5) * alpha;
                color = max(color, energyColor);
            }
        }

        // Particle Ring
        float particleRad = innerRadius * 0.75;
        if (d > particleRad - 0.02 && d < particleRad + 0.02) {
            float particleAngle = theta + treble * 2.0 + iTime * 0.5;
            float particleSpacing = TWOPI / 16.0;
            if (mod(particleAngle, particleSpacing) < 0.15) {
                float brightness = 0.5 + clamp(treble * 1.5, 0.0, 0.5);
                vec4 particleColor = ubuf.secondaryColor * brightness * ubuf.ringOpacity;
                color = max(color, particleColor);
            }
        }

        // Tech Grid Ring
        float gridRad = innerRadius * 0.85;
        if (d > gridRad - 0.012 && d < gridRad + 0.012) {
            float gridAngle = theta + iTime * ubuf.rotationSpeed;
            float gridDensity = 0.08 + clamp(mid * 0.05, 0.0, 0.1);
            if (mod(gridAngle, 0.2) < gridDensity) {
                vec4 gridColor = ubuf.primaryColor * 0.7 * ubuf.ringOpacity;
                gridColor.rgb += vec3(0.1, 0.15, 0.2) * clamp(mid, 0.0, 0.8);
                color = max(color, gridColor);
            }
        }

        // Accent Ring
        float accentRad = innerRadius * 0.92;
        float pulse = clamp(bass * 0.08, 0.0, 0.05);
        if (d > accentRad - pulse - 0.008 && d < accentRad + pulse + 0.015) {
            float colorShift = clamp(bass * 0.5, 0.0, 1.0);
            vec4 ringColor = mix(ubuf.secondaryColor * 0.7, ubuf.primaryColor, colorShift);
            ringColor.a = ubuf.ringOpacity;
            ringColor.rgb *= 1.0 + bass * 0.3;
            color = max(color, ringColor);
        }

        // Outer Ring
        float outerRad = innerRadius + bass * 0.05;
        if (d > outerRad - 0.008 && d < outerRad + 0.008) {
            vec4 outerColor = ubuf.primaryColor * ubuf.ringOpacity;
            outerColor.rgb += vec3(0.2, 0.3, 0.4) * clamp(treble * 0.5, 0.0, 0.3);
            outerColor.rgb *= 1.0 + bass * 0.4;
            color = max(color, outerColor);
        }
    }

    // POLAR WAVE - filled shape with mirrored bands (64 visual bands from 32 samples)
    if (hasWave()) {
        float adjustedTheta = theta + PI + iTime * ubuf.rotationSpeed * 0.2;

        // Map angle to 0-1 range around the full circle
        float normalizedAngle = mod(adjustedTheta, TWOPI) / TWOPI;

        // Mirror: first half (0-0.5) maps to bands 0->31, second half (0.5-1) maps back 31->0
        float mirroredPos = normalizedAngle < 0.5 ? normalizedAngle * 2.0 : (1.0 - normalizedAngle) * 2.0;

        // Catmull-Rom spline interpolation for smooth curve through mirrored bands
        float bandPos = mirroredPos * float(NBARS - 1);
        float fband1 = floor(bandPos);
        float fband0 = max(fband1 - 1.0, 0.0);
        float fband2 = min(fband1 + 1.0, float(NBARS - 1));
        float fband3 = min(fband1 + 2.0, float(NBARS - 1));

        float t = fract(bandPos);

        // Sample the 4 control points
        float p0 = getAudio(fband0 / float(NBARS - 1)) * ubuf.sensitivity;
        float p1 = getAudio(fband1 / float(NBARS - 1)) * ubuf.sensitivity;
        float p2 = getAudio(fband2 / float(NBARS - 1)) * ubuf.sensitivity;
        float p3 = getAudio(fband3 / float(NBARS - 1)) * ubuf.sensitivity;

        // Catmull-Rom spline interpolation
        float t2 = t * t;
        float t3 = t2 * t;
        float smoothedAudio = 0.5 * (
            (2.0 * p1) +
            (-p0 + p2) * t +
            (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
            (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
        );
        smoothedAudio = max(smoothedAudio, 0.0);

        // Calculate wave radius at this angle
        float waveDisplacement = smoothedAudio * 0.5;
        float waveRadius = baseRadius + waveDisplacement; // Fixed outer extent

        // Fill the entire area from inner to wave edge
        if (d >= innerRadius && d <= waveRadius) {
            float fillFactor = (d - innerRadius) / max(waveRadius - innerRadius, 0.001);

            // Gradient from primary at base to accent at edge
            vec3 fillColor = mix(ubuf.primaryColor.rgb * 0.8, ubuf.secondaryColor.rgb, fillFactor);

            // Boost brightness with bass
            fillColor *= 1.0 + bass * 0.3;

            // Alpha: stronger near the edge, fades toward center
            float fillAlpha = mix(0.4, 1.0, fillFactor) * ubuf.waveThickness;
            fillAlpha = clamp(fillAlpha, 0.0, 1.0);

            vec4 fill = vec4(fillColor, fillAlpha);
            color = max(color, fill);
        }

        // Bright edge line at the wave boundary
        float edgeThickness = ubuf.waveThickness * 0.025;
        float distToEdge = abs(d - waveRadius);
        if (distToEdge < edgeThickness) {
            float edgeFactor = 1.0 - smoothstep(0.0, edgeThickness, distToEdge);
            vec3 edgeColor = ubuf.secondaryColor.rgb * (1.2 + smoothedAudio * 0.5);

            // Add highlight at peaks
            if (smoothedAudio > 0.5) {
                edgeColor += vec3(0.3, 0.4, 0.5) * (smoothedAudio - 0.5);
            }

            vec4 edge = vec4(edgeColor, edgeFactor);
            color = max(color, edge);
        }
    }

    return color;
}

// Compute visualization color at given UV coordinates
// Returns vec4 with RGB color and alpha
vec4 computeVisualization(vec2 uv, float iTime, float bass, float mid, float highMid, float treble) {
    float aspect = ubuf.itemWidth / ubuf.itemHeight;
    vec2 centered = (uv - 0.5) * 2.0;
    centered.x *= aspect;

    float theta = atan(centered.y, centered.x);
    float d = length(centered);
    float innerRadius = ubuf.innerDiameter / 2.0;
    float baseRadius = 0.35; // Fixed reference for outer extent

    vec4 color = vec4(0.0);

    // RING SYSTEM
    if (hasRings()) {
        // Center Waves
        if (d < innerRadius * 0.6) {
            float wave = mid * 0.8;
            float ripple = sin(d * 25.0 + wave * 15.0 - iTime * 2.0);
            if (ripple > 0.7) {
                float intensity = clamp(mid * 0.6, 0.0, 0.4);
                vec4 waveColor = ubuf.secondaryColor * intensity * ubuf.ringOpacity;
                color = max(color, waveColor);
            }
        }

        // Energy Ring
        float energyRad = innerRadius * 0.65;
        float energyThickness = 0.015 + clamp(highMid * 0.02, 0.0, 0.03);
        if (d > energyRad - energyThickness && d < energyRad + energyThickness) {
            float segmentAngle = theta * 8.0 + highMid * 3.0 + iTime;
            if (mod(segmentAngle, 1.0) < 0.6) {
                float alpha = clamp(highMid * 2.0, 0.3, 1.0) * ubuf.ringOpacity;
                vec4 energyColor = mix(ubuf.primaryColor, ubuf.secondaryColor, 0.5) * alpha;
                color = max(color, energyColor);
            }
        }

        // Particle Ring
        float particleRad = innerRadius * 0.75;
        if (d > particleRad - 0.02 && d < particleRad + 0.02) {
            float particleAngle = theta + treble * 2.0 + iTime * 0.5;
            float particleSpacing = TWOPI / 16.0;
            if (mod(particleAngle, particleSpacing) < 0.15) {
                float brightness = 0.5 + clamp(treble * 1.5, 0.0, 0.5);
                vec4 particleColor = ubuf.secondaryColor * brightness * ubuf.ringOpacity;
                color = max(color, particleColor);
            }
        }

        // Tech Grid Ring
        float gridRad = innerRadius * 0.85;
        if (d > gridRad - 0.012 && d < gridRad + 0.012) {
            float gridAngle = theta + iTime * ubuf.rotationSpeed;
            float gridDensity = 0.08 + clamp(mid * 0.05, 0.0, 0.1);
            if (mod(gridAngle, 0.2) < gridDensity) {
                vec4 gridColor = ubuf.primaryColor * 0.7 * ubuf.ringOpacity;
                gridColor.rgb += vec3(0.1, 0.15, 0.2) * clamp(mid, 0.0, 0.8);
                color = max(color, gridColor);
            }
        }

        // Accent Ring
        float accentRad = innerRadius * 0.92;
        float pulse = clamp(bass * 0.08, 0.0, 0.05);
        if (d > accentRad - pulse - 0.008 && d < accentRad + pulse + 0.015) {
            float colorShift = clamp(bass * 0.5, 0.0, 1.0);
            vec4 ringColor = mix(ubuf.secondaryColor * 0.7, ubuf.primaryColor, colorShift);
            ringColor.a = ubuf.ringOpacity;
            ringColor.rgb *= 1.0 + bass * 0.3;
            color = max(color, ringColor);
        }

        // Outer Ring
        float outerRad = innerRadius + bass * 0.05;
        if (d > outerRad - 0.008 && d < outerRad + 0.008) {
            vec4 outerColor = ubuf.primaryColor * ubuf.ringOpacity;
            outerColor.rgb += vec3(0.2, 0.3, 0.4) * clamp(treble * 0.5, 0.0, 0.3);
            outerColor.rgb *= 1.0 + bass * 0.4;
            color = max(color, outerColor);
        }
    }

    // CIRCULAR AUDIO BARS (64 bars, mirrored from 32 audio samples)
    if (hasBars() && d > innerRadius) {
        // Double the visual bars by using NBARS * 2
        float section = TWOPI / float(NBARS * 2);
        float center = section / 2.0;

        float adjustedTheta = theta + PI + iTime * ubuf.rotationSpeed * 0.2;
        float m = mod(adjustedTheta, section);
        float ym = d * sin(center - m);

        float barW = ubuf.barWidth * 0.015;
        if (abs(ym) < barW) {
            // Calculate position in the circle (0.0 to 1.0)
            float circlePos = mod(adjustedTheta, TWOPI) / TWOPI;
            // Mirror: first half (0-0.5) maps to 0-1, second half (0.5-1) maps back 1-0
            float mirroredPos = circlePos < 0.5 ? circlePos * 2.0 : (1.0 - circlePos) * 2.0;
            float v = smoothAudio(mirroredPos);

            float wave = sin(theta * 3.0 + mid * 5.0) * clamp(mid * 0.03, 0.0, 0.05);
            v += wave;
            v = max(v, 0.0);

            float barStart = innerRadius;
            float barEnd = baseRadius + v * 0.5; // Fixed outer extent

            if (d >= barStart && d <= barEnd) {
                float heightFactor = (d - barStart) / max(barEnd - barStart, 0.001);

                vec3 bottomColor = ubuf.primaryColor.rgb * 0.6;
                vec3 middleColor = ubuf.primaryColor.rgb;
                vec3 topColor = ubuf.secondaryColor.rgb;

                vec3 barColor;
                if (heightFactor < 0.5) {
                    barColor = mix(bottomColor, middleColor, heightFactor * 2.0);
                } else {
                    barColor = mix(middleColor, topColor, (heightFactor - 0.5) * 2.0);
                }

                barColor *= 1.0 + bass * 0.4;

                if (heightFactor > 0.85) {
                    barColor += vec3(0.3, 0.4, 0.5) * clamp(treble * 0.8, 0.0, 0.5);
                }

                float edgeFactor = 1.0 - smoothstep(barW * 0.7, barW, abs(ym));
                vec4 finalBarColor = vec4(barColor, edgeFactor);
                color = max(color, finalBarColor);
            }
        }
    }

    return color;
}

void main() {
    // ============================================
    // DYNAMIC CONTENT SCALING
    // ============================================
    // Calculate max possible extent from current settings to guarantee
    // nothing ever reaches the widget border.
    //
    // Max visualization radius in centered space [-1,1]:
    //   Bars/Wave: baseRadius(0.35) + sensitivity * 0.5
    //   Rings:     innerDiameter/2 + sensitivity * 0.05 (always smaller)
    //
    // Bloom reach: exp(-dist * minDecayRate / bloomIntensity) decays to
    // < 1/255 at dist ≈ bloomIntensity * 1.0 (from solving exp decay
    // with worst-case amplitude * multiplier chain)
    //
    // contentScale maps the widget edge to ±contentScale in centered space,
    // so setting it to maxTotalRadius ensures everything fits.

    float maxContentRadius = 0.35 + ubuf.sensitivity * 0.5;
    float maxBloomReach = ubuf.bloomIntensity * 1.0;
    float maxTotalRadius = maxContentRadius + maxBloomReach;
    float contentScale = max(maxTotalRadius * 1.05, 1.0); // 5% safety margin

    vec2 uv = (qt_TexCoord0 - 0.5) * contentScale + 0.5;

    // Convert linear time (0-3600) to smooth oscillation for seamless looping
    // sin() ensures perfect continuity when QML wraps from 3600 back to 0
    float iTime = sin(ubuf.time * TWOPI / 3600.0) * 1800.0 + 1800.0;

    // Frequency analysis
    float bass = getBass();
    float mid = getMid();
    float highMid = getHighMid();
    float treble = getTreble();

    // Get base visualization color based on mode
    // Mode 0: bars only, Mode 1: wave only, Mode 2: rings only
    // Mode 3: bars+rings, Mode 4: wave+rings, Mode 5: all
    vec4 color;
    if (hasWave() && !hasBars()) {
        // Wave only or wave+rings (modes 1, 4)
        color = computePolarWave(uv, iTime, bass, mid, highMid, treble);
    } else if (hasBars() && !hasWave()) {
        // Bars only or bars+rings (modes 0, 3)
        color = computeVisualization(uv, iTime, bass, mid, highMid, treble);
    } else if (hasWave() && hasBars()) {
        // All mode (5) - combine both
        vec4 barsColor = computeVisualization(uv, iTime, bass, mid, highMid, treble);
        vec4 waveColor = computePolarWave(uv, iTime, bass, mid, highMid, treble);
        color = max(barsColor, waveColor);
    } else {
        // Rings only (mode 2) - still need to call one of them for ring rendering
        color = computeVisualization(uv, iTime, bass, mid, highMid, treble);
    }

    // ============================================
    // BLOOM EFFECT - Glow based on distance to geometry
    // ============================================

    if (ubuf.bloomIntensity > 0.01 && color.a < 0.01) {
        // Only apply bloom where there's no geometry (empty space)
        // Find distance to nearest bright element

        float aspect = ubuf.itemWidth / ubuf.itemHeight;
        vec2 centered = (uv - 0.5) * 2.0;
        centered.x *= aspect;
        float d = length(centered);
        float theta = atan(centered.y, centered.x);

        float innerRadius = ubuf.innerDiameter / 2.0;
        float baseRadius = 0.35; // Fixed reference for outer extent
        float glowAmount = 0.0;
        vec3 glowColor = vec3(0.0);

        // Glow from rings (if enabled)
        if (hasRings()) {
            // Outer ring glow
            float outerRad = innerRadius + bass * 0.05;
            float ringDist = abs(d - outerRad);
            float ringGlow = exp(-ringDist * 8.0 / ubuf.bloomIntensity) * (1.0 + bass * 0.5);
            glowColor += ubuf.primaryColor.rgb * ringGlow;
            glowAmount = max(glowAmount, ringGlow);

            // Accent ring glow
            float accentRad = innerRadius * 0.92;
            float accentDist = abs(d - accentRad);
            float accentGlow = exp(-accentDist * 10.0 / ubuf.bloomIntensity) * (0.7 + bass * 0.3);
            glowColor += mix(ubuf.secondaryColor.rgb, ubuf.primaryColor.rgb, 0.5) * accentGlow;
            glowAmount = max(glowAmount, accentGlow);
        }

        // Glow from visualization (bars or polar wave)
        if ((hasBars() || hasWave()) && d > innerRadius * 0.8) {
            float adjustedTheta = theta + PI + iTime * ubuf.rotationSpeed * 0.2;
            float circlePos = mod(adjustedTheta, TWOPI) / TWOPI;
            float mirroredPos = circlePos < 0.5 ? circlePos * 2.0 : (1.0 - circlePos) * 2.0;
            float v = smoothAudio(mirroredPos);

            if (hasWave()) {
                // Polar wave bloom - Catmull-Rom spline with mirroring matching main render
                float mirroredPos = circlePos < 0.5 ? circlePos * 2.0 : (1.0 - circlePos) * 2.0;
                float bandPos = mirroredPos * float(NBARS - 1);
                float fband1 = floor(bandPos);
                float fband0 = max(fband1 - 1.0, 0.0);
                float fband2 = min(fband1 + 1.0, float(NBARS - 1));
                float fband3 = min(fband1 + 2.0, float(NBARS - 1));

                float t = fract(bandPos);
                float p0 = getAudio(fband0 / float(NBARS - 1)) * ubuf.sensitivity;
                float p1 = getAudio(fband1 / float(NBARS - 1)) * ubuf.sensitivity;
                float p2 = getAudio(fband2 / float(NBARS - 1)) * ubuf.sensitivity;
                float p3 = getAudio(fband3 / float(NBARS - 1)) * ubuf.sensitivity;

                float t2 = t * t;
                float t3 = t2 * t;
                float smoothedAudio = 0.5 * (
                    (2.0 * p1) +
                    (-p0 + p2) * t +
                    (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
                    (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
                );
                smoothedAudio = max(smoothedAudio, 0.0);

                float waveRadius = baseRadius + smoothedAudio * 0.5;

                // Glow from the filled area and edge
                float distToWave = abs(d - waveRadius);
                float waveGlow = exp(-distToWave * 8.0 / ubuf.bloomIntensity) * smoothedAudio * 2.5;

                vec3 waveGlowColor = mix(ubuf.primaryColor.rgb, ubuf.secondaryColor.rgb, smoothedAudio);
                glowColor += waveGlowColor * waveGlow;
                glowAmount = max(glowAmount, waveGlow);
            }

            if (hasBars()) {
                // Bars bloom
                float section = TWOPI / float(NBARS * 2);
                float m = mod(adjustedTheta, section);
                float center = section / 2.0;

                float barAngleDist = min(abs(m - center), section - abs(m - center));
                float barEnd = baseRadius + v * 0.5; // Fixed outer extent

                float radialDist = 0.0;
                if (d < innerRadius) {
                    radialDist = innerRadius - d;
                } else if (d > barEnd) {
                    radialDist = d - barEnd;
                }

                float totalDist = length(vec2(barAngleDist * d, radialDist));
                float barGlow = exp(-totalDist * 15.0 / ubuf.bloomIntensity) * v * 2.0;

                float heightFactor = clamp((d - innerRadius) / max(barEnd - innerRadius, 0.001), 0.0, 1.0);
                vec3 barGlowColor = mix(ubuf.primaryColor.rgb, ubuf.secondaryColor.rgb, heightFactor);

                glowColor += barGlowColor * barGlow;
                glowAmount = max(glowAmount, barGlow);
            }
        }

        // Apply bloom
        float bloomMult = ubuf.bloomIntensity * (1.0 + bass * 0.5);
        color.rgb = glowColor * bloomMult;
        color.a = glowAmount * bloomMult * 0.6;

        // Clamp to reasonable values
        color.rgb = min(color.rgb, vec3(1.5));
        color.a = min(color.a, 0.8);
    }

    // ============================================
    // EDGE FADE - radial falloff that only affects the bloom zone
    // ============================================
    // Fade starts just past where main content ends (maxContentRadius)
    // and reaches zero at the widget edge (contentScale) in centered space.
    // This catches bloom tails without affecting the main visualization.

    vec2 fromCenter = (qt_TexCoord0 - 0.5) * 2.0; // -1 to 1 in widget space
    float edgeProximity = max(abs(fromCenter.x), abs(fromCenter.y)); // box distance
    float fadeStart = maxContentRadius / contentScale; // where content ends in widget space
    float edgeFade = 1.0 - smoothstep(fadeStart, 1.0, edgeProximity);
    color *= edgeFade;

    // ============================================
    // CORNER MASKING
    // ============================================

    vec2 pixelPos = qt_TexCoord0 * vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 centerPos = pixelPos - vec2(ubuf.itemWidth, ubuf.itemHeight) * 0.5;
    vec2 halfSize = vec2(ubuf.itemWidth, ubuf.itemHeight) * 0.5;
    float dist = roundedBoxSDF(centerPos, halfSize, ubuf.cornerRadius);
    float cornerMask = 1.0 - smoothstep(-1.0, 0.0, dist);

    // Final output with premultiplied alpha
    float finalAlpha = color.a * ubuf.qt_Opacity * cornerMask;
    fragColor = vec4(color.rgb * finalAlpha, finalAlpha);
}
