#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform vec2 uPlayerPos;
uniform float uPlayerDir;
uniform sampler2D uMap;
uniform sampler2D uAtlas;

out vec4 fragColor;

uniform float uFov;
uniform float uPitch;
uniform vec4 uAmbientLight; // r,g,b, unused

struct Light {
    vec2 pos;      
    float radius; 
    vec3 color;    
    float intensity;
};

const int MAX_LIGHTS = 8;
uniform float uFogDistance;
uniform vec4 uLightingParams; // x = uLightCount, yzw = unused
uniform vec4 uLightData[MAX_LIGHTS * 2]; 

// OPT: 48 steps covers the full fog distance of 9 units (was 64, wasteful beyond fog).
const int MAX_STEPS = 48;
// Flutter compilers sometimes struggle with struct arrays in uniforms, so packing into vec4 arrays is safer.
// Layout:
// uLightData[i*2 + 0] = vec4(pos.x, pos.y, radius, intensity)
// uLightData[i*2 + 1] = vec4(r, g, b, 0.0)

const float MAP_SIZE = 32.0;

// Atlas Settings
const float TILE_SIZE = 32.0;
const float ATLAS_SIZE = 128.0;
const float TILES_PER_ROW = 4.0;

// Shadow Casting using DDA
float castShadow(vec2 start, vec2 end) {
    vec2 dir = end - start;
    float dist = length(dir);
    if (dist < 0.1) return 1.0;
    
    dir /= dist;
    
    vec2 rayPos = start + dir * 0.1; // Nudge to avoid self-shadowing
    vec2 mapPos = floor(rayPos);
    
    vec2 stepDir = sign(dir);
    vec2 deltaDist = abs(1.0 / dir);
    vec2 sideDist = (stepDir * 0.5 + 0.5 - fract(rayPos) * stepDir) * deltaDist;
    // Fix for when rayPos is exactly on integer boundary if needed, but fract handles it reasonably.
    // Actually standard DDA setup:
    if (dir.x < 0.0) {
        sideDist.x = (rayPos.x - mapPos.x) * deltaDist.x;
    } else {
        sideDist.x = (mapPos.x + 1.0 - rayPos.x) * deltaDist.x;
    }
    if (dir.y < 0.0) {
        sideDist.y = (rayPos.y - mapPos.y) * deltaDist.y;
    } else {
        sideDist.y = (mapPos.y + 1.0 - rayPos.y) * deltaDist.y;
    }
    
    // OPT: 16 steps is sufficient for shadow rays within the light radius (was 30).
    for (int i = 0; i < 16; i++) {
        if (length(mapPos + 0.5 - start) > dist) return 1.0; // Reached light
        
        // Check wall
        vec2 mapUV = (mapPos + 0.5) / MAP_SIZE;
        if (mapUV.x >= 0.0 && mapUV.x < 1.0 && mapUV.y >= 0.0 && mapUV.y < 1.0) {
             vec4 cell = texture(uMap, mapUV);
             if (cell.r * 255.0 > 0.5) return 0.0; // Hit wall
        }

        // Step
        if (sideDist.x < sideDist.y) {
            sideDist.x += deltaDist.x;
            mapPos.x += stepDir.x;
        } else {
            sideDist.y += deltaDist.y;
            mapPos.y += stepDir.y;
        }
    }
    return 1.0;
}

void main() {
    vec2 pos = FlutterFragCoord().xy;
    vec2 uv = pos / uResolution;

    // 1. Ray Calculation
    vec2 plane = vec2(-sin(uPlayerDir), cos(uPlayerDir)) * uFov;
    vec2 dir = vec2(cos(uPlayerDir), sin(uPlayerDir));
    float cameraX = 2.0 * uv.x - 1.0;
    vec2 rayDir = dir + plane * cameraX;

    // 2. Map Setup
    vec2 mapPos = floor(uPlayerPos);
    // Guard: when rayDir component is exactly 0.0, 1.0/0.0 == INF and
    // (playerPos - mapPos) * INF can produce NaN on a cell boundary (0*INF).
    // Use a large sentinel instead so the DDA never steps in that axis.
    vec2 deltaDist = vec2(
        (rayDir.x == 0.0) ? 1e30 : abs(1.0 / rayDir.x),
        (rayDir.y == 0.0) ? 1e30 : abs(1.0 / rayDir.y)
    );
    vec2 stepDir;
    vec2 sideDist;
    
    if (rayDir.x < 0) {
        stepDir.x = -1.0;
        sideDist.x = (uPlayerPos.x - mapPos.x) * deltaDist.x;
    } else {
        stepDir.x = 1.0;
        sideDist.x = (mapPos.x + 1.0 - uPlayerPos.x) * deltaDist.x;
    }
    
    if (rayDir.y < 0) {
        stepDir.y = -1.0;
        sideDist.y = (uPlayerPos.y - mapPos.y) * deltaDist.y;
    } else {
        stepDir.y = 1.0;
        sideDist.y = (mapPos.y + 1.0 - uPlayerPos.y) * deltaDist.y;
    }

    // 3. DDA Loop
    // NOTE: Out-of-bounds rays do NOT set hit=true.  They just break, leaving
    // hit=false so the floor/ceiling background shows through — preventing the
    // large-black-area bug caused by fog-culling a "wall" at the map boundary.
    bool hit = false;
    float side = 0.0;
    float wallType = 0.0;

    for (int i = 0; i < MAX_STEPS; i++) {
        if (sideDist.x < sideDist.y) {
            sideDist.x += deltaDist.x;
            mapPos.x += stepDir.x;
            side = 0.0;
        } else {
            sideDist.y += deltaDist.y;
            mapPos.y += stepDir.y;
            side = 1.0;
        }

        vec2 mapUV = (mapPos + 0.5) / MAP_SIZE;

        // Ray left the map — stop but don't treat as a wall hit.
        if (mapUV.x < 0.0 || mapUV.x >= 1.0 || mapUV.y < 0.0 || mapUV.y >= 1.0) {
            break;
        }

        vec4 cellData = texture(uMap, mapUV);
        float cellType = floor(cellData.r * 255.0 + 0.1);
        if (cellType > 0.5) {
            hit = true;
            wallType = cellType;
            break;
        }
    }

    // ── 4a. Floor / Ceiling (rendered first for EVERY pixel) ──────────────────
    // Doing this unconditionally means the background is always correct even
    // when a ray misses every wall (open area, map boundary, or fog-culled wall).
    float horizon     = uResolution.y / 2.0 + uPitch;
    float diff        = pos.y - horizon;
    // Avoid divide-by-zero at the exact horizon line.
    if (abs(diff) < 1.0) diff = sign(diff) * 1.0;
    if (diff == 0.0)      diff = 1.0;
    float rowDistance = (0.5 * uResolution.y) / abs(diff);
    bool  isFloor     = pos.y > horizon;

    // OPT: Floor/ceiling fog early-exit — skip texture + lighting if fully fogged.
    if (rowDistance > uFogDistance * 0.88) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        vec2 floorPos = uPlayerPos + rowDistance * rayDir;
        vec2 floorUV  = floorPos - floor(floorPos);

        // Floor = Atlas slot 2, Ceiling = slot 3
        float slotIdx = isFloor ? 2.0 : 3.0;
        float tileX   = mod(slotIdx, TILES_PER_ROW);
        float tileY   = floor(slotIdx / TILES_PER_ROW);

        vec2 atlasUV = vec2(
            (tileX * TILE_SIZE + floorUV.x * TILE_SIZE) / ATLAS_SIZE,
            (tileY * TILE_SIZE + floorUV.y * TILE_SIZE) / ATLAS_SIZE
        );

        vec4 texColor  = texture(uAtlas, atlasUV);
        vec3 lighting  = vec3(0.08, 0.10, 0.13);

        for (int i = 0; i < MAX_LIGHTS; i++) {
            if (i >= int(uLightingParams.x)) break;
            vec4 d1 = uLightData[i * 2];
            vec4 d2 = uLightData[i * 2 + 1];
            float dist = distance(floorPos, d1.xy);
            if (dist < d1.z) {
                float att = 1.0 - (dist / d1.z);
                att       = att * att;
                lighting += d2.rgb * d1.w * att;
            }
        }

        if (!isFloor) {
            lighting *= 0.70;
        } else {
            float floorVignette = clamp(1.0 - (rowDistance / 10.0), 0.25, 1.0);
            lighting *= (0.65 * floorVignette);
        }

        vec3  finalColor = texColor.rgb * lighting;
        float fogFactor  = clamp(1.0 - exp(-pow(rowDistance / (uFogDistance * 0.5), 2.0)), 0.0, 1.0);
        fragColor = vec4(mix(finalColor, vec3(0.0), fogFactor), 1.0);
    }

    // ── 4b. Wall (overlays floor/ceiling only for close-enough, visible hits) ─
    if (hit) {
        float perpWallDist = (side == 0.0) ? (sideDist.x - deltaDist.x)
                                           : (sideDist.y - deltaDist.y);

        // OPT: Fog early-exit for wall columns — skip all texture/lighting work
        // for pixels that will be 100% fogged.  We no longer black-out floor/ceiling
        // here; those pixels already have the correct bg colour from step 4a.
        float earlyFog = clamp(1.0 - exp(-pow(perpWallDist / (uFogDistance * 0.5), 2.0)), 0.0, 1.0);
        if (earlyFog < 0.99) {

            // Read door/exit state from channel B (0.0=closed, 1.0=fully open)
            vec2 hitMapUV  = (mapPos + 0.5) / MAP_SIZE;
            vec4 hitCellData = texture(uMap, hitMapUV);
            float doorState  = hitCellData.b;

            float lineHeight  = uResolution.y / perpWallDist;
            float drawStart   = -lineHeight / 2.0 + uResolution.y / 2.0 + uPitch;
            float drawEnd     =  lineHeight / 2.0 + uResolution.y / 2.0 + uPitch;

            // Apply retractable door: shift wall up by doorState * lineHeight
            float raisedStart = drawStart - lineHeight * doorState;
            float raisedEnd   = drawEnd   - lineHeight * doorState;

            bool isExit = (wallType > 4.5 && wallType < 5.5);

            if (pos.y >= raisedStart && pos.y <= raisedEnd && doorState < 1.0) {
                // Wall Texture Calculation
                float wallX;
                if (side == 0.0) {
                    wallX = uPlayerPos.y + perpWallDist * rayDir.y;
                } else {
                    wallX = uPlayerPos.x + perpWallDist * rayDir.x;
                }
                wallX -= floor(wallX);

                float texX = wallX * TILE_SIZE;
                if (side == 0.0 && rayDir.x > 0.0) texX = TILE_SIZE - texX - 1.0;
                if (side == 1.0 && rayDir.y < 0.0) texX = TILE_SIZE - texX - 1.0;

                float texY = (pos.y - raisedStart) / (raisedEnd - raisedStart) * TILE_SIZE;
                texY = clamp(texY, 0.0, TILE_SIZE - 0.1);

                float slotIdx = 1.0;
                float tileX   = mod(slotIdx, TILES_PER_ROW);
                float tileY   = floor(slotIdx / TILES_PER_ROW);

                vec2 atlasUV = vec2(
                    (tileX * TILE_SIZE + texX) / ATLAS_SIZE,
                    (tileY * TILE_SIZE + texY) / ATLAS_SIZE
                );

                vec4 texColor = texture(uAtlas, atlasUV);
                if (isExit) texColor.rgb *= vec3(1.3, 1.0, 0.3);

                // Lighting
                vec3 lighting = vec3(0.08, 0.10, 0.13);

                vec2 hitPos;
                if (side == 0.0) {
                    hitPos.x = (stepDir.x > 0.0) ? mapPos.x : mapPos.x + 1.0;
                    hitPos.y = uPlayerPos.y + perpWallDist * rayDir.y;
                } else {
                    hitPos.y = (stepDir.y > 0.0) ? mapPos.y : mapPos.y + 1.0;
                    hitPos.x = uPlayerPos.x + perpWallDist * rayDir.x;
                }
                vec2 shadowStart = hitPos + (uPlayerPos - hitPos) * 0.01;

                for (int i = 0; i < MAX_LIGHTS; i++) {
                    if (i >= int(uLightingParams.x)) break;
                    vec4 d1 = uLightData[i * 2];
                    vec4 d2 = uLightData[i * 2 + 1];
                    float dist = distance(hitPos, d1.xy);
                    if (dist < d1.z) {
                        // OPT: full shadow-DDA only within 55% of radius.
                        float shadow = (dist < d1.z * 0.55) ? castShadow(shadowStart, d1.xy) : 0.75;
                        float att    = 1.0 - (dist / d1.z);
                        att          = att * att;
                        lighting    += d2.rgb * d1.w * att * shadow;
                    }
                }

                if (side == 1.0) lighting *= 0.7;

                vec3  finalColor = texColor.rgb * lighting;
                float fogFactor  = clamp(1.0 - exp(-pow(perpWallDist / (uFogDistance * 0.5), 2.0)), 0.0, 1.0);
                finalColor = mix(finalColor, vec3(0.0), fogFactor);

                fragColor = vec4(finalColor, 1.0);
            }
            // Pixels outside [raisedStart, raisedEnd] already have correct floor/ceiling from 4a.
        }
        // If earlyFog >= 0.99, wall is fog-black — keep floor/ceiling bg from 4a.
    }
}
